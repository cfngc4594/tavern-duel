extends RefCounted
## Draw the first result-screen shader variants in temporary loading targets.
## Reuse the result's materials and transmission conversion without showing it.

const SourceProjection = preload("res://scripts/source_board_projection.gd")
const Transmission = preload("res://scripts/native_combat_transmission.gd")
const Background = preload("res://scripts/native_endgame_background.gd")
const Passes = preload("res://scripts/native_endgame_background_passes.gd")
const SETTING := "render_quality/macos_result_warmup"
const FLAG := "--mac-result-warmup"
const SKIP_FLAG := "--mac-skip-result-warmup"
const VIEW_SIZE := Vector2i(64, 64)
const VICTORY_CLOUD := "cab-69c88b234dfa427e02d1fcee9337ae34:4859423617772656272"

var wall_usec := 0
var completed_batches := 0
var _finished := false
var _started_usec := 0
var _staging: Node
var _canvas_view: SubViewport
var _color_view: SubViewport
var _transmission: Transmission
var _draw_callback := Callable()
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
	if not game.native_initial_loading or game.world_canvas.visible or not game.native_endgame.source_ready:
		_finished = true
		return true

	_started_usec = Time.get_ticks_usec()
	game.native_startup_timing.mark("result_shader_warmup_begin")
	_staging = Node.new()
	_staging.name = "ResultShaderWarmup"
	game.add_child(_staging)
	var screen: Node = game.native_endgame.screen
	_stage_canvas(screen.background_effect._use_lite_backdrop())
	_stage_result(game, screen)
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
	_canvas_view = null
	_color_view = null
	_transmission = null

func _stage_canvas(lite: bool) -> void:
	_canvas_view = SubViewport.new()
	_canvas_view.name = "ResultWarmupCanvas"
	_canvas_view.size = VIEW_SIZE
	_canvas_view.disable_3d = true
	_canvas_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_staging.add_child(_canvas_view)
	var paths: Array[String] = [Background.LITE_SHADER_PATH if lite else Background.SHADER_PATH]
	if not lite:
		for suffix in ["desaturation", "vignette", "blur", "blend"]:
			paths.append(Passes.PATH + suffix + ".gdshader")
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	for index in paths.size():
		var material := ShaderMaterial.new()
		material.shader = load(paths[index])
		_shaders.append(material.shader)
		for parameter in material.shader.get_shader_uniform_list():
			if parameter.hint == PROPERTY_HINT_RESOURCE_TYPE and parameter.hint_string == "Texture2D":
				material.set_shader_parameter(parameter.name, texture)
		if index == 0:
			material.set_shader_parameter("_HasResult", true)
		var rect := ColorRect.new()
		rect.position = Vector2(12 * index, 0)
		rect.size = Vector2(12, 12)
		rect.material = material
		_canvas_view.add_child(rect)

func _stage_result(game: Node, screen: Node) -> void:
	var source_camera: Camera3D = game.spatial_scene.camera
	_color_view = SubViewport.new()
	_color_view.name = "ResultWarmupColor"
	_color_view.size = VIEW_SIZE
	_color_view.own_world_3d = true
	_color_view.transparent_bg = true
	_color_view.msaa_3d = source_camera.get_viewport().msaa_3d
	_color_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_staging.add_child(_color_view)
	var scene := Node3D.new()
	_color_view.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	scene.add_child(environment)
	for child in game.spatial_scene.get_children():
		if child is DirectionalLight3D:
			scene.add_child(child.duplicate())
	var camera := Camera3D.new()
	for property in ["projection", "keep_aspect", "fov", "size", "frustum_offset", "near", "far", "h_offset", "v_offset", "cull_mask"]:
		camera.set(property, source_camera.get(property))
	scene.add_child(camera)
	camera.global_transform = source_camera.global_transform
	camera.current = true

	_stage_mesh(screen, camera, scene, VICTORY_CLOUD, 0, Vector2(16, 32))
	if not screen.binding.is_empty() and not screen.binding.portraits.is_empty():
		var portrait_key: String = screen.binding.portrait_game_object.key
		var texture: Texture2D = screen.assets.load_texture(screen.binding.portraits[0].portrait_texture)
		_stage_mesh(screen, camera, scene, portrait_key, 1, Vector2(48, 32), texture)
	_transmission = Transmission.new()
	_staging.add_child(_transmission)
	_transmission.setup(_color_view, scene)
	_transmission.transmission_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _stage_mesh(screen: Node, camera: Camera3D, scene: Node3D, key: String, surface: int, point: Vector2, texture: Texture2D = null) -> void:
	var assets = screen.assets
	var mesh_filter: Dictionary = assets.component(key, "MeshFilter")
	var renderer: Dictionary = assets.component(key, "MeshRenderer")
	var original: ArrayMesh = assets.geometry(mesh_filter.get("refs", {}).get(".m_Mesh", ""))
	if original == null or original.get_surface_count() <= surface:
		return
	var material: Material = assets.material(renderer.get("refs", {}).get(".m_Materials[%d]" % surface, ""), texture)
	if material == null:
		return
	screen.cull_adapter._compensate_reflected_culling(material)
	if material is ShaderMaterial:
		_shaders.append(material.shader)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
	var proxy := MeshInstance3D.new()
	proxy.mesh = mesh
	proxy.material_override = material
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(proxy)
	proxy.basis = SourceProjection.REFLECTION * Basis(Vector3.UP, PI)
	var distance := lerpf(camera.near, camera.far, 0.15)
	proxy.global_position = camera.project_position(point, distance) - proxy.basis * mesh.get_aabb().get_center()

func _drawn(game: Node) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game):
		return
	completed_batches = 1
	wall_usec = Time.get_ticks_usec() - _started_usec
	game.native_startup_timing.mark("result_shader_warmup_end", {
		"wall_usec": wall_usec,
		"batches": completed_batches,
		"canvas_draw_calls": _draw_calls(_canvas_view, Viewport.RENDER_INFO_TYPE_CANVAS),
		"color_draw_calls": _draw_calls(_color_view, Viewport.RENDER_INFO_TYPE_VISIBLE),
		"transmission_draw_calls": _draw_calls(_transmission.transmission_view, Viewport.RENDER_INFO_TYPE_VISIBLE),
	})
	cancel()

func _draw_calls(view: Viewport, type: Viewport.RenderInfoType) -> int:
	return view.get_render_info(type, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
