extends SceneTree

const Solver = preload("res://original_board/scripts/source_particle_solver.gd")
const WARMUP_STEPS := 720
const SAMPLED_STEPS := 180
const STEP := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("run")

func _same_particles(reference, candidate, label: String) -> bool:
	if [reference.live_count, reference.emitted_count, reference.rng.state, reference.dropped_at_capacity,
			reference.screen_size_clamped] != [candidate.live_count, candidate.emitted_count, candidate.rng.state,
			candidate.dropped_at_capacity, candidate.screen_size_clamped]:
		push_error(label + " count, RNG, or clamp mismatch")
		return false
	if var_to_bytes(reference.particles) != var_to_bytes(candidate.particles):
		for index in mini(reference.particles.size(), candidate.particles.size()):
			for key in reference.particles[index]:
				var left = reference.particles[index][key]
				var right = candidate.particles[index].get(key)
				if var_to_bytes(left) != var_to_bytes(right):
					push_error("%s particle %d %s differs: %s / %s" % [label, index, key, left, right])
					return false
		push_error(label + " particle storage mismatch")
		return false
	if reference.mesh.get_surface_count() != candidate.mesh.get_surface_count():
		push_error(label + " surface count mismatch")
		return false
	for surface in reference.mesh.get_surface_count():
		if var_to_bytes(reference.mesh.surface_get_arrays(surface)) != var_to_bytes(candidate.mesh.surface_get_arrays(surface)):
			push_error(label + " mesh array mismatch")
			return false
	return true

func _stats(samples: Array[int]) -> Dictionary:
	samples.sort()
	var total := 0
	for sample in samples:
		total += sample
	return {"mean_usec": float(total) / samples.size(), "p50_usec": samples[samples.size() / 2],
		"p95_usec": samples[ceili(samples.size() * 0.95) - 1]}

func run() -> void:
	if not ClassDB.class_exists(&"TavernParticleKernel"):
		push_error("Load the particle extension before running this test")
		quit(1)
		return
	var previous_switch := Solver.native_board_state_enabled
	Solver.native_board_state_enabled = false
	preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform = true
	root.size = Vector2i(1440, 810)
	var game: Node = load("res://main.tscn").instantiate()
	game.startup_mode = "practice"
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.source_phone_layout.refresh()
	game.source_projection = game.source_phone_layout.context
	game.original_board_bridge.sync_source_camera()
	var probe = game.original_board_bridge.probe
	var host = probe.water_particles
	var pairs: Array[Dictionary] = []
	for entry in host.entries.values():
		var row: Dictionary = entry.row
		if row.get("source_category") != "environment":
			continue
		var spec := {"system": row.system, "renderer": row.renderer, "node": entry.proxy, "autoplay": true,
			"compatibility_basis": host.REFLECTION, "source_scope_root": probe.source_root,
			"fixed_simulation_modules": true, "fixed_draw_curves": true, "emission_density": 1.0}
		spec.merge(row.get("solver_options", {}), true)
		var seed_value: int = entry.current.instance_seed if is_instance_valid(entry.current) else 97004 + pairs.size()
		var reference := Solver.new()
		var candidate := Solver.new()
		reference.setup(spec, host, host, seed_value)
		candidate.setup(spec, host, host, seed_value)
		pairs.append({"reference": reference, "candidate": candidate, "name": row.name})
	if pairs.size() != 8:
		push_error("Expected all eight full-density phone water and dust emitters")
		quit(1)
		return
	var old_samples: Array[int] = []
	var new_samples: Array[int] = []
	for frame in WARMUP_STEPS + SAMPLED_STEPS:
		var age := (frame + 1) * STEP
		for native in ([false, true] if frame % 2 == 0 else [true, false]):
			Solver.native_board_state_enabled = native
			var started := Time.get_ticks_usec()
			for pair in pairs:
				var solver = pair.candidate if native else pair.reference
				solver.seek(age)
				host._prune_expired(solver)
			if frame >= WARMUP_STEPS:
				var samples := new_samples if native else old_samples
				samples.append(Time.get_ticks_usec() - started)
		if frame % 15 == 0 or frame == WARMUP_STEPS + SAMPLED_STEPS - 1:
			for pair in pairs:
				if not _same_particles(pair.reference, pair.candidate, "%s frame %d" % [pair.name, frame]):
					quit(1)
					return
	var batches: Dictionary = {}
	for pair in pairs:
		var exercise_explicit_birth: bool = pair.candidate.native_board_state_batches == 0
		for native in [false, true]:
			Solver.native_board_state_enabled = native
			var solver = pair.candidate if native else pair.reference
			solver.seek(14.8)
			# A normally dormant source still has to exercise the numerical batch.
			if exercise_explicit_birth:
				solver.emit_count(4, 14.8)
				solver.seek(14.85)
		if pair.candidate.native_board_state_batches == 0 or not _same_particles(pair.reference, pair.candidate, pair.name + " rewind"):
			push_error("Missing exact native batch for " + pair.name)
			quit(1)
			return
		batches[pair.name] = pair.candidate.native_board_state_batches
	Solver.native_board_state_enabled = previous_switch
	print("NATIVE_BOARD_PARTICLE_KERNEL_PASS ", JSON.stringify({"old": _stats(old_samples), "new": _stats(new_samples),
		"density": 1.0, "warmup_steps": WARMUP_STEPS, "sampled_steps": SAMPLED_STEPS, "batches": batches}))
	game.free()
	quit()
