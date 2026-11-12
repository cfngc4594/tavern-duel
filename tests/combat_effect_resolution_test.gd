extends SceneTree

const CombatAssets=preload("res://scripts/native_combat_assets.gd")
const CombatEffects=preload("res://scripts/native_combat_effects.gd")
const CombatParticles=preload("res://scripts/native_combat_particles.gd")
const RenderTexture=preload("res://scripts/native_combat_rendertexture.gd")
const ScreenEffects=preload("res://scripts/native_combat_screen_effects.gd")
const CAPTURE_ARM = "render_quality/android_fx_benchmark_arm"
const SPELL_FIXTURES := [
	["CS2_029/start", "cab-69c88b234dfa427e02d1fcee9337ae34:-27170586228406900", "cab-69c88b234dfa427e02d1fcee9337ae34:2359521193231992204"],
	["CS2_029/missile", "cab-69c88b234dfa427e02d1fcee9337ae34:7740699746381147760", "cab-69c88b234dfa427e02d1fcee9337ae34:-5626360573135933840"],
	["CS2_029/impact", "cab-69c88b234dfa427e02d1fcee9337ae34:839035113494640369", "cab-69c88b234dfa427e02d1fcee9337ae34:7286635149810824945"],
	["GAME_005/friendly_area", "cab-8e3755b5c7f289df2f238a71420d2eae:-8631301880503599993", "cab-8e3755b5c7f289df2f238a71420d2eae:-1100169735795114873"],
]
const FIREBLAST_FIXTURE := ["CS2_034/missile", "cab-69c88b234dfa427e02d1fcee9337ae34:8364655279848562821", "cab-69c88b234dfa427e02d1fcee9337ae34:-7915262011419123579"]

class ScreenHost extends Node:
	var world_canvas:=Node2D.new()
	var spatial_scene: Node3D
	var native_summon: Node
	var source_projection: Node
	var presentation_size:=Vector2(1600,900)
	var presentation_offset:=Vector2.ZERO

class ParticleSpeedRecorder extends RefCounted:
	var calls: Array[Vector2] = []

	func set_playback_speed(speed: float, age: float) -> void:
		calls.append(Vector2(speed, age))

func _initialize():
	call_deferred("run")

func _capture(assets,scale: float,route_id := "", fixture := SPELL_FIXTURES[1]) -> Dictionary:
	var projection:=Node3D.new()
	root.add_child(projection)
	var source_key: String=fixture[1]
	var scope: Dictionary=assets.instantiate(source_key,projection)
	var capture:=RenderTexture.new()
	projection.add_child(capture)
	capture.target_scale=scale
	capture.setup(scope,assets,projection,1,route_id)
	for entry in capture.entries:
		if entry.key == fixture[2]:
			return {"projection":projection,"scope":scope,"capture":capture,"missile":entry}
	assert(false,fixture[0]+" capture missing")
	return {}

func _check_capture():
	var assets:=CombatAssets.new()
	assets.setup(null)
	var full:=_capture(assets,1.0)
	var half:=_capture(assets,0.5)
	var a: Dictionary=full.missile
	var b: Dictionary=half.missile
	assert(a.size==a.source_size and a.size==b.source_size)
	assert(b.size==RenderTexture.scaled_target_size(a.size,0.5))
	assert(b.bloom_size==RenderTexture.scaled_target_size(a.bloom_size,0.5))
	assert(a.captures.size()==b.captures.size() and a.passes.size()==b.passes.size())
	assert(b.main_capture.color.view.size==b.main_capture.alpha.view.size)
	assert(a.main_capture.color.camera.transform==b.main_capture.color.camera.transform)
	assert(a.main_capture.color.camera.size==b.main_capture.color.camera.size)
	assert(a.bloom_steps[0].material.get_shader_parameter("_OffsetA")==b.bloom_steps[0].material.get_shader_parameter("_OffsetA"))
	for fixture in [full,half]:
		fixture.capture.dispose()
		fixture.projection.queue_free()

