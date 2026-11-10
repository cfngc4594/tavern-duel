extends Node
const SourceStore=preload('res://original_board/scripts/board_source_store.gd')
## The two enabled source FSMs share their original Animation components and skin.
## Native Unity Legacy mixing/audio parity is explicitly not claimed.
const Curves=preload('res://original_board/scripts/source_legacy_curves.gd')
const SkinRig=preload('res://original_board/scripts/source_kite_skin.gd')
const BASE='res://original_board/assets/kite/'
const CAB='cab-995e7cbc44ff3e7f4314fc93360989d0:'
var probe
var skin
var systems:Dictionary={}
var clips:Dictionary={}
var rest:Dictionary={}
var events:Array=[]
var audio_players:Array=[]
var audio_enabled=true
var elapsed=0.0
var closed=false
var rng=RandomNumberGenerator.new()
var ignored_tracks:Dictionary={}
var errors:Array=[]
func setup(p):
 probe=p;rng.randomize()
 skin=SkinRig.new();skin.name='SourceKiteSkin';add_child(skin);skin.setup(p)
 for kind in ['kite','pole']:
  var file='kite_fsm.json' if kind=='kite' else 'pole_fsm.json'
  var source=SourceStore.json_for(probe,BASE+file)
  var sys={'source':source,'states':{},'state':'','time':0.0,'gates':{},'pending':{},'waits':[],'tween':{},'collider':{}}
  for st in source.states:sys.states[st.name]=st
  var collider_target=''
  for st in source.states:
   for action in st.actions:
    if action.enabled and action['class']=='MousePickRandomAction':collider_target=_go_id(action.params.GameObject)
  for obj in source.objects.values():
   if obj.type in ['SphereCollider','BoxCollider'] and obj.refs['.m_GameObject']==collider_target:sys.collider=obj
  for name in source.animations:
   if clips.has(name):continue
   var clip=source.animations[name]
   clips[name]={'source':clip,'root':clip.animation_root,'name':name,'time':0.0,'enabled':false,'weight':0.0,'fade_from':0.0,'fade_to':0.0,'fade_time':0.0,'fade_duration':0.0,'speed':1.0}
   for track in clip.tracks:
    var node=probe.source_nodes.get(track.target_node_id)
    if not is_instance_valid(node):errors.append('Missing source animation target '+track.target_node_id);continue
    if not rest.has(track.target_node_id):rest[track.target_node_id]={'position':node.position,'rotation':node.quaternion,'scale':node.scale}
    if track.source_curve.curve.m_Curve.is_empty():ignored_tracks[name+':'+track.target_node_id+':'+track.type]='Serialized curve contains zero keys; preserve existing property rather than invent a pose.'
    if track.type=='m_FloatCurves':ignored_tracks[name+':'+track.target_node_id+':'+str(track.source_curve.get('attribute',''))]='Editor EulerAnglesHint or Animation.m_PlayAutomatically property; not an alternate transform curve.'
  systems[kind]=sys
 for kind in systems:_enter(kind,systems[kind].source.fsm.start_state)
 _sample_all();skin.advance(0)
func _go_id(p)->String:
 if p.has('gameObject'):p=p.gameObject
 return CAB+str(p.m_PathID)
func _collider_node(kind):return probe.source_nodes.get(systems[kind].collider.refs['.m_GameObject'])
func target_screen(kind='kite')->Vector2:
 if not systems.has(kind) or systems[kind].collider.is_empty():return Vector2.ZERO
 var node=_collider_node(kind)
 return probe.camera.unproject_position(node.global_transform*probe.source_vector(systems[kind].collider.data.m_Center))
func hit_test(kind:String,screen:Vector2)->bool:
 if closed or not systems.has(kind):return false
 var c=systems[kind].collider
 if c.is_empty():return false
 var node=_collider_node(kind)
 # Renderer.enabled does NOT disable the source collider or deactivate the GameObject.
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
 # Managed InputCollection/UnityInput.GetMouseButtonDown is non-consuming.
 # Synchronous Fsm transitions re-enter checkFirstFrame on this same press.
 for count in range(16):
  var before=systems[kind].state
  _click_once(kind)
  if systems[kind].state==before:return true
  var recheck=false
  for a in systems[kind].states[systems[kind].state].actions:
   if a.enabled and a['class']=='MousePickRandomAction' and a.params.checkFirstFrame:recheck=true
  if not recheck:return true
 errors.append('Same press transition guard reached '+kind);return true
