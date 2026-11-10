extends Node
const SourceStore=preload('res://original_board/scripts/board_source_store.gd')
## Source-driven subset of the two enabled PlayMaker FSMs. Not a general PlayMaker runtime.
const Curves=preload('res://original_board/scripts/source_legacy_curves.gd')
const BASE='res://original_board/assets/arch/'
var probe
var source_cab='cab-995e7cbc44ff3e7f4314fc93360989d0:'
var systems:Dictionary={}
var events:Array=[]
var audio_players:Array=[]
var audio_enabled=true
var closed=false
var elapsed=0.0
var rng=RandomNumberGenerator.new()
func setup(p,options:Dictionary={}):
 probe=p;rng.randomize()
 source_cab=str(options.get('source_cab',source_cab))
 var source_base=str(options.get('source_base',BASE))
 for kind in options.get('kinds',['gong','lantern']):
  var file='lamp' if kind=='lantern' else kind
  var source=SourceStore.json_for(probe,source_base+file+'.json')
  var sys={'source':source,'states':{},'state':'','time':0.0,'gates':{},'speeds':{},'animation':{},'collider':{},'waits':[]}
  for st in source.states:sys.states[st.name]=st
  for obj in source.objects.values():
   if obj.type in ['SphereCollider','BoxCollider']:sys.collider=obj
  systems[kind]=sys
  _enter(kind,source.fsm.start_state)
func _go_id(p)->String:
 if p.has('gameObject'):p=p.gameObject
 return source_cab+str(p.m_PathID)
func _collider_node(kind):
 var c=systems[kind].collider
 return probe.source_nodes.get(c.refs['.m_GameObject'])
func target_screen(kind='gong')->Vector2:
 var sys=systems[kind];var node=_collider_node(kind)
 return probe.camera.unproject_position(node.global_transform*probe.source_vector(sys.collider.data.m_Center))
func hit_test(kind:String,screen:Vector2)->bool:
 if closed:return false
 var sys=systems[kind];var c=sys.collider;var node=_collider_node(kind)
 if not is_instance_valid(node) or not node.is_visible_in_tree() or not c.data.m_Enabled:return false
 var origin=probe.camera.project_ray_origin(screen);var direction=probe.camera.project_ray_normal(screen).normalized()
 var center=probe.source_vector(c.data.m_Center)
 if c.type=='SphereCollider':
  var scale=node.global_basis.get_scale().abs();var radius=float(c.data.m_Radius)*maxf(scale.x,maxf(scale.y,scale.z))
  var rel=origin-node.global_transform*center;var b=rel.dot(direction);var det=b*b-(rel.dot(rel)-radius*radius)
  return det>=0 and -b+sqrt(maxf(det,0))>=0
 var inv=node.global_transform.affine_inverse();var ro=inv*origin;var rd=inv.basis*direction
 var half=probe.v3(c.data.m_Size)*0.5;var lo=center-half;var hi=center+half;var near=0.0;var far=INF
 for axis in range(3):
  if absf(rd[axis])<0.0000001:
   if ro[axis]<lo[axis] or ro[axis]>hi[axis]:return false
  else:
   var t0=(lo[axis]-ro[axis])/rd[axis];var t1=(hi[axis]-ro[axis])/rd[axis]
   near=maxf(near,minf(t0,t1));far=minf(far,maxf(t0,t1))
   if near>far:return false
 return far>=0
func handle_input(event)->bool:
 if closed or event is not InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return false
 for kind in systems:
  if hit_test(kind,event.position):return click_kind(kind)
 return false
func click_kind(kind:String)->bool:
 if closed or not systems.has(kind):return false
 # InputCollection/UnityInput does not consume GetMouseButtonDown. PlayMaker switches
 # states synchronously; checkFirstFrame actions re-read this same desktop press.
 for transition_count in range(16):
  var before=systems[kind].state
  _click_once(kind)
  if systems[kind].state==before:return true
  var recheck=false
  for action in systems[kind].states[systems[kind].state].actions:
   if action.enabled and action['class']=='MousePickRandomAction' and action.params.checkFirstFrame:recheck=true
  if not recheck:return true
 events.append({'event':'reentry_guard','kind':kind})
 return true
