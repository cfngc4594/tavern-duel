extends SceneTree
## Same-process headless A/B against the GDScript solver using actual spell routes.

const Solver = preload("res://scripts/native_combat_particles.gd")
const CameraPolicy = preload("res://scripts/source_board_camera_policy.gd")
const CombatPlayer = preload("res://scripts/native_combat_player.gd")
const SPELLS := ["CS2_024", "CS2_034", "CS2_025", "CS2_029", "GAME_005"]
const CLOCKS := {
	"120hz": [1.0 / 120.0],
	"60hz": [1.0 / 60.0],
	"catchup": [1.0 / 8.0],
	"mixed": [1.0 / 120.0, 1.0 / 60.0, 1.0 / 120.0, 1.0 / 8.0, 1.0 / 60.0],
}
const SOLVER_FIELDS := [
	"dropped_at_capacity", "emitted_count", "live_count", "active", "collision_count",
	"screen_size_clamped", "simulation_time", "stop_time", "death_events", "subemitter_emitted",
	"pending_events", "speed_segments", "last_emitter", "last_local_scale",
]

var failures := 0
var solver_checks := 0
var mesh_checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(matches: bool, label: String) -> void:
	if matches:
		return
	failures += 1
	if failures <= 12:
		push_error("NATIVE_PARTICLE_KERNEL_DIFF " + label)


func compare_particles(reference: Array, native: Array, label: String) -> void:
	if var_to_bytes(reference) == var_to_bytes(native):
		return
	if reference.size() != native.size():
		check(false, "%s particle count %d vs %d" % [label, reference.size(), native.size()])
		return
	for i in reference.size():
		if var_to_bytes(reference[i]) == var_to_bytes(native[i]):
			continue
		var before: Dictionary = reference[i]
		var after: Dictionary = native[i]
		for field in before:
			if var_to_bytes(before[field]) != var_to_bytes(after.get(field)):
				check(false, "%s particle %d %s: %s vs %s" % [label, i, field, before[field], after.get(field)])
				return
		break
	check(false, label + " particle representation")


func compare_solver(reference, native, label: String) -> void:
	compare_particles(reference.particles, native.particles, label)
	check(reference.rng.state == native.rng.state and reference.death_rng.state == native.death_rng.state, label + " RNG")
	for field in SOLVER_FIELDS:
		check(var_to_bytes(reference.get(field)) == var_to_bytes(native.get(field)), label + " " + field)
	var surfaces: int = reference.mesh.get_surface_count()
	check(surfaces == native.mesh.get_surface_count(), label + " surface count")
	for i in mini(surfaces, native.mesh.get_surface_count()):
		check(var_to_bytes(reference.mesh.surface_get_arrays(i)) == var_to_bytes(native.mesh.surface_get_arrays(i)), label + " mesh " + str(i))
		mesh_checks += 1
	check(reference.mesh_instance.visible == native.mesh_instance.visible, label + " visibility")
	check(reference.subemitter_templates.size() == native.subemitter_templates.size(), label + " subemitters")
	for i in mini(reference.subemitter_templates.size(), native.subemitter_templates.size()):
		compare_solver(reference.subemitter_templates[i].solver, native.subemitter_templates[i].solver, label + " child")
	solver_checks += 1


func compare_effects(reference: Node, native: Node, label: String) -> void:
	check(reference.visual_rng.state == native.visual_rng.state, label + " combat RNG")
	check(reference.effect_player.visual_rng.state == native.effect_player.visual_rng.state, label + " effects RNG")
	check(var_to_bytes(reference.history) == var_to_bytes(native.history), label + " completed spell events")
	check(reference.instances.size() == native.instances.size(), label + " active spells")
	for i in mini(reference.instances.size(), native.instances.size()):
		check(var_to_bytes(reference._audit(reference.instances[i])) == var_to_bytes(native._audit(native.instances[i])), label + " active spell events")
	var first: Array = reference.effect_player.effects
	var second: Array = native.effect_player.effects
	check(first.size() == second.size(), label + " effect count")
	for i in mini(first.size(), second.size()):
		var a: Dictionary = first[i]
		var b: Dictionary = second[i]
		check(a.route_id == b.route_id and a.source_event == b.source_event and a.age == b.age, label + " route")
		check(var_to_bytes(a.events) == var_to_bytes(b.events), label + " events")
		check(a.particles.keys() == b.particles.keys(), label + " particle keys")
		for key in a.particles:
			if b.particles.has(key):
				compare_solver(a.particles[key].node, b.particles[key].node, label + " " + str(a.route_id) + " " + str(key))