func _click_once(kind:String):
 var sys=systems[kind];var actions=sys.states[sys.state].actions
 for i in range(actions.size()):
  var a=actions[i]
  if not a.enabled or a['class']!='MousePickRandomAction':continue
  var key=sys.state+':'+str(i);var gate=sys.gates[key];var p=a.params
  gate.count+=1;var opened=gate.count>=gate.threshold
  var evt=p.mouseDownGateOpen if opened else p.mouseDownGateClosed
  if opened:
   gate.opened=true
   if p.ResetOnOpen:gate.count=0
  events.append({'event':'click','kind':kind,'state':sys.state,'gate_action':key,'gate_count':gate.count,'gate_threshold':gate.threshold,'gate_open':opened,'emitted':evt,'time':elapsed})
  _event(kind,evt);return
 events.append({'event':'click_ignored','kind':kind,'state':sys.state,'time':elapsed})
func _event(kind:String,event:String):
 var transitions=systems[kind].states[systems[kind].state].transitions
 if transitions.has(event):_enter(kind,transitions[event])
func _enter(kind:String,state:String):
 var sys=systems[kind];sys.state=state;sys.time=0.0;sys.waits=[];sys.pending={};sys.tween={}
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
     var high=int(p.RandomGateClicksMax);var low=mini(int(p.RandomGateClicksMin),high)
     g.threshold=low if high<=low else rng.randi_range(low,high-1);g.opened=false
    sys.pending[i]={'type':'mouse'}
   'BlendAnimation':_blend(kind,p.animName,float(p.targetWeight),float(p.time))
   'PlayAnimation':
    _play(kind,p.animName,float(p.blendTime),int(p.playMode))
    sys.pending[i]={'type':'animation','clip':p.animName,'event':p.finishEvent}
   'AnimationPlaythroughAction':_play(kind,p.m_AnimName,float(p.m_CrossFadeSec),int(p.m_PlayMode))
   'Wait':
    sys.waits.append({'index':i,'seconds':float(p.time),'event':p.finishEvent});sys.pending[i]={'type':'wait'}
   'iTweenScaleTo':
    var node=probe.source_nodes[_go_id(p.gameObject)]
    sys.tween={'index':i,'node':_go_id(p.gameObject),'from':node.scale,'to':probe.v3(p.vectorScale),'duration':float(p.time),'delay':float(p.delay),'ease_type':int(p.easeType),'event':p.finishEvent}
    sys.pending[i]={'type':'tween'}
   'SetVisibility':_set_visibility(_go_id(p.gameObject),bool(p.visible),kind)
   'AudioPlayRandomClipAction','AudioPlayClipAction','AudioPlaythroughAction':_sound(kind,a)
   _:errors.append('Unsupported enabled action '+a['class'])
func _fade(clip:Dictionary,target:float,duration:float):
 clip.fade_from=clip.weight;clip.fade_to=target;clip.fade_time=0.0;clip.fade_duration=duration
 if duration<=0:
  clip.weight=target
  if target<=0:clip.enabled=false
func _play(kind:String,name:String,fade:float,mode:int):
 if not clips.has(name):errors.append('Missing clip '+name);return
 var clip=clips[name]
 if mode!=4:errors.append('Unexpected playMode '+str(mode))
 for other in clips.values():
  if other.root==clip.root and other.name!=name and other.enabled:_fade(other,0.0,fade)
 # Source CrossFade does not restart a still-enabled clip. Stopped clips start at 0.
 if not clip.enabled:clip.time=0.0;clip.weight=0.0
 clip.enabled=true;_fade(clip,1.0,fade)
 events.append({'event':'animation_play','kind':kind,'state':systems[kind].state,'clip':name,'root':clip.root,'crossfade_seconds':fade,'play_mode':mode,'time':elapsed})
func _blend(kind:String,name:String,target:float,duration:float):
 var clip=clips[name]
 if not clip.enabled:clip.time=0.0;clip.weight=0.0
 clip.enabled=true;_fade(clip,target,duration)
 events.append({'event':'animation_blend','kind':kind,'state':systems[kind].state,'clip':name,'weight':target,'seconds':duration,'time':elapsed})
