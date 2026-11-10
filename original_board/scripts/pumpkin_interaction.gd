extends Node
const SourceStore=preload('res://original_board/scripts/board_source_store.gd')
## Enabled original farm FSMs; also used by the flower controller below.
## Source actions are interpreted in order. Unsupported effects remain explicit audit entries.
const BASE='res://original_board/assets/farm/'
const CAB='cab-995e7cbc44ff3e7f4314fc93360989d0:'
const REFLECTION=Basis(Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,-1))
var probe
var source_cab=CAB
var systems:Dictionary={}
var events:Array=[]
var audio_players:Array=[]
var tweens:Array=[]
var local_rotations:Dictionary={}
var renderer_eligible:Dictionary={}
var audio_enabled=true
var closed=false
var elapsed=0.0
var press_active=false
var entry_depth=0
var next_tween_id=0
var rng=RandomNumberGenerator.new()
func source_kinds()->Array:return ['pumpkin1','pumpkin2','pumpkin3']
func setup(p,options:Dictionary={}):
 probe=p;rng.randomize()
 source_cab=str(options.get('source_cab',CAB))
 var source_base=str(options.get('source_base',BASE))
 for id in probe.source_nodes:
  var n=probe.source_nodes[id]
  local_rotations[id]=n.quaternion
 for id in probe.renderer_nodes:renderer_eligible[id]=probe.renderer_nodes[id].visible
 for kind in source_kinds():
  var source=SourceStore.json_for(probe,source_base+kind+'.json')
  var sys={'source':source,'states':{},'state':'','time':0.0,'generation':0,'variables':{},'gates':{},'collider':{},'waits':[],'updates':[],'pending':{},'visibility':{},'mesh_changes':{}}
  for st in source.states:sys.states[st.name]=st
  for obj in source.objects.values():
   if obj.type in ['SphereCollider','BoxCollider']:sys.collider=obj
  for category in ['boolVariables','vector3Variables','floatVariables','intVariables']:
   for v in source.fsm.variables.get(category,[]):sys.variables[v.name]=v.value
  systems[kind]=sys
  _enter(kind,source.fsm.start_state)
func _value(sys,v):
 if v is Dictionary and v.has('variable'):return sys.variables.get(v.variable,v.initial)
 return v
func _is_none(v)->bool:return v is Dictionary and v.has('variable') and str(v.variable).is_empty()
func _set_value(sys,v,value):
 if v is Dictionary and not str(v.get('variable','')).is_empty():sys.variables[v.variable]=value
func _go_id(sys,p)->String:
 if p.has('ownerOption') and int(p.ownerOption)==0:return sys.source.fsm.game_object
 if p.has('gameObject'):p=p.gameObject
 return source_cab+str(p.m_PathID)
func _node(sys,p):return probe.source_nodes.get(_go_id(sys,p))
func _collider_node(kind):return probe.source_nodes.get(systems[kind].collider.refs['.m_GameObject'])
func target_screen(kind='pumpkin1')->Vector2:
 var sys=systems[kind];var node=_collider_node(kind)
 return probe.camera.unproject_position(node.global_transform*probe.source_vector(sys.collider.data.m_Center))
func hit_test(kind:String,screen:Vector2)->bool:
 if closed or not systems.has(kind):return false
 var sys=systems[kind];var c=sys.collider;var node=_collider_node(kind)
 # SetVisibility toggles Renderer.enabled only, never Collider or GameObject active.
 if not is_instance_valid(node) or not node.is_visible_in_tree() or not c.data.m_Enabled:return false
 var origin=probe.camera.project_ray_origin(screen);var direction=probe.camera.project_ray_normal(screen).normalized()
 var center=probe.source_vector(c.data.m_Center)
 if c.type=='SphereCollider':
  var scale=node.global_basis.get_scale().abs();var radius=float(c.data.m_Radius)*maxf(scale.x,maxf(scale.y,scale.z))
  if radius<=0.0:return false
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
 var sys=systems[kind];press_active=true
 for i in range(sys.states[sys.state].actions.size()):
  var a=sys.states[sys.state].actions[i]
  if a.enabled and a['class']=='MousePickRandomAction':_mouse(kind,a,i);break
 press_active=false
 return true
