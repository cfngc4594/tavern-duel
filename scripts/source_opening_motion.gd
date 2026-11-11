extends RefCounted
## Build37.0.0.255130.254477, Unity world coordinates, no rendering/state mutation.
## Evidence: original_mulligan_work/evidence/motion_contract/{contract,itween.cil}.json.
## iTween DLL SHA25635702517648b33a463b6f061478787c30cba28555bf2178cc5cafbda56fb660d.
const Rotation=preload("res://scripts/source_itween_rotation.gd")
const DEAL_SECONDS:float=1.5
const SPREAD_SECONDS:float=0.9333333373069763
const REPLACEMENT_STAGGER:float=0.5
const DECK_EULER:Vector3=Vector3(275,270,0)
const DECK_SCALE:Vector3=Vector3(0.88,0.88,0.88)

static func progress(age:float,duration:float)->float:
	if duration<=0.0:return 1.0
	return clampf(age/duration,0.0,1.0)

static func source_ease(value:float,ease_id:int)->float:
	# Raw source easing, intentionally no endpoint correction for exponential.
	match ease_id:
		3:return value*value*value
		4:return pow(value-1.0,3.0)+1.0
		5:
			if value<0.5:return 4.0*value*value*value
			return 0.5*pow(2.0*value-2.0,3.0)+1.0
		16:return 1.0-pow(2.0,-10.0*value)
		33:
			# 0x060000be compares value>start/2; path passes start=0, NOT .5.
			if value>0.0:return 1.0-pow(2.0,-10.0*value)
			return 1.0-cos(value*1.5707963705062866)
		_:return value

static func control_points(path:PackedVector3Array)->PackedVector3Array:
	# GenerateMoveToPathTargets0x06000036. Opening callers include current at0.
	assert(path.size()>=2)
	var points:=PackedVector3Array()
	points.append(path[0]+(path[0]-path[1]))
	points.append_array(path)
	points.append(path[-1]+(path[-1]-path[-2]))
	# Unity Vector3 equality squared-distance threshold1e-10.
	if path[0].distance_squared_to(path[-1])<0.0000000001:
		points[0]=points[-3]
		points[-1]=points[2]
	return points

static func sample_path(path:PackedVector3Array,t:float)->Vector3:
	# CRSpline.Interp0x060000c9: uniform Catmull-Rom, no arc-length conversion.
	var points:=control_points(path)
	var segments:int=points.size()-3
	var parameter:float=clampf(t,0.0,1.0)*float(segments)
	var index:int=mini(int(floor(parameter)),segments-1)
	var u:float=parameter-float(index)
	var a:Vector3=points[index]
	var b:Vector3=points[index+1]
	var c:Vector3=points[index+2]
	var d:Vector3=points[index+3]
	return 0.5*((-a+3.0*b-3.0*c+d)*u*u*u+(2.0*a-5.0*b+4.0*c-d)*u*u+(-a+c)*u+2.0*b)

static func path_motion(path:PackedVector3Array,age:float,duration:float,ease_id:int)->Vector3:
	# ApplyMoveToPathTargets0x0600004d does NOT snap endpoint at percentage1.
	return sample_path(path,clampf(source_ease(progress(age,duration),ease_id),0.0,1.0))

static func card_scale()->Vector3:
	return Vector3(0.9,0.28,0.9)

static func row_position(index:int,count:int,zone_position:Vector3,collider_width:float,hand_y:float,initial_first_player:bool=false)->Vector3:
	assert(count>0 and index>=0 and index<count)
	var width:float=collider_width*0.55
	var spacing:float=width/float(count+1 if initial_first_player else count)
	return Vector3(zone_position.x-width/2.0+spacing*(float(index)+0.5),hand_y+7.0,zone_position.z-0.2)

static func base_launch_time(index:int)->float:
	assert(index>=0)
	return 0.0 if index==0 else 0.19+0.09*float(index-1)

static func deal_path(start:Vector3,target:Vector3)->PackedVector3Array:
	return PackedVector3Array([start,start+Vector3(0,3.6,0),target])

static func deal_position(start:Vector3,target:Vector3,age:float)->Vector3:
	return path_motion(deal_path(start,target),age,DEAL_SECONDS,33)

static func deal_rotation(start_euler:Vector3,age:float)->Vector3:
	return Rotation.interpolate(start_euler,Vector3.ZERO,Rotation.ease_out_expo_progress(age,DEAL_SECONDS,DEAL_SECONDS/16.0))

static func deal_scale(start_scale:Vector3,age:float)->Vector3:
	# ApplyScaleToTargets0x06000050 explicitly snaps endpoint, unlike path motion.
	var t:float=progress(age,DEAL_SECONDS)
	return start_scale.lerp(card_scale(),1.0 if t>=1.0 else source_ease(t,16))

static func spread_position(start:Vector3,target:Vector3,age:float)->Vector3:
	return start.lerp(target,source_ease(progress(age,SPREAD_SECONDS),5))

static func replacement_out_path(start:Vector3,mulliganed_position:Vector3,deck_zone_position:Vector3)->PackedVector3Array:
	return PackedVector3Array([start,start+Vector3(2,-1.7,0),mulliganed_position,deck_zone_position])

static func replacement_out_position(start:Vector3,mulliganed_position:Vector3,deck_zone_position:Vector3,age:float)->Vector3:
	return path_motion(replacement_out_path(start,mulliganed_position,deck_zone_position),age,DEAL_SECONDS,4)

static func replacement_in_path(start:Vector3,mulliganed_position:Vector3,target:Vector3)->PackedVector3Array:
	return PackedVector3Array([start,mulliganed_position,target+Vector3(2,-1.7,0),target])

static func replacement_in_position(start:Vector3,mulliganed_position:Vector3,target:Vector3,age:float)->Vector3:
	return path_motion(replacement_in_path(start,mulliganed_position,target),age,DEAL_SECONDS,3)

static func replacement_clip_time(age:float,clip_duration:float,reverse:bool=false)->float:
	# Actual exported putCardBack clip owns local rotation/scale, not an invented flip.
	return clampf(clip_duration-age if reverse else age,0.0,clip_duration)
