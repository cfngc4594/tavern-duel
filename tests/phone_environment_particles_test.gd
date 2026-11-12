extends SceneTree
# Headless CPU fixtures only. No phone/emulator or renderer parity claim.
const Controller=preload('res://original_board/scripts/source_particles.gd')
class Factory:
 extends RefCounted
 var materials=[]
 func register_lighting_material(mat):
  if not materials.has(mat):materials.append(mat)
  mat.set_shader_parameter('_UnitySHW',Vector3(0.2,0.3,0.4))
class Probe:
 extends Node3D
 var source_nodes={}
 var source_root:Node3D
 var material_factory=Factory.new()
 var config={'lighting':{'ambient_target_raw_rgba':{'r':0.8,'g':0.8,'b':0.8,'a':1.0}}}
var failures=[]
var report={}
func check(value,label):
 if not value:failures.append(label)
func _initialize():call_deferred('_run')
func fixture(quality=-1):
 var p=Probe.new();root.add_child(p);p.source_root=Node3D.new();p.add_child(p.source_root)
 var path='res://original_board/assets/phone/scene_phone.json'
 var scene=JSON.parse_string(FileAccess.get_file_as_string(path))
 var reflect=Controller.REFLECTION
 for row in scene.nodes:
  var n=Node3D.new();p.source_nodes[row.id]=n
  if str(row.parent).is_empty():p.source_root.add_child(n)
  else:p.source_nodes[row.parent].add_child(n)
  var q=row.rotation;var s=row.scale;var pos=row.position
  n.transform=Transform3D((reflect*Basis(Quaternion(q.x,q.y,q.z,q.w))*reflect).scaled_local(Vector3(s.x,s.y,s.z)),reflect*Vector3(pos.x,pos.y,pos.z));n.visible=bool(row.active)
 var c=Controller.new();p.add_child(c)
 c.setup(p,{'source_file':'res://original_board/assets/phone/water_particles/source.json','render_quality_level':quality})
 return {'p':p,'c':c}
func ambient(c):return c.entries.values().filter(func(e):return e.row.get('source_category','')=='environment')
func ambient_playing(c):return ambient(c).filter(func(e):return e.playing).size()
func get_entry(c,name):
 for e in ambient(c):
  if e.row.name==name:return e
 return {}