func receive_source_event(fsm_id,event)->bool:
 if closed:return false
 for kind in systems:
  var sys=systems[kind]
  if str(fsm_id) in [str(sys.source.fsm.key),str(sys.source.fsm.game_object),str(sys.source.fsm.key).get_slice(':',1),str(sys.source.fsm.game_object).get_slice(':',1)]:
   events.append({'event':'source_event_received','kind':kind,'target':fsm_id,'source_event':event,'time':elapsed})
   return _event(kind,event)
 events.append({'event':'unresolved_source_event','target':fsm_id,'source_event':event,'time':elapsed});return false
func _mouse(kind,a,index)->bool:
 var sys=systems[kind];var p=a.params;var key=sys.state+':'+str(index);var g=sys.gates[key]
 g.count+=1
 var opened=g.count>=g.threshold;var evt=p.mouseDownGateOpen if opened else p.mouseDownGateClosed
 if opened:
  g.opened=true
  if p.ResetOnOpen:g.count=0
 events.append({'event':'click','kind':kind,'state':sys.state,'gate':key,'threshold':g.threshold,'count':g.count,'gate_open':opened,'emitted':evt,'time':elapsed})
 return _event(kind,evt)
func _event(kind,event)->bool:
 if str(event).is_empty():return false
 var sys=systems[kind]
 for trans in sys.source.fsm.global_transitions:
  if trans.fsmEvent.name==event:_enter(kind,trans.toState);return true
 var trans=sys.states[sys.state].transitions
 if trans.has(event):_enter(kind,trans[event]);return true
 return false
func _enter(kind,state):
 if entry_depth>=32:events.append({'event':'reentry_guard','kind':kind,'state':state});return
 entry_depth+=1
 _enter_actions(kind,state)
 entry_depth-=1
func _enter_actions(kind,state):
 var sys=systems[kind]
 for t in tweens.duplicate():
  if t.kind==kind and t.generation==sys.generation:
   if t.stop_on_exit:tweens.erase(t);events.append({'event':'tween_stopped','kind':kind,'reason':'source stopOnExit','time':elapsed})
   else:t.callbacks=false
 sys.state=state;sys.time=0.0;sys.generation+=1;sys.waits=[];sys.updates=[];sys.pending={}
 var generation=sys.generation
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
    if p.everyFrame:sys.pending[str(i)]=true
    if press_active and p.checkFirstFrame and _mouse(kind,a,i):return
   'GetPosition':
    var n=_node(sys,p.gameObject);var pos=n.global_position if int(p.space)==0 else n.position
    var v={'x':pos.x,'y':pos.y,'z':-pos.z};_set_value(sys,p.vector,v)
    for axis in ['x','y','z']:_set_value(sys,p[axis],v[axis])
   'Translate':
    if p.everyFrame:sys.updates.append(a);sys.pending[str(i)]=true
    else:_translate(sys,p,0.0)
   'SetPosition':
    var n=_node(sys,p.gameObject);var pos=n.global_position if int(p.space)==0 else n.position
    var v=Vector3(pos.x,pos.y,-pos.z)
    if not _is_none(p.vector):v=probe.v3(_value(sys,p.vector))
    for j in range(3):
     var axis=['x','y','z'][j]
     if not _is_none(p[axis]):v[j]=float(_value(sys,p[axis]))
    if int(p.space)==0:n.global_position=Vector3(v.x,v.y,-v.z)
    else:n.position=Vector3(v.x,v.y,-v.z)
   'SetScale':
    var n=_node(sys,p.gameObject);var scale=n.scale
    if not _is_none(p.vector):scale=probe.v3(_value(sys,p.vector))
    for j in range(3):
     var axis=['x','y','z'][j]
     if not _is_none(p[axis]):scale[j]=float(_value(sys,p[axis]))
    _set_scale(_go_id(sys,p.gameObject),scale)
   'SetVisibility':_set_visibility(kind,p)
   'SetBoolValue':_set_value(sys,p.boolVariable,bool(_value(sys,p.boolValue)))
   'BoolTest':
    if _event(kind,p.isTrue if bool(_value(sys,p.boolVariable)) else p.isFalse):return
   'Wait','RandomWaitAction':
    var random=a['class']=='RandomWaitAction'
    var seconds=rng.randf_range(float(p.m_MinTime),float(p.m_MaxTime)) if random else float(_value(sys,p.time))
    sys.waits.append({'seconds':seconds,'event':p.m_FinishEvent if random else p.finishEvent,'strict':random,'action':str(i)});sys.pending[str(i)]=true
   'SendRandomEvent':
    var index=_weighted_index(p.weights)
    events.append({'event':'weighted_event','kind':kind,'index':index,'weights':p.weights,'selected':p.events[index],'time':elapsed})
    if _event(kind,p.events[index]):return
   'iTweenScaleTo','iTweenShakeRotation':sys.pending[str(i)]=true;_start_tween(kind,a,i)
   'SetProperty':_set_mesh(kind,p.targetProperty)
   'ParticlePlayAction':_particle(kind,p)
   'AudioPlayRandomClipAction','AudioPlayClipAction':_sound(kind,a)
   _:events.append({'event':'unsupported_action','kind':kind,'class':a['class']})
  if generation!=sys.generation:return
 if sys.pending.is_empty():_event(kind,'FINISHED')
