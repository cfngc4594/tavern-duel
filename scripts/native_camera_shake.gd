extends RefCounted
## CameraShakeMgr 06015080..8A / MainCameraShakerAction 06016bde..e0. One main camera.
## Source owns arbitration, time and xyz translation. Presentation projects that
## translation once after the existing 2.5D scene is composed; no source FOV claim.
const Curves=preload("res://scripts/native_summon_curves.gd")
const PROJECTION_SCALE=0.702
var native_camera_presentation:=false
var rng:=RandomNumberGenerator.new()
var started:=false
var amount:=Vector3.ZERO
var curve:Dictionary={}
var hold_at=null
var is_override:=false
var progress:=0.0
var duration:=0.0
var initial_position:=Vector3.ZERO
var position:=Vector3.ZERO
var world_offset:=Vector3.ZERO
var screen_offset:=Vector2.ZERO
var sampled_progress:=0.0
var intensity:=0.0
var samples:=0
var requests:=0
var accepted:=0
var history:Array=[]

func _init():rng.seed=35115080 # Independent Godot visual RNG, not Unity's sequence.

static func linear_curve(time:float,from:float=1.0)->Dictionary:
 var slope:float=-from/time if time>0.0 else 0.0
 return {"m_Curve":[{"time":0.0,"value":from,"inSlope":slope,"outSlope":slope},{"time":time,"value":0.0,"inSlope":slope,"outSlope":slope}]}

func request(value:Vector3,time:float,label:String="") -> bool:
 return request_curve(value,linear_curve(time),null,false,label)

func request_curve(value:Vector3,source_curve:Dictionary,hold=null,override_shake:bool=false,label:String="") -> bool:
 requests+=1
 var keys:Array=source_curve.get("m_Curve",[])
 if keys.is_empty() or float(keys[-1].time)<=0.0:
  stop();_record("zero_time_stop",label);return false
 if not override_shake and value.length_squared()<amount.length_squared():
  _record("smaller_ignored",label);return false
 if is_override:
  _record("override_ignored",label);return false
 if not started:initial_position=position;started=true
 amount=value;curve=source_curve.duplicate(true);hold_at=hold;is_override=override_shake
 progress=0.0;duration=float(keys[-1].time);accepted+=1
 _record("accepted",label);return true

func is_holding()->bool:return hold_at!=null and progress>=float(hold_at)

func advance(delta:float):
 if not started:return
 if progress>=duration and not is_holding():stop();return
 sampled_progress=progress;intensity=Curves.scalar_keys(curve.m_Curve,progress)
 var scaled:Vector3=amount*intensity
 world_offset=Vector3(rng.randf_range(-scaled.x,scaled.x),rng.randf_range(-scaled.y,scaled.y),rng.randf_range(-scaled.z,scaled.z))
 position=initial_position+world_offset
 # A camera translation moves scene content in the opposite screen direction.
 screen_offset=-Vector2(world_offset.x,-world_offset.y*sin(PI/12.0)-world_offset.z*cos(PI/12.0))*PROJECTION_SCALE*100.0
 samples+=1
 if not is_holding():progress=minf(progress+maxf(delta,0.0),duration)

func present_source_camera(projection)->bool:
 # Call once after advance and before source geometry/input snapshots. Every other
 # viewport copies the already-shaken source camera; never applies offset again.
 native_camera_presentation=projection!=null and projection.is_enabled() and projection.apply_camera_source_offset(world_offset)
 if native_camera_presentation:screen_offset=Vector2.ZERO
 return native_camera_presentation

func stop():
 if started:position=initial_position
 started=false;amount=Vector3.ZERO;curve={};hold_at=null;is_override=false
 world_offset=Vector3.ZERO;screen_offset=Vector2.ZERO;intensity=0.0

func clear():
 stop();progress=0.0;duration=0.0;sampled_progress=0.0
 samples=0;requests=0;accepted=0;history.clear()

# OnEnter creates this record only. The owning FSM calls update_action once on
# each later active OnUpdate, with its actual scaled delta, never a guessed 1/60.
# The local FSM schedules that callback next update; original Unity same-frame
# component execution ordering is not recovered by the action CIL.
static func new_action(value:Vector3,time:float,delay:float,entered_update:int,label:String="")->Dictionary:
 return {"amount":value,"duration":time,"delay":delay,"timer":0.0,"entered_update":entered_update,"attempted":false,"label":label}

func update_action(action:Dictionary,delta:float,update_id:int):
 if update_id<=int(action.entered_update) or bool(action.attempted):return
 action.timer+=maxf(delta,0.0)
 if float(action.timer)>=float(action.delay):
  action.attempted=true
  request(action.amount,float(action.duration),str(action.label))

func _record(event:String,label:String):
 history.append({"event":event,"label":label,"progress":progress,"amount":amount,"override":is_override})
 if history.size()>128:history.pop_front()

func get_audit()->Dictionary:
 return {"started":started,"amount":amount,"progress":progress,"sampled_progress":sampled_progress,"duration":duration,"intensity":intensity,"holding":is_holding(),"override":is_override,"world_offset":world_offset,"screen_offset":screen_offset,"samples":samples,"requests":requests,"accepted":accepted,"history":history.duplicate(true),"native_camera_presentation":native_camera_presentation,"compatibility":"Phone: source world xyz translation on registered perspective camera, once; desktop: existing 0.702/15-degree 2.5D screen projection. Godot visual RNG is not Unity Random."}
