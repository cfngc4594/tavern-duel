extends Node3D
## Source ParticleSystem modules, with an explicit Godot compatibility solver.
## Unity's native RNG, integration and billboard rasterization are not recovered.
const Curves = preload("res://scripts/native_summon_curves.gd")
const STEP := 1.0 / 120.0
const EPSILON := 0.00000001
const SUPPORTED_MODULES := ["InitialModule", "ShapeModule", "EmissionModule", "SizeModule", "ColorModule", "UVModule", "VelocityModule", "ClampVelocityModule", "RotationModule", "RotationBySpeedModule"]
static var skip_hidden_geometry := OS.has_feature("android")
static var profile_sources := false
static var source_times:Dictionary = {}
var constant_plan_enabled := true
var _constant_plan:RefCounted
var _resident:RefCounted
var fraction_snapshot_enabled := true
var uv_snapshot_enabled := true
var size_snapshot_enabled := true
var color_snapshot_enabled := true
var constant_step_enabled := true
var _constant_step_valid := false
var _constant_limit_amount := 0.0
var raw: Dictionary = {}
var source_renderer: Dictionary = {}
var particles: Array = []
var mesh := ArrayMesh.new()
var elapsed_seconds := 0.0
var active := false
var source_transform := Transform3D.IDENTITY
var source_key := ""
var material: Material
var source_node: Node3D
var mesh_instance: MeshInstance3D
var compatibility_basis := Basis.IDENTITY
var rng := RandomNumberGenerator.new()
var unsupported: Array = []
var enabled_modules: Array = []
var period_events: Array = []
var next_cycle := 0
var pending_events: Array = []
var simulation_time := -EPSILON
var stop_time := INF
var start_delay := 0.0
var duration := 1.0
var last_emitter := Transform3D.IDENTITY
var last_local_scale := Vector3.ONE
var mesh_triangles: Array = []
var mesh_area := 0.0
var emitted_count := 0
var live_count := 0
var dropped_at_capacity := 0
var shape_mesh_key := ""
var source_destroyed := false

func setup(spec: Dictionary, assets, parent_root: Node3D, seed_value: int) -> void:
	raw = spec.system.data
	source_renderer = spec.renderer.get("data", {})
	source_key = spec.system.key
	source_node = spec.node
	parent_root.add_child(self)
	# Remain owned by the effect container for cancellation, but do not inherit
	# its motion twice. World particles retain their birth transform; local
	# particles explicitly use the source emitter's current transform below.
	top_level = true
	global_transform = Transform3D.IDENTITY
	compatibility_basis = parent_root.global_basis
	last_emitter = source_node.global_transform
	last_local_scale = source_node.scale
	source_transform = last_emitter
	material = assets.material(str(spec.renderer.get("refs", {}).get(".m_Materials[0]", "")))
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	# This is deliberately independent of game.rng and of global randf().
	rng.seed = seed_value
	start_delay = maxf(0.0, Curves.minmax(raw.get("startDelay", {}), 0.0, rng.randf()))
	duration = maxf(EPSILON, float(raw.get("lengthInSec", 1.0)))
	for module in raw:
		if raw[module] is Dictionary and bool(raw[module].get("enabled", false)):
			enabled_modules.append(module)
			if not SUPPORTED_MODULES.has(module): _unsupported(module)
	_validate_used_fields()
	_load_shape_mesh(spec, assets)
	_build_emission_period()
	seek(0.0)

func _unsupported(field: String) -> void:
	if not unsupported.has(field): unsupported.append(field)

func _validate_used_fields() -> void:
	if int(raw.get("moveWithTransform", 0)) not in [0, 1]: _unsupported("custom simulation space")
	if bool(raw.get("prewarm", false)): _unsupported("prewarm")
	var initial: Dictionary = raw.get("InitialModule", {})
	if bool(initial.get("size3D", false)): _unsupported("InitialModule.size3D")
	if bool(initial.get("rotation3D", false)): _unsupported("InitialModule.rotation3D")
	if _curve_nonzero(initial.get("gravityModifier", {})): _unsupported("InitialModule.gravityModifier")
	var shape: Dictionary = raw.get("ShapeModule", {})
	if bool(shape.get("enabled", false)):
		if int(shape.get("type", -1)) not in [5, 6, 10]: _unsupported("ShapeModule.type=" + str(shape.get("type")))
		for field in ["randomDirectionAmount", "sphericalDirectionAmount", "randomPositionAmount"]:
			if float(shape.get(field, 0.0)) != 0.0: _unsupported("ShapeModule." + field)
		if int(shape.get("type", 0)) == 6 and int(shape.get("placementMode", 0)) != 2: _unsupported("ShapeModule mesh placement other than Triangle")
		if int(shape.get("type", 0)) == 10 and int(shape.get("arc", {}).get("mode", 0)) != 0: _unsupported("ShapeModule non-random arc mode")
	var emission: Dictionary = raw.get("EmissionModule", {})
	if bool(emission.get("enabled", false)):
		if int(emission.get("rateOverTime", {}).get("minMaxState", 0)) != 0: _unsupported("EmissionModule nonconstant rateOverTime")
		if _curve_nonzero(emission.get("rateOverDistance", {})): _unsupported("EmissionModule.rateOverDistance")
	for name in ["SizeModule", "RotationModule", "RotationBySpeedModule"]:
		var module: Dictionary = raw.get(name, {})
		if bool(module.get("enabled", false)) and bool(module.get("separateAxes", false)): _unsupported(name + ".separateAxes")
	var velocity: Dictionary = raw.get("VelocityModule", {})
	if bool(velocity.get("enabled", false)):
		for field in ["orbitalX", "orbitalY", "orbitalZ", "orbitalOffsetX", "orbitalOffsetY", "orbitalOffsetZ", "radial"]:
			if _curve_nonzero(velocity.get(field, {})): _unsupported("VelocityModule." + field)
	var uv_module: Dictionary = raw.get("UVModule", {})
	if bool(uv_module.get("enabled", false)) and int(uv_module.get("mode", 0)) != 0: _unsupported("UVModule Sprites mode")
	if int(source_renderer.get("m_RenderMode", 0)) not in [0, 1, 2]: _unsupported("renderer mode=" + str(source_renderer.get("m_RenderMode")))
	if int(source_renderer.get("m_RenderAlignment", 0)) != 0: _unsupported("renderer alignment other than View")
	if float(source_renderer.get("m_CameraVelocityScale", 0.0)) != 0.0: _unsupported("renderer camera velocity stretch")