func run() -> void:
	if not ClassDB.class_exists(&"TavernParticleKernel"):
		push_error("NATIVE_PARTICLE_KERNEL_FAIL build and import the native extension before running this test")
		quit(1)
		return
	CameraPolicy.qa_phone_platform = true
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.headless = false
	game.sound_enabled = false
	game._setup_spatial_presentation()
	var players := [CombatPlayer.new(), CombatPlayer.new()]
	for player in players:
		game.add_child(player)
		player.setup(game)
	var was_enabled: bool = Solver.native_batch_enabled
	var batch_start: int = Solver.native_batch_calls
	var particle_start: int = Solver.native_batch_particles
	for key in SPELLS:
		var before: int = Solver.native_batch_calls
		var before_constants: int = Solver.native_constant_batches
		for clock in CLOCKS:
			run_spell(game, players, key, clock, CLOCKS[clock])
		if key in ["CS2_024", "CS2_025", "CS2_034"]:
			check(Solver.native_batch_calls > before, key + " reached native batches")
		if key == "CS2_025":
			check(Solver.native_constant_batches > before_constants, key + " reached constant native batches")
	run_collision_and_rewind(game, players[0].effect_player)
	for player in players:
		player.cancel_all()
	Solver.native_batch_enabled = was_enabled
	game.headless = true
	game.queue_free()
	await process_frame
	check(mesh_checks > 0, "compared generated meshes")
	var batches: int = Solver.native_batch_calls - batch_start
	var particles: int = Solver.native_batch_particles - particle_start
	check(batches > 0 and particles > 0, "native extension did not run")
	if failures == 0:
		print("NATIVE_PARTICLE_KERNEL_PASS checks=", solver_checks, " meshes=", mesh_checks,
			" native_batches=", batches, " native_particles=", particles, " constant_batches=", Solver.native_constant_batches)
	else:
		print("NATIVE_PARTICLE_KERNEL_FAIL failures=", failures)
	quit(1 if failures else 0)


func run_spell(game, players: Array, key: String, clock: String, deltas: Array) -> void:
	var target: Dictionary = {} if key in ["CS2_025", "GAME_005"] else {
		"type": "hero", "side": 1, "pos": game.ENEMY_HERO,
	}
	var source: Vector2 = game.POWER_POS if key == "CS2_034" else Vector2(800, 765)
	var before_batches: int = Solver.native_batch_calls
	var before_particles: int = Solver.native_batch_particles
	for arm in players.size():
		Solver.native_batch_enabled = arm == 1
		var player: Node = players[arm]
		player.cancel_all()
		player.effect_player.visual_rng.seed = 5834
		player.begin_spell(key, source, target, 0, Callable(), Callable())

	var samples: Array[PackedInt64Array] = [PackedInt64Array(), PackedInt64Array()]
	var elapsed := 0.0
	var frame := 0
	while elapsed < 3.3 and not (players[0].effect_player.effects.is_empty() and players[0].instances.is_empty()):
		var delta: float = deltas[frame % deltas.size()]
		# Reverse the measurement order every frame to balance cache and scheduler effects.
		for arm in ([0, 1] if frame % 2 == 0 else [1, 0]):
			Solver.native_batch_enabled = arm == 1
			var batches_before_advance: int = Solver.native_batch_calls
			var start := Time.get_ticks_usec()
			players[arm].advance(delta)
			samples[arm].append(Time.get_ticks_usec() - start)
			if arm == 0:
				check(Solver.native_batch_calls == batches_before_advance, "reference stayed on GDScript")
		compare_effects(players[0], players[1], "%s %s frame %d" % [key, clock, frame])
		frame += 1
		elapsed += delta
	check(frame > 0, key + " produced timed frames")
	print("NATIVE_PARTICLE_KERNEL_AB ", JSON.stringify({
		"key": key,
		"clock": clock,
		"frames": frame,
		"gdscript_usec": summarize(samples[0]),
		"native_usec": summarize(samples[1]),
		"native_batches": Solver.native_batch_calls - before_batches,
		"native_particles": Solver.native_batch_particles - before_particles,
	}))


func summarize(samples: PackedInt64Array) -> Dictionary:
	if samples.is_empty():
		return {}
	samples.sort()
	var total := 0
	for value in samples:
		total += value
	return {
		"mean": float(total) / samples.size(),
		"p50": samples[ceili(samples.size() * 0.50) - 1],
		"p95": samples[ceili(samples.size() * 0.95) - 1],
		"max": samples[-1],
	}


