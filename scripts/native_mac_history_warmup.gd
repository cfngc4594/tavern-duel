extends RefCounted
## Draw the real history tiles behind the loading canvas before their first use.

const CARD := "CS2_172"
const KINDS := ["played", "attack"]
const ENABLED_SETTING := "render_quality/macos_history_shader_warmup"

var wall_usec := 0
var completed_batches := 0
var _game: Node
var _staged: Node3D
var _draw_callback := Callable()
var _started_usec := -1
var _next_kind := 0
var _finished := false

static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return OS.has_feature("macos") and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and not args.has("--mac-skip-history-warmup") \
		and (args.has("--mac-history-warmup") or bool(ProjectSettings.get_setting(ENABLED_SETTING, false)))

func advance(game: Node) -> bool:
	if _finished:return true
	if _draw_callback.is_valid():return false
	if not _can_stage(game):
		cancel()
		return true
	if _started_usec < 0:
		_game = game
		_started_usec = Time.get_ticks_usec()
		game.native_startup_timing.mark("history_shader_warmup_begin")
	if _next_kind == KINDS.size():
		_finished = true
		wall_usec = Time.get_ticks_usec() - _started_usec
		game.native_startup_timing.mark("history_shader_warmup_end", {"wall_usec":wall_usec,"batches":completed_batches})
		return true
	var kind: String = KINDS[_next_kind]
	_next_kind += 1
	var started := Time.get_ticks_usec()
	var renderer: Node3D = game.spatial_scene.phone_history_renderer
	var tile: Dictionary = renderer._make({"serial":-1,"kind":kind,"key":CARD,"side":0})
	if tile.is_empty():
		game.native_startup_timing.mark("history_shader_warmup_tile_unavailable", {"kind":kind})
		return false
	_staged = tile.root
	# The live tile enters from offscreen. Warm the actual first-slot pose so
	# the camera sees all its surfaces during this draw.
	_staged.position = renderer.top_position() + Vector3(0, 0, float(tile.size) * 0.5 if tile.half else 0.0)
	game.native_transmission.sync()
	_draw_callback = _on_drawn.bind(kind, started)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	_release_tile()

func _can_stage(game: Node) -> bool:
	return game.native_initial_loading and is_instance_valid(game.world_canvas) and not game.world_canvas.visible \
		and is_instance_valid(game.spatial_scene) and is_instance_valid(game.spatial_scene.phone_history_renderer) \
		and is_instance_valid(game.spatial_view) and is_instance_valid(game.native_transmission)

func _on_drawn(kind: String, started: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(_game) or not is_instance_valid(_staged):return
	var surfaces := 0
	for mesh in _staged.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree() and mesh.mesh != null:surfaces += mesh.mesh.get_surface_count()
	if surfaces > 0:completed_batches += 1
	_game.native_startup_timing.mark("history_shader_warmup_tile_drawn", {
		"kind":kind,"wall_usec":Time.get_ticks_usec()-started,"surfaces":surfaces,
		"color_draw_calls":_game.spatial_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"transmission_draw_calls":_game.native_transmission.transmission_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
	})
	_release_tile()

func _release_tile() -> void:
	if not is_instance_valid(_staged):return
	_staged.hide()
	_staged.queue_free()
	_staged = null
	if is_instance_valid(_game) and _game.is_inside_tree() and is_instance_valid(_game.native_transmission):
		_game.native_transmission.sync()
