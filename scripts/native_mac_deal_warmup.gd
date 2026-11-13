extends RefCounted
## Stage the two geometry paths first visible when the opening deal begins.
## The live opening timeline, input and audio remain under the match flow.

const OpeningPresentation = preload("res://scripts/native_opening_presentation.gd")
const SourceProjection = preload("res://scripts/source_board_projection.gd")
const HandHighlight = preload("res://shaders/native_hand_highlight.gdshader")
const FLAG := "--mac-opening-deal-warmup"
const SKIP_FLAG := "--mac-skip-opening-deal-warmup"
const SETTING := "render_quality/macos_opening_deal_warmup"
const HAND_SETTING := "render_quality/macos_hand_highlight_warmup"
const STAGES := ["first_card", "choose_banner"]
const SAMPLE_AGE := 0.04

var wall_usec := 0
var completed_batches := 0
var _started_usec := 0
var _next_stage := 0
var _finished := false
var _preview: Node
var _hand_glow: MeshInstance3D
var _card: Dictionary = {}
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
		if game.flow.opening_hand.is_empty() or not game.native_card_renderer.cards.has(game.flow.opening_hand[0]):return true
		_started_usec = Time.get_ticks_usec()
		_preview = OpeningPresentation.new()
		_preview.name = "OpeningDealShaderWarmup"
		game.add_child(_preview)
		_preview.setup(game, true)
		_preview.set_active(true)
		_preview.tooltip_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_preview.tooltip_transmission.transmission_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_preview.cosmetic.seed = 5834
		_preview.phase = "deal"
		var projection = SourceProjection.from_game(game)
		if projection != null:projection.copy_camera(_preview.camera)
		game.native_startup_timing.mark("opening_deal_shader_warmup_begin", {"first_card":game.flow.opening_hand[0],"size":str(_preview.viewport.size)})
	if _next_stage == STAGES.size() and _hand_enabled():
		_next_stage += 1
		_stage_hand_highlight(game)
		return false
	if _next_stage >= STAGES.size():
		cancel()
		wall_usec = Time.get_ticks_usec() - _started_usec
		game.native_startup_timing.mark("opening_deal_shader_warmup_end", {"wall_usec":wall_usec,"batches":completed_batches})
		return true
	var started := Time.get_ticks_usec()
	var stage: String = STAGES[_next_stage]
	_next_stage += 1
	if stage == "first_card":
		_card = _preview._source_card(game.flow.opening_hand[0])
		_preview._apply_pose(_card, _preview._card_pose(0, SAMPLE_AGE))
	else:
		_card.root.visible = false
		_preview.ui.banner.root.visible = true
		_preview._start_particles(_preview.ui.banner, 0.0)
		for row in _preview.particles:
			row.node.seek(SAMPLE_AGE)
			if row.node.material is ShaderMaterial:
				row.node.material.set_shader_parameter("_UnityTimeX", float(game.elapsed) / 20.0)
	_preview.transmission.sync()
	_draw_callback = _sample_drawn.bind(game, stage, started)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	if is_instance_valid(_hand_glow):
		_hand_glow.hide()
		_hand_glow.queue_free()
		_hand_glow = null
	_card.clear()
	if not is_instance_valid(_preview):return
	_preview.dispose()
	_preview.queue_free()
	_preview = null

static func _hand_enabled() -> bool:
	return bool(ProjectSettings.get_setting(HAND_SETTING, false)) \
		and not OS.get_cmdline_user_args().has("--mac-skip-hand-highlight-warmup")

func _stage_hand_highlight(game: Node) -> void:
	# The hand-ready material first appears after the first playable draw.
	# Submit the same shader to both real board targets while the canvas is hidden.
	var started := Time.get_ticks_usec()
	var camera: Camera3D = game.spatial_scene.camera
	var material := ShaderMaterial.new()
	material.shader = HandHighlight
	_hand_glow = MeshInstance3D.new()
	_hand_glow.name = "HandReadyShaderWarmup"
	_hand_glow.mesh = QuadMesh.new()
	_hand_glow.material_override = material
	_hand_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.spatial_scene.add_child(_hand_glow)
	_hand_glow.global_transform = Transform3D(camera.global_basis,
		camera.project_position(game.spatial_view.get_visible_rect().size * 0.5, 3.0))
	game.native_transmission.sync()
	_draw_callback = _hand_drawn.bind(game, started)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)

func _hand_drawn(game: Node, started: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game) or not is_instance_valid(_hand_glow):return
	_hand_glow.hide()
	_hand_glow.queue_free()
	_hand_glow = null
	game.native_transmission.sync()
	completed_batches += 1
	game.native_startup_timing.mark("hand_highlight_shader_warmup_drawn", {"wall_usec":Time.get_ticks_usec()-started})

func _sample_drawn(game: Node, stage: String, started: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game) or not is_instance_valid(_preview):return
	completed_batches += 1
	game.native_startup_timing.mark("opening_deal_shader_warmup_drawn", {
		"stage":stage,"sample_age":SAMPLE_AGE,"wall_usec":Time.get_ticks_usec()-started,
		"color_draw_calls":_preview.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"transmission_draw_calls":_preview.transmission.transmission_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
	})
