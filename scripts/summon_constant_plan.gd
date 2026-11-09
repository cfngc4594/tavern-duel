extends RefCounted
# Created fresh for one base-solver seek; setup is intentionally single-use.
# No references to mutable module dictionaries. Scalars remain float64.
# Parameter slots: 0/1/2 velocity XYZ, 3 speed multiplier, 4 speed cap, 5 rotation.
var modes:=PackedInt32Array()
var low:=PackedFloat64Array()
var high:=PackedFloat64Array()
var velocity_enabled:bool
var velocity_world:bool
var limited:bool
var rotates:bool
var dampen_base:float
func setup(raw:Dictionary,curves)->void:
 var velocity:Dictionary=raw.get("VelocityModule",{})
 var limit:Dictionary=raw.get("ClampVelocityModule",{})
 var rotation:Dictionary=raw.get("RotationModule",{})
 velocity_enabled=bool(velocity.get("enabled",false))
 velocity_world=bool(velocity.get("inWorldSpace",false))
 limited=bool(limit.get("enabled",false));rotates=bool(rotation.get("enabled",false))
 var parameters:Array=[velocity.get("x",{}),velocity.get("y",{}),velocity.get("z",{}),velocity.get("speedModifier",{"scalar":1.0}),limit.get("magnitude",{}),rotation.get("curve",{})]
 var active:Array=[velocity_enabled,velocity_enabled,velocity_enabled,velocity_enabled,limited,rotates]
 for index in 6:
  var curve:Dictionary=parameters[index] if active[index] else {}
  var mode:int=int(curve.get("minMaxState",0))
  var hi:float=curves.number(curve.get("scalar",0.0))
  var lo:float=curves.number(curve.get("minScalar",hi)) if mode==3 else hi
  modes.append(mode);high.append(hi);low.append(lo)
 dampen_base=1.0-clampf(float(limit.get("dampen",0.0)),0.0,1.0) if limited else 1.0
func velocity(p:Dictionary,compatibility_basis:Basis)->Vector3:
 if not velocity_enabled:return Vector3.ZERO
 var mix:Vector3=p.velocity_mix
 var result:=Vector3(high[0] if modes[0]==0 else lerpf(low[0],high[0],mix.x),high[1] if modes[1]==0 else lerpf(low[1],high[1],mix.y),high[2] if modes[2]==0 else lerpf(low[2],high[2],mix.z))
 if velocity_world:result=p.motion_basis.inverse()*(compatibility_basis*result)
 return result
func scalar(index:int,mix:float)->float:
 return high[index] if modes[index]==0 else lerpf(low[index],high[index],mix)