static func _curve_nonzero(curve: Dictionary) -> bool:
	return absf(Curves.minmax(curve, 0.0, 0.0)) > EPSILON or absf(Curves.minmax(curve, 0.5, 0.5)) > EPSILON or absf(Curves.minmax(curve, 1.0, 1.0)) > EPSILON

func _load_shape_mesh(spec: Dictionary, assets) -> void:
	if int(raw.get("ShapeModule", {}).get("type", -1)) != 6: return
	shape_mesh_key = str(spec.system.get("refs", {}).get(".ShapeModule.m_Mesh", ""))
	var source_mesh: ArrayMesh = assets.geometry(shape_mesh_key)
	if source_mesh == null:
		_unsupported("missing original shape mesh " + shape_mesh_key)
		return
	var shape: Dictionary = raw.ShapeModule
	for surface in range(source_mesh.get_surface_count()):
		if bool(shape.get("m_UseMeshMaterialIndex", false)) and surface != int(shape.get("m_MeshMaterialIndex", 0)): continue
		var arrays: Array = source_mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var colors = arrays[Mesh.ARRAY_COLOR]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null or indices.is_empty():
			indices = PackedInt32Array()
			for i in range(points.size()): indices.append(i)
		for i in range(0, indices.size() - 2, 3):
			var ids := Vector3i(indices[i], indices[i + 1], indices[i + 2])
			var a := points[ids.x]; var b := points[ids.y]; var c := points[ids.z]
			var cross := (b - a).cross(c - a)
			var area := cross.length() * 0.5
			if area <= EPSILON: continue
			mesh_area += area
			var ns: Array = [cross.normalized(), cross.normalized(), cross.normalized()]
			var cs: Array = [Color.WHITE, Color.WHITE, Color.WHITE]
			for j in range(3):
				if normals != null and normals.size() == points.size(): ns[j] = normals[ids[j]]
				if colors != null and colors.size() == points.size(): cs[j] = colors[ids[j]]
			mesh_triangles.append({"points": [a, b, c], "normals": ns, "colors": cs, "area_end": mesh_area})

func _build_emission_period() -> void:
	var emission: Dictionary = raw.get("EmissionModule", {})
	if not bool(emission.get("enabled", false)): return
	# Play(withChildren) does not enable a disabled EmissionModule. In
	# particular the source EdgeLandMotes' serialized bursts stay disabled.
	for burst in emission.get("m_Bursts", []):
		var repeats := int(burst.get("cycleCount", 1))
		var interval := float(burst.get("repeatInterval", 0.0))
		if repeats == 0: repeats = maxi(1, int(ceil(duration / maxf(interval, STEP))))
		for repeat in range(repeats):
			var at := float(burst.get("time", 0.0)) + repeat * interval
			if at > duration + EPSILON: continue
			period_events.append({"at": at, "burst": burst})
	var rate_curve: Dictionary = emission.get("rateOverTime", {})
	if int(rate_curve.get("minMaxState", 0)) == 0:
		var rate := maxf(0.0, Curves.minmax(rate_curve, 0.0))
		if rate > 0.0:
			for i in range(1, int(floor(duration * rate + EPSILON)) + 1):
				period_events.append({"at": float(i) / rate, "count": 1})
	period_events.sort_custom(func(a, b): return float(a.at) < float(b.at))

func stop_emitting(seconds: float = -1.0) -> void:
	# Unity Stop(bool) forwards StopEmitting (1), not StopEmittingAndClear.
	var requested := elapsed_seconds if seconds < 0.0 else maxf(seconds, 0.0)
	stop_time = minf(stop_time, requested * float(raw.get("simulationSpeed", 1.0)))
	# Also handle a caller delivering a source stop event after a coarse seek.
	particles = particles.filter(func(p): return float(p.birth) <= stop_time)
	pending_events = pending_events.filter(func(event): return float(event.at) < stop_time)
	seek(elapsed_seconds)

func _emitter_transform() -> Transform3D:
	return source_node.global_transform if is_instance_valid(source_node) else last_emitter

func _emitter_scale() -> Vector3:
	return source_node.scale if is_instance_valid(source_node) else last_local_scale