func _set_scale(id:String,value:Vector3):
 var n=probe.source_nodes[id];var rotation=local_rotations[id]
 if n.scale.length_squared()>0.00000001:rotation=n.quaternion;local_rotations[id]=rotation
 var b=Basis(rotation);n.basis=Basis(b.x*value.x,b.y*value.y,b.z*value.z)
func _translate(sys,p,dt):
 var n=_node(sys,p.gameObject);var vector=Vector3.ZERO
 if not _is_none(p.vector):vector=probe.v3(_value(sys,p.vector))
 for j in range(3):
  var axis=['x','y','z'][j]
  if not _is_none(p[axis]):vector[j]=float(_value(sys,p[axis]))
 vector=Vector3(vector.x,vector.y,-vector.z)*(dt if p.perSecond else 1.0)
 if int(p.space)==0:n.global_position+=vector
 else:n.position+=Basis(local_rotations[_go_id(sys,p.gameObject)])*vector
func _set_visibility(kind,p):
 var sys=systems[kind];var id=_go_id(sys,p.gameObject);var count=0
 var row=sys.source.scene_nodes.get(id,{})
 for r in row.get('renderers',[]):
  var renderer=probe.renderer_nodes.get(r.id)
  if not is_instance_valid(renderer):continue
  var visible=not sys.visibility.get(id,true) if p.toggle else bool(p.visible)
  sys.visibility[id]=visible;renderer.visible=visible and renderer_eligible.get(r.id,false);count+=1
 events.append({'event':'renderer_visibility','kind':kind,'node_id':id,'visible':bool(p.visible),'renderers':count,'collider_unchanged':true,'time':elapsed})
func _weighted_index(weights)->int:
 var total=0.0
 for w in weights:total+=float(w)
 var v=rng.randf()*total
 for i in range(weights.size()):
  v-=float(weights[i])
  if v<=0:return i
 return weights.size()-1
func _start_tween(kind,a,index):
 var sys=systems[kind];var p=a.params;var id=_go_id(sys,p.gameObject);var node=probe.source_nodes[id]
 var mode='scale' if a['class']=='iTweenScaleTo' else 'shake_rotation'
 # The only competing pair here is growth scale -> pick scale, different arguments.
 for prior in tweens.duplicate():
  if prior.node_id==id and prior.mode==mode:tweens.erase(prior);events.append({'event':'tween_replaced','kind':kind,'node_id':id,'time':elapsed})
 var t={'id':next_tween_id,'kind':kind,'generation':sys.generation,'action':str(index),'node_id':id,'mode':mode,'time':0.0,'duration':float(p.time),'delay':float(p.delay),'stop_on_exit':bool(p.stopOnExit),'finish_event':p.finishEvent,'callbacks':true,'loop_type':int(p.loopType),'loop_dont_finish':bool(p.loopDontFinish)}
 next_tween_id+=1
 if mode=='scale':t.from=node.scale;t.to=probe.v3(p.vectorScale);t.ease=int(p.easeType)
 else:t.amount=probe.v3(p.vector);t.base_global=node.global_basis.orthonormalized();t.space=int(p.space)
 tweens.append(t)
 events.append({'event':'tween_start','kind':kind,'state':sys.state,'node_id':id,'mode':mode,'duration':t.duration,'ease':t.get('ease',-1),'source_owner':int(p.gameObject.ownerOption)==0,'time':elapsed})
