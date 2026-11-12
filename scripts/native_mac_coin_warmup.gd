extends RefCounted
## Render the opening coin through its production color and transmission views.
## The game retains its own prepared coin, which starts on the usual deal frame.

const CoinPresentation = preload("res://scripts/native_coin_presentation.gd")
const FLAG := "--mac-opening-coin-warmup"
const SKIP_FLAG := "--mac-skip-opening-coin-warmup"
const SETTING := "render_quality/macos_opening_coin_warmup"
const SAMPLE_TIMES := [0.02, 0.22]

var wall_usec := 0
var completed_batches := 0
var _started_usec := 0
var _next_sample := 0
var _sample_time := 0.0
var _finished := false
var _preview: Node
var _draw_callback := Callable()

static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return OS.has_feature("macos") and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and not args.has(SKIP_FLAG) and (args.has(FLAG) or bool(ProjectSettings.get_setting(SETTING, false)))

func advance(game: Node) -> bool:
	if _finished:return true
	if _draw_callback.is_valid():return false
	if not is_instance_valid(_preview):
		if not game.native_initial_loading or game.world_canvas.visible or game.flow.mode != "normal":return true
		var prepared: Dictionary = game.flow.visuals.prepared_coin_assets
		if prepared.is_empty():return true
		_started_usec = Time.get_ticks_usec()
		_preview = CoinPresentation.new()
		_preview.name = "OpeningCoinShaderWarmup"
		game.add_child(_preview)
		_preview.setup(game, prepared)
		_preview.set_process(false)
		_preview.player.audio_enabled = false
		var seeds: Array[int] = []
		for index in _preview.player.drop_source.source.emitters.size():seeds.append(5834 + index)
		_preview.player.drop_source.inject_source_seeds(seeds)
		_preview.begin_source_drop(game.flow.first_side == 0)
		game.native_startup_timing.mark("opening_coin_shader_warmup_begin", {"first_side":game.flow.first_side,"size":str(_preview.viewport.size)})
	if _next_sample == SAMPLE_TIMES.size():
		cancel()
		wall_usec = Time.get_ticks_usec() - _started_usec
		game.native_startup_timing.mark("opening_coin_shader_warmup_end", {"wall_usec":wall_usec,"batches":completed_batches})
		return true
	var started := Time.get_ticks_usec()
	var next_time: float = SAMPLE_TIMES[_next_sample]
	_preview.advance_source(next_time - _sample_time, float(game.elapsed))
	_preview.sync_composite()
	_sample_time = next_time
	_next_sample += 1
	_draw_callback = _sample_drawn.bind(game, started)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	if not is_instance_valid(_preview):return
	_preview.set_active(false)
	_preview.player.finish_coin_object()
	_preview.queue_free()
	_preview = null

func _sample_drawn(game: Node, started: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game) or not is_instance_valid(_preview):return
	completed_batches += 1
	game.native_startup_timing.mark("opening_coin_shader_warmup_drawn", {
		"sample_age":_sample_time,"wall_usec":Time.get_ticks_usec()-started,
		"color_draw_calls":_preview.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"transmission_draw_calls":_preview.transmission.transmission_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
	})
