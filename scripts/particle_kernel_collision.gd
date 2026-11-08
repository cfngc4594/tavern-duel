extends "res://scripts/particle_kernel_combat.gd"
# Main-thread snapshots only. No Node, Resource, RNG or scene access in tasks.
var emitter_frame:=Transform3D.IDENTITY
var emitter_motion:=Basis.IDENTITY
var plane_samples:Array=[]
func prepare()->void:
	super.prepare()
	_constant_plan=null # This generic path has not proved the constant-plan signature.
func _particle_state(p: Dictionary, age: float) -> Dictionary:
	var previous_linear: bool = _constant_zero_linear
	var previous_spatial: bool = _constant_zero_spatial
	_constant_zero_linear = false; _constant_zero_spatial = false
	# No subclass callback can change a module during this base-only evaluation.
	if true:
		var velocity_module: Dictionary = raw.get("VelocityModule", {})
		if bool(velocity_module.get("enabled", false)):
			_constant_zero_linear = _zero_constant_components(velocity_module, ["x", "y", "z"])
			if bool(velocity_module.get("inWorldSpace", false)) and (not is_finite(p.motion_basis.determinant()) or absf(p.motion_basis.determinant()) <= EPSILON): _constant_zero_linear = false
			_constant_zero_spatial = _zero_constant_components(velocity_module, ["orbitalX", "orbitalY", "orbitalZ", "radial"])
	if age + EPSILON < float(p.sim_age):
		p.sim_age = 0.0; p.displacement = Vector3.ZERO; p.sim_velocity = p.velocity + _velocity_over_life(p, 0.0) + _inherit_velocity(p, 0.0); p.sim_rotation = p.rotation; p.sim_render_velocity = p.sim_velocity + _spatial_velocity(p, Vector3.ZERO, 0.0); p.kill_age = INF; p.collision_loss = 0.0; p.collision_hits = 0
	var state: Dictionary = {"age": p.sim_age, "position": p.displacement, "velocity": p.sim_velocity, "rotation": p.sim_rotation, "render_velocity": p.sim_render_velocity, "kill_age": p.kill_age, "collision_loss": p.collision_loss, "collision_hits": p.collision_hits}
	while float(state.age) + STEP <= age + EPSILON:
		state = _integrate_step(p, state, STEP, true) if collision_planes.is_empty() else _integrate(p, state, STEP)
	p.sim_age = state.age; p.displacement = state.position; p.sim_velocity = state.velocity; p.sim_rotation = state.rotation; p.sim_render_velocity = state.get("render_velocity", state.velocity); p.kill_age = state.kill_age; p.collision_loss = state.collision_loss; p.collision_hits = state.collision_hits
	if age > float(state.age) + EPSILON: state = _integrate(p, state, age - float(state.age))
	_constant_zero_linear = previous_linear; _constant_zero_spatial = previous_spatial
	return state

func _resolve_collisions(p: Dictionary, previous: Dictionary, next: Dictionary, normalized: float) -> Dictionary:
	if collision_planes.is_empty(): return next
	var collision: Dictionary = raw.get("CollisionModule", {})
	var world_space := int(raw.get("moveWithTransform", 0)) == 1
	var frame := emitter_frame
	var motion: Basis = p.motion_basis if world_space else emitter_motion
	var origin: Vector3 = p.start if world_space else frame * p.shape_point
	var old_center: Vector3 = origin + motion * previous.position
	var center: Vector3 = origin + motion * next.position
	var velocity: Vector3 = motion * next.velocity
	var size: float = p.size
	if bool(raw.get("SizeModule", {}).get("enabled", false)): size *= Curves.minmax(raw.SizeModule.curve, normalized, p.size_mix)
	var radius := absf(size) * 0.5 * maxf(motion.x.length(), maxf(motion.y.length(), motion.z.length())) * float(collision.get("radiusScale", 1.0))
	for plane_data in plane_samples:
		var normal: Vector3 = plane_data.normal
		var signed_distance: float = normal.dot(center - plane_data.position)
		if signed_distance >= radius or normal.dot(velocity) >= 0.0: continue
		var old_distance: float = normal.dot(old_center - plane_data.position)
		if old_distance < -radius and not bool(collision.get("interiorCollisions", true)): continue
		center += normal * (radius - signed_distance)
		var dampen := clampf(Curves.minmax(collision.get("m_Dampen", {}), normalized, p.limit_mix), 0.0, 1.0)
		var bounce := Curves.minmax(collision.get("m_Bounce", {}), normalized, p.limit_mix)
		var normal_velocity := normal * velocity.dot(normal)
		velocity = (velocity - normal_velocity) * (1.0 - dampen) - normal_velocity * bounce
		var loss := clampf(Curves.minmax(collision.get("m_EnergyLossOnCollision", {}), normalized, p.limit_mix), 0.0, 1.0)
		next.collision_loss += loss
		next.kill_age = minf(next.kill_age, float(p.life) * maxf(0.0, 1.0 - float(next.collision_loss)))
		var speed := velocity.length()
		if speed < float(collision.get("minKillSpeed", 0.0)) or speed > float(collision.get("maxKillSpeed", INF)): next.kill_age = float(next.age)
		next.collision_hits += 1
	next.position = motion.inverse() * (center - origin)
	var velocity_delta: Vector3 = motion.inverse() * velocity - next.velocity
	next.velocity += velocity_delta
	next.render_velocity = next.get("render_velocity", next.velocity) + velocity_delta
	return next


