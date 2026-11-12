extends RefCounted
## Prime hero-death mesh and particle shaders in the real C/T viewports.
## The loading gate hides their composition and does not advance match clocks.

const SourceProjection = preload("res://scripts/source_board_projection.gd")
const MacResultWarmup = preload("res://scripts/native_mac_result_warmup.gd")
const ENABLED_SETTING := "render_quality/android_hero_shader_warmup"
const MACOS_ENABLED_SETTING := "render_quality/macos_hero_shader_warmup"
const DEBRIS := "cab-69c88b234dfa427e02d1fcee9337ae34:-3138239647439378684"
const CRATER := "cab-69c88b234dfa427e02d1fcee9337ae34:-8518041788018317564"
const MESHES := [DEBRIS, CRATER]
const CRACK := "cab-69c88b234dfa427e02d1fcee9337ae34:6957090474196412164"
const FLARE := "cab-69c88b234dfa427e02d1fcee9337ae34:193837936947963652"

var wall_usec := 0
var completed_batches := 0
var _started_usec := -1
var _next_batch := 0
var _finished := false
var _staged: Node3D
var _shaders: Array[Shader] = []
var _batches: Array[String] = []

static func enabled() -> bool:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return false
	if OS.has_feature("macos"):
		return bool(ProjectSettings.get_setting(MACOS_ENABLED_SETTING, false))
	return OS.has_feature("android") and (bool(ProjectSettings.get_setting(ENABLED_SETTING, false)) or OS.get_cmdline_user_args().has("--android-hero-shader-warmup"))

func advance(game: Node) -> bool:
	if _finished:return true
	if is_instance_valid(_staged):return false
	if _started_usec < 0:
		_started_usec = Time.get_ticks_usec()
		_batches.append_array(MESHES)
		if MacResultWarmup.enabled():
			_batches.append_array([CRACK, FLARE])
		game.native_startup_timing.mark("hero_shader_warmup_begin")
	while _next_batch < _batches.size():
		var source_key: String = _batches[_next_batch]
		_next_batch += 1
		var started := Time.get_ticks_usec()
		if _stage_batch(game, source_key):
			RenderingServer.frame_post_draw.connect(_finish_batch.bind(game, source_key, started), Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
			return false
	_finished = true
	wall_usec = Time.get_ticks_usec() - _started_usec
	game.native_startup_timing.mark("hero_shader_warmup_end", {"wall_usec":wall_usec,"batches":completed_batches})
	return true

func _stage_batch(game: Node, source_key: String) -> bool:
	if not game.native_initial_loading or not is_instance_valid(game.world_canvas) or game.world_canvas.visible:return false
	if not is_instance_valid(game.native_endgame) or not game.native_endgame.source_ready:return false
	if not is_instance_valid(game.spatial_scene) or not is_instance_valid(game.native_transmission) or not is_instance_valid(game.native_damage):return false
	var camera: Camera3D = game.spatial_scene.camera
	var assets = game.native_endgame.assets
	if not is_instance_valid(camera) or not assets.objects.has(source_key):return false
	var staging := Node3D.new()
	staging.name = "HeroDeathShaderWarmup"
	game.spatial_scene.add_child(staging)
	var renderer: MeshInstance3D
	var materials: Array
	if source_key == FLARE:
		# Use the exact Fireworks flare material without starting its particle simulation.
		var source: Dictionary = assets.component(source_key, "ParticleSystemRenderer")
		var material: Material = assets.material(source.get("refs", {}).get(".m_Materials[0]", ""))
		if material != null:
			renderer = MeshInstance3D.new()
			renderer.mesh = QuadMesh.new()
			renderer.material_override = material
			renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			staging.add_child(renderer)
			materials = [material]
	else:
		var state: Dictionary = assets.instantiate(source_key, staging)
		renderer = state.renderers.get(source_key)
		materials = state.materials.get(source_key, [])
		state.root.visible = true
	if not is_instance_valid(renderer) or (renderer.layers & camera.cull_mask) == 0:
		staging.queue_free()
		return false
	for material in materials:
		game.native_damage._compensate_reflected_culling(material)
	if source_key == DEBRIS:
		# Both hero portraits have the same mip, wrap, filter and bias settings.
		assets.bind_hero_portrait(materials, assets.load_texture(assets.manifest.root_labels.jaina_portrait))
	for material in materials:
		if material is ShaderMaterial and material.shader != null and not _shaders.has(material.shader):
			_shaders.append(material.shader)
	var basis: Basis = SourceProjection.REFLECTION
	var projection = SourceProjection.from_game(game)
	if projection != null and projection.anchors.has("hero:1"):
		var anchor: Dictionary = projection.anchors["hero:1"]
		if anchor.get("rotation") is Quaternion and anchor.get("scale") is Vector3:
			basis *= Basis(anchor.rotation) * Basis.from_scale(anchor.scale)
	staging.global_basis = basis
	var distance := lerpf(camera.near, camera.far, 0.15)
	var center := camera.project_position(camera.get_viewport().get_visible_rect().size * 0.5, distance)
	staging.global_position += center - (renderer.global_transform * renderer.get_aabb().get_center())
	renderer.visible = true
	_staged = staging
	game.native_transmission.sync()
	return true

func _finish_batch(game: Node, source_key: String, started: int) -> void:
	if not is_instance_valid(_staged):return
	_staged.visible = false
	_staged.queue_free()
	_staged = null
	if not is_instance_valid(game):return
	game.native_transmission.sync()
	completed_batches += 1
	game.native_startup_timing.mark("hero_shader_warmup_batch_drawn", {"source_key":source_key,"wall_usec":Time.get_ticks_usec()-started})
