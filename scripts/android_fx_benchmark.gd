extends RefCounted
## Short opt-in fixture. Use the live card and terminal rules with real frame deltas.
const ARM_SETTING := "render_quality/android_fx_benchmark_arm"
const ARM_ORDER_ARG := "--android-fx-ab-order="
const ARM_ID_ARG := "--android-fx-ab-id="
const CASES := ["fireball_cold", "fireball_repeat", "coin_cold", "coin_repeat", "endgame_cold", "endgame_repeat"]
const HEAVY_SPELL_CASES := ["fireball_first", "fireball_repeat", "fireblast_first", "fireblast_repeat"]
const TERMINAL_CASES := ["terminal_first", "terminal_repeat"]
const FIREBALL := "CS2_029"
const FIREBLAST := "CS2_034"
const COIN := "GAME_005"
const SETTLE_USEC := 650_000
const EFFECT_HOLD_USEC := 1_800_000
const RESULT_HOLD_SECONDS := 1.0

var arm := "reference"
var run_index := 0
var error := ""
var case_results: Array[Dictionary] = []
var terminal_audits: Array[Dictionary] = []
var _counter_path := ""
var _scenario := ""
var _cases := CASES
var _case_index := 0
var _opened := false
var _prepared_at := -1
var _triggered_at := -1
var _result_frame := -1
var _game: Node

func setup(game: Node, args: PackedStringArray) -> void:
	_game = game
	var order := PackedStringArray(["reference"])
	var run_id := ""
	for arg in args:
		if arg.begins_with(ARM_ORDER_ARG):
			order = arg.trim_prefix(ARM_ORDER_ARG).split(",")
		elif arg.begins_with(ARM_ID_ARG):
			run_id = arg.trim_prefix(ARM_ID_ARG)
	for item in order:
		if item not in ["reference", "candidate", "spell", "endgame", "no_bloom", "candidate_hero_lite", "candidate_spell_lite"]:
			error = "invalid_fx_arm_order"
			return
	if order.is_empty():
		error = "invalid_fx_arm_order"
		return
	if order.size() > 1:
		var order_key := (",".join(order) + ":" + run_id).sha256_text().substr(0, 16)
		_counter_path = "user://android-fx-benchmark-" + order_key + ".txt"
		if FileAccess.file_exists(_counter_path):
			var value := FileAccess.get_file_as_string(_counter_path).strip_edges()
			if not value.is_valid_int() or int(value) < 0:
				error = "invalid_fx_arm_counter"
				return
			run_index = int(value)
	arm = order[run_index % order.size()]
	ProjectSettings.set_setting(ARM_SETTING, arm)

func setup_scenario(game: Node, scenario: String) -> void:
	_game = game
	_scenario = scenario
	arm = "production"
	match scenario:
		"heavy-spell": _cases = HEAVY_SPELL_CASES
		"terminal": _cases = TERMINAL_CASES
		_: error = "invalid_fx_scenario"

func finish() -> bool:
	if _counter_path.is_empty():
		return true
	var counter := FileAccess.open(_counter_path, FileAccess.WRITE)
	if counter == null:
		return false
	counter.store_string(str(run_index + 1))
	counter.flush()
	return counter.get_error() == OK

func advance(benchmark: Node) -> void:
	if not error.is_empty():
		benchmark.result = error
		return
	if not _opened:
		benchmark.phase = "fixture_setup"
		if _scenario == "terminal":
			_game.native_endgame.profile_screen_construction = true
		_game.flow.finish_opening()
		_opened = true
		return
	var now := Time.get_ticks_usec()
	var case_name: String = _cases[_case_index]
	if _triggered_at >= 0:
		if _is_terminal():
			_observe_terminal(benchmark, case_name)
		elif not _game.busy and now - _triggered_at >= EFFECT_HOLD_USEC:
			_observe_spell(benchmark, case_name)
		return
	benchmark.phase = "fixture_settle"
	if _prepared_at < 0:
		if _game.cards.any(func(card): return card.get("drawing", false) or card.get("returning", false)):
			return
		_prepare_case()
		_prepared_at = now
		return
	if now - _prepared_at < SETTLE_USEC:
		return
	benchmark.phase = "hero_death_" + _terminal_pass() if _scenario == "terminal" else case_name
	_triggered_at = now
	if _is_terminal():
		# Match the winning result in the full-match trace, through its real gate.
		_game.health = [24, -2]
		_game._check_victory()
		benchmark._mark_action(case_name, "win", now, false)
	else:
		var key := _card_key()
		var target := _target_point(key)
		_game.pointer = target
		if key == FIREBLAST:
			_game.targeting_power = true
			_game._begin_spell_audio_preview(FIREBLAST)
			_game._resolve_target(target)
			if not _game.power_used:
				benchmark.result = "fx_hero_power_rejected_" + case_name
		elif not _game.play_card(_game.cards.size() - 1, target):
			benchmark.result = "fx_card_rejected_" + case_name
		benchmark._mark_action(case_name, key, now, false)

