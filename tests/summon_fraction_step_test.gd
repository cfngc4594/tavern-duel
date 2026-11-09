extends SceneTree
const Solver=preload("res://scripts/native_summon_particles.gd")
const Assets=preload("res://scripts/native_summon_assets.gd")
class Derived extends Solver:
 func _velocity_over_life(p:Dictionary,normalized:float)->Vector3:return super._velocity_over_life(p,normalized)
var checks=0
func _initialize():call_deferred("run")
func compare(a,b,label):
 require(a.rng.state==b.rng.state,label+" RNG")
 require(a.emitted_count==b.emitted_count and a.live_count==b.live_count,label+" counts")
 require(a.particles==b.particles,label+" exact particle state")
 require(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces")
 for surface in a.mesh.get_surface_count():
  var aa=a.mesh.surface_get_arrays(surface);var bb=b.mesh.surface_get_arrays(surface)
  for channel in Mesh.ARRAY_MAX:require(aa[channel]==bb[channel],label+" mesh "+str(channel))
 checks+=1
func run():
 var assets=Assets.new();assets.setup()
 var parent=Node3D.new();root.add_child(parent)
 if "--dynamic-only" in OS.get_cmdline_user_args():
  exercise_dynamic(assets,parent);parent.free();quit();return
 var pairs=[];var index=0
 for key in assets.objects:
  var record=assets.objects[key]
  if record.type!="ParticleSystem":continue
  var go=str(record.refs.get(".m_GameObject",""))
  var renderer=assets.component(go,"ParticleSystemRenderer")
  var node=Node3D.new();parent.add_child(node)
  var spec={"system":record,"renderer":renderer,"node":node}
  var a=Solver.new();var b=Solver.new();b.fraction_snapshot_enabled=false
  a.setup(spec,assets,parent,1900+index);b.setup(spec,assets,parent,1900+index)
  pairs.append({"a":a,"b":b,"key":key,"max_live":0,"eligible":a._constant_step_valid});index+=1
 require(pairs.size()==16)
 var frame_count=48
 for frame in frame_count:
  var at=(frame+1)/60.0
  for pair in pairs:
   for which in (["a","b"] if frame%2==0 else ["b","a"]):
    pair[which].seek(at)
   pair.max_live=maxi(pair.max_live,pair.a.live_count)
   if frame%10==0:compare(pair.a,pair.b,pair.key+" frame "+str(frame))
 for pair in pairs:
  for at in [2.503,2.507,1.31,1.319,2.71]:
   pair.a.seek(at);pair.b.seek(at);compare(pair.a,pair.b,pair.key+" partial/rewind "+str(at))
  pair.a.stop_emitting();pair.b.stop_emitting()
  pair.a.seek(5.0);pair.b.seek(5.0);compare(pair.a,pair.b,pair.key+" stop")
 exercise_dynamic(assets,parent)
 print("SUMMON_CONSTANT_STEP_PASS exact particles/RNG/all mesh arrays, all 16 sources, fractional steps, rewind and stop")
 parent.free();quit()
func exercise_dynamic(assets,parent):
 exercise_nonfinite(assets)
 var key="cab-69c88b234dfa427e02d1fcee9337ae34:6590410617251757833"
 var derived=Derived.new();derived.raw=assets.objects[key].data;derived._prepare_constant_steps();require(not derived._constant_step_valid,"subclass fallback");derived.free()
 var record=assets.objects[key];var go=str(record.refs.get(".m_GameObject",""))
 for seed_value in [1,731,99001]:
  var node=Node3D.new();parent.add_child(node)
  var spec={"system":record,"renderer":assets.component(go,"ParticleSystemRenderer"),"node":node}
  var a=Solver.new();var b=Solver.new();b.fraction_snapshot_enabled=false
  a.setup(spec,assets,parent,seed_value);b.setup(spec,assets,parent,seed_value)
  for world in [0,1]:
   for mode in ["constant","curve","speed_rotation","axis","drag"]:
    var changed=record.data.duplicate(true);changed.moveWithTransform=world
    if mode=="curve":changed.VelocityModule.x.minMaxState=1
    if mode=="speed_rotation":changed.RotationBySpeedModule.enabled=true
    if mode=="axis":changed.ClampVelocityModule.separateAxis=true
    if mode=="drag":changed.ClampVelocityModule.drag.scalar=.5
    a.raw=changed;b.raw=changed
    node.transform=Transform3D(Basis.from_euler(Vector3(.1,.3,.2)).scaled(Vector3(1.2,.8,1.7)),Vector3(.2,.1,.3))
    for solver in [a,b]:
     for particle in solver.particles:particle.motion_basis=Basis.from_euler(Vector3(.2,.1,.3)).scaled(Vector3(.8,1.3,1.1))
    for at in [.123,.137,.251,.311]:
     a.seek(at);b.seek(at)
     require(a._constant_step_valid==(mode=="constant"),"signature "+mode)
     compare(a,b,"dynamic "+str(seed_value)+"/"+str(world)+"/"+mode+"/"+str(at))
    if not a.particles.is_empty():
     # Direct public helper must revalidate after changing raw without a seek.
     a.raw=record.data.duplicate(true);b.raw=a.raw;a.raw.ClampVelocityModule.drag.scalar=.1
     var pa=a.particles[0].duplicate(true);var pb=b.particles[0].duplicate(true)
     require(a._position(pa,.35)==b._position(pb,.35),"direct position")
  a.free();b.free();node.free()
 print("SUMMON_CONSTANT_DYNAMIC_PASS 3 seeds, world/local, changed motion basis, module invalidation, direct position")

func require(condition:bool,message:String="exact check failed")->void:
 if not condition:
  push_error(message)
  quit(1)
  assert(condition,message)

func exercise_nonfinite(assets)->void:
 var record=assets.objects["cab-69c88b234dfa427e02d1fcee9337ae34:6590410617251757833"]
 var solver=Solver.new()
 for value in [INF,-INF,NAN]:
  solver.raw=record.data.duplicate(true)
  solver.raw.VelocityModule.enabled=true
  solver.raw.VelocityModule.x={"minMaxState":0,"scalar":value}
  solver._prepare_constant_steps()
  require(not solver._constant_step_valid,"nonfinite constant must use original integrator")
 solver.free()