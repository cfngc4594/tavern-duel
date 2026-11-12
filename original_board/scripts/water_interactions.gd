extends Node
## Source FSM subset; original scalar curves and action order, explicit delegated effects.
const BASE='res://original_board/assets/water/'
var probe
var source_cab='cab-995e7cbc44ff3e7f4314fc93360989d0:'
var systems={}
var events=[]
var audio_players=[]
var audio_enabled=true
var closed=false
var elapsed=0.0
var rng=RandomNumberGenerator.new()
var press_active=false
var animated_materials={}
var material_bindings={}
func setup(p,options:Dictionary={}):
 probe=p;rng.randomize()
 source_cab=str(options.get('source_cab',source_cab))
 var source_base=str(options.get('source_base',BASE))
 for kind in options.get('kinds',['mill_wheel','silo']):
  var source=JSON.parse_string(FileAccess.get_file_as_string(source_base+kind+'.json'))
  var sys={'source':source,'states':{},'state':'','time':0.0,'variables':{},'gates':{},'collider':{},'waits':[],'animation':{},'rotation_speed':-10.0,'rotation_node':'','curves':[],'ease':[],'material_values':{}}
  for st in source.states:sys.states[st.name]=st
  for obj in source.objects.values():
   if obj.type in ['SphereCollider','BoxCollider']:sys.collider=obj
   if obj.get('class_name','')=='RotateOverTime':sys.rotation_node=obj.refs['.m_GameObject'];sys.rotation_speed=float(obj.data.RotateSpeedY)
  systems[kind]=sys
  _enter(kind,source.fsm.start_state)
func _value(sys,v):
 if v is Dictionary and v.has('variable'):
  if v.variable=='':return v.initial
  if not sys.variables.has(v.variable):sys.variables[v.variable]=v.initial
  return sys.variables[v.variable]
 return v
func _set_value(sys,v,value):
 if v is Dictionary and not str(v.get('variable','')).is_empty():sys.variables[v.variable]=value
func _go_id(p)->String:
 if p.has('gameObject'):p=p.gameObject
 return source_cab+str(p.m_PathID)
func _collider_node(kind):
 var c=systems[kind].collider
 return probe.source_nodes.get(c.refs['.m_GameObject'])
func target_screen(kind='mill_wheel')->Vector2:
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
 press_active=true
 var sys=systems[kind]
 for action in sys.states[sys.state].actions:
  if action.enabled and action['class']=='MousePickRandomAction':
   _mouse(kind,action);break
 press_active=false
 return true
func _mouse(kind,action)->bool:
 var p=action.params
 # Both source interactions have zero-threshold gates. No invented click pacing.
 var event=p.mouseDownGateOpen
 events.append({'event':'click','kind':kind,'state':systems[kind].state,'emitted':event,'time':elapsed})
 return _event(kind,event)
func _event(kind,event)->bool:
 var sys=systems[kind];var trans=sys.states[sys.state].transitions
 if trans.has(event):_enter(kind,trans[event]);return true
 return false
func _enter(kind,state):
 var sys=systems[kind];sys.state=state;sys.time=0.0;sys.waits=[];sys.curves=[];sys.ease=[]
 events.append({'event':'state_enter','kind':kind,'state':state,'time':elapsed})
 var unfinished=false
 for a in sys.states[state].actions:
  if not a.enabled:continue
  var p=a.params
  match a['class']:
   'MousePickRandomAction':
    unfinished=true
    if press_active and p.checkFirstFrame and _mouse(kind,a):return # ActivateActions short-circuits pending state changes.
   'Wait':sys.waits.append({'seconds':float(_value(sys,p.time)),'event':p.finishEvent});unfinished=true
   'RandomWaitAction':sys.waits.append({'seconds':rng.randf_range(float(p.m_MinTime),float(p.m_MaxTime)),'event':p.m_FinishEvent,'strict':true});unfinished=true
   'AnimateFloat':
    sys.curves.append(p);_set_value(sys,p.floatVariable,_scalar(p.animCurve.curve.m_Curve,0));unfinished=true
   'EaseFloat':
    sys.ease.append({'params':p,'from':float(_value(sys,p.fromValue))});_set_value(sys,p.floatVariable,_value(sys,p.fromValue));unfinished=true
   'SetProperty':
    _property(kind,p)
    if p.everyFrame:unfinished=true
   'ParticlePlayAction','ParticleStopAction':_particle(kind,p,a['class']=='ParticlePlayAction')
   'AnimationPlaythroughAction':_play(kind,p.m_AnimName)
   'AudioPlayRandomClipAction','AudioPlayClipAction':_sound(kind,a)
   'SendEvent':_send_event(kind,p)
   _:events.append({'event':'unsupported_action','kind':kind,'class':a['class']});unfinished=true
 if not unfinished:_event(kind,'FINISHED')