func _sample_tween(t,percentage):
 var node=probe.source_nodes[t.node_id]
 if t.mode=='scale':
  var weight=percentage if t.ease==21 else 1.0-pow(2.0,-10.0*percentage)
  _set_scale(t.node_id,t.to if percentage>=1.0 else t.from.lerp(t.to,weight))
 else:
  var amount=t.amount*(1.0-percentage)
  var degrees=Vector3(rng.randf_range(-amount.x,amount.x),rng.randf_range(-amount.y,amount.y),rng.randf_range(-amount.z,amount.z))
  # Unity Transform.Rotate(Vector3) is Z, then X, then Y. Reflect the proper rotation.
  var q=Basis(Vector3.UP,deg_to_rad(degrees.y))*Basis(Vector3.RIGHT,deg_to_rad(degrees.x))*Basis(Vector3.BACK,deg_to_rad(degrees.z))
  var delta=REFLECTION*q*REFLECTION
  var world=t.base_global*delta if t.space==1 else delta*t.base_global
  var scale=node.global_basis.get_scale();node.global_basis=Basis(world.x*scale.x,world.y*scale.y,world.z*scale.z)
  local_rotations[t.node_id]=node.quaternion
func advance(dt:float):
 if closed:return
 elapsed+=dt
 for kind in systems:
  var sys=systems[kind];var generation=sys.generation;sys.time+=dt
  for action in sys.updates:_translate(sys,action.params,dt)
  for wait in sys.waits:
   if (sys.time>wait.seconds if wait.strict else sys.time>=wait.seconds):
    sys.pending.erase(wait.action)
    if not _event(kind,wait.event) and sys.pending.is_empty():_event(kind,'FINISHED')
    break
  if generation!=sys.generation:continue
 for t in tweens.duplicate():
  if not tweens.has(t):continue
  # Source TweenUpdate applies previous percentage then updates its clock.
  var local_time=maxf(t.time-t.delay,0.0)
  if t.time>=t.delay:_sample_tween(t,clampf(local_time/t.duration,0,1))
  if local_time>=t.duration:
   tweens.erase(t);events.append({'event':'tween_finished','kind':t.kind,'mode':t.mode,'node_id':t.node_id,'time':elapsed})
   var sys=systems[t.kind]
   if t.callbacks and sys.generation==t.generation:
    sys.pending.erase(t.action)
    if not _event(t.kind,t.finish_event) and sys.pending.is_empty():_event(t.kind,'FINISHED')
  else:t.time+=dt
 for player in audio_players.duplicate():
  if not is_instance_valid(player):audio_players.erase(player)
  else:
   var distance=player.global_position.distance_to(probe.door_interaction.listener.global_position)
   var gain=1.0-clampf((distance-float(player.get_meta('source_min_distance')))/(float(player.get_meta('source_max_distance'))-float(player.get_meta('source_min_distance'))),0,1)
   player.volume_db=linear_to_db(maxf(float(player.get_meta('source_volume'))*gain,0.00001))
func _set_mesh(kind,property):
 var sys=systems[kind];var target_id=CAB+str(property.TargetObject.m_PathID);var target=sys.source.objects.get(target_id,{})
 var mesh_id=''
 for id in sys.source.objects:
  if sys.source.objects[id].type=='Mesh' and id.get_slice(':',1)==str(property.ObjectParameter.m_PathID):mesh_id=id;break
 if target.is_empty() or mesh_id.is_empty():events.append({'event':'missing_mesh_property','kind':kind,'target':target_id});return
 var mesh=probe.meshes.get(mesh_id)
 if mesh==null:
  var obj=sys.source.objects[mesh_id];probe.data.meshes[mesh_id]={'file':BASE+obj.files.mesh,'name':obj.name};mesh=probe._build_mesh(mesh_id);probe.meshes[mesh_id]=mesh
 var go_id=target.refs['.m_GameObject'];var count=0
 # Preserve the source Pumpkin1 Vegi5 cross-reference to Pumpkin2, rather than correcting it.
 var row=sys.source.scene_nodes.get(go_id,{})
 if row.is_empty() or row.get('renderers',[]).is_empty():
  for scene_row in probe.data.nodes:
   if scene_row.id==go_id:row=scene_row;break
 for r in row.get('renderers',[]):
  var renderer=probe.renderer_nodes.get(r.id)
  if is_instance_valid(renderer):renderer.mesh=mesh;renderer.set_meta('source_mesh',mesh_id);count+=1
 sys.mesh_changes[go_id]=mesh_id
 events.append({'event':'mesh_property','kind':kind,'component_id':target_id,'node_id':go_id,'mesh_id':mesh_id,'renderers':count,'time':elapsed})
