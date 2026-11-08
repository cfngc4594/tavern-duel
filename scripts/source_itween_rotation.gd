extends RefCounted
## Original Blizzard.T5.iTween.dll 35702517648b33a463b6f061478787c30cba28555bf2178cc5cafbda56fb660d.
## GenerateRotateToTargets 0x0600003c / ApplyRotateToTargets 0x06000052:
## read world Euler angles, clerp each destination with value=1, ease each
## component, then Quaternion.Euler. This is deliberately not quaternion slerp.

static func clerp(start:float,finish:float,value:float)->float:
	# Original 0x0600009c: strict comparisons preserve the direction at +/-180.
	var delta:=finish-start
	if delta < -180.0:return start+(360.0-start+finish)*value
	if delta > 180.0:return start+(-(360.0-finish+start))*value
	return start+delta*value

static func adjusted_target(start:Vector3,finish:Vector3)->Vector3:
	return Vector3(clerp(start.x,finish.x,1.0),clerp(start.y,finish.y,1.0),clerp(start.z,finish.z,1.0))

static func interpolate(start:Vector3,finish:Vector3,ease_value:float)->Vector3:
	return start.lerp(adjusted_target(start,finish),ease_value)

static func ease_out_expo_progress(age:float,duration:float,delay:float=0.0)->float:
	var elapsed:=age-delay
	if elapsed<=0.0:return 0.0
	# ApplyRotateToTargets explicitly snaps to its adjusted endpoint at 1.
	if duration<=0.0 or elapsed>=duration:return 1.0
	return 1.0-pow(2.0,-10.0*elapsed/duration)

static func source_basis(degrees:Vector3)->Basis:
	# Original Unity Quaternion.Euler order: Z, X, Y, in unreflected source space.
	return Basis(Vector3.UP,deg_to_rad(degrees.y))*Basis(Vector3.RIGHT,deg_to_rad(degrees.x))*Basis(Vector3.BACK,deg_to_rad(degrees.z))

static func matches_rotation(degrees:Vector3,rotation:Quaternion)->bool:
	return degrees.is_finite() and rotation.is_finite() and source_basis(degrees).is_equal_approx(Basis(rotation))
