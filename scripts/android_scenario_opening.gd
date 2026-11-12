extends RefCounted
## Real opening and first player draw, replayed with the same seed in one process.

const PASSES := ["first", "repeat"]
const SETTLE_USEC := 650_000

var case_results: Array[Dictionary] = []
var _game: Node
var _pass_index := 0
var _draw_key := ""
var _deck_before_draw := -1
var _draw_started := false
var _settled_at := -1
var _first_state_hash := ""

func setup(game: Node) -> void:
	_game = game

func advance(benchmark: Node) -> void:
	var flow = _game.flow
	if flow.mode != "normal" or flow.first_side != 0 or flow.seed_value != benchmark.seed_value:
		benchmark.result = "opening_fixture_wrong_match"
		return
	var suffix: String = PASSES[_pass_index]
	var now := Time.get_ticks_usec()
	if _settled_at >= 0:
		benchmark.phase = "opening_settle_" + suffix
		if now - _settled_at >= SETTLE_USEC:
			_restart_or_finish(benchmark)
		return
	if flow.phase != "playing":
		benchmark.phase = "opening_%s_%s" % [flow.phase, suffix]
		if flow.phase == "mulligan" and flow.phase_time >= 0.5:
			benchmark._confirm_mulligan()
		elif flow.phase == "gather":
			if _game.deck.is_empty():
				benchmark.result = "opening_fixture_empty_deck"
				return
			_draw_key = str(_game.deck.front())
			_deck_before_draw = _game.deck.size()
		return
	_observe_draw(benchmark, suffix, now)

func _observe_draw(benchmark: Node, suffix: String, now: int) -> void:
	var draw_phase := "opening_draw_" + suffix
	benchmark.phase = draw_phase
	if _draw_key.is_empty() or not _game.player_turn or _game.turn != 1:
		benchmark.result = "opening_fixture_missing_first_draw"
		return
	var opening_hand: Array = _game.flow.opening_hand
	if _game.cards.size() != opening_hand.size() + 1 or _game.deck.size() != _deck_before_draw - 1:
		benchmark.result = "opening_fixture_wrong_card_counts"
		return
	var drawn: Dictionary = _game.cards.back()
	if drawn.key != _draw_key:
		benchmark.result = "opening_fixture_wrong_draw_card"
		return
	if not _draw_started:
		_draw_started = true
		benchmark._mark_action(draw_phase, _draw_key, now, false)
	if drawn.drawing:
		return
	var counts := {"opening_deal": 0, "mulligan_confirm": 0, "opening_complete": 0, "draw_depart": 0, "draw_seated": 0}
	for entry in _game.event_trace:
		if counts.has(entry.event):
			counts[entry.event] += 1
	if counts.opening_deal < 1 or _game.flow.deal_announced != _game.flow.first_hand_count or counts.mulligan_confirm != 1 or counts.opening_complete != 1 or counts.draw_depart != 1 or counts.draw_seated != 1:
		benchmark.result = "opening_fixture_wrong_trigger_counts"
		return
	var hand: Array = _game.cards.map(func(card): return card.key)
	if hand.slice(0, opening_hand.size()) != opening_hand:
		benchmark.result = "opening_fixture_wrong_opening_hand"
		return
	var state_hash := JSON.stringify({
		"hand": hand, "deck": _game.deck, "opponent_hand": _game.enemy_hand, "opponent_deck": _game.enemy_deck,
		"replacement": _game.flow.replacement_history, "health": _game.health, "turns_by_side": _game.side_turn,
		"mana": _game.mana, "enemy_mana": _game.enemy_mana
	}).sha256_text()
	case_results.append({
		"case": "opening_" + suffix, "seed": benchmark.seed_value,
		"deal_phase": "opening_deal_" + suffix, "draw_phase": draw_phase,
		"dealt": _game.flow.deal_announced, "drawn": _draw_key, "hand": hand,
		"deck_before": _deck_before_draw, "deck_after": _game.deck.size(),
		"draw_depart": counts.draw_depart, "draw_seated": counts.draw_seated, "state_sha256": state_hash
	})
	if _pass_index == 0:
		_first_state_hash = state_hash
	elif state_hash != _first_state_hash:
		benchmark.result = "opening_fixture_replay_mismatch"
		return
	_settled_at = now

func _restart_or_finish(benchmark: Node) -> void:
	if _pass_index == PASSES.size() - 1:
		benchmark.result = "completed"
		return
	benchmark.phase = "opening_reset"
	_pass_index += 1
	_draw_key = ""
	_deck_before_draw = -1
	_draw_started = false
	_settled_at = -1
	_game.start_match("normal", 0, benchmark.seed_value)