func _particle(kind,p):
 var sys=systems[kind];var id=_go_id(sys,p.m_GameObject);var delegate=probe.get('water_particles')
 if not is_instance_valid(delegate):delegate=probe.get('source_particles')
 var delegated=is_instance_valid(delegate) and delegate.has_method('set_playing') and delegate.has_method('supports_source') and delegate.supports_source(id)
 if delegated:delegate.set_playing(id,true)
 events.append({'event':'particle_command','kind':kind,'node_id':id,'playing':true,'include_children':p.m_IncludeChildren,'delegated':delegated,'status':'source delegate' if delegated else 'missing original particle adapter; no substitute','time':elapsed})
func _sound(kind,a):
 var sys=systems[kind];var p=a.params;var options=a.audio_sources
 var index=_weighted_index(p.m_Weights) if options.size()>1 else 0;var selected=options[index];var clip=selected.clips[0]
 var volume=float(p.get('m_Volume',p.get('m_MinVolume',1.0)));var pitch=float(p.get('m_Pitch',p.get('m_MinPitch',1.0)))
 if p.has('m_MaxVolume'):volume=rng.randf_range(volume,float(p.m_MaxVolume))
 if p.has('m_MaxPitch'):pitch=rng.randf_range(pitch,float(p.m_MaxPitch))
 var anchor=_node(sys,p.m_ParentObject);var listener=probe.door_interaction.listener;var cfg=sys.source.runtime_audio_source_template.audio_source
 var distance=anchor.global_position.distance_to(listener.global_position);var gain=1.0-clampf((distance-float(cfg.MinDistance))/(float(cfg.MaxDistance)-float(cfg.MinDistance)),0,1)
 events.append({'event':'audio_start','kind':kind,'state':sys.state,'guid':clip.guid,'file':clip.file,'volume':volume,'pitch':pitch,'gain':gain,'time':elapsed,'enabled':audio_enabled})
 if not audio_enabled:return
 var stream=AudioStreamWAV.load_from_file(BASE+clip.file)
 if stream==null:events.append({'event':'audio_error','file':clip.file});return
 var player=AudioStreamPlayer3D.new();player.bus=&"SFX";probe.source_root.add_child(player);player.global_position=anchor.global_position;player.set_meta('source_volume',volume);player.set_meta('source_min_distance',float(cfg.MinDistance));player.set_meta('source_max_distance',float(cfg.MaxDistance));player.stream=stream;player.pitch_scale=pitch;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance=0;player.volume_db=linear_to_db(maxf(volume*gain,0.00001));player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
 audio_players.append(player);player.finished.connect(player.queue_free);player.play()
func get_audit():
 var summary={}
 for kind in systems:
  var s=systems[kind];summary[kind]={'state':s.state,'state_time':s.time,'variables':s.variables.duplicate(true),'gates':s.gates.duplicate(true),'pending':s.pending.duplicate(true),'visibility':s.visibility.duplicate(true),'mesh_changes':s.mesh_changes.duplicate(true)}
 return {'systems':summary,'events':events.duplicate(true),'tweens':tweens.duplicate(true),'closed':closed,'compatibility':['Original action order, variable values, transform/mesh targets, collider sizes, gates, enabled actions, weighted choices and audio clips preserved.','Source SetVisibility changes only Renderer.enabled, not collider or child particle visibility.','Pumpkin1 stays State7 after 3-second growth because its finishEvent is empty; Pumpkin2/3 explicitly emit FINISHED and return State1. A click while State7 reenters State1 then State2 on the same desktop press, skipping GetPosition.','Flower shake and scale target the original empty FSM owner, not the visible flower mesh. No runtime reparenting has been proven; visible flower transforms are not invented.','iTween scale linear/easeOutExpo formula and final exact endpoint preserved; shake restores original world rotation then samples decaying XYZ ranges with Unity ZXY rotation order. Godot RNG sequence and Unity native frame scheduling are not bit-identical.','Original Pumpkin1 Vegi5 changes Pumpkin2 mesh, matching the source cross-reference.','Source particle actions delegate only when supports_source confirms a full source adapter; omitted effects remain explicit, never generic debris.','Original sound gain/pitch ranges and shared listener; source audio captures the anchor world position then stays under the stable scene root; native reverb, mixer ducking and pan remain compatibility limits.','Ray tests use source colliders but do not reproduce complete Unity physics occlusion/nearest-hit ordering.']}
func close_interaction():
 if closed:return
 closed=true;press_active=false;tweens.clear()
 for p in audio_players:
  if is_instance_valid(p):p.stop();p.queue_free()
 audio_players.clear();systems.clear()
