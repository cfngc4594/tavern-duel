extends SceneTree
const Solver=preload("res://scripts/native_summon_particles.gd")
const Assets=preload("res://scripts/native_summon_assets.gd")
const Resident=preload("res://scripts/summon_resident.gd")
const Compute=preload("res://scripts/summon_compute.gd")
var checks:=0
var failed:=false
var hidden_live:=0
func _initialize():call_deferred("run")
func require(ok:bool,label:String):
 if not ok:
  failed=true
  push_error(label)
func compare(a,b,label:String):
 require(var_to_bytes(a.particles)==var_to_bytes(b.particles),label+" exact particle bytes")
 require(a.rng.state==b.rng.state,label+" RNG")
 for field in ["active","live_count","emitted_count","dropped_at_capacity","simulation_time","stop_time","next_cycle","last_emitter","last_local_scale","source_destroyed"]:
  require(a.get(field)==b.get(field),label+" "+field)
 require(var_to_bytes(a.pending_events)==var_to_bytes(b.pending_events),label+" pending events")
 require(a._constant_plan==null and b._constant_plan==null,label+" plan cleared")
 require(a.mesh_instance.visible==b.mesh_instance.visible,label+" visibility")
 if b.mesh_instance.visible:
  require(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces")
  for s in mini(a.mesh.get_surface_count(),b.mesh.get_surface_count()):
   require(var_to_bytes(a.mesh.surface_get_arrays(s))==var_to_bytes(b.mesh.surface_get_arrays(s)),label+" exact visible mesh")
 else:
  require(b.mesh.get_surface_count()==0,label+" hidden optimized mesh empty")
  if b.live_count>0:hidden_live+=1
 checks+=1
func sample(a,b,t:float,label:String):
 # Alternate evaluation order to expose accidental static/shared state coupling.
 for solver in ([a,b] if checks%2==0 else [b,a]):
  Solver.skip_hidden_geometry=solver==b
  solver.seek(t)
 compare(a,b,label)
func run():
 var saved_flag=Solver.skip_hidden_geometry
 var saved_resident=Resident.enabled
 var saved_compute=Compute.enabled
 Resident.enabled=false;Compute.enabled=false
 var assets=Assets.new();assets.setup()
 var parent=Node3D.new();root.add_child(parent)
 var source_count:=0
 for key in assets.objects:
  var record=assets.objects[key]
  if record.type!="ParticleSystem":continue
  source_count+=1
  for world in [0,1]:
   var node=Node3D.new();parent.add_child(node)
   var system=record.duplicate(true);system.data.moveWithTransform=world
   var renderer=assets.component(str(record.refs.get(".m_GameObject","")),"ParticleSystemRenderer").duplicate(true)
   renderer.data.m_Enabled=true
   var spec={"system":system,"renderer":renderer,"node":node}
   var a=Solver.new();var b=Solver.new()
   Solver.skip_hidden_geometry=false;a.setup(spec,assets,parent,731+source_count)
   Solver.skip_hidden_geometry=true;b.setup(spec,assets,parent,731+source_count)
   var label=str(key)+" world="+str(world)
   sample(a,b,.113,label+" initial")
   node.visible=false
   for t in [.127,.241,.509]:
    node.position=Vector3(t,t*.3,-t*.2)
    node.rotation=Vector3(.1,t,.2)
    node.scale=Vector3(1.2,.8,1.1)
    sample(a,b,t,label+" source hidden "+str(t))
   # Rewind while hidden, then rebuild the first visible frame exactly.
   sample(a,b,.219,label+" hidden rewind")
   node.visible=true;sample(a,b,.347,label+" reappear")
   renderer.data.m_Enabled=false
   sample(a,b,.633,label+" renderer disabled")
   renderer.data.m_Enabled=true;sample(a,b,.691,label+" renderer enabled")
   parent.visible=false;sample(a,b,.743,label+" ancestor hidden")
   parent.visible=true;sample(a,b,.757,label+" ancestor restored")
   node.visible=false
   for solver in [a,b]:
    Solver.skip_hidden_geometry=solver==b
    solver.stop_emitting(.45)
   compare(a,b,label+" hidden stop")
   node.visible=true;sample(a,b,.813,label+" stopped reappear")
   sample(a,b,.191,label+" stopped rewind")
   sample(a,b,5.0,label+" expired")
   node.free();sample(a,b,5.1,label+" source destroyed")
   a.free();b.free()
 require(source_count==16,"all 16 source systems")
 require(hidden_live>0,"hidden path exercised with living particles")
 parent.free()
 Solver.skip_hidden_geometry=saved_flag;Resident.enabled=saved_resident;Compute.enabled=saved_compute
 print("SUMMON_HIDDEN_GEOMETRY ","FAIL" if failed else "PASS"," sources=",source_count," checks=",checks," hidden_live=",hidden_live," exact particle/RNG/counts/visible mesh; local/world, visibility, rewind, stop, destroy")
 quit(1 if failed else 0)