func _click_once(kind:String)->bool:
 if closed or not systems.has(kind):return false
 var sys=systems[kind];var actions=sys.states[sys.state].actions
 for i in range(actions.size()):
  var a=actions[i]
  if not a.enabled or a['class']!='MousePickRandomAction':continue
  var gate_key=sys.state+':'+str(i);var gate=sys.gates[gate_key];var p=a.params
  gate.count+=1
  var opened=gate.count>=gate.threshold
  var evt=p.mouseDownGateOpen if opened else p.mouseDownGateClosed
  if opened:
   gate.opened=true
   if p.ResetOnOpen:gate.count=0
  events.append({'event':'click','kind':kind,'state':sys.state,'gate_action':gate_key,'gate_threshold':gate.threshold,'gate_count':gate.count,'gate_open':opened,'emitted':evt,'time':elapsed})
  _event(kind,evt);return true
 events.append({'event':'click_ignored','kind':kind,'state':sys.state,'time':elapsed});return true
func _event(kind:String,event:String):
 var sys=systems[kind];var trans=sys.states[sys.state].transitions
 if trans.has(event):_enter(kind,trans[event])
func _enter(kind:String,state:String):
 var sys=systems[kind];sys.state=state;sys.time=0.0;sys.waits=[]
 events.append({'event':'state_enter','kind':kind,'state':state,'time':elapsed})
 var actions=sys.states[state].actions
 for i in range(actions.size()):
  var a=actions[i]
  if not a.enabled:continue
  var p=a.params
  match a['class']:
   'MousePickRandomAction':
    var key=state+':'+str(i)
    if not sys.gates.has(key):sys.gates[key]={'count':int(p.ClickCount),'opened':true,'threshold':0}
    var g=sys.gates[key]
    if g.opened:
     var hi=int(p.RandomGateClicksMax);var low=mini(int(p.RandomGateClicksMin),hi)
     g.threshold=low if hi<=low else rng.randi_range(low,hi-1);g.opened=false
   'SetAnimationSpeed':sys.speeds[p.animName]=float(p.speed)
   'StopAnimation':
    if sys.animation.get('name','')==p.animName:sys.animation={}
    events.append({'event':'animation_stop','kind':kind,'clip':p.animName,'pose_policy':'held pose compatibility','time':elapsed})
   'BlendAnimation':
    # Source call is followed immediately by StopAnimation for the same clip.
    events.append({'event':'animation_blend_request','kind':kind,'clip':p.animName,'weight':p.targetWeight,'seconds':p.time,'cancelled_by_next_source_stop':true,'time':elapsed})
   'AnimationPlaythroughAction':_play(kind,p.m_AnimName,float(p.m_CrossFadeSec),'immediate action Finish; playback continues')
   'PlayAnimation':_play(kind,p.animName,float(p.blendTime),'play action waiting semantics not used for FSM transitions here')
   'Wait':sys.waits.append({'seconds':float(p.time),'event':p.finishEvent})
   'AudioPlayRandomClipAction','AudioPlayClipAction':_sound(kind,a)
   _:events.append({'event':'unsupported_action','kind':kind,'class':a['class']})
func _play(kind:String,name:String,fade:float,finish_policy:String):
 var sys=systems[kind];var clip=sys.source.animations[name];var poses={}
 for track in clip.tracks:
  var node=probe.source_nodes.get(track.target_node_id)
  if is_instance_valid(node):poses[track.target_node_id]=node.quaternion
 sys.animation={'name':name,'time':0.0,'fade':fade,'fade_time':0.0,'from':poses,'speed':sys.speeds.get(name,1.0)}
 events.append({'event':'animation_play','kind':kind,'clip':name,'speed':sys.animation.speed,'fade':fade,'finish_policy':finish_policy,'time':elapsed})
 _sample(kind)
