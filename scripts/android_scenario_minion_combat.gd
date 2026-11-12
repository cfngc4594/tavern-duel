extends RefCounted
## Seeded rules and rendering probe for a hand-played minion and its first legal attack.

const CARD := "CS2_172"
const OPPONENT_CARD := "CS2_182"
const PASSES := ["first", "repeat"]
const SUMMON_EVENTS := ["summon_lift", "summon_transform", "summon_reveal", "summon_contact", "summon_settled"]
const ATTACK_EVENTS := ["attack_anticipation", "attack_lunge", "attack_contact", "attack_return"]
const SETTLE_USEC := 650_000

enum Step { SETUP, WAIT_SUMMON, SUMMON, PASS_TURN, WAIT_ATTACK, ATTACK }

var case_results: Array[Dictionary] = []
var _game: Node
var _pass_index := 0
var _step := Step.SETUP
var _ready_at := -1
var _card_id := -1
var _hand_before_summon := -1
var _event_offset := 0

func setup(game: Node) -> void:
	_game = game

func advance(benchmark: Node) -> void:
	var now := Time.get_ticks_usec()
	match _step:
		Step.SETUP:
			_setup_fixture(benchmark)
		Step.WAIT_SUMMON:
			if _settled(benchmark, now):_start_summon(benchmark, now)
		Step.SUMMON:
			_observe_summon(benchmark)
		Step.PASS_TURN:
			_pass_turn(benchmark, now)
		Step.WAIT_ATTACK:
			if _settled(benchmark, now):_start_attack(benchmark, now)
		Step.ATTACK:
			_observe_attack(benchmark)

func _setup_fixture(benchmark: Node) -> void:
	benchmark.phase = "fixture_setup"
	if _game.flow.mode != "normal" or _game.flow.first_side != 0 or _game.flow.seed_value != benchmark.seed_value:
		benchmark.result = "minion_fixture_wrong_match"
		return
	if not is_instance_valid(_game.original_board_bridge.probe):return
	_game.flow.finish_opening()
	if _game.turn != 1 or not _game.player_turn or not _game.allies.is_empty() or not _game.enemies.is_empty() or _game.enemy_deck.is_empty():
		benchmark.result = "minion_fixture_wrong_opening"
		return
	# The fixture seats a Raptor and grants its two mana. The opponent's first
	# draw and hand have no affordable plays, so the real AI passes naturally.
	_game.mana = 2
	_game.max_mana = 2
	_game.enemy_hand.fill(OPPONENT_CARD)
	_game.enemy_deck[0] = OPPONENT_CARD
	_game._add_card(CARD, false)
	_card_id = _game.cards.back().source_presentation_id
	_step = Step.WAIT_SUMMON

func _settled(benchmark: Node, now: int) -> bool:
	benchmark.phase = "fixture_settle"
	if not _game.player_turn or _game.busy or _game.banner_time > 0.0 or _game.cards.any(func(card): return card.get("drawing", false) or card.get("returning", false)):
		_ready_at = -1
		return false
	if _ready_at < 0:_ready_at = now
	return now - _ready_at >= SETTLE_USEC

func _start_summon(benchmark: Node, now: int) -> void:
	var index: int = _game.cards.find_custom(func(card): return card.source_presentation_id == _card_id)
	if index < 0:
		benchmark.result = "minion_fixture_card_missing"
		return
	benchmark.phase = "summon_" + PASSES[_pass_index]
	var pos: Vector2 = _game.source_phone_layout.snapshot.items.friendly_play.center if _game._phone_hand_enabled() else _game.PLAY_RECT.get_center()
	_game.pointer = pos
	_hand_before_summon = _game.cards.size()
	_event_offset = _game.event_trace.size()
	# The empty board has one legal slot. The benchmark has no held-card drag.
	if not _game.play_card(index, pos, 0):
		benchmark.result = "minion_fixture_summon_rejected"
		return
	benchmark._mark_action(benchmark.phase, CARD, now, false)
	_step = Step.SUMMON

