extends SceneTree
# CPU-only controller fixture. It does not claim rendering or Android touch parity.
class Probe:
 extends Node3D
 const REFLECTION=Basis(Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,-1))
 var source_nodes={}
 var renderer_nodes={}
 var source_root:Node3D
 var camera_root:Node3D
 var camera:Camera3D
 var door_interaction
 var arch_interactions
 var water_particles
 var bush_interactions
 var water_interactions
 var meshes={}
 var data={}
 var config={'lighting':{'ambient_target_raw_rgba':{'r':0.8529411554336548,'g':0.8341262936592102,'b':0.8341262936592102,'a':1.0}}}
 static func v3(d):return Vector3(d.x,d.y,d.z)
 static func source_vector(d):return REFLECTION*v3(d)
 static func source_transform(p,q,s):
  var rotation=REFLECTION*Basis(Quaternion(q.x,q.y,q.z,q.w).normalized())*REFLECTION
  return Transform3D(Basis(rotation.x*s.x,rotation.y*s.y,rotation.z*s.z),source_vector(p))
 static func raw_transform(t):return source_transform(t.m_LocalPosition,t.m_LocalRotation,t.m_LocalScale)

var failures=[]
var results=[]
func _initialize():call_deferred('_run')
func check(ok,label):
 if not ok:failures.append(label)
func _fixture():
 var p=Probe.new();root.add_child(p)
 p.source_root=Node3D.new();p.add_child(p.source_root)
 p.camera_root=Node3D.new();p.add_child(p.camera_root)
 p.camera=Camera3D.new();p.camera_root.add_child(p.camera);p.camera.position=Vector3(0,30,0);p.camera.rotation_degrees=Vector3(-90,0,0)
 p.data=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/assets/phone/scene_phone.json'))
 for row in p.data.nodes:
  var n=Node3D.new();p.source_nodes[row.id]=n
  if str(row.parent).is_empty():p.source_root.add_child(n)
  else:p.source_nodes[row.parent].add_child(n)
  n.transform=p.source_transform(row.position,row.rotation,row.scale);n.visible=bool(row.active)
  for renderer in row.renderers:
   var r=MeshInstance3D.new();n.add_child(r);r.visible=bool(renderer.enabled);p.renderer_nodes[renderer.id]=r
 var profile=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/assets/phone/interaction_profile.json'))
 for field in ['door_interaction','arch_interactions','water_particles','bush_interactions','water_interactions']:
  var row=profile[field];var controller=load(row.script).new();p.set(field,controller);p.add_child(controller)
  if field!='water_particles':controller.audio_enabled=false
  controller.setup(p,row.options)
 return p
func _exercise():
 var p=_fixture();var label='phone'
 check(p.source_nodes.size()==128,label+' actual node count')
 check(p.arch_interactions.systems.size()==1,label+' arch kinds')
 check(p.water_interactions.systems.size()==1,label+' water kinds')
 check(p.water_particles.entries.size()==20,label+' particle kinds')
 check(p.bush_interactions.systems.size()==11,label+' retained bushes')
 check(bool(p.door_interaction.source.collider.data.m_Enabled)==false,label+' source door collider enabled')
 for sys in p.bush_interactions.systems.values():check(bool(sys.collider.data.m_Enabled)==false,label+' source flower collider enabled')
 check(p.water_particles.render_quality_level==1,'phone profile uses evidenced source Medium fallback')
 check(p.water_particles.get_audit().render_quality_source.contains('actual device preference unread'),'phone quality provenance does not claim device read')
 var ambient=p.water_particles.entries.values().filter(func(e):return e.row.get('source_category','')=='environment')
 check(ambient.filter(func(e):return e.playing).size()==8,'Medium enables all8 environmental emitters')
 p.water_particles.set_render_quality_level(0)
 check(ambient.filter(func(e):return e.playing).size()==4,'Low disables precisely4 FX dust emitters')
 p.water_particles.set_render_quality_level(2)
 check(ambient.filter(func(e):return e.playing).size()==8,'High restores4 FX dust emitters')
 p.water_particles.set_render_quality_level(-1)
 check(ambient.filter(func(e):return e.playing).size()==4,'Unknown quality defers4 FX dust emitters')
 check(p.water_particles.get_audit().quality_status.contains('unresolved'),'Unknown quality explicit audit')
 p.water_particles.set_render_quality_level(1)
 check(not p.door_interaction.hit_test(Vector2.ZERO),'phone disabled door cannot hit')
 for kind in p.bush_interactions.systems:check(not p.bush_interactions.hit_test(kind,Vector2.ZERO),'phone disabled bush cannot hit '+kind)
 for i in range(8):
  p.arch_interactions.click_kind('gong')
  p.water_interactions.click_kind('mill_wheel')
  # Explicit direct controller exercise, not simulated touch on disabled flower colliders.
  p.bush_interactions.click_kind('BushFlower01')
  for step in range(40):
   p.door_interaction.advance(0.05);p.arch_interactions.advance(0.05);p.water_interactions.advance(0.05);p.bush_interactions.advance(0.05);p.water_particles.advance(0.05)
 # Direct solver coverage of every retained raw emitter, including disabled-click flowers.
 for key in p.water_particles.entries:p.water_particles.set_playing(key,true)
 for step in range(20):p.water_particles.advance(0.05)
 for key in p.water_particles.entries:p.water_particles.set_playing(key,false)
 for step in range(100):p.water_particles.advance(0.05)
 check(p.water_particles.errors.is_empty(),label+' particle refs: '+str(p.water_particles.errors))
 var missing=[]
 for c in [p.arch_interactions,p.water_interactions,p.bush_interactions]:
  for event in c.events:
   if str(event.event).begins_with('unsupported') or str(event.event).begins_with('missing'):missing.append(event)
 check(missing.is_empty(),label+' unsupported/missing action: '+str(missing))
 results.append({'variant':label,'source_nodes':p.source_nodes.size(),'arch_systems':p.arch_interactions.systems.keys(),'water_systems':p.water_interactions.systems.keys(),'bush_systems':p.bush_interactions.systems.size(),'particle_emitters':p.water_particles.entries.size(),'particle_generations':p.water_particles.generation,'door_collider_enabled':p.door_interaction.source.collider.data.m_Enabled,'missing_or_unsupported_events':missing,'particle_errors':p.water_particles.errors.duplicate(),'programmatic_clicks_only':true,'bush_particle_commands':p.bush_interactions.events.filter(func(e):return e.event=='particle_command'),'bush1':p.bush_interactions.systems['BushFlower01'].state})
 for c in [p.water_interactions,p.bush_interactions,p.water_particles,p.arch_interactions,p.door_interaction]:c.close_interaction();c.close_interaction()
 p.queue_free()
func _run():
 _exercise()
 await process_frame
 _exercise()
 await process_frame
 var result={'ok':failures.is_empty(),'failures':failures,'runs':results,'scope':'Headless CPU-only fixture: exact hierarchy IDs, controller setup/actions/particles and repeated close. No Android, emulator, device, rendered screenshot, audio output or physical touch claim.'}
 var f=FileAccess.open('user://phone_interaction_smoke_result.json',FileAccess.WRITE);f.store_string(JSON.stringify(result,'  '));f.close()
 if failures.is_empty():print('PHONE_BOARD_INTERACTION_SMOKE_PASS')
 print(JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
