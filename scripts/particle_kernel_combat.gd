extends RefCounted
# Worker-private numerical evaluator. No scene, resource mutation or RNG calls.
const Curves = preload("res://scripts/native_summon_curves.gd")
const STEP := 1.0 / 120.0
const EPSILON := 0.00000001
var _constant_plan: RefCounted
var raw: Dictionary = {}
var compatibility_basis := Basis.IDENTITY
var source_gravity := Vector3.ZERO
var collision_planes: Array = []
var _constant_zero_linear := false
var _constant_zero_spatial := false
var _linear_zero := false
var _spatial_zero := false
var _world_velocity := false
# Caller has already proved eligibility and keeps raw immutable until join.
func prepare() -> void:
	_constant_plan=preload("res://scripts/particle_constant_plan.gd").new(); _constant_plan.setup(raw,Curves)
	_linear_zero = false; _spatial_zero = false; _world_velocity = false
	var module: Dictionary = raw.get("VelocityModule", {})
	if bool(module.get("enabled", false)):
		_linear_zero = _zero_constant_components(module, ["x", "y", "z"])
		_spatial_zero = _zero_constant_components(module, ["orbitalX", "orbitalY", "orbitalZ", "radial"])
		_world_velocity = bool(module.get("inWorldSpace", false))

func _particle_state(p: Dictionary, age: float) -> Dictionary:
	var previous_linear: bool = _constant_zero_linear
	var previous_spatial: bool = _constant_zero_spatial
	_constant_zero_linear = _linear_zero
	_constant_zero_spatial = _spatial_zero
	if _constant_zero_linear and _world_velocity and (not is_finite(p.motion_basis.determinant()) or absf(p.motion_basis.determinant()) <= EPSILON): _constant_zero_linear = false
	if age + EPSILON < float(p.sim_age):
		p.sim_age = 0.0; p.displacement = Vector3.ZERO; p.sim_velocity = p.velocity + _velocity_over_life(p, 0.0) + _inherit_velocity(p, 0.0); p.sim_rotation = p.rotation; p.sim_render_velocity = p.sim_velocity + _spatial_velocity(p, Vector3.ZERO, 0.0); p.kill_age = INF; p.collision_loss = 0.0; p.collision_hits = 0
	var state: Dictionary = {"age": p.sim_age, "position": p.displacement, "velocity": p.sim_velocity, "rotation": p.sim_rotation, "render_velocity": p.sim_render_velocity, "kill_age": p.kill_age, "collision_loss": p.collision_loss, "collision_hits": p.collision_hits}
	state = _constant_step_state(p, state, age)
	p.sim_age = state.age; p.displacement = state.position; p.sim_velocity = state.velocity; p.sim_rotation = state.rotation; p.sim_render_velocity = state.get("render_velocity", state.velocity); p.kill_age = state.kill_age; p.collision_loss = state.collision_loss; p.collision_hits = state.collision_hits
	if age > float(state.age) + EPSILON: state = _integrate(p, state, age - float(state.age))
	_constant_zero_linear = previous_linear; _constant_zero_spatial = previous_spatial
	return state


func _integrate(p: Dictionary, state: Dictionary, dt: float) -> Dictionary:
	return _integrate_step(p, state, dt, false)


func _integrate_step(p: Dictionary, state: Dictionary, dt: float, reuse_state: bool) -> Dictionary:
	if _constant_plan != null and _constant_plan.valid and _constant_plan.fraction_valid and collision_planes.is_empty(): return _constant_plan.integrate_fraction(self,p,state,dt,reuse_state)
	var normalized := clampf((float(state.age) + dt) / float(p.life), 0.0, 1.0)
	var velocity: Vector3 = state.velocity
	# Velocity-over-life is an additive velocity, not an acceleration added
	# every step. Apply the difference from its preceding sample.
	velocity += _velocity_over_life(p, normalized) - _velocity_over_life(p, float(state.age) / float(p.life))
	velocity += _inherit_velocity(p, normalized) - _inherit_velocity(p, float(state.age) / float(p.life))
	velocity += _acceleration(p, normalized, int(floor((float(state.age) + EPSILON) / STEP))) * dt
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
	var render_velocity := (velocity + _spatial_velocity(p, state.position, normalized)) * multiplier
	# Only the base solver's private full-step loop opts in. Collision handling
	# and overridden _integrate methods retain a distinct previous/next state.
	if reuse_state and collision_planes.is_empty():
		var next_position: Vector3 = state.position + render_velocity * dt
		state.age = float(state.age) + dt
		state.position = next_position; state.velocity = velocity
		state.render_velocity = render_velocity; state.rotation = rotation
		return state
	var next: Dictionary = {"age": float(state.age) + dt, "position": state.position + render_velocity * dt, "velocity": velocity, "render_velocity": render_velocity, "rotation": rotation, "kill_age": state.get("kill_age", INF), "collision_loss": state.get("collision_loss", 0.0), "collision_hits": state.get("collision_hits", 0)}
	return _resolve_collisions(p, state, next, normalized)