func _birth_frame(at: float, now: float, current: Transform3D) -> Transform3D:
	if now <= simulation_time + EPSILON: return current
	var weight := clampf((at - simulation_time) / (now - simulation_time), 0.0, 1.0)
	# The caller supplies sampled source animation. Interpolation of its birth
	# transforms is a compatibility boundary, not recovered native scheduling.
	return last_emitter.interpolate_with(current, weight)

func _emit_until(now: float, current: Transform3D, local_scale: Vector3) -> void:
	if period_events.is_empty(): return
	var end := minf(now, stop_time)
	while start_delay + next_cycle * duration <= end + EPSILON:
		if next_cycle > 0 and not bool(raw.get("looping", false)): break
		var base := start_delay + next_cycle * duration
		for event in period_events:
			var item: Dictionary = event.duplicate()
			item.at = base + float(event.at)
			if float(item.at) < stop_time: pending_events.append(item)
		next_cycle += 1
	var remaining: Array = []
	for event in pending_events:
		var at: float = event.at
		if at > now + EPSILON:
			remaining.append(event)
			continue
		if at >= stop_time: continue
		var count: int = event.get("count", 0)
		if event.has("burst"):
			if rng.randf() > float(event.burst.get("probability", 1.0)): continue
			count = maxi(0, int(Curves.minmax(event.burst.countCurve, fposmod(at - start_delay, duration) / duration, rng.randf())))
		var frame := _birth_frame(at, now, current)
		var weight := 1.0 if now <= simulation_time + EPSILON else clampf((at - simulation_time) / (now - simulation_time), 0.0, 1.0)
		var birth_scale := last_local_scale.lerp(local_scale, weight)
		var living_at_birth := 0
		for p in particles:
			if float(p.birth) <= at and float(p.birth) + float(p.life) > at: living_at_birth += 1
		var available := maxi(0, int(raw.get("InitialModule", {}).get("maxNumParticles", 1000)) - living_at_birth)
		dropped_at_capacity += maxi(0, count - available)
		for _index in range(mini(count, available)): _spawn_particle(at, frame, birth_scale)
	pending_events = remaining

func _sample_shape() -> Dictionary:
	var shape: Dictionary = raw.get("ShapeModule", {})
	var point := Vector3.ZERO
	var direction := Vector3.BACK # Unity shape's +Z emission direction.
	var shape_color := Color.WHITE
	if bool(shape.get("enabled", false)):
		match int(shape.get("type", -1)):
			5:
				point = Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
			6:
				if mesh_triangles.is_empty() or int(shape.get("placementMode", 0)) != 2: return {}
				var area_choice := rng.randf() * mesh_area
				var triangle: Dictionary = mesh_triangles[-1]
				for candidate in mesh_triangles:
					if area_choice <= float(candidate.area_end): triangle = candidate; break
				var root_u := sqrt(rng.randf())
				var weights := Vector3(1.0 - root_u, root_u * (1.0 - rng.randf()), 0.0)
				weights.z = 1.0 - weights.x - weights.y
				direction = Vector3.ZERO
				shape_color = Color(0, 0, 0, 0)
				for j in range(3):
					point += triangle.points[j] * weights[j]
					direction += triangle.normals[j] * weights[j]
					shape_color += triangle.colors[j] * weights[j]
				direction = direction.normalized()
				point += direction * float(shape.get("m_MeshNormalOffset", 0.0))
				if not bool(shape.get("m_UseMeshColors", true)): shape_color = Color.WHITE
			10:
				var angle := rng.randf() * deg_to_rad(float(shape.get("arc", {}).get("value", 360.0)))
				direction = Vector3(cos(angle), sin(angle), 0)
				var radius := float(shape.get("radius", {}).get("value", 1.0))
				var thickness := clampf(float(shape.get("radiusThickness", 1.0)), 0.0, 1.0)
				if thickness > 0.0: radius *= sqrt(lerpf(pow(1.0 - thickness, 2), 1.0, rng.randf()))
				point = direction * radius
			_:
				return {} # Do not invent a shape for unsupported source modules.
		var shape_basis := Basis.from_euler(Curves.vec(shape.get("m_Rotation", {})) * PI / 180.0, EULER_ORDER_YXZ)
		point = shape_basis * (point * Curves.vec(shape.get("m_Scale", {"x": 1, "y": 1, "z": 1}))) + Curves.vec(shape.get("m_Position", {}))
		direction = shape_basis * direction
	return {"point": point, "direction": direction, "color": shape_color}

func _motion_basis(frame: Transform3D, local_scale: Vector3) -> Basis:
	var source_basis := compatibility_basis.inverse() * frame.basis
	match int(raw.get("scalingMode", 0)):
		0: return frame.basis
		1: return compatibility_basis * source_basis.orthonormalized().scaled_local(local_scale)
		2: return compatibility_basis * source_basis.orthonormalized()
	return frame.basis