func _sample_all():
 var samples={}
 for clip in clips.values():
  if not clip.enabled or clip.weight<=0:continue
  var source=clip.source;var t=minf(clip.time,float(source.duration_seconds))
  if int(source.wrap_mode)==2:t=fposmod(clip.time,float(source.duration_seconds))
  for track in source.tracks:
   var prop='';var value
   var keys=track.source_curve.curve.m_Curve
   if keys.is_empty():continue
   match track.type:
    'm_RotationCurves':
     prop='rotation';var q=Curves.sample_quaternion(keys,t);value=Quaternion(-q.x,-q.y,q.z,q.w)
    'm_PositionCurves':
     prop='position';value=Vector3(Curves.sample_scalar(keys,t,'x'),Curves.sample_scalar(keys,t,'y'),-Curves.sample_scalar(keys,t,'z'))
    'm_ScaleCurves':
     prop='scale';value=Vector3(Curves.sample_scalar(keys,t,'x'),Curves.sample_scalar(keys,t,'y'),Curves.sample_scalar(keys,t,'z'))
    _:continue
   var key=track.target_node_id+'|'+prop
   if not samples.has(key):samples[key]={'node':track.target_node_id,'property':prop,'values':[],'total':0.0}
   samples[key].values.append({'value':value,'weight':clip.weight});samples[key].total+=clip.weight
 for sample in samples.values():
  var node=probe.source_nodes.get(sample.node)
  if not is_instance_valid(node):continue
  var base=rest[sample.node][sample.property];var total=maxf(1.0,sample.total);var remaining=maxf(0.0,1.0-sample.total)
  if sample.property=='rotation':
   var v=Vector4(base.x,base.y,base.z,base.w)*remaining
   for pair in sample['values']:
    var q:Quaternion=pair.value
    if base.dot(q)<0:q=-q
    v+=Vector4(q.x,q.y,q.z,q.w)*float(pair.weight)
   var q=Quaternion(v.x,v.y,v.z,v.w).normalized();var b=Basis(q);var s=node.scale
   node.basis=Basis(b.x*s.x,b.y*s.y,b.z*s.z)
  else:
   var v:Vector3=base*remaining
   for pair in sample['values']:v+=pair.value*float(pair.weight)
   node.set(sample.property,v/total)
func advance(dt:float):
 if closed:return
 elapsed+=dt
 var ended=[]
 for clip in clips.values():
  if not clip.enabled:continue
  clip.time+=dt*clip.speed;clip.fade_time+=dt
  var ratio=1.0 if clip.fade_duration<=0 else clampf(clip.fade_time/clip.fade_duration,0.0,1.0)
  clip.weight=lerpf(clip.fade_from,clip.fade_to,ratio)
  if ratio>=1 and clip.fade_to<=0:clip.enabled=false;continue
  if int(clip.source.wrap_mode)!=2 and clip.time>=float(clip.source.duration_seconds):ended.append(clip)
 _sample_all()
 for clip in ended:
  clip.enabled=false
  events.append({'event':'animation_disabled','clip':clip.name,'reason':'nonloop source endpoint','time':elapsed})
 # Stable kite-then-pole order. Full client inter-FSM Update ordering remains unobserved.
 for kind in systems:
  var sys=systems[kind];sys.time+=dt;var before=sys.state
  if not sys.tween.is_empty():
   var tw=sys.tween;var ratio=clampf((sys.time-tw.delay)/tw.duration,0,1)
   if tw.ease_type!=21:errors.append('Unimplemented source tween easing '+str(tw.ease_type))
   probe.source_nodes[tw.node].scale=tw['from'].lerp(tw.to,ratio)
   if ratio>=1:
    sys.pending.erase(tw.index);sys.tween={};_event(kind,tw.event)
  if sys.state!=before:continue
  for wait in sys.waits.duplicate():
   if sys.time>=wait.seconds:
    sys.pending.erase(wait.index);sys.waits.erase(wait);_event(kind,wait.event)
    if sys.state!=before:break
  if sys.state!=before:continue
  for key in sys.pending.keys():
   var action=sys.pending[key]
   if action.type=='animation' and not clips[action.clip].enabled:
    sys.pending.erase(key);_event(kind,action.event)
    if sys.state!=before:break
  if sys.state==before and sys.pending.is_empty():_event(kind,'FINISHED')
 skin.advance(dt)
 for row in audio_players.duplicate():
  if not is_instance_valid(row.player):audio_players.erase(row);continue
  _update_audio_gain(row)
func _set_visibility(node_id:String,visible:bool,kind:String):
 var count=0
 for renderer in probe.renderer_nodes.values():
  if is_instance_valid(renderer) and renderer.get_meta('source_node','')==node_id:
   renderer.visible=visible;count+=1
 events.append({'event':'renderer_visibility','kind':kind,'node':node_id,'visible':visible,'renderers':count,'game_object_kept_active':true,'time':elapsed})
 if count==0:errors.append('SetVisibility missing renderer '+node_id)
