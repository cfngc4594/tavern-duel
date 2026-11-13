extends RefCounted
## Submit the first hero weld and summon dust shaders while loading.
## Small isolated targets reproduce their Compatibility light specializations.

const OpeningAssets = preload("res://scripts/source_opening_assets.gd")
const SourceManifest = preload("res://scripts/native_source_manifest.gd")
const Transmission = preload("res://scripts/native_combat_transmission.gd")
const SETTING := "render_quality/macos_opening_battlecry_warmup"
const FLAG := "--mac-opening-battlecry-warmup"
const SKIP_FLAG := "--mac-skip-opening-battlecry-warmup"
const VIEW_SIZE := Vector2i(64, 64)
const WELDLINE := "cab-3563ba8b89db13ca6eb196aa111591f1:-2139291312852994735"
const WELD_SPARK := "cab-3563ba8b89db13ca6eb196aa111591f1:-1010197123275176497"
const SUMMON_DUST := "cab-3563ba8b89db13ca6eb196aa111591f1:-2825523773836913966"

var _finished := false
var _started_usec := 0
var _staging: Node
var _draw_callback := Callable()
var _views: Dictionary = {}
var _shaders: Array[Shader] = []

static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return OS.has_feature("macos") and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and not args.has(SKIP_FLAG) and (args.has(FLAG) or bool(ProjectSettings.get_setting(SETTING, false)))

func advance(game: Node) -> bool:
	if _finished:
		return true
	if _draw_callback.is_valid():
		return false
	if not game.native_initial_loading or game.world_canvas.visible:
		_finished = true
		return true

	_started_usec = Time.get_ticks_usec()
	game.native_startup_timing.mark("opening_battlecry_shader_warmup_begin")
	_staging = Node.new()
	_staging.name = "OpeningBattlecryShaderWarmup"
	game.add_child(_staging)
	if game.flow.mode == "normal":
		var assets := OpeningAssets.new()
		assets.base_path = OpeningAssets.OPENING_BASE
		assets.objects = SourceManifest.load_manifest(OpeningAssets.OPENING_BASE + "weld.json").objects
		assets._prepare_render_order()
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0, 1)
		light.omni_range = 4.0
		_stage(&"weldline", assets.material(WELDLINE) as ShaderMaterial, light, Viewport.MSAA_2X)
		if _views.has(&"weldline"):
			_stage_weld_color(_views[&"weldline"][0], assets.material(WELD_SPARK) as ShaderMaterial)
	var board: Viewport = game.spatial_scene.get_viewport()
	_stage(&"summon_dust", game.native_summon.assets.material(SUMMON_DUST) as ShaderMaterial,
		DirectionalLight3D.new(), board.msaa_3d)
	_draw_callback = _drawn.bind(game)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	if is_instance_valid(_staging):
		_staging.queue_free()
	_staging = null
	_views.clear()

func _stage(label: StringName, material: ShaderMaterial, light: Light3D, msaa: Viewport.MSAA) -> void:
	if material == null:
		light.free()
		return
	_shaders.append(material.shader)
	var color_view := SubViewport.new()
	color_view.size = VIEW_SIZE
	color_view.own_world_3d = true
	color_view.transparent_bg = true
	color_view.msaa_3d = msaa
	color_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_staging.add_child(color_view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0, 4)
	color_view.add_child(camera)
	camera.current = true
	color_view.add_child(light)
	_stage_quad(color_view, material)
	var transmission := Transmission.new()
	_staging.add_child(transmission)
	transmission.setup(color_view)
	transmission.transmission_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_views[label] = [color_view, transmission.transmission_view]

func _stage_weld_color(color_view: SubViewport, spark: ShaderMaterial) -> void:
	# The first weld light also specializes its additive sparks and nearby
	# unshaded text. These two programs are used only on the color pass.
	if spark != null:
		_shaders.append(spark.shader)
		_stage_quad(color_view, spark)
	var label := Label3D.new()
	label.text = "A"
	label.shaded = false
	label.double_sided = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	color_view.add_child(label)

func _stage_quad(view: SubViewport, material: ShaderMaterial) -> void:
	var proxy := MeshInstance3D.new()
	proxy.mesh = QuadMesh.new()
	proxy.material_override = material
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(proxy)

func _drawn(game: Node) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game):
		return
	var draw_calls := {}
	for label in _views:
		var passes: Array = []
		for view: SubViewport in _views[label]:
			passes.append(view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		draw_calls[label] = passes
	game.native_startup_timing.mark("opening_battlecry_shader_warmup_end", {
		"wall_usec": Time.get_ticks_usec() - _started_usec,
		"color_transmission_draw_calls": draw_calls,
	})
	cancel()