func _spawn_particle(at: float, frame: Transform3D, local_scale: Vector3) -> void:
	var sample := _sample_shape()
	if sample.is_empty(): return
	var initial: Dictionary = raw.get("InitialModule", {})
	var phase := fposmod(maxf(0.0, at - start_delay), duration) / duration
	var life := maxf(0.0, Curves.minmax(initial.get("startLifetime", {}), phase, rng.randf()))
	if life <= 0.0: return
	var rotation := Curves.minmax(initial.get("startRotation", {}), phase, rng.randf())
	if rng.randf() < float(initial.get("randomizeRotationDirection", 0.0)): rotation *= -1.0
	var speed := Curves.minmax(initial.get("startSpeed", {}), phase, rng.randf())
	var p: Dictionary = {"birth": at, "life": life, "size": Curves.minmax(initial.get("startSize", {}), phase, rng.randf()), "shape_point": sample.point, "start": frame * sample.point, "birth_frame": frame, "birth_scale": local_scale, "motion_basis": _motion_basis(frame, local_scale), "velocity": sample.direction * speed, "color": sample.color * sample_color(initial.get("startColor", {}), phase, rng.randf()), "rotation": rotation, "size_mix": rng.randf(), "color_mix": rng.randf(), "limit_mix": rng.randf(), "tile_mix": rng.randf(), "tile_start_mix": rng.randf(), "rotation_mix": rng.randf(), "velocity_mix": Vector3(rng.randf(), rng.randf(), rng.randf()), "row_mix": rng.randf(), "flip_u": rng.randf(), "flip_v": rng.randf(), "sim_age": 0.0, "displacement": Vector3.ZERO, "sim_rotation": rotation}
	p.sim_velocity = p.velocity + _velocity_over_life(p, 0.0)
	particles.append(p)
	emitted_count += 1

static func gradient(d: Dictionary, t: float) -> Color:
	var result := Color.WHITE
	for part in ["color", "alpha"]:
		var count := int(d.get("m_NumColorKeys" if part == "color" else "m_NumAlphaKeys", 0))
		if count == 0: continue
		var times: Array = []
		for i in range(count): times.append(float(d.get(("ctime" if part == "color" else "atime") + str(i), 0)) / 65535.0)
		var index := 0
		while index < count - 1 and t >= float(times[index + 1]): index += 1
		var a := Curves.color(d.get("key" + str(index), {}))
		var b := Curves.color(d.get("key" + str(mini(index + 1, count - 1)), {}))
		var u := 0.0
		if index < count - 1 and float(times[index + 1]) > float(times[index]): u = clampf((t - float(times[index])) / (float(times[index + 1]) - float(times[index])), 0.0, 1.0)
		if int(d.get("m_Mode", 0)) == 1: u = 0.0
		var c := a.lerp(b, u)
		if part == "color": result.r = c.r; result.g = c.g; result.b = c.b
		else: result.a = c.a
	return result

static func sample_color(d: Dictionary, t: float, mix_value: float) -> Color:
	match int(d.get("minMaxState", 0)):
		0: return Curves.color(d.get("maxColor", {}))
		1: return gradient(d.get("maxGradient", {}), t)
		2: return Curves.color(d.get("minColor", {})).lerp(Curves.color(d.get("maxColor", {})), mix_value)
		3: return gradient(d.get("minGradient", {}), t).lerp(gradient(d.get("maxGradient", {}), t), mix_value)
		4: return gradient(d.get("maxGradient", {}), mix_value)
	return Color.WHITE

func _velocity_over_life(p: Dictionary, normalized: float) -> Vector3:
	var module: Dictionary = raw.get("VelocityModule", {})
	if not bool(module.get("enabled", false)): return Vector3.ZERO
	var velocity := Vector3(Curves.minmax(module.get("x", {}), normalized, p.velocity_mix.x), Curves.minmax(module.get("y", {}), normalized, p.velocity_mix.y), Curves.minmax(module.get("z", {}), normalized, p.velocity_mix.z))
	if bool(module.get("inWorldSpace", false)): velocity = p.motion_basis.inverse() * (compatibility_basis * velocity)
	return velocity

func _integrate(p: Dictionary, state: Dictionary, dt: float) -> Dictionary:
	var normalized := clampf((float(state.age) + dt) / float(p.life), 0.0, 1.0)
	var velocity: Vector3 = state.velocity
	# Velocity-over-life is an additive velocity, not an acceleration added
	# every step. Apply the difference from its preceding sample.
	velocity += _velocity_over_life(p, normalized) - _velocity_over_life(p, float(state.age) / float(p.life))
	var limit: Dictionary = raw.get("ClampVelocityModule", {})
	if bool(limit.get("enabled", false)):
		var amount := 1.0 - pow(1.0 - clampf(float(limit.get("dampen", 0.0)), 0.0, 1.0), dt / STEP)
		if bool(limit.get("separateAxis", false)):
			for axis in range(3):
				var cap := maxf(0.0, Curves.minmax(limit.get(["x", "y", "z"][axis], {}), normalized, p.limit_mix))
				velocity[axis] = lerpf(velocity[axis], clampf(velocity[axis], -cap, cap), amount)
		else:
			var cap := maxf(0.0, Curves.minmax(limit.get("magnitude", {}), normalized, p.limit_mix))
			var speed := velocity.length()
			if speed > cap: velocity *= lerpf(speed, cap, amount) / speed
		var drag := maxf(0.0, Curves.minmax(limit.get("drag", {}), normalized, p.limit_mix))
		if drag > 0.0:
			if bool(limit.get("multiplyDragByParticleSize", false)): drag *= float(p.size)
			if bool(limit.get("multiplyDragByParticleVelocity", false)): drag *= velocity.length()
			velocity *= maxf(0.0, 1.0 - drag * dt)
	var rotation: float = state.rotation
	var rotation_module: Dictionary = raw.get("RotationModule", {})
	if bool(rotation_module.get("enabled", false)): rotation += Curves.minmax(rotation_module.get("curve", {}), normalized, p.rotation_mix) * dt
	var by_speed: Dictionary = raw.get("RotationBySpeedModule", {})
	if bool(by_speed.get("enabled", false)):
		var speed_range: Dictionary = by_speed.get("range", {})
		var span := float(speed_range.get("y", 1.0)) - float(speed_range.get("x", 0.0))
		var speed_t := clampf((velocity.length() - float(speed_range.get("x", 0.0))) / maxf(span, EPSILON), 0.0, 1.0)
		rotation += Curves.minmax(by_speed.get("curve", {}), speed_t, p.rotation_mix) * dt
	var multiplier := 1.0
	if bool(raw.get("VelocityModule", {}).get("enabled", false)): multiplier = Curves.minmax(raw.VelocityModule.get("speedModifier", {"scalar": 1.0}), normalized, p.velocity_mix.x)
	return {"age": float(state.age) + dt, "position": state.position + velocity * multiplier * dt, "velocity": velocity, "rotation": rotation}