func _property(kind,p):
 var sys=systems[kind];var property=p.targetProperty
 if property.TargetTypeName=='RotateOverTime' and property.PropertyName=='RotateSpeedY':sys.rotation_speed=float(_value(sys,property.FloatParameter))
 else:events.append({'event':'unsupported_property','kind':kind,'property':property.PropertyName})
func _particle(kind,p,playing):
 var id=_go_id(p.m_GameObject);var delegate=probe.get('water_particles');var delegated=is_instance_valid(delegate) and delegate.has_method('set_playing')
 if delegated:delegate.set_playing(id,playing)
 events.append({'event':'particle_command','kind':kind,'node_id':id,'playing':playing,'include_children':p.m_IncludeChildren,'delegated':delegated,'time':elapsed})
func _send_event(kind,p):
 var id=_go_id(p.eventTarget.gameObject);var delegate=probe.get('pumpkin_interaction');var available=is_instance_valid(delegate) and delegate.has_method('receive_source_event');var delegated=false
 if available:delegated=delegate.receive_source_event(id,p.sendEvent)==true
 events.append({'event':'source_send_event','kind':kind,'target_node':id,'source_event':p.sendEvent,'delegate_available':available,'delegated':delegated,'time':elapsed})
func _play(kind,name):
 systems[kind].animation={'name':name,'time':0.0}
 events.append({'event':'animation_play','kind':kind,'clip':name,'time':elapsed})
 _sample(kind)
static func _scalar(keys,t)->float:
 if t<=float(keys[0].time):return float(keys[0].value)
 if t>=float(keys[-1].time):return float(keys[-1].value)
 for i in range(keys.size()-1):
  var a=keys[i];var b=keys[i+1]
  if t>float(b.time):continue
  var duration=float(b.time)-float(a.time);var u=(t-float(a.time))/duration
  var m0=float(a.outSlope);var m1=float(b.inSlope)
  if not is_finite(m0) or not is_finite(m1):return float(a.value)
  return (2*u*u*u-3*u*u+1)*float(a.value)+(u*u*u-2*u*u+u)*duration*m0+(-2*u*u*u+3*u*u)*float(b.value)+(u*u*u-u*u)*duration*m1
 return float(keys[-1].value)
func _sample(kind):
 var sys=systems[kind]
 if sys.animation.is_empty():return
 var clip=sys.source.animations[sys.animation.name]
 for track in clip.tracks:
  if track.type!='m_FloatCurves':continue
  var attr=track.source_curve.attribute;var value=_scalar(track.source_curve.curve.m_Curve,minf(sys.animation.time,float(clip.duration_seconds)))
  sys.material_values[attr]=value
  _material_float(track.target_node_id,attr,value)
func _material_float(id,attribute,value):
 if not animated_materials.has(id):
  var node=probe.source_nodes.get(id)
  if is_instance_valid(node):
   for child in node.get_children():
    if child is MeshInstance3D:
     var mat=child.get_active_material(0)
     if mat is ShaderMaterial:
      var unique=mat.duplicate();material_bindings[id]={'node':child,'original':mat};child.set_surface_override_material(0,unique);animated_materials[id]=unique
      if probe.has_method('register_source_lighting_material'):probe.register_source_lighting_material(unique)
      break
 if animated_materials.has(id):animated_materials[id].set_shader_parameter(attribute,value)
