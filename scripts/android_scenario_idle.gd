extends RefCounted
## Production idle board, with frozen diagnostics that retain the last meshes and all render passes.
## Frozen diagnostics attribute cost; their snapshots are not visually equivalent animation.

const CASES := ["idle_reference", "idle_water_frozen", "idle_transmission_frozen", "idle_reference_repeat"]
const SETTLE_USEC := 900_000
const WINDOW_FRAMES := 180

var case_results: Array[Dictionary] = []
var _game: Node
var _probe: Node
var _transmission: Node
var _setup_done := false
var _clock_paused := false
var _saved_clock_delta := -1.0
var _settled_at := -1
var _window_active := false
var _water_samples := PackedInt64Array()
var _window_start: Dictionary
var _window_end: Dictionary
var _viewports: Array[SubViewport] = []
var _viewport_state: Array[Vector3i] = []


func setup(game: Node) -> void:
	_game = game


func advance(benchmark: Node) -> void:
	if not _setup_done:
		benchmark.phase = "fixture_setup"
		if not _open_board():
			finish()
			benchmark.result = "idle_board_setup_failed"
		return
	if _window_active:
		if _water_samples.size() == WINDOW_FRAMES:
			_close_window(benchmark)
		else:
			benchmark.phase = CASES[case_results.size()]
			_water_samples.append(_probe.benchmark_water_particles_usec)
			if _water_samples.size() == WINDOW_FRAMES:
				_window_end = _snapshot()
		return

	benchmark.phase = "fixture_settle"
	if _game.busy or _game.banner_time > 0.0 or _game.cards.any(_is_moving_card):
		_settled_at = -1
		return
	if _settled_at < 0:
		_settled_at = Time.get_ticks_usec()
		return
	if Time.get_ticks_usec() - _settled_at >= SETTLE_USEC:
		_begin_window(benchmark)


func _open_board() -> bool:
	var bridge = _game.original_board_bridge
	if not is_instance_valid(bridge) or not is_instance_valid(bridge.probe):
		return false
	_probe = bridge.probe
	_transmission = _game.native_transmission
	if not is_instance_valid(_probe.water_particles) or not is_instance_valid(_transmission):
		return false
	_viewports = [bridge.viewport, _game.spatial_view, _transmission.transmission_view]
	if _viewports.any(func(view: SubViewport): return not is_instance_valid(view)):
		return false
	_game.flow.finish_opening()
	_saved_clock_delta = _game.flow.test_clock_delta
	_game.flow.test_clock_delta = 0.0
	_clock_paused = true
	_setup_done = _game.player_turn and _game.flow.phase == "playing"
	return _setup_done


func _is_moving_card(card: Dictionary) -> bool:
	return card.get("drawing", false) or card.get("returning", false)


func _begin_window(benchmark: Node) -> void:
	var state := _view_state()
	if state.any(func(view: Vector3i): return view.z != SubViewport.UPDATE_ALWAYS):
		finish()
		benchmark.result = "idle_viewport_not_rendering"
		return
	if not _viewport_state.is_empty() and state != _viewport_state:
		finish()
		benchmark.result = "idle_viewport_changed"
		return
	_viewport_state = state
	var phase: String = CASES[case_results.size()]
	_probe.benchmark_profile_water_particles = true
	_probe.benchmark_freeze_water_particles = phase == "idle_water_frozen"
	_transmission.benchmark_freeze_sync = phase == "idle_transmission_frozen"
	_water_samples = PackedInt64Array()
	_window_start = _snapshot()
	_window_active = true
	# The recorder reads the preceding game frame. Wait for the new switches to
	# take effect before setting the phase label for its first timed sample.


func _close_window(benchmark: Node) -> void:
	var phase: String = CASES[case_results.size()]
	var water_elapsed: float = _window_end.water_elapsed - _window_start.water_elapsed
	var mirror_steps: int = _window_end.mirror_frames - _window_start.mirror_frames
	var board_steps: int = _window_end.board_frames - _window_start.board_frames
	var water_frozen: bool = _probe.benchmark_freeze_water_particles
	var mirror_frozen: bool = _transmission.benchmark_freeze_sync
	benchmark.phase = "fixture_settle"
	_reset_switches()
	var expected_mirror_steps := 0 if mirror_frozen else WINDOW_FRAMES
	if board_steps != WINDOW_FRAMES or (water_elapsed == 0.0) != water_frozen or mirror_steps != expected_mirror_steps:
		finish()
		benchmark.result = "idle_switch_invariant_failed"
		return
	if _view_state() != _viewport_state:
		finish()
		benchmark.result = "idle_viewport_changed"
		return
	case_results.append({
		"phase": phase,
		"sample_frames": WINDOW_FRAMES,
		"water_advance_usec": _water_statistics(),
		"water_elapsed_sec": snappedf(water_elapsed, 0.000001),
		"transmission_sync_calls": mirror_steps,
		"transmission_mirrors": _transmission.mirrors.size(),
		"viewport_update_modes": [_viewport_state[0].z, _viewport_state[1].z, _viewport_state[2].z],
		"diagnostic_freeze": water_frozen or mirror_frozen,
	})
	_window_active = false
	_settled_at = -1
	if case_results.size() == CASES.size():
		finish()
		benchmark.result = "completed"


func _snapshot() -> Dictionary:
	return {"water_elapsed": _probe.water_particles.elapsed, "board_frames": _probe.process_count,
		"mirror_frames": _transmission.frame_number}


func _view_state() -> Array[Vector3i]:
	var state: Array[Vector3i] = []
	for view in _viewports:
		state.append(Vector3i(view.size.x, view.size.y, view.render_target_update_mode))
	return state


func _water_statistics() -> Dictionary:
	_water_samples.sort()
	var sum := 0
	for sample in _water_samples:
		sum += sample
	return {"mean": float(sum) / WINDOW_FRAMES, "p50": _percentile(0.5), "p95": _percentile(0.95),
		"p99": _percentile(0.99), "max": _water_samples[-1]}


func _percentile(fraction: float) -> int:
	return _water_samples[ceili(WINDOW_FRAMES * fraction) - 1]


func _reset_switches() -> void:
	if is_instance_valid(_probe):
		_probe.benchmark_profile_water_particles = false
		_probe.benchmark_freeze_water_particles = false
	if is_instance_valid(_transmission):
		_transmission.benchmark_freeze_sync = false


func finish() -> void:
	_reset_switches()
	if _clock_paused and is_instance_valid(_game):
		_game.flow.test_clock_delta = _saved_clock_delta
	_clock_paused = false