func _particle_state(p: Dictionary, age: float) -> Dictionary:
	if age + EPSILON < float(p.sim_age):
		p.sim_age = 0.0; p.displacement = Vector3.ZERO; p.sim_velocity = p.velocity + _velocity_over_life(p, 0.0); p.sim_rotation = p.rotation
	var state: Dictionary = {"age": p.sim_age, "position": p.displacement, "velocity": p.sim_velocity, "rotation": p.sim_rotation}
	if _constant_step_valid:
		state = _plan_advance(p, state, age) if _constant_plan != null else _advance_constant_steps(p, state, age)
	else:
		while float(state.age) + STEP <= age + EPSILON: state = _integrate(p, state, STEP)
	p.sim_age = state.age; p.displacement = state.position; p.sim_velocity = state.velocity; p.sim_rotation = state.rotation
	if age > float(state.age) + EPSILON:
		state = (_plan_fraction(p, state, age - float(state.age)) if _constant_plan != null else _constant_fraction(p, state, age - float(state.age))) if fraction_snapshot_enabled and _constant_step_valid else _integrate(p, state, age - float(state.age))
	return state

func _position(p: Dictionary, time: float) -> Vector3:
	_prepare_constant_steps()
	var state := _particle_state(p, time)
	if int(raw.get("moveWithTransform", 0)) == 1: return p.start + p.motion_basis * state.position
	var frame := _emitter_transform()
	return frame * p.shape_point + _motion_basis(frame, _emitter_scale()) * state.position

func _uv_corners(p: Dictionary, age: float, speed: float) -> Array:
	var uv_module: Dictionary = raw.get("UVModule", {})
	var cols := 1; var rows := 1; var tile := 0
	if bool(uv_module.get("enabled", false)) and int(uv_module.get("mode", 0)) == 0:
		cols = maxi(1, int(uv_module.get("tilesX", 1))); rows = maxi(1, int(uv_module.get("tilesY", 1)))
		var normalized := age / float(p.life)
		var phase := normalized
		if int(uv_module.get("timeMode", 0)) == 1:
			var limits: Dictionary = uv_module.get("speedRange", {})
			phase = clampf((speed - float(limits.get("x", 0.0))) / maxf(EPSILON, float(limits.get("y", 1.0)) - float(limits.get("x", 0.0))), 0.0, 1.0)
		var frame_count := cols * rows if int(uv_module.get("animationType", 0)) == 0 else cols
		var frame := Curves.minmax(uv_module.get("frameOverTime", {}), phase, p.tile_mix) * float(uv_module.get("cycles", 1.0))
		if int(uv_module.get("timeMode", 0)) == 2: frame = age * float(uv_module.get("fps", 30.0)) / frame_count
		# Serialized UVModule values are normalized: the Unity inspector remaps
		# both curves by tilesX*tilesY (or tilesX for SingleRow).
		frame += Curves.minmax(uv_module.get("startFrame", {}), 0.0, p.tile_start_mix)
		tile = posmod(int(floor(frame * frame_count)), frame_count)
		if int(uv_module.get("animationType", 0)) == 1:
			var row := int(uv_module.get("rowIndex", 0))
			if int(uv_module.get("rowMode", 0)) == 1: row = mini(rows - 1, int(p.row_mix * rows))
			tile += clampi(row, 0, rows - 1) * cols
	var origin := Vector2(tile % cols, int(tile / cols)) / Vector2(cols, rows)
	var corners: Array = []
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		if float(p.flip_u) < float(uv_module.get("flipU", 0.0)): corner.x = 1.0 - corner.x
		if float(p.flip_v) < float(uv_module.get("flipV", 0.0)): corner.y = 1.0 - corner.y
		corners.append(origin + corner / Vector2(cols, rows))
	return corners

func seek(seconds: float) -> void:
	if not profile_sources:
		_seek_impl(seconds)
		return
	var started:=Time.get_ticks_usec()
	_seek_impl(seconds)
	var key:=source_key+('/visible' if is_instance_valid(mesh_instance) and mesh_instance.is_visible_in_tree() else '/hidden')
	var row:Dictionary=source_times.get(key,{"calls":0,"usec":0,"max_usec":0,"max_live":0})
	var cost:=Time.get_ticks_usec()-started
	row.calls+=1;row.usec+=cost;row.max_usec=maxi(row.max_usec,cost);row.max_live=maxi(row.max_live,live_count)
	source_times[key]=row