func advance(dt):
 if closed:return
 elapsed+=dt
 for mat in animated_materials.values():mat.set_shader_parameter('_SourceTime',elapsed)
 for kind in systems:
  var sys=systems[kind];sys.time+=dt
  # Original FSM action order determines final property value each update.
  for a in sys.states[sys.state].actions:
   if not a.enabled:continue
   var p=a.params
   if a['class']=='AnimateFloat':_set_value(sys,p.floatVariable,_scalar(p.animCurve.curve.m_Curve,sys.time))
   elif a['class']=='EaseFloat':
    # Destination is overwritten by the subsequent source WheelSpeed SetProperty.
    var from_value=sys.ease[0]['from'];var u=clampf(sys.time/float(p.time),0,1)
    _set_value(sys,p.floatVariable,lerpf(from_value,float(p.toValue),u))
   elif a['class']=='SetProperty' and p.everyFrame:_property(kind,p)
  if not sys.rotation_node.is_empty():
   var node=probe.source_nodes.get(sys.rotation_node)
   if is_instance_valid(node):node.rotate_object_local(Vector3.UP,deg_to_rad(-sys.rotation_speed*dt))
  if not sys.animation.is_empty():sys.animation.time+=dt;_sample(kind)
  for wait in sys.waits:
   var ready=sys.time>wait.seconds if wait.get('strict',false) else sys.time>=wait.seconds
   if ready:_event(kind,wait.event);break
 for player in audio_players.duplicate():
  if not is_instance_valid(player):audio_players.erase(player)
func get_audit():
 var summary={}
 for kind in systems:
  var s=systems[kind];summary[kind]={'state':s.state,'time':s.time,'variables':s.variables.duplicate(),'rotation_speed':s.rotation_speed,'animation':s.animation.duplicate(),'material_values':s.material_values.duplicate(),'waits':s.waits.duplicate(true)}
 return {'systems':summary,'events':events.duplicate(true),'closed':closed,'compatibility':['Scalar source Hermite sampling; native Unity renderer not pixel-validated.','Particle and material animation calls require source_particles delegate; no synthetic particle fallback.','Pumpkin Action events are explicit delegated boundaries if no controller is present.','Source EaseFloat type21 is linear; newSpeed is overwritten at renderer by later WheelSpeed SetProperty.','RotateOverTime update ordering versus PlayMaker native frame not yet golden-sampled.','Original sound clips; native mixer, reverb, ducking and pan not reproduced.']}
func close_interaction():
 closed=true
 for player in audio_players:
  if is_instance_valid(player):player.stop();player.queue_free()
 for binding in material_bindings.values():
  if is_instance_valid(binding.node):binding.node.set_surface_override_material(0,binding.original)
 audio_players.clear();systems.clear();animated_materials.clear();material_bindings.clear()
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
 var anchor=probe.source_nodes.get(_go_id(p.m_ParentObject));var listener=probe.door_interaction.listener
 var anchor_position=anchor.global_position if is_instance_valid(anchor) else Vector3.ZERO
 var cfg=systems[kind].source.runtime_audio_source_template.audio_source
 var distance=anchor_position.distance_to(listener.global_position)
 var gain=1.0-clampf((distance-float(cfg.MinDistance))/(float(cfg.MaxDistance)-float(cfg.MinDistance)),0,1)
 events.append({'event':'audio_start','kind':kind,'state':systems[kind].state,'guid':clip.guid,'file':clip.file,'volume':volume,'pitch':pitch,'gain':gain,'time':elapsed,'enabled':audio_enabled,'anchor_world':{'x':anchor_position.x,'y':anchor_position.y,'z':anchor_position.z},'parent_is_null':not is_instance_valid(anchor)})
 if not audio_enabled:return
 var stream=AudioStreamWAV.load_from_file(BASE+clip.file)
 if stream==null:events.append({'event':'audio_error','file':clip.file});return
 var player=AudioStreamPlayer3D.new();player.bus=&"SFX";probe.source_root.add_child(player);player.global_position=anchor_position;player.stream=stream;player.pitch_scale=pitch;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance=0;player.volume_db=linear_to_db(maxf(volume*gain,0.00001));player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
 audio_players.append(player);player.finished.connect(player.queue_free);player.play()