func _prepare_case() -> void:
	_game._clear_temporary_mana(0)
	_game.mana = 4
	_game.max_mana = 4
	_game.health = [30, 30]
	if not _is_terminal():
		var key := _card_key()
		if key == FIREBLAST:
			_game.power_used = false
		else:
			_game._add_card(key, false)

func _is_terminal() -> bool:
	return _scenario == "terminal" or (_scenario.is_empty() and _case_index >= 4)

func _terminal_pass() -> String:
	return "first" if _case_index == 0 else "repeat"

func _card_key() -> String:
	if _case_index < 2:
		return FIREBALL
	return FIREBLAST if _scenario == "heavy-spell" else COIN

func _target_point(key: String) -> Vector2:
	if _game._phone_hand_enabled():
		var zone := "friendly_play" if key == COIN else "opposing_hero"
		return _game.source_phone_layout.snapshot.items[zone].center
	return _game.PLAY_RECT.get_center() if key == COIN else _game.ENEMY_HERO

func _observe_spell(benchmark: Node, case_name: String) -> void:
	var key := _card_key()
	var expected_health := 24 if key == FIREBALL else 30
	var expected_mana := 0 if key == FIREBALL else 5
	if key == FIREBLAST:
		expected_health = 29
		expected_mana = 2
	if _game.health[1] != expected_health or _game.mana != expected_mana:
		benchmark.result = "fx_wrong_spell_result_" + case_name
		return
	case_results.append({"case": case_name, "health": _game.health.duplicate(), "mana": _game.mana})
	_next_case(benchmark)

func _observe_terminal(benchmark: Node, case_name: String) -> void:
	var endgame = _game.native_endgame
	if endgame.state in ["waiting_source", "waiting_screen"]:
		benchmark.result = endgame.state
		return
	if endgame.state != "result" or not is_instance_valid(endgame.screen):
		return
	if _result_frame < 0:
		_result_frame = benchmark.frame + 1
		if _scenario == "terminal":
			benchmark.phase = "settlement_" + _terminal_pass()
	if endgame.screen.age < RESULT_HOLD_SECONDS:
		return
	if endgame.result.get("outcome") != "win":
		benchmark.result = "fx_wrong_terminal_result"
		return
	if _scenario == "terminal" and (_game.health != [24, -2] or endgame.result.get("dead_sides") != [1]):
		benchmark.result = "fx_wrong_terminal_health"
		return
	case_results.append({"case": case_name, "health": _game.health.duplicate(), "outcome": "win"})
	var background = endgame.screen.background_effect
	if is_instance_valid(background):
		var audit: Dictionary = background.get_audit()
		var summary := {
			"case": case_name, "result_frame": _result_frame,
			"mode": audit.get("backdrop_mode", ""), "viewports": audit.get("backdrop_viewports", 0),
			"backdrop_setup_usec": audit.get("backdrop_setup_usec", 0), "result_setup_usec": audit.get("result_setup_usec", 0),
			"result_viewports": audit.get("live_result_viewports", 0)
		}
		if _scenario == "terminal":
			summary["screen_show_usec"] = endgame.screen_show_usec
		terminal_audits.append(summary)
	if _case_index + 1 < _cases.size():
		benchmark.phase = "fixture_settle"
		endgame.clear()
		_game.game_over = false
		_game.won = false
		_game.health = [30, 30]
	_next_case(benchmark)

func _next_case(benchmark: Node) -> void:
	_case_index += 1
	_prepared_at = -1
	_triggered_at = -1
	_result_frame = -1
	if _case_index == _cases.size():
		benchmark.result = "completed"
