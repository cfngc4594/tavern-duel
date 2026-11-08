extends RefCounted
## Source-derived High-quality NoiseModule derivative kernel.
## Source kernel0x18141b850 returns dx/dy, not noise value.
## Independent numeric vectors come from bounded original-instruction arithmetic.
## This does NOT establish emitter seed/coordinate/application equivalence.
var permutation:Array=[]
var gradients:Array=[]
var source:Dictionary={}
func _init():
	source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/noise_kernel_tables.json"))
	permutation=source.permutation
	for g in source.gradients:gradients.append(Vector3(g[0],g[1],g[2]))
func derivative(p:Vector3,frequency:float) -> Vector2:
	# Vector3 multiplication supplies the source float32 coordinate product.
	var q=p*frequency
	var cell=Vector3i(floori(q.x),floori(q.y),floori(q.z))
	var t=q-Vector3(cell)
	var u=Vector3.ZERO
	var du=Vector3.ZERO
	for i in 3:
		var a=float(t[i]);u[i]=a*a*a*(a*(a*6.0-15.0)+10.0)
		du[i]=30.0*a*a*(a*(a-2.0)+1.0)
	var result=Vector2.ZERO
	for x in 2:
		for y in 2:
			for z in 2:
				var ix=int(permutation[(cell.x&255)+x])
				var iy=int(permutation[ix+(cell.y&255)+y])
				var hash_value=int(permutation[iy+(cell.z&255)+z])&15
				var g:Vector3=gradients[hash_value]
				var dot_value=g.dot(t-Vector3(x,y,z))
				var wx=float(u.x) if x else 1.0-float(u.x)
				var wy=float(u.y) if y else 1.0-float(u.y)
				var wz=float(u.z) if z else 1.0-float(u.z)
				result.x+=(g.x*wx+dot_value*du.x*(1.0 if x else -1.0))*wy*wz
				result.y+=(g.y*wy+dot_value*du.y*(1.0 if y else -1.0))*wx*wz
	return result*frequency
func octave_derivative(p:Vector3,frequency:float,count:int,multiplier:float,scale:float) -> Vector2:
	# Original0x181420a30: weighted derivative sum / sum(weights).
	var result=derivative(p,frequency)
	# Both source emitters have2 identical octave samples (scale1,weight1).
	# Native(sum(sample,sample)/2) equals sample for this finite field range.
	if count==2 and multiplier==1.0 and scale==1.0:return result
	var weight=1.0
	var weight_sum=1.0
	for i in range(1,count):
		frequency*=scale;weight*=multiplier
		result+=derivative(p,frequency)*weight;weight_sum+=weight
	return result/weight_sum

func curl_at_source_position(source_position:Vector3,source_offset:Vector3,scroll:float,frequency:float,count:int,multiplier:float,scale:float) -> Vector3:
	# Exact argument permutations and subtraction order in0x181428bb8..0x181428d1a.
	# This returns the field only. Strength/damping/time/application are external.
	var p=source_position+source_offset
	var f=maxf(frequency,0.000001)
	var a=octave_derivative(Vector3(p.z,p.y,p.x+scroll),f,count,multiplier,scale)
	var b=octave_derivative(Vector3(p.x+100.0,p.z,p.y+scroll),f,count,multiplier,scale)
	var c=octave_derivative(Vector3(p.y,p.x+100.0,p.z+scroll),f,count,multiplier,scale)
	return Vector3(c.x-b.y,a.x-c.y,b.x-a.y)

static func source_seed_offset(system_seed:int) -> Vector3:
	# Original shared-axis dispatch0x181420209..0x1814202c6 derives
	# three offsets from ParticleSystem.randomSeed, not the per-particle seed.
	# Caller must supply a traced source seed. No invented auto-seed here.
	var state:Array[int]=[system_seed&0xffffffff]
	for i in 3:state.append((state[-1]*0x6c078965+1)&0xffffffff)
	var value=Vector3.ZERO
	for i in 3:
		var t=(state[0]^(state[0]<<11))&0xffffffff
		var w=(state[3]^(state[3]>>19)^t^(t>>8))&0xffffffff
		state=[state[1],state[2],state[3],w]
		value[i]=float(w&0x7fffff)*1.1920930376163597e-7
	return value*100.0
