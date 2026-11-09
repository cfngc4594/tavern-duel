extends SceneTree
const Solver=preload("res://scripts/native_summon_particles.gd")
const Assets=preload("res://scripts/native_summon_assets.gd")
const Compute=preload("res://scripts/summon_compute.gd")
var checks:=0
var failed:=false
func require(ok:bool,label:String)->bool:
 if not ok:push_error("COMPUTE_PARITY_FAIL "+label);failed=true
 return ok
func compare(a,b,label:String)->bool:
 if not require(a.rng.state==b.rng.state,label+" rng"):return false
 if not require(a.particles==b.particles,label+" particle checkpoints"):
  for i in mini(a.particles.size(),b.particles.size()):
   for key in a.particles[i]:
    if a.particles[i][key]!=b.particles[i][key]:print("FIRST_DIFFERENCE ",i," ",key," gpu=",a.particles[i][key]," cpu=",b.particles[i][key]);return false
  return false
 if not require(a.emitted_count==b.emitted_count and a.live_count==b.live_count,label+" count"):return false
 if not require(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces"):return false
 for s in a.mesh.get_surface_count():
  var aa=a.mesh.surface_get_arrays(s);var bb=b.mesh.surface_get_arrays(s)
  for channel in Mesh.ARRAY_MAX:
   if not require(aa[channel]==bb[channel],label+" mesh "+str(channel)):return false
 if not require(var_to_bytes(a.particles)==var_to_bytes(b.particles),label+" checkpoint bytes"):return false
 for surface in a.mesh.get_surface_count():
  if not require(var_to_bytes(a.mesh.surface_get_arrays(surface))==var_to_bytes(b.mesh.surface_get_arrays(surface)),label+" mesh bytes"):return false
 checks+=1;return true
func _initialize():call_deferred("run")
func run():
 var assets=Assets.new();assets.setup()
 var parent=Node3D.new();root.add_child(parent)
 Compute.enabled=false;Compute.reset_stats()
 for seed_value in [7,1900,91000]:
  for key in assets.objects:
   var record=assets.objects[key]
   if record.type!="ParticleSystem":continue
   if "--all-sources" not in OS.get_cmdline_user_args() and not key.ends_with(":7435642337723423872"):continue
   var node=Node3D.new();parent.add_child(node)
   var spec={"system":record,"renderer":assets.component(str(record.refs.get(".m_GameObject","")),"ParticleSystemRenderer"),"node":node}
   var a=Solver.new();var b=Solver.new()
   a.setup(spec,assets,parent,seed_value);b.setup(spec,assets,parent,seed_value)
   for frame in 48:
    var t=(frame+1)/30.0
    Compute.enabled=true;a.seek(t);Compute.enabled=false;b.seek(t)
    if not compare(a,b,str(key)+" seed="+str(seed_value)+" frame="+str(frame)):break
   if not failed:
    for t in [.175,.181,.6,.616,1.9]:
     Compute.enabled=true;a.seek(t);Compute.enabled=false;b.seek(t)
     if not compare(a,b,"rewind/seek "+str(t)):break
   if not failed:
    a.stop_emitting(.5);b.stop_emitting(.5)
    for t in [.55,.75,1.2]:
     Compute.enabled=true;a.seek(t);Compute.enabled=false;b.seek(t)
     if not compare(a,b,"stop-emission "+str(t)):break
   print("COMPUTE_SOURCE ",key," checks=",checks," stats=",JSON.stringify(Compute.get_stats()))
   a.free();b.free();node.free()
   if failed:break
  if failed:break
 if not failed and "--expect-fallback" not in OS.get_cmdline_user_args():batch_boundaries();atomic_fallback()
 var stats=Compute.get_stats()
 if "--expect-fallback" in OS.get_cmdline_user_args():
  require(int(stats.get("dispatches",0))==0,"unsupported device must stay on CPU")
 else:
  require(int(stats.get("dispatches",0))>0,"actual GPU dispatch required (not fallback pass)")
 if "--expect-fallback" not in OS.get_cmdline_user_args():
  require(int(stats.get("particles",0))>0,"actual GPU particles required")
  require(int(stats.get("gpu_dispatch_nanoseconds",0))>0,"real GPU timestamp duration required")
  require(int(stats.get("gpu_timestamp_samples",0))==int(stats.get("dispatches",0)),"every GPU dispatch must have timestamps")
 print("COMPUTE_FINAL ",JSON.stringify({"checks":checks,"failed":failed,"stats":stats}))
 Compute.enabled=false;Compute.shutdown();parent.free()
 if not failed:print("SUMMON_COMPUTE_PARITY_PASS")
 quit(1 if failed else 0)

func batch_boundaries()->void:
 var a=Solver.new();var b=Solver.new()
 var raw={"VelocityModule":{"enabled":false},"ClampVelocityModule":{"enabled":false},"RotationModule":{"enabled":true,"curve":{"minMaxState":0,"scalar":0.17}}}
 a.raw=raw;b.raw=raw
 for count in [1,2,63,64,65,127,399]:
  var pa:Array=[];var pb:Array=[]
  for i in count:
   # Large absolute clock detects accidental float32 scalar math immediately.
   var p={"birth":0.0,"life":100000.0,"sim_age":65536.0,"displacement":Vector3(i*.013,-.25,.75),"sim_velocity":Vector3(.3,-.7,1.2),"sim_rotation":0.123456789012345,"velocity":Vector3(.3,-.7,1.2),"rotation":0.123456789012345,"limit_mix":.4,"rotation_mix":.7}
   pa.append(p);pb.append(p.duplicate(true))
  var until=65536.03125
  Compute.enabled=true
  if not require(Compute.apply(pa,raw,until,INF),"real FP64 dispatch boundary "+str(count)):break
  Compute.enabled=false
  for i in count:
   a._prepare_constant_steps();b._prepare_constant_steps()
   var sa=a._particle_state(pa[i],until);var sb=b._particle_state(pb[i],until)
   if not require(sa==sb and pa[i]==pb[i],"FP64/vector32 exact boundary "+str(count)+" particle "+str(i)):break
  if failed:break
  checks+=1
 a.free();b.free()
 print("COMPUTE_BOUNDARIES 1,2,63,64,65,127,399 high-clock FP64 verified=",not failed)
func atomic_fallback()->void:
 var raw={"VelocityModule":{"enabled":false},"ClampVelocityModule":{"enabled":false},"RotationModule":{"enabled":false}}
 var valid={"birth":0.0,"life":100.0,"sim_age":0.0,"displacement":Vector3.ZERO,"sim_velocity":Vector3.ONE,"sim_rotation":.2,"velocity":Vector3.ONE,"rotation":.2,"limit_mix":.4,"rotation_mix":.7}
 var invalid=valid.duplicate(true);invalid.displacement=Vector3(INF,0,0)
 var batch=[valid.duplicate(true),invalid];var original=batch.duplicate(true)
 var previous=int(Compute.get_stats().get("dispatches",0))
 Compute.enabled=true
 require(not Compute.apply(batch,raw,.1,INF),"invalid mixed batch must fallback")
 require(batch==original,"invalid mixed batch must not partially write")
 var long_seek=[valid.duplicate(true)];var before=long_seek.duplicate(true)
 require(not Compute.apply(long_seek,raw,11.0,INF),"large seek must fallback")
 require(long_seek==before,"large seek must preserve CPU input")
 var stalled=valid.duplicate(true);stalled.sim_age=1.0e16;stalled.life=1.0e18
 var stalled_batch=[stalled];var stalled_before=stalled_batch.duplicate(true)
 require(not Compute.apply(stalled_batch,raw,1.0e16,INF),"non-advancing FP64 clock must not dispatch")
 require(stalled_batch==stalled_before,"non-advancing clock preserves input")
 Compute.enabled=false
 require(int(Compute.get_stats().get("dispatches",0))==previous,"rejected batch must not dispatch")
 print("COMPUTE_ATOMIC_FALLBACK verified=",not failed)
