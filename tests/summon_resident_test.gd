extends SceneTree
const Solver=preload("res://scripts/native_summon_particles.gd")
const Assets=preload("res://scripts/native_summon_assets.gd")
const Resident=preload("res://scripts/summon_resident.gd")
var received:Dictionary={}
var arrived:=false
var failed:=false
var comparisons:=0
var max_center_error:=0.0
var max_state_error:=0.0
func require(ok:bool,label:String)->bool:
 if not ok:push_error("RESIDENT_FAIL "+label);failed=true
 return ok
func delivered(value:Dictionary):received=value;arrived=true
func _initialize():call_deferred("run")
func run():
 var assets=Assets.new();assets.setup()
 var parent=Node3D.new();root.add_child(parent)
 if "--expect-fallback" in OS.get_cmdline_user_args():
  var record=assets.objects[Resident.KEY]
  var node=Node3D.new();parent.add_child(node)
  var spec={"system":record,"renderer":assets.component(str(record.refs.get(".m_GameObject","")),"ParticleSystemRenderer"),"node":node}
  var a=Solver.new();var b=Solver.new()
  Resident.enabled=true;a.setup(spec,assets,parent,1900);a.seek(.4)
  Resident.enabled=false;b.setup(spec,assets,parent,1900);b.seek(.4)
  require(a._resident==null,"unsupported renderer did not initialize GPU")
  require(var_to_bytes(a.mesh.surface_get_arrays(0))==var_to_bytes(b.mesh.surface_get_arrays(0)),"unsupported renderer CPU mesh exact")
  a.free();b.free();parent.free()
  if not failed:print("RESIDENT_FALLBACK_PASS")
  quit(1 if failed else 0);return
 for seed_value in [7,1900,91000]:
  var record=assets.objects[Resident.KEY]
  var node=Node3D.new();parent.add_child(node)
  node.position=Vector3(.3,-.2,.7);node.rotation=Vector3(.1,.2,-.1)
  var spec={"system":record,"renderer":assets.component(str(record.refs.get(".m_GameObject","")),"ParticleSystemRenderer"),"node":node}
  var a=Solver.new();var b=Solver.new()
  Resident.enabled=true;a.setup(spec,assets,parent,seed_value)
  Resident.enabled=false;b.setup(spec,assets,parent,seed_value)
  require(a.material.get_shader_parameter("_TintColor")==b.material.get_shader_parameter("_TintColor"),"original material tint preserved")
  for tick in 20:
   await process_frame
   if a._resident!=null and a._resident.ready:break
  if not require(a._resident!=null and a._resident.ready,"global RD ready"):break
  var times:Array=[]
  for f in 48:times.append((f+1)/30.0)
  times.append_array([.175,.181,.6,.616,1.9])
  for t in times:
   Resident.enabled=true;a.seek(t);Resident.enabled=false;b.seek(t)
   arrived=false;a._resident.inspect(delivered)
   for wait in 30:
    await process_frame
    if arrived:break
   if not require(arrived and not received.is_empty(),"validation readback"):break
   if not require(a.rng.state==b.rng.state and a.live_count==b.live_count,"RNG/live count"):break
   var bytes:PackedByteArray=received.state;var pixels:PackedByteArray=received.pixels
   var motion:Basis=b._motion_basis(node.global_transform,node.scale)
   var mesh_arrays:Array=b.mesh.surface_get_arrays(0) if b.mesh.get_surface_count()>0 else []
   var live_index=0
   for i in b.particles.size():
    var p:Dictionary=b.particles[i];var age:float=t-p.birth
    if age<0 or age>=p.life or p.birth>b.stop_time:continue
    var offset=i*96
    var gpu_age=bytes.decode_double(offset)
    var pos=Vector3(bytes.decode_float(offset+32),bytes.decode_float(offset+36),bytes.decode_float(offset+40))
    var vel=Vector3(bytes.decode_float(offset+48),bytes.decode_float(offset+52),bytes.decode_float(offset+56))
    max_state_error=maxf(max_state_error,maxf(pos.distance_to(p.displacement),vel.distance_to(p.sim_velocity)))
    if comparisons==0:print("FIRST_DIFF ",{"age_equal":gpu_age==p.sim_age,"position_delta":pos-p.displacement,"velocity_delta":vel-p.sim_velocity})
    if not require(gpu_age==p.sim_age and pos==p.displacement and vel==p.sim_velocity,"checkpoint seed=%s t=%s i=%s"%[seed_value,t,i]):break
    var state=b._particle_state(p,age)
    var center:Vector3=node.global_transform*p.shape_point+motion*state.position
    var at=i*5*16
    var actual=Vector3(pixels.decode_float(at),pixels.decode_float(at+4),pixels.decode_float(at+8))
    max_center_error=maxf(max_center_error,center.distance_to(actual))
    if not require(center.distance_to(actual)<0.00001,"world center tolerance"):break
    var x=Vector3(pixels.decode_float(at+16),pixels.decode_float(at+20),pixels.decode_float(at+24))
    var y=Vector3(pixels.decode_float(at+32),pixels.decode_float(at+36),pixels.decode_float(at+40))
    var offsets=[-x+y,x+y,x-y,-x-y]
    for corner in 4:
     if not require(actual+offsets[corner]==mesh_arrays[Mesh.ARRAY_VERTEX][live_index*4+corner],"quad vertex exact"):break
     if not require(a._resident.fixed_mesh.custom_aabb.has_point(actual+offsets[corner]),"conservative bounds contain exact vertex"):break
    if failed:break
    var color_offset=at+64
    var gpu_color=Color(pixels.decode_float(color_offset),pixels.decode_float(color_offset+4),pixels.decode_float(color_offset+8),pixels.decode_float(color_offset+12))
    var cpu_color:Color=mesh_arrays[Mesh.ARRAY_COLOR][live_index*4]
    if not require(gpu_color==cpu_color,"mesh color format gpu=%s cpu=%s"%[gpu_color,cpu_color]):break
    live_index+=1
    comparisons+=1
   if failed:break
  if not failed:
   node.visible=false;Resident.enabled=true;a.seek(1.0);Resident.enabled=false;b.seek(1.0)
   require(not a.mesh_instance.visible,"source visibility preserved")
   node.visible=true;a.stop_emitting(.5);b.stop_emitting(.5)
   Resident.enabled=true;a.seek(.8);Resident.enabled=false;b.seek(.8)
   require(a.live_count==b.live_count,"stop live count")
   a.seek(.7);b.seek(.7)
   require(a.mesh_instance.mesh==a.mesh,"disabled CPU fallback mesh")
   require(var_to_bytes(a.mesh.surface_get_arrays(0))==var_to_bytes(b.mesh.surface_get_arrays(0)),"CPU fallback exact mesh")
   Resident.enabled=true;a.seek(.75);Resident.enabled=false;b.seek(.75)
   arrived=false;a._resident.inspect(delivered)
   for wait in 30:
    await process_frame
    if arrived:break
   require(arrived and not received.is_empty(),"GPU resumed after CPU fallback")
   a._resident.failed=true;Resident.enabled=true;a.seek(.76);Resident.enabled=false;b.seek(.76)
   require(a.mesh_instance.mesh==a.mesh,"failed GPU CPU fallback mesh")
   require(var_to_bytes(a.mesh.surface_get_arrays(0))==var_to_bytes(b.mesh.surface_get_arrays(0)),"failed GPU exact CPU mesh")
  a.free();b.free();node.free()
  for tick in 3:await process_frame
  if failed:break
 if not failed:
  var record=assets.objects[Resident.KEY]
  var node=Node3D.new();parent.add_child(node)
  var spec={"system":record,"renderer":assets.component(str(record.refs.get(".m_GameObject","")),"ParticleSystemRenderer"),"node":node}
  Resident.enabled=true
  var immediate=Solver.new();immediate.setup(spec,assets,parent,7);immediate.free();node.free()
  for tick in 3:await process_frame
 Resident.enabled=false
 parent.free()
 print("RESIDENT_RESULT ",JSON.stringify({"failed":failed,"comparisons":comparisons,"max_center_error":max_center_error,"max_state_error":max_state_error,"stats":Resident.stats}))
 if not failed:print("RESIDENT_PARITY_PASS")
 quit(1 if failed else 0)