func _constant_step_state(p: Dictionary, state: Dictionary, until: float) -> Dictionary:
	if _constant_plan != null and _constant_plan.valid: return _constant_plan.advance(self,p,state,until)
	# Keep every original 1/120-second Euler step and arithmetic order. Only
	# constant module sampling and per-step Dictionary allocation are hoisted.
	# Nonrandomized mode 0/3 modules depend only on birth-time mixes.
	# Per-step randomized force retains the original sampler and step index.
	var age: float = state.age
	if age + STEP > until + EPSILON: return state
	var velocity: Vector3 = state.velocity
	var position: Vector3 = state.position
	var rotation: float = state.rotation
	var force: Dictionary = raw.get("ForceModule", {})
	var random_force: bool = bool(force.get("enabled", false)) and bool(force.get("randomizePerFrame", false))
	var acceleration_step: Vector3 = Vector3.ZERO if random_force else _acceleration(p, 0.0, 0) * STEP
	var velocity_module: Dictionary = raw.get("VelocityModule", {})
	var velocity_enabled: bool = bool(velocity_module.get("enabled", false))
	var additive_delta: Vector3 = Vector3.ZERO
	var multiplier: float = 1.0
	if velocity_enabled:
		var additive: Vector3 = _velocity_over_life(p, 0.0)
		additive_delta = additive - additive
		multiplier = Curves.minmax(velocity_module.get("speedModifier", {"scalar": 1.0}), 0.0, p.velocity_mix.x)
	var render_velocity: Vector3 = state.render_velocity
	var limit: Dictionary = raw.get("ClampVelocityModule", {})
	var limited: bool = bool(limit.get("enabled", false))
	var limit_amount: float = 1.0 - pow(1.0 - clampf(float(limit.get("dampen", 0.0)), 0.0, 1.0), STEP / STEP) if limited else 0.0
	var limit_cap: float = maxf(0.0, Curves.minmax(limit.get("magnitude", {}), 0.0, p.limit_mix)) if limited else 0.0
	var rotation_module: Dictionary = raw.get("RotationModule", {})
	var rotates: bool = bool(rotation_module.get("enabled", false))
	var rotation_step: float = Curves.minmax(rotation_module.get("curve", {}), 0.0, p.rotation_mix) * STEP if rotates else 0.0
	while age + STEP <= until + EPSILON:
		if velocity_enabled:
			velocity += additive_delta
			velocity += Vector3.ZERO - Vector3.ZERO
		if random_force:
			var normalized: float = clampf((age + STEP) / float(p.life), 0.0, 1.0)
			velocity += _acceleration(p, normalized, int(floor((age + EPSILON) / STEP))) * STEP
		else:
			velocity += acceleration_step
		if limited:
			var speed: float = velocity.length()
			if speed > limit_cap: velocity *= lerpf(speed, limit_cap, limit_amount) / speed
		if rotates: rotation += rotation_step
		render_velocity = (velocity + Vector3.ZERO) * multiplier if velocity_enabled else velocity
		position += render_velocity * STEP
		age += STEP
	state.age = age; state.position = position; state.velocity = velocity
	state.render_velocity = render_velocity; state.rotation = rotation
	return state


func _zero_constant_components(module: Dictionary, fields: Array) -> bool:
	for field in fields:
		var curve: Dictionary = module.get(field, {})
		if int(curve.get("minMaxState", 0)) != 0 or Curves.number(curve.get("scalar", 0.0)) != 0.0: return false
	return true