func _seek_impl(seconds: float) -> void:
	_prepare_constant_steps()
	elapsed_seconds = maxf(seconds, 0.0)
	# The wrapper is not the original emitter GO. Destroying that GO must also
	# destroy its particles, unlike an explicit StopEmitting action.
	if not is_instance_valid(source_node) or source_node.is_queued_for_deletion():
		if _resident!=null:_resident.close()
		source_destroyed = true; active = false; live_count = 0; stop_time = 0.0
		particles.clear(); pending_events.clear(); mesh.clear_surfaces()
		if is_instance_valid(mesh_instance): mesh_instance.visible = false
		return
	var now := elapsed_seconds * float(raw.get("simulationSpeed", 1.0))
	var frame := _emitter_transform()
	var local_scale := _emitter_scale()
	# Rewinding resamples existing particles; it must not restart an emitter.
	if now + EPSILON >= simulation_time:
		_emit_until(now, frame, local_scale)
		simulation_time = now; last_emitter = frame; last_local_scale = local_scale
	if preload("res://scripts/summon_resident.gd").eligible(self):
		if _resident==null:
			_resident=preload("res://scripts/summon_resident.gd").new();_resident.setup(self)
		if _resident.update(now,frame,local_scale):return
	if _resident!=null and mesh_instance.mesh==_resident.fixed_mesh:
		# Reconstruct CPU checkpoints from original birth state on fallback.
		mesh_instance.mesh=mesh;mesh_instance.material_override=material
		for p in particles:
			p.sim_age=0.0;p.displacement=Vector3.ZERO;p.sim_velocity=p.velocity+_velocity_over_life(p,0.0);p.sim_rotation=p.rotation
	if preload("res://scripts/summon_compute.gd").enabled and _constant_step_valid:
		preload("res://scripts/summon_compute.gd").apply(particles,raw,now,stop_time)
	var render_geometry:=not skip_hidden_geometry or (bool(source_renderer.get("m_Enabled",true)) and source_node.is_visible_in_tree())
	mesh.clear_surfaces()
	live_count = 0
	var vertices := PackedVector3Array(); var uvs := PackedVector2Array(); var colors := PackedColorArray(); var indices := PackedInt32Array(); var normals := PackedVector3Array()
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var view_right := camera.global_basis.x.normalized() if camera != null else compatibility_basis.x.normalized()
	var view_up := camera.global_basis.y.normalized() if camera != null else compatibility_basis.y.normalized()
	var view_normal := view_right.cross(view_up).normalized()
	var color_sampler = _frame_color_sampler() if render_geometry and not particles.is_empty() else null
	var size_sampler = _frame_size_sampler() if render_geometry and not particles.is_empty() else null
	var uv_sampler = _frame_uv_snapshot() if render_geometry and not particles.is_empty() else null
	if constant_plan_enabled and _constant_step_valid and not particles.is_empty():
		_constant_plan = preload("res://scripts/summon_constant_plan.gd").new()
		_constant_plan.setup(raw, Curves)
	for p in particles:
		var age := now - float(p.birth)
		if age < 0.0 or age >= float(p.life) or float(p.birth) > stop_time: continue
		live_count += 1
		if not render_geometry:
			_particle_state(p,age)
			continue
		var normalized := age / float(p.life)
		var size: float = p.size
		if size_sampler != null: size *= size_sampler.sample(normalized, p.size_mix)
		elif bool(raw.get("SizeModule", {}).get("enabled", false)): size *= Curves.minmax(raw.SizeModule.curve, normalized, p.size_mix)
		var color: Color = p.color
		if color_sampler != null: color *= color_sampler.sample(normalized, p.color_mix)
		elif bool(raw.get("ColorModule", {}).get("enabled", false)): color *= sample_color(raw.ColorModule.gradient, normalized, p.color_mix)
		var state := _particle_state(p, age)
		var world_space := int(raw.get("moveWithTransform", 0)) == 1
		var motion: Basis = p.motion_basis if world_space else _motion_basis(frame, local_scale)
		var center: Vector3 = p.start + motion * state.position if world_space else frame * p.shape_point + motion * state.position
		var velocity: Vector3 = motion * state.velocity
		var scale_x := motion.x.length(); var scale_y := motion.y.length()
		var right := view_right; var up := view_up; var normal := view_normal
		var mode := int(source_renderer.get("m_RenderMode", 0))
		if mode == 2:
			right = compatibility_basis.x.normalized(); up = compatibility_basis.z.normalized()
			normal = right.cross(up).normalized(); scale_y = motion.z.length()
		elif mode == 1:
			var projected := velocity - view_normal * velocity.dot(view_normal)
			if projected.length_squared() > EPSILON: up = projected.normalized(); right = up.cross(view_normal).normalized()
			scale_y = scale_y * float(source_renderer.get("m_LengthScale", 1.0)) + velocity.length() * float(source_renderer.get("m_VelocityScale", 0.0)) / maxf(absf(size), EPSILON)
		var rotation: float = state.rotation
		# Stretched particles follow velocity when the source renderer requests it.
		if mode != 1 or not bool(source_renderer.get("m_RotateWithStretchDirection", true)):
			right = right.rotated(normal, rotation); up = up.rotated(normal, rotation)
		var x := right * size * scale_x * 0.5
		var y := up * size * scale_y * 0.5
		var start := vertices.size()
		for offset in [-x + y, x + y, x - y, -x - y]: vertices.append(center + offset); colors.append(color); normals.append(normal)
		for uv in (uv_sampler.sample(p, age, state.velocity.length()) if uv_sampler != null else _uv_corners(p, age, state.velocity.length())): uvs.append(uv)
		indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	_constant_plan = null
	var can_emit := bool(raw.get("EmissionModule", {}).get("enabled", false)) and not period_events.is_empty() and now < stop_time and (bool(raw.get("looping", false)) or now <= start_delay + duration)
	active = live_count > 0 or can_emit
	mesh_instance.visible = bool(source_renderer.get("m_Enabled", true)) and (not is_instance_valid(source_node) or source_node.is_visible_in_tree())
	if vertices.is_empty(): return
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_INDEX] = indices; arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func get_audit() -> Dictionary:
	return {"source_key": source_key, "original_count": emitted_count, "live_count": live_count, "elapsed": elapsed_seconds, "active": active, "emission_enabled": raw.get("EmissionModule", {}).get("enabled", false), "stop_seconds": stop_time / maxf(EPSILON, float(raw.get("simulationSpeed", 1.0))) if is_finite(stop_time) else -1.0, "start_delay": start_delay, "simulation_space": raw.get("moveWithTransform", 0), "scaling_mode": raw.get("scalingMode", 0), "shape_type": raw.get("ShapeModule", {}).get("type"), "shape_mesh_key": shape_mesh_key, "source_mesh_triangles": mesh_triangles.size(), "render_mode": source_renderer.get("m_RenderMode"), "enabled_modules": enabled_modules.duplicate(), "original_modules": unsupported.is_empty(), "unsupported": unsupported.duplicate(), "dropped_at_capacity": dropped_at_capacity, "source_destroyed": source_destroyed, "solver": "Godot compatibility: fixed 1/120 velocity/limit/rotation integration; source curves and module enable flags", "birth_transform_sampling": "source emitter transforms interpolated between seek calls; not native Unity frame scheduling", "renderer_compatibility": "source billboard/horizontal/stretch modes; Godot camera, triangle rasterization, and screen-size clamp are not Unity-native", "rng": "instance-local Godot PCG; not Unity RNG; never game.rng", "native_pixel_equivalence": false}

