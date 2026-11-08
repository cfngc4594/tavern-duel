extends RefCounted
## iTween.GenerateShakePositionTargets0x0600003f / ApplyShakePositionTargets
## 0x06000054, same-build Blizzard.T5.iTween.dll. NOT CameraShakeMgr.
## Caller captures Camera.main WORLD position once when shake starts.
## Each source update draws independent Random.Range on x,y,z in that order.
## Supply those3 draws as unit_random in[-1,1]. This pure helper deliberately
## does not pretend Godot RNG matches Unity global Random state/frame sequence.
const AMOUNT:Vector3=Vector3(0.029999999329447746,0.009999999776482582,0.029999999329447746)
const DURATION:float=0.6000000238418579

static func offset(age:float,unit_random:Vector3)->Vector3:
	if age<0.0 or age>=DURATION:return Vector3.ZERO
	var decay:float=1.0-age/DURATION
	# No easing, sinusoid, frequency or accumulated displacement in source.
	return AMOUNT*unit_random*decay

static func position(captured_world_position:Vector3,age:float,unit_random:Vector3)->Vector3:
	# Each frame resets from the initially captured position; at completion
	# percentage1 produces Range(0,0), restoring the captured position exactly.
	return captured_world_position+offset(age,unit_random)

static func draw_offset(age:float,range_float:Callable)->Vector3:
	# Optional adapter to a caller-owned RNG. Bounds/order match source literally.
	# Do not call outside the active tween; source completion still draws3 zeros.
	if age<0.0:return Vector3.ZERO
	var amplitude:Vector3=AMOUNT*(1.0-clampf(age/DURATION,0.0,1.0))
	return Vector3(range_float.call(-amplitude.x,amplitude.x),range_float.call(-amplitude.y,amplitude.y),range_float.call(-amplitude.z,amplitude.z))
