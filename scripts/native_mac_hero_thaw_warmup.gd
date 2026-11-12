extends RefCounted
## Render the source frozen-hero shatter in the two board views while loading.

const StatusEffects = preload("res://scripts/native_status_effects.gd")
const SETTING := "render_quality/macos_hero_thaw_warmup"
const ROUTE := "frozen_hero/root"
const SAMPLE_AGE := 0.10

var _preview: Node
var _draw_callback := Callable()
var _finished := false
var _shaders: Array[Shader] = []

static func enabled() -> bool:
	return OS.has_feature("macos") and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and bool(ProjectSettings.get_setting(SETTING, false)) \
		and not OS.get_cmdline_user_args().has("--mac-skip-hero-thaw-warmup")

func advance(game: Node) -> bool:
	if _finished:return true
	if _draw_callback.is_valid():return false
	if not game.native_initial_loading or not is_instance_valid(game.world_canvas) or game.world_canvas.visible \
			or not is_instance_valid(game.native_status) or not is_instance_valid(game.native_transmission) \
			or not is_instance_valid(game.spatial_scene) or not is_instance_valid(game.spatial_scene.camera):
		return true
	var started := Time.get_ticks_usec()
	game.native_startup_timing.mark("hero_thaw_shader_warmup_begin")
	_preview = StatusEffects.new()
	_preview.name = "HeroThawShaderWarmup"
	_preview.suppress_game_shake = true
	game.add_child(_preview)
	var status: Node = game.native_status
	_preview.setup_status(game, status.assets, null, status.routes)
	var target := {"type":"hero", "side":1, "pos":game.ENEMY_HERO}
	var context := {"key":"HERO_07" if game.hero_classes[1] == "WARLOCK" else "HERO_08",
		"side":1, "source":game.ENEMY_HERO, "target":target}
	var effect: Dictionary = _preview._spawn_route(ROUTE, game.ENEMY_HERO, "Birth", 1, context)
	if effect.is_empty():
		cancel()
		return true
	# The shatter emitter starts on Death, after the original Birth schedule.
	_preview.advance(SAMPLE_AGE)
	_preview._start_event(effect, "Death", float(effect.age))
	_preview.advance(SAMPLE_AGE)
	_preview.sync_projection()
	game.native_transmission.sync()
	_draw_callback = _drawn.bind(game, effect, started)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	_release_preview()
	_shaders.clear()

func _drawn(game: Node, effect: Dictionary, started: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game) or not is_instance_valid(_preview):return
	# Preserve the immutable color resources after removing the staging meshes.
	# The transmission renderer owns its generated shaders independently.
	var surfaces := 0
	for player in effect.particles.values():
		var geometry: MeshInstance3D = player.node.mesh_instance
		if not is_instance_valid(geometry) or not geometry.is_visible_in_tree() or geometry.mesh == null:continue
		for surface in geometry.mesh.get_surface_count():
			var material := geometry.get_active_material(surface)
			if material is ShaderMaterial and material.shader != null and not _shaders.has(material.shader):
				_shaders.append(material.shader)
			surfaces += 1
	game.native_startup_timing.mark("hero_thaw_shader_warmup_drawn", {
		"wall_usec":Time.get_ticks_usec()-started, "particle_surfaces":surfaces, "shader_count":_shaders.size(),
	})
	_release_preview()
	_finished = true

func _release_preview() -> void:
	if not is_instance_valid(_preview):return
	_preview.cancel_all()
	_preview.queue_free()
	_preview = null