# Rebuilt each seek: no cross-frame module or curve assumptions. All unsupported
# signatures use the original integrator, including their fractional steps.
func _prepare_constant_steps() -> void:
	_constant_plan = null
	_constant_step_valid = false
	if not constant_step_enabled or get_script().get_base_script() != null: return
	var velocity: Dictionary = raw.get("VelocityModule", {})
	var limit: Dictionary = raw.get("ClampVelocityModule", {})
	var rotation: Dictionary = raw.get("RotationModule", {})
	if bool(raw.get("RotationBySpeedModule", {}).get("enabled", false)): return
	var parameters: Array = []
	if bool(velocity.get("enabled", false)):
		parameters.append_array([velocity.get("x", {}), velocity.get("y", {}), velocity.get("z", {}), velocity.get("speedModifier", {"scalar": 1.0})])
	if bool(limit.get("enabled", false)):
		if bool(limit.get("separateAxis", false)): return
		var drag: Dictionary = limit.get("drag", {})
		if int(drag.get("minMaxState", 0)) != 0 or Curves.number(drag.get("scalar", 0.0)) != 0.0: return
		parameters.append(limit.get("magnitude", {}))
	if bool(rotation.get("enabled", false)): parameters.append(rotation.get("curve", {}))
	for curve in parameters:
		if int(curve.get("minMaxState", 0)) not in [0, 3]: return
		if not is_finite(Curves.number(curve.get("scalar", 0.0))) or not is_finite(Curves.number(curve.get("minScalar", curve.get("scalar", 0.0)))): return
	_constant_limit_amount = 1.0 - pow(1.0 - clampf(float(limit.get("dampen", 0.0)), 0.0, 1.0), STEP / STEP)
	_constant_step_valid = true

func _advance_constant_steps(p: Dictionary, state: Dictionary, until: float) -> Dictionary:
	var age: float = state.age
	if age + STEP > until + EPSILON: return state
	var velocity: Vector3 = state.velocity
	var position: Vector3 = state.position
	var rotation: float = state.rotation
	var additive := _velocity_over_life(p, 0.0)
	# Keep the original subtraction/addition even for constant additive velocity.
	var additive_delta := additive - additive
	var module: Dictionary = raw.get("VelocityModule", {})
	var multiplier := Curves.minmax(module.get("speedModifier", {"scalar": 1.0}), 0.0, p.velocity_mix.x) if bool(module.get("enabled", false)) else 1.0
	var limit: Dictionary = raw.get("ClampVelocityModule", {})
	var limited := bool(limit.get("enabled", false))
	var cap := maxf(0.0, Curves.minmax(limit.get("magnitude", {}), 0.0, p.limit_mix)) if limited else 0.0
	var rotation_module: Dictionary = raw.get("RotationModule", {})
	var rotates := bool(rotation_module.get("enabled", false))
	var rotation_step := Curves.minmax(rotation_module.get("curve", {}), 0.0, p.rotation_mix) * STEP if rotates else 0.0
	while age + STEP <= until + EPSILON:
		velocity += additive_delta
		if limited:
			var speed := velocity.length()
			if speed > cap: velocity *= lerpf(speed, cap, _constant_limit_amount) / speed
		if rotates: rotation += rotation_step
		position = position + velocity * multiplier * STEP
		age = age + STEP
	return {"age": age, "position": position, "velocity": velocity, "rotation": rotation}

