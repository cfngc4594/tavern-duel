extends RefCounted
class SmallPart:
	extends RefCounted
	var count:int;var fixed:bool
	var t0:float;var t1:float;var t2:float
	var c0:Color;var c1:Color;var c2:Color
	func setup(times:Array[float],keys:Array[Color],hold:bool)->void:
		count=times.size();fixed=hold
		if count>0:t0=times[0];c0=keys[0]
		if count>1:t1=times[1];c1=keys[1]
		if count>2:t2=times[2];c2=keys[2]
	func sample(time:float)->Color:
		if count==0:return Color.WHITE
		if count==1:return c0.lerp(c0,0.0)
		var a:Color;var b:Color;var begin:float;var end:float
		if time>=t1:
			if count==2:return c1.lerp(c1,0.0)
			if time>=t2:return c2.lerp(c2,0.0)
			a=c1;b=c2;begin=t1;end=t2
		else:a=c0;b=c1;begin=t0;end=t1
		var u:float=0.0
		if end>begin:u=clampf((time-begin)/(end-begin),0.0,1.0)
		if fixed:u=0.0
		return a.lerp(b,u)
var small_color:SmallPart
var small_alpha:SmallPart
var color_times: Array[float] = []
var alpha_times: Array[float] = []
var color_keys: Array[Color] = []
var alpha_keys: Array[Color] = []
var fixed: bool = false
func setup(data: Dictionary, curves) -> void:
	color_times.clear(); alpha_times.clear(); color_keys.clear(); alpha_keys.clear()
	small_color=null;small_alpha=null
	fixed = int(data.get("m_Mode", 0)) == 1
	for part in range(2):
		var count: int = int(data.get("m_NumColorKeys" if part == 0 else "m_NumAlphaKeys", 0))
		for index in range(count):
			var time: float = float(data.get(("ctime" if part == 0 else "atime") + str(index), 0)) / 65535.0
			var color: Color = curves.color(data.get("key" + str(index), {}))
			if part == 0: color_times.append(time); color_keys.append(color)
			else: alpha_times.append(time); alpha_keys.append(color)
	if color_times.size()<=3:
		small_color=SmallPart.new();small_color.setup(color_times,color_keys,fixed)
	if alpha_times.size()<=3:
		small_alpha=SmallPart.new();small_alpha.setup(alpha_times,alpha_keys,fixed)
func _part(time: float, times: Array[float], keys: Array[Color]) -> Color:
	var count: int = times.size()
	if count == 0: return Color.WHITE
	var index: int = 0
	while index < count - 1 and time >= float(times[index + 1]): index += 1
	var a: Color = keys[index]
	var b: Color = keys[mini(index + 1, count - 1)]
	var u: float = 0.0
	if index < count - 1 and float(times[index + 1]) > float(times[index]): u = clampf((time - float(times[index])) / (float(times[index + 1]) - float(times[index])), 0.0, 1.0)
	if fixed: u = 0.0
	return a.lerp(b, u)
func sample(time: float) -> Color:
	var color: Color = small_color.sample(time) if small_color!=null else _part(time, color_times, color_keys)
	var alpha: Color = small_alpha.sample(time) if small_alpha!=null else _part(time, alpha_times, alpha_keys)
	return Color(color.r, color.g, color.b, alpha.a)
