extends RefCounted
## Original streamed cubic coefficients and source Animator controller inputs.
## Directional/radial blending and normalized transitions are compatibility ports
## of Unity's native Animator kernel, whose implementation is not in managed CIL.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
var game: Node
var source: Dictionary={}
var entries: Array=[]
var history: Array=[]
var rng:=RandomNumberGenerator.new()
var leaves: Array=[]
var points: Array=[]
var transition: Dictionary={}
func setup(owner_game: Node):
 game=owner_game;rng.seed=321527
 source=JSON.parse_string(FileAccess.get_file_as_string('res://references/combat_v32/minion_shake_runtime.json'))
 var state: Dictionary=source.controller.m_StateMachineArray[0].data.m_StateConstantArray[1].data
 var nodes: Array=state.m_BlendTreeConstantArray[0].data.m_NodeArray
 points=nodes[0].data.m_Blend2dData.data.m_ChildPositionArray
 for node in nodes.slice(1):leaves.append(source.clips[source.clip_index_to_key[int(node.data.m_ClipID)]])
 transition=state.m_TransitionConstantArray[0].data
func trigger(params: Dictionary,context: Dictionary,anchor: Vector2):
 var units: Array=game._presentation_units()
 if int(params.get('MinionsToShake',0))==1:
  var target: Dictionary=context.get('target',{})
  units=[target.unit] if target.get('type','')=='unit' else []
 var magnitude: float={1:0.1,2:0.5,3:1.0}.get(int(params.get('shakeSize',2)),float(params.get('custom',0.1)))
 var radius: float=float(params.get('radius_value',0.0)) if int(params.get('MinionsToShake',0))==0 else 0.0
 for unit in units:
  if bool(unit.get('dead',false)) or bool(unit.get('hidden',false)) or bool(unit.get('animating',false)):continue
  if unit.has('native_combat_position') or unit.has('native_summon_position'):continue
  if radius>0.0:
   var projection=SourceProjection.from_game(game)
   if projection!=null:
    var origin=projection.resolve_anchor(context)
    var target=projection.resolve_anchor(unit)
    if origin.is_empty() or target.is_empty():
     projection.block("Minion radial shake requires explicit source anchor");continue
    if target.position.distance_to(origin.position)>radius:continue
   elif unit.pos.distance_to(anchor)/(100.0*0.702)>radius:continue
  var angle:=rng.randf_range(0.0,TAU)
  var point:=Vector2(-sin(angle),-cos(angle))*magnitude
  var weights:=_weights(point)
  var duration:=0.0
  for i in range(leaves.size()):duration+=float(weights[i])*float(leaves[i].stop_time)
  for prior in entries.duplicate():
   if int(prior.unit.id)==int(unit.id):_remove(prior)
  entries.append({'unit':unit,'key':unit.key,'age':0.0,'duration':duration,'weights':weights,'parameter':[point.x,point.y],'end':duration*(float(transition.m_ExitTime)+float(transition.m_TransitionDuration))})
func _weights(point: Vector2) -> Array:
 var result: Array=[];result.resize(points.size());result.fill(0.0)
 var angle:=fposmod(atan2(point.x,point.y),TAU)/(PI*0.5)
 var lower:=int(floor(angle))%4;var upper: int=(lower+1)%4;var angular: float=angle-floorf(angle)
 var magnitude:=point.length();var lo:=0;var hi:=0;var radial:=0.0
 if magnitude>0.5:lo=1;hi=2;radial=clampf((magnitude-0.5)/0.5,0.0,1.0)
 elif magnitude>0.1:lo=0;hi=1;radial=clampf((magnitude-0.1)/0.4,0.0,1.0)
 for pair in [[lo,1.0-radial],[hi,radial]]:
  result[int(pair[0])*4+lower]+=float(pair[1])*(1.0-angular)
  result[int(pair[0])*4+upper]+=float(pair[1])*angular
 return result
func _scalar(keys: Array,time: float) -> float:
 var selected: Dictionary=keys[0]
 for key in keys:
  if float(key.time)>time:break
  selected=key
 var dt:=time-float(selected.time);var c: Array=selected.coefficients
 return ((float(c[0])*dt+float(c[1]))*dt+float(c[2]))*dt+float(c[3])
func sample_clip(clip: Dictionary,time: float) -> Dictionary:
 var t:=clampf(time,float(clip.start_time),float(clip.stop_time));var v: Array=[]
 for channel in clip.tracks:v.append(_scalar(channel,t))
 return {'position':Vector3(v[0],v[1],v[2]),'rotation':Quaternion(v[3],v[4],v[5],v[6]).normalized()}
func advance(delta: float):
 for entry in entries.duplicate():
  entry.age+=maxf(delta,0.0)
  if str(entry.unit.key)!=str(entry.key) or bool(entry.unit.get('dead',false)) or float(entry.age)>=float(entry.end):_remove(entry);continue
  var phase: float=float(entry.age)/maxf(float(entry.duration),0.000001)
  var position:=Vector3.ZERO;var quat:=Vector4.ZERO
  for i in range(leaves.size()):
   var weight: float=entry.weights[i]
   if weight<=0.0:continue
   var sample:=sample_clip(leaves[i],phase*float(leaves[i].stop_time))
   position+=sample.position*weight
   var q: Quaternion=sample.rotation
   if q.w<0.0:q=-q
   quat+=Vector4(q.x,q.y,q.z,q.w)*weight
  var fade:=1.0-clampf((phase-float(transition.m_ExitTime))/float(transition.m_TransitionDuration),0.0,1.0)
  # Entry blend is normalized to the source Idle clip duration, not one second.
  fade*=clampf(float(entry.age)/float(source.clips[source.clip_index_to_key[0]].stop_time),0.0,1.0)
  entry.unit.native_shake_position=position*fade
  entry.unit.native_shake_rotation=Quaternion.IDENTITY.slerp(Quaternion(quat.x,quat.y,quat.z,quat.w).normalized(),fade)
func _remove(entry: Dictionary):
 entry.unit.erase('native_shake_position');entry.unit.erase('native_shake_rotation')
 history.append({'unit_id':entry.unit.id,'parameters':entry.parameter,'clip_weights':entry.weights,'duration':entry.duration,'end':entry.end})
 if history.size()>64:history.pop_front()
 entries.erase(entry)
func cancel_all():
 for entry in entries.duplicate():_remove(entry)
func get_audit() -> Dictionary:
 return {'active_count':entries.size(),'history':history.duplicate(true),'source':'Original 13 streamed clips and controller','compatibility':'Unity native 2D blend weights and transition normalization independently implemented'}
