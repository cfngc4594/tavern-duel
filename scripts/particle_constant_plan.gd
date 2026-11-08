extends RefCounted
# Only task-local mode 0/3 parameters. Never persists beyond the frame's job.
const STEP := 1.0/120.0
const EPSILON := 0.00000001
var valid: bool = false
var modes := PackedInt32Array()
var low := PackedFloat64Array()
var high := PackedFloat64Array()
var force_enabled: bool
var random_force: bool
var force_world: bool
var velocity_enabled: bool
var limited: bool
var rotates: bool
var limit_amount: float
var fraction_valid: bool = false
var velocity_world: bool
var dampen_base: float
func setup(raw: Dictionary, curves) -> void:
	var force: Dictionary=raw.get("ForceModule",{})
	var velocity: Dictionary=raw.get("VelocityModule",{})
	var limit: Dictionary=raw.get("ClampVelocityModule",{})
	var rotation: Dictionary=raw.get("RotationModule",{})
	force_enabled=bool(force.get("enabled",false)); random_force=force_enabled and bool(force.get("randomizePerFrame",false)); force_world=bool(force.get("inWorldSpace",false))
	velocity_enabled=bool(velocity.get("enabled",false)); limited=bool(limit.get("enabled",false)); rotates=bool(rotation.get("enabled",false))
	# The owner checks the complete signature. Recheck our actual scalar inputs.
	var parameters: Array=[force.get("x",{}),force.get("y",{}),force.get("z",{}),raw.get("InitialModule",{}).get("gravityModifier",{}),velocity.get("speedModifier",{"scalar":1.0}),limit.get("magnitude",{}),rotation.get("curve",{})]
	var active: Array[bool]=[force_enabled,force_enabled,force_enabled,true,velocity_enabled,limited,rotates]
	for index in range(parameters.size()):
		var curve: Dictionary=parameters[index] if active[index] else {}
		var mode: int=int(curve.get("minMaxState",0))
		if mode not in [0,3]: return
		var hi: float=curves.number(curve.get("scalar",0.0))
		var lo: float=curves.number(curve.get("minScalar",hi)) if mode == 3 else hi
		if not is_finite(hi) or not is_finite(lo): return
		modes.append(mode); high.append(hi); low.append(lo)
	limit_amount=1.0-pow(1.0-clampf(float(limit.get("dampen",0.0)),0.0,1.0),STEP/STEP) if limited else 0.0
	fraction_valid=_setup_fraction(raw,curves)
	valid=true
func advance(kernel, p: Dictionary, state: Dictionary, until: float) -> Dictionary:
	var age: float=state.age
	if age+STEP > until+EPSILON: return state
	var velocity: Vector3=state.velocity
	var position: Vector3=state.position
	var rotation: float=state.rotation
	var acceleration_step:=Vector3.ZERO
	if not random_force:
		var acceleration:=Vector3.ZERO
		if force_enabled:
			var mix: Vector3=p.force_mix
			acceleration=Vector3(high[0] if modes[0]==0 else lerpf(low[0],high[0],mix.x),high[1] if modes[1]==0 else lerpf(low[1],high[1],mix.y),high[2] if modes[2]==0 else lerpf(low[2],high[2],mix.z))
			if force_world: acceleration=p.motion_basis.inverse()*(kernel.compatibility_basis*acceleration)
		var gravity: float=high[3] if modes[3]==0 else lerpf(low[3],high[3],p.gravity_mix)
		if absf(gravity)>EPSILON: acceleration+=p.motion_basis.inverse()*(kernel.compatibility_basis*kernel.source_gravity*gravity)
		acceleration_step=acceleration*STEP
	var additive_delta:=Vector3.ZERO
	var multiplier:=1.0
	if velocity_enabled:
		var additive: Vector3=kernel._velocity_over_life(p,0.0)
		additive_delta=additive-additive
		multiplier=high[4] if modes[4]==0 else lerpf(low[4],high[4],p.velocity_mix.x)
	var render_velocity: Vector3=state.render_velocity
	var limit_cap: float=maxf(0.0,high[5] if modes[5]==0 else lerpf(low[5],high[5],p.limit_mix)) if limited else 0.0
	var rotation_step: float=(high[6] if modes[6]==0 else lerpf(low[6],high[6],p.rotation_mix))*STEP if rotates else 0.0
	while age+STEP <= until+EPSILON:
		if velocity_enabled:
			velocity+=additive_delta
			velocity+=Vector3.ZERO-Vector3.ZERO
		if random_force:
			var normalized: float=clampf((age+STEP)/float(p.life),0.0,1.0)
			velocity+=kernel._acceleration(p,normalized,int(floor((age+EPSILON)/STEP)))*STEP
		else: velocity+=acceleration_step
		if limited:
			var speed: float=velocity.length()
			if speed>limit_cap: velocity*=lerpf(speed,limit_cap,limit_amount)/speed
		if rotates: rotation+=rotation_step
		render_velocity=(velocity+Vector3.ZERO)*multiplier if velocity_enabled else velocity
		position+=render_velocity*STEP
		age+=STEP
	state.age=age; state.position=position; state.velocity=velocity; state.render_velocity=render_velocity; state.rotation=rotation
	return state