func _run():
 var f=fixture();var c=f.c
 check(c.entries.size()==20,'20 exact PHONE systems')
 check(ambient(c).size()==8,'8 environmental systems')
 check(ambient_playing(c)==4,'Unknown quality defers exactly four dust systems')
 check(c.get_audit().render_quality_level==-1,'Unknown quality explicitly audited')
 c.set_render_quality_level(0);check(ambient_playing(c)==4,'Low quality disables dust')
 c.set_render_quality_level(1);check(ambient_playing(c)==8,'Medium quality enables dust')
 var emissions=[]
 for e in ambient(c):
  check(e.current.unsupported.is_empty(),e.row.name+' supported modules '+str(e.current.unsupported))
  check(e.current.source_renderer.m_Enabled,e.row.name+' renderer enabled')
  emissions.append({'name':e.row.name,'id':e.row.node_id,'modules':e.current.enabled_modules,'rate':e.current.constant_source_rate,'life':e.current.raw.InitialModule.startLifetime,'source_sort_mode':e.current.source_renderer.m_SortMode})
 var ripple_initial=get_entry(c,'FX_WaterRipples1').current.emitted_count
 var spray_initial=get_entry(c,'FX_WaterSpray1').current.emitted_count
 check(ripple_initial==27,'Original5sec ripple prewarm emits27')
 check(spray_initial==50,'Original6sec spray prewarm includes next source loop burst')
 # Replay 60 source seconds with fractional rate carried over source loop boundaries.
 for step in range(600):c.advance(0.1)
 var ripple=get_entry(c,'FX_WaterRipples1')
 check(ripple.current.emitted_count==356 and ripple.current.emitted_count-ripple_initial==329,'Original5sec prewarm+60sec at5.48999977/sec yields356 total,329 new, got '+str(ripple.current.emitted_count))
 var spray=get_entry(c,'FX_WaterSpray1')
 check(spray.current.emitted_count==450 and spray.current.emitted_count-spray_initial==400,'Original6sec prewarm+60sec source bursts yield450 total,400 new, got '+str(spray.current.emitted_count))
 var sort=get_entry(c,'FX_Dust1[0]').current
 var first_live=null
 for particle in sort.particles:
  if sort.simulation_time-particle.birth<particle.life:first_live=particle;break
 check(sort.source_sort_mode and first_live!=null,'Dust source old-in-front enabled')
 var sorted_mesh=sort.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var newest=sort.particles[-1];var center=sort._position(newest,sort.simulation_time-newest.birth)
 var rendered_center=(sorted_mesh[0]+sorted_mesh[1]+sorted_mesh[2]+sorted_mesh[3])*0.25
 check(rendered_center.distance_to(center)<0.0001,'OldestInFront draws newest quad first')
 var max_storage=0
 for e in ambient(c):max_storage=maxi(max_storage,e.current.particles.size())
 check(max_storage<=101,'Expired storage pruned under source lifetime, max '+str(max_storage))
 # Exact source GameObject inactivity clears; quality reactivation restarts autoplay.
 c.set_render_quality_level(0);check(ambient_playing(c)==4,'Repeated Low disables dust')
 for e in ambient(c):
  if e.row.source_activation.disable_low_quality:check(e.instances.is_empty(),'Low clears disabled GO '+e.row.name)
 c.set_render_quality_level(2);check(ambient_playing(c)==8,'High reactivates source dust')
 # A disabled source ancestor must also suppress top-level proxy and clear particles.
 var wheel=get_entry(c,'FX_WaterMist1');var parent_id=wheel.row.source_activation.active_chain[1].node_id
 f.p.source_nodes[parent_id].visible=false;c.advance(0.1)
 check(ambient_playing(c)==4,'Inactive wheel ancestor stops4 environmental children')
 f.p.source_nodes[parent_id].visible=true;c.advance(0.1);check(ambient_playing(c)==8,'Reactivating wheel ancestor honors playOnAwake')
 # Repeated Play remains idempotent; explicit Stop preserves alive source tail.
 var generation=c.generation
 for e in ambient(c):c.set_playing(e.row.node_id,true)
 check(c.generation==generation,'RepeatedPlay does not restart living generations')
 for step in range(13):c.advance(0.1)
 var before_stop=0
 for e in ambient(c):before_stop+=e.current.live_count;c.set_playing(e.row.node_id,false)
 var tail=0
 for e in ambient(c):
  for item in e.instances:tail+=item.solver.live_count
 check(tail==before_stop and tail>0,'StopEmitting preserves source-lifetime tails')
 for step in range(110):c.advance(0.1)
 for e in ambient(c):check(e.instances.is_empty(),'Natural tail retirement '+e.row.name)
 check(c.errors.is_empty(),'No unresolved runtime assets '+str(c.errors))
 check(f.p.material_factory.materials.size()==4,'All4 source environmental materials registered')
 for mat in f.p.material_factory.materials:check(mat.get_shader_parameter('_UnitySHW')==Vector3(0.2,0.3,0.4),'Board current lighting applied')
 report={'source_emitters':20,'environment_emitters':emissions,'unknown_auto':4,'medium_auto':8,'ripple_count_at60_including_source_prewarm':356,'spray_count_at60_including_source_prewarm':450,'ripple_new_particles_after_warmup':329,'spray_new_particles_after_warmup':400,'max_particle_storage':max_storage,'source_texture_materials_registered':f.p.material_factory.materials.size(),'source_gates':'unknown/low/medium/high + ancestor disable/reactivate','stop_tail_count':tail,'scope':'CPU fixed-step source-data, activation, emission, sorting and lifetime fixture. No device/emulator or pixel-equivalence claim.'}
 c.close_interaction();c.close_interaction();f.p.queue_free();await process_frame
 var again=fixture();check(ambient_playing(again.c)==4,'Repeated PHONE fixture resets unknown quality')
 again.c.close_interaction();again.p.queue_free();await process_frame
 report.ok=failures.is_empty();report.failures=failures
 var out=FileAccess.open('user://phone_environment_particles_result.json',FileAccess.WRITE);out.store_string(JSON.stringify(report,'  '));out.close()
 if report.ok:print('PHONE_ENVIRONMENT_PARTICLES_PASS')
 print(JSON.stringify({'ok':report.ok,'failures':failures,'max_particle_storage':max_storage}));quit(0 if failures.is_empty() else 1)