func _observe_summon(benchmark: Node) -> void:
	if _game.busy or not _game.native_summon.instances.is_empty():return
	if _game.allies.size() != 1 or not _game.enemies.is_empty() or _game.cards.size() != _hand_before_summon - 1 or _game.mana != 0:
		benchmark.result = "minion_fixture_wrong_summon_state"
		return
	var unit: Dictionary = _game.allies[0]
	if unit.key != CARD or unit.atk != 3 or unit.hp != 2 or unit.hidden or unit.animating or not unit.summoning_sick or _game.can_attack(unit) or _game.health != [30, 30]:
		benchmark.result = "minion_fixture_wrong_summoned_unit"
		return
	if _record(benchmark, unit, SUMMON_EVENTS, 0):
		_step = Step.PASS_TURN

func _pass_turn(benchmark: Node, now: int) -> void:
	benchmark.phase = "fixture_turn"
	_game.end_turn()
	if _game.player_turn:
		benchmark.result = "minion_fixture_end_turn_rejected"
		return
	benchmark._mark_action("minion_fixture_end_turn", "", now, false)
	_ready_at = -1
	_step = Step.WAIT_ATTACK

func _start_attack(benchmark: Node, now: int) -> void:
	if _game.side_turn != [2, 1] or _game.allies.size() != 1 or not _game.enemies.is_empty() or _game.health != [30, 30]:
		benchmark.result = "minion_fixture_wrong_attack_turn"
		return
	var pos: Vector2 = _game.source_phone_layout.snapshot.items.opposing_hero.center if _game._phone_hand_enabled() else _game.ENEMY_HERO
	var target: Dictionary = _game.target_at(pos, 1)
	if target.get("type", "") != "hero" or int(target.side) != 1:
		benchmark.result = "minion_fixture_target_missing"
		return
	benchmark.phase = "attack_" + PASSES[_pass_index]
	_game.pointer = pos
	_event_offset = _game.event_trace.size()
	if not _game.attack(_game.allies[0], target):
		benchmark.result = "minion_fixture_attack_rejected"
		return
	benchmark._mark_action(benchmark.phase, CARD, now, false)
	_step = Step.ATTACK

func _observe_attack(benchmark: Node) -> void:
	var damage: Dictionary = _game.native_damage.entries.get("hero:1", {})
	if _game.busy or not _game.native_combat.effect_player.effects.is_empty() or damage.get("active", false):return
	if _game.allies.size() != 1 or not _game.enemies.is_empty() or _game.health != [30, 27] or _game.mana != 3:
		benchmark.result = "minion_fixture_wrong_attack_state"
		return
	var unit: Dictionary = _game.allies[0]
	if unit.key != CARD or unit.hp != 2 or unit.attacks_used != 1 or unit.animating or _game.can_attack(unit):
		benchmark.result = "minion_fixture_wrong_attacker"
		return
	if not _record(benchmark, unit, ATTACK_EVENTS, 1):return
	if _pass_index == PASSES.size() - 1:
		benchmark.result = "completed"
		return
	benchmark.phase = "fixture_setup"
	_pass_index += 1
	_step = Step.SETUP
	_ready_at = -1
	_game.start_match("normal", 0, benchmark.seed_value)

func _record(benchmark: Node, unit: Dictionary, expected_events: Array, action_index: int) -> bool:
	var events: Array = _game.event_trace.slice(_event_offset).map(func(entry): return entry.event)
	events = events.filter(func(event): return expected_events.has(event))
	if events != expected_events:
		benchmark.result = "minion_fixture_wrong_event_order"
		return false
	var state := {
		"health": _game.health.duplicate(), "mana": _game.mana, "turns": _game.side_turn.duplicate(),
		"hand": _game.cards.map(func(card): return card.key), "deck": _game.deck.duplicate(),
		"opponent_hand": _game.enemy_hand.duplicate(), "opponent_deck": _game.enemy_deck.duplicate(),
		"unit": [unit.key, unit.hp, unit.atk, unit.summoning_sick, unit.attacks_used], "events": events,
	}
	var state_hash := JSON.stringify(state).sha256_text()
	if _pass_index > 0 and case_results[action_index].state_sha256 != state_hash:
		benchmark.result = "minion_fixture_replay_mismatch"
		return false
	case_results.append({
		"case": benchmark.phase, "card": CARD, "health": state.health, "mana": state.mana,
		"turns": state.turns, "unit": state.unit, "events": events, "state_sha256": state_hash,
	})
	return true
