extends RefCounted
## Samples recovered Unity AnimationClip / MinMaxCurve keys without resampling.
## Unity's unweighted curves are cubic Hermite. Weighted curves use the original
## key time/value Bezier controls, solving x before evaluating y.
static func number(value, fallback: float = 0.0) -> float:
	if value == null: return fallback
	if value is String:
		if value.to_lower() in ["infinity", "+infinity", "inf", "+inf"]: return INF
		if value.to_lower() in ["-infinity", "-inf"]: return -INF
	return float(value)

static func scalar_keys(keys: Array, time: float, fallback: float = 0.0) -> float:
	if keys.is_empty(): return fallback
	if time <= number(keys[0].time): return number(keys[0].value)
	if time >= number(keys[-1].time): return number(keys[-1].value)
	for i in range(keys.size()-1):
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i+1]
		if time > number(b.time): continue
		var span: float = number(b.time)-number(a.time)
		if span <= 0.0: return number(b.value)
		var out_slope: float = number(a.get("outSlope", a.get("outTangent", 0.0)))
		var in_slope: float = number(b.get("inSlope", b.get("inTangent", 0.0)))
		if is_inf(out_slope) or is_inf(in_slope) or int(a.get("outTangentInfinity",0)) != 0 or int(b.get("inTangentInfinity",0)) != 0:
			return number(a.value)
		var t: float = (time-number(a.time))/span
		var wa: bool = (int(a.get("weightedMode",0)) & 2) != 0
		var wb: bool = (int(b.get("weightedMode",0)) & 1) != 0
		if wa or wb:
			var out_weight: float = number(a.get("outWeight",1.0/3.0)) if wa else 1.0/3.0
			var in_weight: float = number(b.get("inWeight",1.0/3.0)) if wb else 1.0/3.0
			var low := 0.0
			var high := 1.0
			for _iteration in range(30):
				var mid := (low+high)*0.5
				if _bezier(0.0,out_weight,1.0-in_weight,1.0,mid) < t: low=mid
				else: high=mid
			return _bezier(number(a.value),number(a.value)+out_slope*span*out_weight,number(b.value)-in_slope*span*in_weight,number(b.value),(low+high)*0.5)
		var t2 := t*t
		var t3 := t2*t
		return (2*t3-3*t2+1)*number(a.value)+(t3-2*t2+t)*span*out_slope+(-2*t3+3*t2)*number(b.value)+(t3-t2)*span*in_slope
	return number(keys[-1].value)

static func _bezier(a: float,b: float,c: float,d: float,t: float) -> float:
	var u := 1.0-t
	return u*u*u*a+3*u*u*t*b+3*u*t*t*c+t*t*t*d

static func component_keys(keys: Array, component: String) -> Array:
	var result: Array=[]
	for source in keys:
		var key: Dictionary=source.duplicate(true)
		for field in ["value","inSlope","outSlope","inWeight","outWeight"]:
			if key.get(field) is Dictionary: key[field]=key[field].get(component,0.0)
		result.append(key)
	return result

static func vector_curve(curve: Dictionary,time: float,default: Vector3=Vector3.ZERO) -> Vector3:
	var keys: Array=curve.get("m_Curve",[])
	return Vector3(scalar_keys(component_keys(keys,"x"),time,default.x),scalar_keys(component_keys(keys,"y"),time,default.y),scalar_keys(component_keys(keys,"z"),time,default.z))

static func quaternion_curve(curve: Dictionary,time: float) -> Quaternion:
	var keys: Array=curve.get("m_Curve",[])
	var q := Quaternion(scalar_keys(component_keys(keys,"x"),time),scalar_keys(component_keys(keys,"y"),time),scalar_keys(component_keys(keys,"z"),time),scalar_keys(component_keys(keys,"w"),time,1.0))
	return q.normalized() if q.length_squared()>0.000001 else Quaternion.IDENTITY

static func minmax(curve: Dictionary,time: float,mix_value: float=0.5) -> float:
	var mode := int(curve.get("minMaxState",0))
	var hi := number(curve.get("scalar",0.0))
	if mode == 0: return hi
	if mode == 3: return lerpf(number(curve.get("minScalar",hi)),hi,mix_value)
	var max_keys: Array=curve.get("maxCurve",{}).get("m_Curve",[])
	if mode == 1: return scalar_keys(max_keys,time,1.0)*hi
	var min_keys: Array=curve.get("minCurve",{}).get("m_Curve",[])
	return lerpf(scalar_keys(min_keys,time,1.0)*hi,scalar_keys(max_keys,time,1.0)*hi,mix_value)

static func vec(d: Dictionary) -> Vector3:
	return Vector3(number(d.get("x",0.0)),number(d.get("y",0.0)),number(d.get("z",0.0)))

static func color(d: Dictionary) -> Color:
	return Color(number(d.get("r",1.0)),number(d.get("g",1.0)),number(d.get("b",1.0)),number(d.get("a",1.0)))