func _setup_fraction(raw: Dictionary, curves) -> bool:
	# Match _inherit_velocity: enabled inheritance is still exactly zero
	# outside world simulation or outside birth-velocity mode.
	var inherit:Dictionary=raw.get("InheritVelocityModule",{})
	if bool(inherit.get("enabled",false)) and int(raw.get("moveWithTransform",0))==1 and int(inherit.get("m_Mode",0))==0:return false
	if bool(raw.get("RotationBySpeedModule",{}).get("enabled",false)):return false
	var module:Dictionary=raw.get("VelocityModule",{})
	velocity_world=bool(module.get("inWorldSpace",false))
	if velocity_enabled:
		for name in ["orbitalX","orbitalY","orbitalZ","radial"]:
			var curve:Dictionary=module.get(name,{})
			if int(curve.get("minMaxState",0))!=0 or curves.number(curve.get("scalar",0.0))!=0.0:return false
	for axis in ["x","y","z"]:
		var curve:Dictionary=module.get(axis,{}) if velocity_enabled else {}
		var mode:int=int(curve.get("minMaxState",0))
		if mode not in [0,3]:return false
		var hi:float=curves.number(curve.get("scalar",0.0))
		var lo:float=curves.number(curve.get("minScalar",hi)) if mode==3 else hi
		if not is_finite(hi) or not is_finite(lo):return false
		modes.append(mode);high.append(hi);low.append(lo)
	var limit:Dictionary=raw.get("ClampVelocityModule",{})
	if limited:
		if bool(limit.get("separateAxis",false)):return false
		var drag:Dictionary=limit.get("drag",{})
		if int(drag.get("minMaxState",0))!=0 or curves.number(drag.get("scalar",0.0))!=0.0:return false
		dampen_base=1.0-clampf(float(limit.get("dampen",0.0)),0.0,1.0)
	return true

func _constant_acceleration(kernel, p:Dictionary) -> Vector3:
	var acceleration:=Vector3.ZERO
	if force_enabled:
		var mix:Vector3=p.force_mix
		acceleration=Vector3(high[0] if modes[0]==0 else lerpf(low[0],high[0],mix.x),high[1] if modes[1]==0 else lerpf(low[1],high[1],mix.y),high[2] if modes[2]==0 else lerpf(low[2],high[2],mix.z))
		if force_world:acceleration=p.motion_basis.inverse()*(kernel.compatibility_basis*acceleration)
	var gravity:float=high[3] if modes[3]==0 else lerpf(low[3],high[3],p.gravity_mix)
	if absf(gravity)>EPSILON:acceleration+=p.motion_basis.inverse()*(kernel.compatibility_basis*kernel.source_gravity*gravity)
	return acceleration

func _constant_additive(kernel, p:Dictionary) -> Vector3:
	if not velocity_enabled or kernel._constant_zero_linear:return Vector3.ZERO
	var mix:Vector3=p.velocity_mix
	var additive:=Vector3(high[7] if modes[7]==0 else lerpf(low[7],high[7],mix.x),high[8] if modes[8]==0 else lerpf(low[8],high[8],mix.y),high[9] if modes[9]==0 else lerpf(low[9],high[9],mix.z))
	if velocity_world:additive=p.motion_basis.inverse()*(kernel.compatibility_basis*additive)
	return additive

func integrate_fraction(kernel, p:Dictionary, state:Dictionary, dt:float, reuse_state:bool) -> Dictionary:
	var normalized:float=clampf((float(state.age)+dt)/float(p.life),0.0,1.0)
	var velocity:Vector3=state.velocity
	# Keep both original additive subtractions/additions, including disabled modules.
	var additive:Vector3=_constant_additive(kernel,p)
	velocity+=additive-additive
	velocity+=Vector3.ZERO-Vector3.ZERO
	var acceleration:Vector3=kernel._acceleration(p,normalized,int(floor((float(state.age)+EPSILON)/STEP))) if random_force else _constant_acceleration(kernel,p)
	velocity+=acceleration*dt
	if limited:
		var amount:float=1.0-pow(dampen_base,dt/STEP)
		var cap:float=maxf(0.0,high[5] if modes[5]==0 else lerpf(low[5],high[5],p.limit_mix))
		var speed:float=velocity.length()
		if speed>cap:velocity*=lerpf(speed,cap,amount)/speed
	var rotation:float=state.rotation
	if rotates:rotation+=(high[6] if modes[6]==0 else lerpf(low[6],high[6],p.rotation_mix))*dt
	var multiplier:float=1.0
	if velocity_enabled:multiplier=high[4] if modes[4]==0 else lerpf(low[4],high[4],p.velocity_mix.x)
	var render_velocity:Vector3=(velocity+Vector3.ZERO)*multiplier
	if reuse_state and kernel.collision_planes.is_empty():
		var next_position:Vector3=state.position+render_velocity*dt
		state.age=float(state.age)+dt;state.position=next_position;state.velocity=velocity;state.render_velocity=render_velocity;state.rotation=rotation
		return state
	var next:Dictionary={"age":float(state.age)+dt,"position":state.position+render_velocity*dt,"velocity":velocity,"render_velocity":render_velocity,"rotation":rotation,"kill_age":state.get("kill_age",INF),"collision_loss":state.get("collision_loss",0.0),"collision_hits":state.get("collision_hits",0)}
	return kernel._resolve_collisions(p,state,next,normalized)