func _check_particle_capture_axes(spell_fixture: Array):
	var assets := CombatAssets.new()
	assets.setup(null)
	var previous_arm: Variant = ProjectSettings.get_setting(CAPTURE_ARM, null)
	ProjectSettings.set_setting(CAPTURE_ARM, "reference")
	var route_id: String = spell_fixture[0]
	var fixtures := [_capture(assets, 1.0, route_id, spell_fixture), _capture(assets, 1.0, route_id, spell_fixture)]
	ProjectSettings.set_setting(CAPTURE_ARM, previous_arm)
	var previous_prebind := RenderTexture.prebind_particle_capture_axes_enabled
	RenderTexture.prebind_particle_capture_axes_enabled = true
	var changes := [0, 0]
	for index in fixtures.size():
		var fixture: Dictionary = fixtures[index]
		var players := {}
		for key in fixture.scope.particles:
			var spec: Dictionary = fixture.scope.particles[key]
			if spec.node != fixture.missile.source and not fixture.missile.source.is_ancestor_of(spec.node):continue
			var player := CombatParticles.new()
			player.setup(spec, assets, fixture.projection, 140 + players.size())
			player.mesh.changed.connect(func(): changes[index] += 1)
			players[key] = player
		assert(not players.is_empty())
		fixture.scope.particle_players = players
	var reference: Dictionary = fixtures[0].scope.particle_players
	var candidate: Dictionary = fixtures[1].scope.particle_players
	var live_frames := 0
	for age in [0.0, 0.06, 0.12, 0.19, 0.27, 0.35, 0.42, 0.55]:
		for index in fixtures.size():
			var fixture: Dictionary = fixtures[index]
			fixture.projection.rotation.y = age * 0.83
			fixture.projection.position.x = age * 0.41
			if index == 1:fixture.capture.prepare_particle_capture_axes()
			for player in fixture.scope.particle_players.values():player.seek(age)
			fixture.capture.sync(age)
		for key in reference:
			var a: CombatParticles = reference[key]
			var b: CombatParticles = candidate[key]
			assert(a.capture_camera_right == b.capture_camera_right and a.capture_camera_up == b.capture_camera_up)
			assert(var_to_bytes(a.particles) == var_to_bytes(b.particles) and a.rng.state == b.rng.state and a.death_rng.state == b.death_rng.state)
			assert(a.emitted_count == b.emitted_count and a.simulation_time == b.simulation_time and a.screen_size_clamped == b.screen_size_clamped)
			assert(a.live_count == b.live_count and a.mesh.get_surface_count() == b.mesh.get_surface_count())
			for surface in a.mesh.get_surface_count():
				assert(var_to_bytes(a.mesh.surface_get_arrays(surface)) == var_to_bytes(b.mesh.surface_get_arrays(surface)))
				live_frames += 1
	assert(live_frames > 0 and changes[0] > changes[1])
	print("COMBAT_CAPTURE_AXES_EXACT route=", route_id, " mesh_samples=", live_frames, " mesh_changes=", changes)
	RenderTexture.prebind_particle_capture_axes_enabled = previous_prebind
	for fixture in fixtures:
		fixture.capture.dispose()
		fixture.projection.queue_free()

func _check_android_spell_capture():
	var assets := CombatAssets.new()
	assets.setup(null)
	var previous_arm: Variant = ProjectSettings.get_setting(CAPTURE_ARM, null)
	for arm in ["reference", "no_bloom", "spell"]:
		ProjectSettings.set_setting(CAPTURE_ARM, arm)
		for kind in range(SPELL_FIXTURES.size()):
			var fixture: Array = SPELL_FIXTURES[kind]
			var projection := Node3D.new()
			root.add_child(projection)
			var scope: Dictionary = assets.instantiate(fixture[1], projection)
			var record: Dictionary = assets.objects[fixture[2]]
			var owner_key: String = record.refs[".m_GameObject"]
			var source_property := ".ObjectToRender" if kind == 3 else ".m_ObjectToRender"
			var source_key: String = record.refs[source_property]
			var owner: Node3D = scope.nodes[owner_key]
			var current := owner
			while current != projection:
				current.show()
				current = current.get_parent()
			var original_plane: MeshInstance3D = scope.renderers.get(owner_key)
			var original_materials: Array = scope.materials.get(owner_key, [])
			var captured_geometry := MeshInstance3D.new()
			captured_geometry.mesh = BoxMesh.new()
			scope.nodes[source_key].add_child(captured_geometry)
			var uncaptured_geometry := MeshInstance3D.new()
			uncaptured_geometry.mesh = BoxMesh.new()
			projection.add_child(uncaptured_geometry)
			var capture := RenderTexture.new()
			projection.add_child(capture)
			capture.setup(scope, assets, projection, 2, fixture[0])
			assert(capture.entries.size() == 1, "Capture entry missing for " + fixture[0])
			var entry: Dictionary = capture.entries[0]
			var expected_mode := "direct" if arm == "spell" else ("no_bloom" if arm == "no_bloom" and kind != 3 else "reference")
			var expected_views := 0 if arm == "spell" else (3 if arm == "no_bloom" or kind == 3 else 9)
			assert(entry.capture_mode == expected_mode)
			assert(capture.get_audit().live_viewports == expected_views)
			assert(entry.plane.is_visible_in_tree())
			assert(captured_geometry.layers == 0 and uncaptured_geometry.layers == 1)
			if arm == "spell":
				assert(entry.cue_material.get_shader_parameter("cue_kind") == kind)
				assert(scope.materials[owner_key].has(entry.cue_material))
				assert(not capture.get_audit().components[0].output_texture_bound)
				if kind == 3:
					assert(entry.plane == original_plane)
					assert(entry.cue_material.get_shader_parameter("_Alpha") == original_materials[0].get_shader_parameter("_Alpha"))
				elif kind < 2:
					capture.sync(1.0, "Death")
					capture.sync(1.36, "Death")
					assert(is_zero_approx(entry.cue_material.get_shader_parameter("cue_fade")))
			capture.dispose()
			assert(captured_geometry.layers == 1)
			if kind == 3:
				assert(original_plane.material_override == null)
				assert(scope.materials[owner_key] == original_materials)
			projection.queue_free()
	assert(RenderTexture._select_capture_mode("EX1_277/missile", "spell") == "reference")
	ProjectSettings.set_setting(CAPTURE_ARM, previous_arm)

