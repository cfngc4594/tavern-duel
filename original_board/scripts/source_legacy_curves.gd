extends RefCounted
## Original exported unweighted quaternion component curves. No hand-authored rotation.
## Legacy engine sampling parity is not claimed; component Hermite + normalization is explicit.
static func sample_scalar(keys:Array,t:float,axis:String)->float:
 if keys.is_empty():return 0.0
 if t<=float(keys[0].time):return float(keys[0].value[axis])
 if t>=float(keys[-1].time):return float(keys[-1].value[axis])
 for i in range(keys.size()-1):
  var a=keys[i];var b=keys[i+1]
  if t>float(b.time):continue
  var duration=float(b.time)-float(a.time)
  var u=(t-float(a.time))/duration
  var p0=float(a.value[axis]);var p1=float(b.value[axis])
  var m0=float(a.outSlope[axis]);var m1=float(b.inSlope[axis])
  if not is_finite(m0) or not is_finite(m1):return p0
  return (2*u*u*u-3*u*u+1)*p0+(u*u*u-2*u*u+u)*duration*m0+(-2*u*u*u+3*u*u)*p1+(u*u*u-u*u)*duration*m1
 return float(keys[-1].value[axis])
static func sample_quaternion(keys:Array,t:float)->Quaternion:
 return Quaternion(sample_scalar(keys,t,'x'),sample_scalar(keys,t,'y'),sample_scalar(keys,t,'z'),sample_scalar(keys,t,'w')).normalized()
static func apply(clip:Dictionary,t:float,targets:Dictionary):
 for curve in clip.m_RotationCurves:
  var node=targets.get(curve.path)
  if not is_instance_valid(node):continue
  var q=sample_quaternion(curve.curve.m_Curve,t)
  var scale=node.scale
  var r=Basis(Quaternion(-q.x,-q.y,q.z,q.w))
  node.basis=Basis(r.x*scale.x,r.y*scale.y,r.z*scale.z)
