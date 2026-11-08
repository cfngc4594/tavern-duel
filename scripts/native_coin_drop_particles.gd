extends "res://scripts/native_combat_particles.gd"
## Coin-only source Noise mathematical port inside the existing compatibility
## particle solver. Source field/coordinate semantics are independently audited.
## Fixed-step integration, shape RNG and rasterization remain Godot bridges.
const NoiseKernel=preload("res://scripts/native_coin_noise_kernel.gd")
var noise_kernel=NoiseKernel.new()
var noise_source:Dictionary={}
var noise_offset=Vector3.ZERO
var noise_gate=false
var noise_samples=0
var source_seed_provenance=""
func setup(spec:Dictionary,assets,parent_root:Node3D,seed_value:int) -> void:
	noise_source=spec.system.data.get("NoiseModule",{}).duplicate(true)
	noise_gate=_verified_source_configuration(noise_source,spec.system.data)
	assert(noise_gate,"Refusing unverified Coin Noise configuration")
	source_seed_provenance=spec.get("source_seed_provenance","")
	assert(not source_seed_provenance.is_empty(),"Noise requires explicit seed provenance")
	noise_offset=NoiseKernel.source_seed_offset(seed_value)
	super.setup(spec,assets,parent_root,seed_value)
	unsupported.erase("NoiseModule")
	compatibility_notes.append("Noise: recovered original High derivative/curl/octave/seed mapping; auto-seed initial entropy is Godot runtime, source xorshift transition retained")
	compatibility_notes.append("Noise: source local coordinates and additive velocity; compatibility fixed step remains1/120, not Unity scheduling or pixel equivalence")
func _verified_source_configuration(n:Dictionary,system:Dictionary) -> bool:
	# This subclass adds Noise after base integration. It must never be used
	# with collision or velocity multipliers requiring a different ordering.
	for name in system:
		var module=system[name]
		if module is Dictionary and bool(module.get("enabled",false)) and name not in ["InitialModule","ShapeModule","EmissionModule","SizeModule","RotationModule","ColorModule","ClampVelocityModule","NoiseModule"]:return false
	if int(system.get("ShapeModule",{}).get("type",-1)) not in [0,10]:return false
	if not bool(n.get("enabled",false)) or int(n.get("quality",-1))!=2:return false
	if int(n.get("octaves",-1))!=2 or float(n.get("octaveMultiplier",-1.0))!=1.0 or float(n.get("octaveScale",-1.0))!=1.0:return false
	if not bool(n.get("damping",false)):return false
	if bool(n.get("separateAxes",true)) or bool(n.get("remapEnabled",true)):return false
	if int(system.get("moveWithTransform",-1))!=0:return false
	if int(n.get("strength",{}).get("minMaxState",-1))!=1:return false
	for field in ["scrollSpeed","positionAmount","rotationAmount","sizeAmount"]:
		if int(n.get(field,{}).get("minMaxState",-1))!=0:return false
	if float(n.rotationAmount.scalar)!=0.0 or float(n.sizeAmount.scalar)!=0.0:return false
	return true
func _integrate(p:Dictionary,state:Dictionary,dt:float) -> Dictionary:
	var result=super._integrate(p,state,dt)
	if not noise_gate:return result
	var normalized=maxf(0.0,float(state.age)/float(p.life))
	var frequency=maxf(float(noise_source.frequency),0.000001)
	var scroll=(float(p.birth)+float(state.age)+dt)*float(noise_source.scrollSpeed.scalar)
	var field=noise_kernel.curl_at_source_position(p.shape_point+state.position,noise_offset,scroll,frequency,int(noise_source.octaves),float(noise_source.octaveMultiplier),float(noise_source.octaveScale))
	var strength=Curves.minmax(noise_source.strength,normalized,0.0)
	if bool(noise_source.damping):strength/=frequency
	field*=strength*float(noise_source.positionAmount.scalar)
	# Native worker adds temporary velocity(c0/e0/100); integration then adds
	# (base+temporary)*dt to position. Never accumulate Noise into base velocity.
	result.position+=field*dt
	result.render_velocity+=field
	noise_samples+=1
	return result
func get_audit() -> Dictionary:
	var report=super.get_audit()
	report.noise_source_math_verified=noise_gate
	report.noise_samples=noise_samples
	report.noise_source_seed=instance_seed
	report.noise_seed_provenance=source_seed_provenance
	report.noise_coordinate_space="original emitter-local particle position"
	report.noise_application="temporary additive velocity, not force or accumulated acceleration"
	report.noise_numeric_reference="256 derivative +16 curl +8 seed vectors"
	return report