func _velocity_over_life(p: Dictionary, normalized: float) -> Vector3:
	var module: Dictionary = raw.get("VelocityModule", {})
	if not bool(module.get("enabled", false)): return Vector3.ZERO
	if _constant_zero_linear: return Vector3.ZERO
	var velocity := Vector3(Curves.minmax(module.get("x", {}), normalized, p.velocity_mix.x), Curves.minmax(module.get("y", {}), normalized, p.velocity_mix.y), Curves.minmax(module.get("z", {}), normalized, p.velocity_mix.z))
	if bool(module.get("inWorldSpace", false)): velocity = p.motion_basis.inverse() * (compatibility_basis * velocity)
	return velocity


func _spatial_velocity(p: Dictionary, displacement: Vector3, normalized: float) -> Vector3:
	var module: Dictionary = raw.get("VelocityModule", {})
	if not bool(module.get("enabled", false)): return Vector3.ZERO
	if _constant_zero_spatial: return Vector3.ZERO
	var omega := Vector3(Curves.minmax(module.get("orbitalX", {}), normalized, p.velocity_mix.x), Curves.minmax(module.get("orbitalY", {}), normalized, p.velocity_mix.y), Curves.minmax(module.get("orbitalZ", {}), normalized, p.velocity_mix.z))
	var offset := Vector3(Curves.minmax(module.get("orbitalOffsetX", {}), normalized, p.velocity_mix.x), Curves.minmax(module.get("orbitalOffsetY", {}), normalized, p.velocity_mix.y), Curves.minmax(module.get("orbitalOffsetZ", {}), normalized, p.velocity_mix.z))
	var radial := Curves.minmax(module.get("radial", {}), normalized, p.velocity_mix.x)
	if omega.is_zero_approx() and absf(radial) < EPSILON: return Vector3.ZERO
	var relative: Vector3 = p.shape_point + displacement - offset
	if bool(module.get("inWorldSpace", false)):
		var to_source: Basis = compatibility_basis.inverse() * p.motion_basis
		var source_relative: Vector3 = to_source * (p.shape_point + displacement) - offset
		return to_source.inverse() * (omega.cross(source_relative) + source_relative.normalized() * radial)
	return omega.cross(relative) + relative.normalized() * radial


func _inherit_velocity(p: Dictionary, normalized: float) -> Vector3:
	var inherit: Dictionary = raw.get("InheritVelocityModule", {})
	if not bool(inherit.get("enabled", false)) or int(raw.get("moveWithTransform", 0)) != 1: return Vector3.ZERO
	if int(inherit.get("m_Mode", 0)) != 0: return Vector3.ZERO
	var amount := Curves.minmax(inherit.get("m_Curve", {}), normalized, p.inherit_mix)
	return p.motion_basis.inverse() * p.inherited_velocity * amount


static func _force_step_mix(seed_mix: Vector3, step_index: int) -> Vector3:
	# A stateless per-particle/per-step compatibility sampler. Never consume
	# emission RNG or global/game RNG, so seek granularity and rewind cannot
	# change future births or the reconstructed fixed-step force history.
	var result := Vector3.ZERO
	for axis in range(3):
		var value := (int(seed_mix[axis] * 2147483647.0) + maxi(0, step_index) * 104729 + (axis + 1) * 15485863) & 0x7fffffff
		value = ((value ^ (value >> 16)) * 1103515245 + 12345) & 0x7fffffff
		value = ((value ^ (value >> 13)) * 1103515245 + 12345) & 0x7fffffff
		result[axis] = float(value) / 2147483648.0
	return result


func _acceleration(p: Dictionary, normalized: float, step_index: int = 0) -> Vector3:
	var result := Vector3.ZERO
	var force: Dictionary = raw.get("ForceModule", {})
	if bool(force.get("enabled", false)):
		var mix: Vector3 = _force_step_mix(p.force_mix, step_index) if bool(force.get("randomizePerFrame", false)) else p.force_mix
		result = Vector3(Curves.minmax(force.get("x", {}), normalized, mix.x), Curves.minmax(force.get("y", {}), normalized, mix.y), Curves.minmax(force.get("z", {}), normalized, mix.z))
		if bool(force.get("inWorldSpace", false)): result = p.motion_basis.inverse() * (compatibility_basis * result)
	var gravity := Curves.minmax(raw.get("InitialModule", {}).get("gravityModifier", {}), normalized, p.gravity_mix)
	if absf(gravity) > EPSILON: result += p.motion_basis.inverse() * (compatibility_basis * source_gravity * gravity)
	return result


func _resolve_collisions(_p: Dictionary, _previous: Dictionary, next: Dictionary, _normalized: float) -> Dictionary:
	return next