# Per-seek snapshot only: runtime edits take effect on the next sample. Subclasses
# retain the original callback path because their callbacks may mutate raw data.
func _frame_color_sampler() -> RefCounted:
	if not color_snapshot_enabled or get_script().get_base_script() != null: return null
	var module: Dictionary = raw.get("ColorModule", {})
	if not bool(module.get("enabled", false)): return null
	var sampler = preload("res://scripts/particle_color_sampler.gd").new()
	sampler.setup(module.gradient, Curves)
	return sampler

func _frame_size_sampler() -> RefCounted:
	if not size_snapshot_enabled or get_script().get_base_script() != null: return null
	var module: Dictionary = raw.get("SizeModule", {})
	if not bool(module.get("enabled", false)): return null
	# setup assumes a fresh object; do not retain this sampler across seeks.
	var sampler = preload("res://scripts/particle_size_sampler.gd").new()
	sampler.setup(module.curve, Curves)
	return sampler

func _frame_uv_snapshot():
	if not uv_snapshot_enabled or get_script().get_base_script()!=null:return null
	var sampler=preload("res://scripts/particle_uv_sampler.gd").new()
	return sampler if sampler.setup(raw.get("UVModule",{})) else null
# Exact fractional Euler step for the existing base-only constant-module guard.
func _constant_fraction(p: Dictionary, state: Dictionary, dt: float) -> Dictionary:
	var velocity: Vector3 = state.velocity
	var additive := _velocity_over_life(p, 0.0)
	velocity += additive - additive
	var limit: Dictionary = raw.get("ClampVelocityModule", {})
	if bool(limit.get("enabled", false)):
		var amount := 1.0 - pow(1.0 - clampf(float(limit.get("dampen", 0.0)), 0.0, 1.0), dt / STEP)
		var cap := maxf(0.0, Curves.minmax(limit.get("magnitude", {}), 0.0, p.limit_mix))
		var speed := velocity.length()
		if speed > cap: velocity *= lerpf(speed, cap, amount) / speed
	var rotation: float = state.rotation
	var rotation_module: Dictionary = raw.get("RotationModule", {})
	if bool(rotation_module.get("enabled", false)): rotation += Curves.minmax(rotation_module.get("curve", {}), 0.0, p.rotation_mix) * dt
	var multiplier := 1.0
	var module: Dictionary = raw.get("VelocityModule", {})
	if bool(module.get("enabled", false)): multiplier = Curves.minmax(module.get("speedModifier", {"scalar": 1.0}), 0.0, p.velocity_mix.x)
	return {"age": float(state.age) + dt, "position": state.position + velocity * multiplier * dt, "velocity": velocity, "rotation": rotation}

func _plan_advance(p:Dictionary,state:Dictionary,until:float)->Dictionary:
	var age:float=state.age
	if age+STEP>until+EPSILON:return state
	var velocity:Vector3=state.velocity
	var position:Vector3=state.position
	var rotation:float=state.rotation
	var additive:Vector3=_constant_plan.velocity(p,compatibility_basis)
	var additive_delta:=additive-additive
	var multiplier:float=_constant_plan.scalar(3,p.velocity_mix.x) if _constant_plan.velocity_enabled else 1.0
	var limited:bool=_constant_plan.limited
	var cap:float=maxf(0.0,_constant_plan.scalar(4,p.limit_mix)) if limited else 0.0
	var rotates:bool=_constant_plan.rotates
	var rotation_step:float=_constant_plan.scalar(5,p.rotation_mix)*STEP if rotates else 0.0
	while age+STEP<=until+EPSILON:
		velocity+=additive_delta
		if limited:
			var speed:=velocity.length()
			if speed>cap:velocity*=lerpf(speed,cap,_constant_limit_amount)/speed
		if rotates:rotation+=rotation_step
		position=position+velocity*multiplier*STEP
		age=age+STEP
	return {"age":age,"position":position,"velocity":velocity,"rotation":rotation}
func _plan_fraction(p:Dictionary,state:Dictionary,dt:float)->Dictionary:
	var velocity:Vector3=state.velocity
	var additive:Vector3=_constant_plan.velocity(p,compatibility_basis)
	velocity+=additive-additive
	if _constant_plan.limited:
		var amount:=1.0-pow(_constant_plan.dampen_base,dt/STEP)
		var cap:=maxf(0.0,_constant_plan.scalar(4,p.limit_mix))
		var speed:=velocity.length()
		if speed>cap:velocity*=lerpf(speed,cap,amount)/speed
	var rotation:float=state.rotation
	if _constant_plan.rotates:rotation+=_constant_plan.scalar(5,p.rotation_mix)*dt
	var multiplier:=1.0
	if _constant_plan.velocity_enabled:multiplier=_constant_plan.scalar(3,p.velocity_mix.x)
	return {"age":float(state.age)+dt,"position":state.position+velocity*multiplier*dt,"velocity":velocity,"rotation":rotation}

func _exit_tree()->void:
	if _resident!=null:_resident.close();_resident=null