func _sample(kind:String):
 var sys=systems[kind]
 if sys.animation.is_empty():return
 var anim=sys.animation;var clip=sys.source.animations[anim.name];var t=minf(anim.time,float(clip.duration_seconds))
 if int(clip.wrap_mode)==2:t=fposmod(anim.time,float(clip.duration_seconds))
 var weight=1.0 if anim.fade<=0 else clampf(anim.fade_time/anim.fade,0,1)
 for track in clip.tracks:
  if track.type!='m_RotationCurves':continue # EulerAnglesHint are editor hints, not runtime rotations.
  var node=probe.source_nodes.get(track.target_node_id)
  if not is_instance_valid(node):continue
  var q=Curves.sample_quaternion(track.source_curve.curve.m_Curve,t)
  var dest=Quaternion(-q.x,-q.y,q.z,q.w)
  var blend=anim.from[track.target_node_id].slerp(dest,weight)
  var scale=node.scale;var b=Basis(blend);node.basis=Basis(b.x*scale.x,b.y*scale.y,b.z*scale.z)
func advance(dt:float):
 if closed:return
 elapsed+=dt
 for kind in systems:
  var sys=systems[kind];sys.time+=dt
  if not sys.animation.is_empty():
   sys.animation.time+=dt*float(sys.animation.speed);sys.animation.fade_time+=dt;_sample(kind)
  for wait in sys.waits:
   if sys.time>=wait.seconds:
    _event(kind,wait.event);break # Native state scheduling is frame-based; no fabricated leftover-time cascade.
 for p in audio_players.duplicate():
  if not is_instance_valid(p):audio_players.erase(p)
func _sound(kind:String,action:Dictionary):
 var p=action.params;var options=action.audio_sources;var index=0
 if options.size()>1:
  var weights=p.get('m_Weights',[]);var total=0.0
  for w in weights:total+=float(w)
  var value=rng.randf()*total
  for i in range(weights.size()):
   value-=float(weights[i]);index=i
   if value<=0:break
 var selected=options[index];var clip=selected.clips[0]
 var volume=float(p.get('m_Volume',p.get('m_MinVolume',1.0)));var pitch=float(p.get('m_Pitch',p.get('m_MinPitch',1.0)))
 if p.has('m_MaxVolume'):volume=rng.randf_range(volume,float(p.m_MaxVolume))
 if p.has('m_MaxPitch'):pitch=rng.randf_range(pitch,float(p.m_MaxPitch))
 var anchor=probe.source_nodes[_go_id(p.m_ParentObject)];var listener=probe.door_interaction.listener
 var cfg=systems[kind].source.runtime_audio_source_template.audio_source
 var distance=anchor.global_position.distance_to(listener.global_position)
 var gain=1.0-clampf((distance-float(cfg.MinDistance))/(float(cfg.MaxDistance)-float(cfg.MinDistance)),0,1)
 events.append({'event':'audio_start','kind':kind,'state':systems[kind].state,'guid':clip.guid,'file':clip.file,'volume':volume,'pitch':pitch,'gain':gain,'time':elapsed,'enabled':audio_enabled})
 if not audio_enabled:return
 var stream=AudioStreamWAV.load_from_file(BASE+clip.file)
 if stream==null:events.append({'event':'audio_error','file':clip.file});return
 var player=AudioStreamPlayer3D.new();player.bus=&"SFX";probe.source_root.add_child(player);player.global_position=anchor.global_position;player.stream=stream;player.pitch_scale=pitch;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance=0;player.volume_db=linear_to_db(maxf(volume*gain,0.00001));player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
 audio_players.append(player);player.finished.connect(player.queue_free);player.play()
func get_audit():
 var summary={}
 for kind in systems:
  var s=systems[kind];summary[kind]={'state':s.state,'state_time':s.time,'gates':s.gates.duplicate(true),'animation':s.animation.duplicate(true)}
 return {'systems':summary,'events':events.duplicate(true),'closed':closed,'compatibility':['Original action order, speeds, enabled waits and per-action random counters preserved.','Same-press checkFirstFrame re-entry follows managed desktop Fsm/InputCollection/UnityInput chain; native full-client timing not directly sampled.','Quaternion component Hermite + normalization; crossfade from held pose with spherical interpolation is a declared compatibility approximation to Unity legacy blend.','Animation endpoint is held; native post-disable pose persistence not sampled.','Original source clips and listener reused; original reverb preset27, mixer/ducking and native spatial pan not reproduced.','Only selected original box/sphere ray tests; no complete physics occlusion/nearest-hit parity.']}
func close_interaction():
 if closed:return
 closed=true
 for p in audio_players:
  if is_instance_valid(p):p.stop();p.queue_free()
 audio_players.clear();systems.clear()