func run_collision_and_rewind(game, effects: Node) -> void:
	var world := Node3D.new()
	game.spatial_scene.add_child(world)
	var root_key: String = effects.routes["CS2_024/impact"].root_key
	var state: Dictionary = effects.assets.instantiate(root_key, world)
	var spec: Dictionary = {}
	for entry in state.particles.values():
		if str(entry.system.key).ends_with(":-8226338306119467556"):
			spec = entry.duplicate(true)
			break
	check(not spec.is_empty(), "Frostbolt Ice Shards emitter exists")
	if spec.is_empty():
		world.free()
		return
	spec.autoplay = false
	spec.system.data.InitialModule.maxNumParticles = 1000
	spec.system.data.InitialModule.startLifetime = {"minMaxState": 0, "scalar": 3.0}
	var solvers := [Solver.new(), Solver.new()]
	for arm in solvers.size():
		Solver.native_batch_enabled = arm == 1
		var solver: Node = solvers[arm]
		solver.setup(spec, effects.assets, world, 771)
		solver.emit_from_parent(Vector3(0.2, 0.3, 0.4), 0.0, 48)
	for age in [0.011, 0.033, 0.137, 0.251, 0.051, 0.191]:
		seek_both(solvers, age, "Ice Shards rewind")

	var plane := Node3D.new()
	world.add_child(plane)
	plane.global_transform = Transform3D.IDENTITY
	for solver in solvers:
		solver.raw.moveWithTransform = 1
		solver.raw.InitialModule.gravityModifier = {"scalar": 0.0}
		for module in ["VelocityModule", "ForceModule", "InheritVelocityModule", "ClampVelocityModule", "SizeModule"]:
			solver.raw[module] = {"enabled": false}
		solver.raw.CollisionModule = {"enabled": true, "m_Bounce": {"scalar": 0.8}}
		solver.collision_planes = [plane]
		for particle in solver.particles:
			particle.start = Vector3(0, 0.3, 0)
			particle.motion_basis = Basis.IDENTITY
			particle.velocity = Vector3(0, -2, 0)
			particle.size = 0.1
	var calls: int = Solver.native_batch_calls
	for age in [0.011, 0.231, 0.385, 0.185, 0.507]:
		seek_both(solvers, age, "Ice Shards plane")
	check(solvers[0].collision_count > 0, "Ice Shards collided with the plane")
	check(Solver.native_batch_calls > calls, "Ice Shards with collision planes reached native batches")

	var weighted := {
		"minMaxState": 1,
		"scalar": 0.7,
		"maxCurve": {"m_Curve": [
			{"time": 0.0, "value": 1.0, "outSlope": -1.0, "weightedMode": 2, "outWeight": 0.2},
			{"time": 1.0, "value": 0.5},
		]},
	}
	for solver in solvers:
		solver.collision_planes = []
		solver.raw.ClampVelocityModule = {"enabled": true, "magnitude": weighted, "dampen": 1.0}
	calls = Solver.native_batch_calls
	for age in [0.051, 0.129, 0.232]:
		seek_both(solvers, age, "weighted clamp")
	check(Solver.native_batch_calls == calls, "weighted clamp curves fall back to GDScript")

	var constant_range := {"minMaxState": 3, "scalar": 1.25, "minScalar": -0.75}
	for solver in solvers:
		solver.raw.InitialModule.gravityModifier = constant_range
		solver.raw.ForceModule = {
			"enabled": true, "randomizePerFrame": true, "inWorldSpace": true,
			"x": constant_range, "y": {"scalar": -0.25}, "z": constant_range,
		}
		solver.raw.VelocityModule = {
			"enabled": true, "inWorldSpace": true, "x": constant_range,
			"speedModifier": {"minMaxState": 3, "scalar": 0.95, "minScalar": 0.65},
		}
		solver.raw.ClampVelocityModule = {"enabled": true, "magnitude": {"scalar": 0.4}, "dampen": 0.7}
		solver.raw.RotationModule = {"enabled": true, "curve": constant_range}
		solver.raw.RotationBySpeedModule = {"enabled": false}
		solver.bind_scene_gravity(Vector3(0.1, -9.8, 0.2))
		for particle in solver.particles:
			particle.motion_basis = Basis(Vector3.UP, 0.25).scaled(Vector3(0.8, 1.2, 0.9))
		check(solver._can_random_force_step(), "randomized constant force is eligible")
	calls = Solver.native_constant_batches
	for age in [0.011, 0.033, 0.137, 0.251, 0.051, 0.191]:
		seek_both(solvers, age, "randomized force worker and rewind")
	check(Solver.native_constant_batches > calls, "randomized constant force reached native batches")
	for solver in solvers:
		solver.free()
	world.free()


func seek_both(solvers: Array, age: float, label: String) -> void:
	for arm in solvers.size():
		Solver.native_batch_enabled = arm == 1
		solvers[arm].seek(age)
	compare_solver(solvers[0], solvers[1], "%s %s" % [label, age])
