extends RefCounted
# Per-seek snapshot. Original unweighted Hermite arithmetic; every other case
# remains with the source sampler. No resampling, approximation or Curve asset.
class Segment:
	extends RefCounted
	var start:float;var end:float;var span:float
	var a:float;var b:float;var outgoing:float;var incoming:float
	var held:bool
	func sample(time:float)->float:
		if span<=0.0:return b
		if held:return a
		var t:float=(time-start)/span
		var t2:=t*t
		var t3:=t2*t
		return (2*t3-3*t2+1)*a+(t3-2*t2+t)*span*outgoing+(-2*t3+3*t2)*b+(t3-t2)*span*incoming
class Track:
	extends RefCounted
	var segments:Array[Segment]=[]
	var empty:bool
	var first_time:float;var last_time:float;var first_value:float;var last_value:float
	func setup(keys:Array,curves)->bool:
		empty=keys.is_empty()
		if empty:return true
		for key in keys:
			if not key is Dictionary or not key.has("time") or not key.has("value"):return false
			if not is_finite(curves.number(key.time)) or not is_finite(curves.number(key.value)):return false
		first_time=curves.number(keys[0].time);last_time=curves.number(keys[-1].time)
		first_value=curves.number(keys[0].value);last_value=curves.number(keys[-1].value)
		for index in range(keys.size()-1):
			var a:Dictionary=keys[index];var b:Dictionary=keys[index+1]
			var s:=Segment.new()
			s.start=curves.number(a.time);s.end=curves.number(b.time);s.span=s.end-s.start
			s.a=curves.number(a.value);s.b=curves.number(b.value)
			s.outgoing=curves.number(a.get("outSlope",a.get("outTangent",0.0)))
			s.incoming=curves.number(b.get("inSlope",b.get("inTangent",0.0)))
			if is_nan(s.outgoing) or is_nan(s.incoming):return false
			s.held=is_inf(s.outgoing) or is_inf(s.incoming) or int(a.get("outTangentInfinity",0))!=0 or int(b.get("inTangentInfinity",0))!=0
			if (int(a.get("weightedMode",0)) & 2)!=0 or (int(b.get("weightedMode",0)) & 1)!=0:return false
			segments.append(s)
		return true
	func sample(time:float)->float:
		if empty:return 1.0
		if time<=first_time:return first_value
		if time>=last_time:return last_value
		for segment in segments:
			if time>segment.end:continue
			return segment.sample(time)
		return last_value
var valid:bool=false
var mode:int
var high:float;var low:float
var maximum:Track;var minimum:Track
var _raw:Dictionary
var _curves
func setup(curve:Dictionary,curves)->void:
	_raw=curve;_curves=curves
	mode=int(curve.get("minMaxState",0));high=curves.number(curve.get("scalar",0.0))
	if not is_finite(high):return
	if mode==0:valid=true;return
	if mode==3:
		low=curves.number(curve.get("minScalar",high));valid=is_finite(low);return
	if mode not in [1,2]:return
	maximum=Track.new()
	if not maximum.setup(curve.get("maxCurve",{}).get("m_Curve",[]),curves):return
	if mode==2:
		minimum=Track.new()
		if not minimum.setup(curve.get("minCurve",{}).get("m_Curve",[]),curves):return
	valid=true
func sample(time:float,mix_value:float)->float:
	if not valid or not is_finite(time):return _curves.minmax(_raw,time,mix_value)
	if mode==0:return high
	if mode==3:return lerpf(low,high,mix_value)
	if mode==1:return maximum.sample(time)*high
	return lerpf(minimum.sample(time)*high,maximum.sample(time)*high,mix_value)
