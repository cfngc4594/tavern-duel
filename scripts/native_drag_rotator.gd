extends RefCounted
## DragRotator.Update/Reset source arithmetic. Inputs are ORIGINAL world axes;
## projection and initial card pose conversion stay explicitly outside this class.
var info:Dictionary
var previous_position:=Vector3.ZERO
var pitch:=0.0
var roll:=0.0
var pitch_velocity:=0.0
var roll_velocity:=0.0
func _init():
 info=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/drag_rotator_parameters.json")).info
func reset(world_position:Vector3):
 previous_position=world_position;pitch=0.0;roll=0.0;pitch_velocity=0.0;roll_velocity=0.0
func sample(world_position:Vector3,delta:float)->Vector2:
 var movement=world_position-previous_position
 if movement.length_squared()>0.0001:
  pitch=clampf(pitch+movement.z*float(info.m_PitchInfo.m_ForceMultiplier),float(info.m_PitchInfo.m_MinDegrees),float(info.m_PitchInfo.m_MaxDegrees))
  roll=clampf(roll-movement.x*float(info.m_RollInfo.m_ForceMultiplier),float(info.m_RollInfo.m_MinDegrees),float(info.m_RollInfo.m_MaxDegrees))
 var p=smooth_damp_zero(pitch,pitch_velocity,float(info.m_PitchInfo.m_RestSeconds)*0.1,delta)
 var r=smooth_damp_zero(roll,roll_velocity,float(info.m_RollInfo.m_RestSeconds)*0.1,delta)
 pitch=p.x;pitch_velocity=p.y;roll=r.x;roll_velocity=r.y
 previous_position=world_position
 return Vector2(pitch,roll)
static func smooth_damp_zero(current:float,velocity:float,smooth_time:float,delta:float)->Vector2:
 # Unity Mathf.SmoothDamp default maxSpeed=Infinity, target=0.
 if delta<=0.0:return Vector2(current,velocity)
 var omega=2.0/maxf(0.0001,smooth_time)
 var x=omega*delta
 var decay=1.0/(1.0+x+0.48*x*x+0.235*x*x*x)
 var temp=(velocity+omega*current)*delta
 var next_velocity=(velocity-omega*temp)*decay
 var output=(current+temp)*decay
 if (-current>0.0)==(output>0.0):output=0.0;next_velocity=0.0
 return Vector2(output,next_velocity)