func _sound(kind:String,action:Dictionary):
 var p=action.params;var options=action.get('audio_sources',[])
 if options.is_empty():errors.append('Missing audio source '+action['class']);return
 var index=0
 if options.size()>1:
  var weights=p.get('m_Weights',[]);var total=0.0
  for w in weights:total+=float(w)
  var choice=rng.randf()*total
  for i in range(weights.size()):
   choice-=float(weights[i]);index=i
   if choice<=0:break
 var selected=options[index];var clip=selected.clips[0]
 var volume=float(p.get('m_Volume',p.get('m_MinVolume',p.get('m_VolumeScale',1.0))));var pitch=float(p.get('m_Pitch',p.get('m_MinPitch',1.0)))
 if p.has('m_MaxVolume'):volume=rng.randf_range(volume,float(p.m_MaxVolume))
 if p.has('m_MaxPitch'):pitch=rng.randf_range(pitch,float(p.m_MaxPitch))
 var cfg=systems[kind].source.runtime_audio_source_template.audio_source
 var parent_id=_go_id(p.get('m_ParentObject',p.get('m_GameObject',{})))
 var spatial=float(p.get('m_SpatialBlend',1.0));var source_mode='runtime template'
 if action['class']=='AudioPlaythroughAction':
  for obj in systems[kind].source.objects.values():
   if obj.type=='AudioSource' and obj.refs['.m_GameObject']==parent_id:cfg=obj.data
  spatial=float(cfg.panLevelCustomCurve.m_Curve[0].value);pitch=float(cfg.m_Pitch);source_mode='source AudioSource cloned; OneShotSound takes precedence over legacy OneShotClip'
 var anchor=probe.source_nodes[parent_id]
 events.append({'event':'audio_start','kind':kind,'state':systems[kind].state,'guid':clip.guid,'file':clip.file,'volume':volume,'pitch':pitch,'spatial_blend':spatial,'min_distance':cfg.MinDistance,'max_distance':cfg.MaxDistance,'reverb_mix':cfg.reverbZoneMixCustomCurve.m_Curve[0].value,'source_mode':source_mode,'time':elapsed,'enabled':audio_enabled})
 if not audio_enabled:return
 var stream=AudioStreamWAV.load_from_file(BASE+clip.file)
 if stream==null:errors.append('Audio load failed '+clip.file);return
 # SoundManager.InitSourceTransform parents a new source to its stable scene object,
 # then copies the source anchor world position once. It does not follow the anchor.
 var player=AudioStreamPlayer3D.new();player.bus=&"SFX";probe.source_root.add_child(player);player.global_position=anchor.global_position;player.stream=stream;player.pitch_scale=pitch;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance=0;player.panning_strength=spatial;player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
 var row={'player':player,'volume':volume,'spatial':spatial,'config':cfg}
 audio_players.append(row);_update_audio_gain(row);player.finished.connect(player.queue_free);player.play()
func _update_audio_gain(row:Dictionary):
 var listener=probe.door_interaction.listener
 var distance=row.player.global_position.distance_to(listener.global_position);var cfg=row.config
 var gain=1.0-clampf((distance-float(cfg.MinDistance))/(float(cfg.MaxDistance)-float(cfg.MinDistance)),0,1)
 row.player.volume_db=linear_to_db(maxf(row.volume*lerpf(1.0,gain,row.spatial),0.00001))
func get_audit():
 var states={};var animations={}
 for kind in systems:
  var s=systems[kind];states[kind]={'state':s.state,'state_time':s.time,'gates':s.gates.duplicate(true),'pending':s.pending.duplicate(true),'tween':s.tween.duplicate(true)}
 for name in clips:
  var c=clips[name];animations[name]={'root':c.root,'time':c.time,'enabled':c.enabled,'weight':c.weight,'target_weight':c.fade_to,'duration':c.source.duration_seconds,'wrap_mode':c.source.wrap_mode}
 return {'systems':states,'animations':animations,'skin':skin.get_audit() if is_instance_valid(skin) else {},'events':events.duplicate(true),'errors':errors.duplicate(),'closed':closed,'ignored_nontransform_tracks':ignored_tracks,'compatibility':['Original 2223-vertex skin, 13 bones, weights/bind matrices and 5 original animation clips; no synthetic sway.','Original per-action gates, same-press checkFirstFrame managed desktop call chain, action Finish and renderer-only visibility preserved.','Shared original Animation roots support StopAll interruptions across the two FSMs. Full-client inter-FSM Update ordering remains unobserved; stable kite-then-pole order is explicit.','Unweighted Hermite curves with quaternion normalization. Multi-clip weight fades and normalized quaternion averaging are a declared compatibility approximation to native Unity Legacy crossfade/Blend, not native playback parity.','Source nonloop clip endpoints are sampled then disabled; native pose reset behavior after disabling has not been sampled.','Original WAVs, action volume/pitch/weights, one-time anchor world-position copy, listener/min/max, and FlyAway AudioSource panLevel .2 are preserved. Godot panning, partial spatial stereo, mixer/ducking/reverb and audio backend are not Unity-native parity.','No invented particle effects are attached to kite actions; source particle systems are separately audited by the board particle controller.','Selected source collider ray tests are supported, not full-client nearest physics hit/occlusion parity.']}
func close_interaction():
 if closed:return
 closed=true
 for row in audio_players:
  if is_instance_valid(row.player):row.player.stop();row.player.queue_free()
 audio_players.clear()
 if is_instance_valid(skin):skin.close_interaction();skin.queue_free()
 clips.clear();systems.clear();rest.clear()
