extends SceneTree
const Solver=preload("res://scripts/native_summon_particles.gd")
const Assets=preload("res://scripts/native_summon_assets.gd")
class Derived extends Solver:
 func _velocity_over_life(p:Dictionary,normalized:float)->Vector3:return super._velocity_over_life(p,normalized)
var checks=0
func _initialize():call_deferred("run")
func compare(a,b,label):
 assert(a.rng.state==b.rng.state,label+" RNG")
 assert(a.emitted_count==b.emitted_count and a.live_count==b.live_count,label+" counts")
 assert(a.particles==b.particles,label+" exact particle state")
 assert(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces")
 for surface in a.mesh.get_surface_count():
  var aa=a.mesh.surface_get_arrays(surface);var bb=b.mesh.surface_get_arrays(surface)
  for channel in Mesh.ARRAY_MAX:assert(aa[channel]==bb[channel],label+" mesh "+str(channel))
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
  var a=Solver.new();var b=Solver.new();b.size_snapshot_enabled=false;assert(a.constant_step_enabled and b.constant_step_enabled)
  a.setup(spec,assets,parent,1900+index);b.setup(spec,assets,parent,1900+index)
  pairs.append({"a":a,"b":b,"key":key,"new_us":0,"old_us":0,"max_live":0,"eligible":a._frame_size_sampler()!=null});index+=1
 assert(pairs.size()==16)
 var frame_count=150 if "--benchmark" in OS.get_cmdline_user_args() else 48
 var measured=frame_count-10
 for frame in frame_count:
  var at=(frame+1)/60.0
  for pair in pairs:
   for which in (["a","b"] if frame%2==0 else ["b","a"]):
    var t=Time.get_ticks_usec();pair[which].seek(at)
    if frame>=10:pair["new_us" if which=="a" else "old_us"]+=Time.get_ticks_usec()-t
   pair.max_live=maxi(pair.max_live,pair.a.live_count)
   if frame%10==0:compare(pair.a,pair.b,pair.key+" frame "+str(frame))
 var totals=Vector2.ZERO
 for pair in pairs:
  totals+=Vector2(pair.old_us,pair.new_us)
  for at in [2.503,2.507,1.31,1.319,2.71]:
   pair.a.seek(at);pair.b.seek(at);compare(pair.a,pair.b,pair.key+" partial/rewind "+str(at))
  pair.a.stop_emitting();pair.b.stop_emitting()
  pair.a.seek(5.0);pair.b.seek(5.0);compare(pair.a,pair.b,pair.key+" stop")
  print("SUMMON_SIZE_BENCH ",JSON.stringify({"key":pair.key,"eligible":pair.eligible,"max_live":pair.max_live,"old_us":pair.old_us/float(measured),"new_us":pair.new_us/float(measured)}))
 print("SUMMON_SIZE_TOTAL ",JSON.stringify({"checks":checks,"old_us":totals.x/float(measured),"new_us":totals.y/float(measured),"warmup_frames":10,"measured_frames":measured,"dt":1.0/60,"alternating":true}))
 exercise_dynamic(assets,parent)
 print("SUMMON_SIZE_STEP_PASS exact particles/RNG/all mesh arrays, all 16 sources, fractional steps, rewind and stop")
 parent.free();quit()
func curve_for(mode:int,keys:Array)->Dictionary:
 return {"minMaxState":mode,"scalar":1.7,"minScalar":.3,"maxCurve":{"m_Curve":keys},"minCurve":{"m_Curve":[{"time":0.0,"value":.2,"inSlope":0.0,"outSlope":.7},{"time":1.0,"value":.9,"inSlope":-.2,"outSlope":0.0}]}}
func exercise_dynamic(assets,parent):
 var scalar_checks=0
 var ordinary=[{"time":0.0,"value":.1,"outSlope":.2},{"time":.5,"value":.8,"inSlope":-.3,"outSlope":.7},{"time":1.0,"value":.4,"inSlope":.5}]
 var repeated=ordinary.duplicate(true);repeated[1].time=0.0
 var weighted=ordinary.duplicate(true);weighted[0].weightedMode=2;weighted[0].outWeight=.2
 var held=ordinary.duplicate(true);held[0].outSlope="Infinity"
 var sets=[[],[{"time":.2,"value":.7}],ordinary,repeated,weighted,held]
 for keys in sets:
  for mode in range(5):
   var spec=curve_for(mode,keys)
   var sampler=preload("res://scripts/particle_size_sampler.gd").new();sampler.setup(spec,Solver.Curves)
   if keys==weighted:assert(not sampler.valid or mode in [0,3],"weighted fallback")
   var ages=[-1.0,0.0,.2,.5,1.0,2.0,INF,-INF]
   for keyframe in keys:ages.append_array([float(keyframe.time)-1e-8,float(keyframe.time),float(keyframe.time)+1e-8])
   for at in ages:
    for mix_value in [0.0,.371,1.0]:
     var a=sampler.sample(at,mix_value);var b=Solver.Curves.minmax(spec,at,mix_value)
     assert(a==b or (is_nan(a) and is_nan(b)),"exact size mode "+str(mode)+" at "+str(at));scalar_checks+=1
 var key="cab-69c88b234dfa427e02d1fcee9337ae34:6590410617251757833"
 var derived=Derived.new();derived.raw=assets.objects[key].data;assert(derived._frame_size_sampler()==null,"subclass callback fallback");derived.free()
 var record=assets.objects[key];var go=str(record.refs.get(".m_GameObject",""))
 for seed_value in [1,731,99001]:
  var node=Node3D.new();parent.add_child(node)
  var spec={"system":record,"renderer":assets.component(go,"ParticleSystemRenderer"),"node":node}
  var a=Solver.new();var b=Solver.new();b.size_snapshot_enabled=false
  assert(a.constant_step_enabled and b.constant_step_enabled and a.color_snapshot_enabled and b.color_snapshot_enabled)
  a.setup(spec,assets,parent,seed_value);b.setup(spec,assets,parent,seed_value)
  for mode in range(5):
   var changed=record.data.duplicate(true);changed.SizeModule={"enabled":true,"curve":curve_for(mode,repeated)}
   a.raw=changed;b.raw=changed
   for at in [.123,.137,.251,.311]:
    a.seek(at);b.seek(at);compare(a,b,"size dynamic "+str(seed_value)+"/"+str(mode)+"/"+str(at))
   changed.SizeModule.curve=curve_for(mode,weighted)
   a.seek(.337);b.seek(.337);compare(a,b,"weighted mutation")
   changed.SizeModule.enabled=false
   a.seek(.35);b.seek(.35);compare(a,b,"disabled size mutation")
  a.free();b.free();node.free()
 print("SUMMON_SIZE_DYNAMIC_PASS ",scalar_checks," exact scalar sizes, 0-4 modes, empty/single/repeated/boundary/held/weighted keys, raw mutation and subclass fallback")