func _check_direct_particle_solver():
	var assets := CombatAssets.new()
	assets.setup(null)
	var effects := CombatEffects.new()
	effects.assets = assets
	var previous_arm: Variant = ProjectSettings.get_setting(CAPTURE_ARM, null)
	for arm in ["spell", "candidate_spell_lite"]:
		var skip_solver: bool = arm == "candidate_spell_lite"
		ProjectSettings.set_setting(CAPTURE_ARM, arm)
		for kind in range(SPELL_FIXTURES.size()):
			var fixture: Array = SPELL_FIXTURES[kind]
			var projection := Node3D.new()
			root.add_child(projection)
			var scope: Dictionary = assets.instantiate(fixture[1], projection)
			scope.particle_players = {}
			var refs: Dictionary = assets.objects[fixture[2]].refs
			var source: Node3D = scope.nodes[refs.get(".m_ObjectToRender", refs.get(".ObjectToRender"))]
			var owner: Node3D = scope.nodes[refs[".m_GameObject"]]
			var current := owner
			while current != projection:
				current.show()
				current = current.get_parent()
			var deferred := kind == 3
			if deferred:
				owner.hide()
			var capture := RenderTexture.new()
			projection.add_child(capture)
			capture.setup(scope, assets, projection, 2, fixture[0])
			assert(capture.entries.is_empty() == deferred)
			var effect := {"projection": projection, "particles": scope.particle_players, "rendertexture": capture, "serial": 2}
			var hidden_player: CombatParticles
			var visible_player: CombatParticles
			var replaced_count := 0
			for particle_key in scope.particles:
				var spec: Dictionary = scope.particles[particle_key]
				var player := CombatParticles.new()
				var captured: bool = spec.node == source or source.is_ancestor_of(spec.node)
				var replaced: bool = captured and not spec.system.data.playOnAwake
				capture.prepare_direct_particle_solver(player, spec.node, spec.system.key)
				assert(player.capture_solver_suppressed == (skip_solver and replaced and not deferred))
				if replaced:
					replaced_count += 1
				if (replaced and hidden_player == null) or (not captured and visible_player == null):
					effects._setup_particle(player, spec, effect)
					assert(player.instance_seed == 2 * 391 + effect.particles.size())
					effect.particles[particle_key] = {"node": player, "start": 0.0}
					if replaced: hidden_player = player
					else: visible_player = player
				else:
					player.free()
			assert(replaced_count == [1, 4, 1, 3][kind])
			assert(hidden_player != null and visible_player != null)
			if deferred:
				assert(not hidden_player.capture_solver_suppressed)
				owner.show()
			capture.sync(0.1)
			var detached := CombatParticles.new()
			capture.prepare_direct_particle_solver(detached, projection, hidden_player.source_key)
			assert(not detached.capture_solver_suppressed)
			detached.free()
			assert(hidden_player.capture_solver_suppressed == skip_solver)
			assert(not visible_player.capture_solver_suppressed)
			assert(hidden_player.mesh_instance.layers == 0 and visible_player.mesh_instance.layers != 0)
			var initial_time := hidden_player.simulation_time
			hidden_player.set_playback_speed(0.5, 0.2)
			hidden_player.seek(0.45)
			hidden_player.stop_emitting(0.45)
			assert(is_equal_approx(hidden_player.elapsed_seconds, 0.45))
			assert(is_equal_approx(hidden_player.playback_speed, 0.5))
			assert(hidden_player.get_audit().get("capture_solver_suppressed", false) == skip_solver)
			assert(is_equal_approx(hidden_player.simulation_time, initial_time) == skip_solver)
			capture.dispose()
			projection.queue_free()
	ProjectSettings.set_setting(CAPTURE_ARM, previous_arm)
	effects.free()

