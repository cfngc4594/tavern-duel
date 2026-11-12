extends SceneTree

const Warmup = preload("res://scripts/native_endgame_hero_warmup.gd")

func _initialize():
	call_deferred("run")

func run():
	assert(not Warmup.enabled())
	var game: Node = load("res://main.tscn").instantiate()
	game.startup_mode = "practice"
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.headless = false
	game._setup_spatial_presentation()
	game.spatial_scene.sync_from_game()
	game.native_initial_loading = true
	game.world_canvas.visible = false
	var initial_state := [game.health.duplicate(), game.rng.state, game.native_endgame.effects.visual_rng.state, game.native_endgame.frame_id]
	var warmup := Warmup.new()
	for key in Warmup.MESHES:
		assert(warmup._stage_batch(game, key))
		var meshes := warmup._staged.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1)
		var source: MeshInstance3D = meshes[0]
		var mirror: MeshInstance3D = game.native_transmission.mirrors[source.get_instance_id()]
		assert(source.is_visible_in_tree() and mirror.is_visible_in_tree())
		assert(game.spatial_scene.camera.is_position_in_frustum(source.global_transform * source.get_aabb().get_center()))
		assert(source.mesh == mirror.mesh and source.mesh.get_surface_count() == (2 if key == Warmup.DEBRIS else 1))
		assert(game.spatial_view.msaa_3d == game.native_transmission.transmission_view.msaa_3d)
		for i in range(source.mesh.get_surface_count()):
			var color: ShaderMaterial = source.get_active_material(i)
			var transmission: ShaderMaterial = mirror.get_active_material(i)
			assert(color.shader.code.contains("cull_front") and warmup._shaders.has(color.shader))
			assert(color.shader != transmission.shader and game.native_transmission.shader_cache[color.shader.code] == transmission.shader)
			if key == Warmup.DEBRIS and game.native_endgame.assets.objects[color.get_meta("source_key")].name.contains("portrait"):
				var texture: Texture2D = color.get_shader_parameter("_MainTex")
				assert(texture.get_meta("original_texture_key") == game.native_endgame.assets.manifest.root_labels.jaina_portrait)
		warmup._finish_batch(game, key, Time.get_ticks_usec())
		assert(warmup._staged == null and not mirror.visible)
		await process_frame
	assert(warmup.completed_batches == 2 and warmup._shaders.size() >= 2)
	assert(game.native_endgame.state == "idle" and game.native_endgame.effects.effects.is_empty())
	assert(initial_state == [game.health, game.rng.state, game.native_endgame.effects.visual_rng.state, game.native_endgame.frame_id])
	game.world_canvas.visible = true
	assert(not warmup._stage_batch(game, Warmup.DEBRIS))
	game.free()
	print("HERO_SHADER_WARMUP_PASS two exact mesh families staged in both views, retained shaders, retired geometry, and untouched terminal state")
	quit()