func _check_continuous_playback_speed():
	var assets := CombatAssets.new()
	assets.objects = {
		"first:42": {"type": "ParticleSystem", "refs": {".m_GameObject": "first_emitter"}},
		"second:42": {"type": "ParticleSystem", "refs": {".m_GameObject": "second_emitter"}},
	}
	var effects := CombatEffects.new()
	effects.assets = assets
	var first := ParticleSpeedRecorder.new()
	var second := ParticleSpeedRecorder.new()
	var effect := {
		"root_key": "root", "state": {}, "age": 2.0, "variables": {"Speed": 1.25}, "continuous": [],
		"particles": {"first_emitter": {"node": first, "start": 0.5}, "second_emitter": {"node": second, "start": 0.5}},
	}
	var action := {
		"class_name": "SetProperty", "params": {"everyFrame": true, "targetProperty": {
			"TargetObject": {"value": {"m_PathID": 42}}, "PropertyName": "playbackSpeed",
			"FloatParameter": {"useVariable": true, "name": "Speed"},
		}},
	}
	effects._action(effect, action, 2.0)
	assert(effect.continuous[0].resolved_target == assets.objects["first:42"])
	effect.age = 3.0
	effect.variables.Speed = 0.75
	effects._apply_continuous(effect, effect.continuous[0])
	assert(first.calls == [Vector2(1.25, 1.5), Vector2(0.75, 2.5)] and second.calls.is_empty())
	effects.free()

func _check_screen_effect():
	var host:=ScreenHost.new()
	root.add_child(host)
	host.add_child(host.world_canvas)
	var view:=SubViewport.new()
	view.size=Vector2i(1954,900)
	view.msaa_3d=Viewport.MSAA_2X
	host.add_child(view)
	var camera:=Camera3D.new()
	view.add_child(camera)
	host.spatial_scene=Node3D.new()
	view.add_child(host.spatial_scene)
	var effects:=ScreenEffects.new()
	host.add_child(effects)
	var assets:=CombatAssets.new()
	assets.setup(null)
	effects.setup(host,assets)
	effects.target_scale=0.5
	effects._make_graph(Vector2i(977,450),view)
	assert(effects.source_dimensions==view.size and effects.dimensions==Vector2i(977,450))
	assert(effects.views.size()==5 and effects.masks.color.view.msaa_3d==Viewport.MSAA_DISABLED)
	assert(effects.passes[1].material.get_shader_parameter("_BlitTexture_TexelSize")==Vector4(1.0/1954.0,1.0/900.0,1954,900))
	var source:=MeshInstance3D.new()
	source.mesh=BoxMesh.new()
	host.spatial_scene.add_child(source)
	var seen: Dictionary={}
	for kind in ["color","alpha"]:effects._mirror(source,0,effects.prepass_material,kind,"cardraycast",seen)
	assert(seen.size()==2)
	assert(effects.mirrors.values()[0].mesh==effects.mirrors.values()[1].mesh)
	var initial_mesh: Mesh=effects.mirrors.values()[0].mesh
	source.mesh=BoxMesh.new()
	for kind in ["color","alpha"]:effects._mirror(source,0,effects.prepass_material,kind,"cardraycast",seen)
	assert(effects.mirrors.values()[0].mesh==effects.mirrors.values()[1].mesh)
	assert(effects.mirrors.values()[0].mesh!=initial_mesh)
	effects.dispose()
	host.queue_free()

func run():
	_check_capture()
	_check_particle_capture_axes(SPELL_FIXTURES[1])
	_check_particle_capture_axes(FIREBLAST_FIXTURE)
	_check_android_spell_capture()
	_check_direct_particle_solver()
	_check_continuous_playback_speed()
	_check_screen_effect()
	await process_frame
	print("COMBAT_EFFECT_RESOLUTION_PASS")
	quit()
