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
  var a=Solver.new();var b=Solver.new();b.color_snapshot_enabled=false;assert(a.constant_step_enabled and b.constant_step_enabled)
  a.setup(spec,assets,parent,1900+index);b.setup(spec,assets,parent,1900+index)
  pairs.append({"a":a,"b":b,"key":key,"new_us":0,"old_us":0,"max_live":0,"eligible":a._frame_color_sampler()!=null});index+=1
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
  print("SUMMON_COLOR_BENCH ",JSON.stringify({"key":pair.key,"eligible":pair.eligible,"max_live":pair.max_live,"old_us":pair.old_us/float(measured),"new_us":pair.new_us/float(measured)}))
 print("SUMMON_COLOR_TOTAL ",JSON.stringify({"checks":checks,"old_us":totals.x/float(measured),"new_us":totals.y/float(measured),"warmup_frames":10,"measured_frames":measured,"dt":1.0/60,"alternating":true}))
 exercise_dynamic(assets,parent)
 print("SUMMON_COLOR_STEP_PASS exact particles/RNG/all mesh arrays, all 16 sources, fractional steps, rewind and stop")
 parent.free();quit()
func gradient_for(times:Array,hold:int)->Dictionary:
 var g={"m_NumColorKeys":times.size(),"m_NumAlphaKeys":maxi(0,times.size()-1),"m_Mode":hold}
 for i in times.size():
  g["ctime"+str(i)]=times[i];g["atime"+str(i)]=times[i]
  g["key"+str(i)]={"r":.1+i*.17,"g":.9-i*.13,"b":.27+i*.07,"a":.2+i*.11}
 return g
func color_spec(mode:int,g:Dictionary)->Dictionary:
 return {"minMaxState":mode,"maxColor":{"r":.1,"g":.6,"b":.9,"a":.7},"minColor":{"r":.8,"g":.3,"b":.2,"a":.4},"maxGradient":g,"minGradient":gradient_for([0,14000,65535],1)}
func exercise_dynamic(assets,parent):
 var scalar_checks=0
 var timesets=[[],[0],[0,65535],[0,32767,65535],[0,0,65535],[0,32767,32767,65535]]
 for times in timesets:
  for hold in [0,1]:
   for mode in range(5):
    var spec=color_spec(mode,gradient_for(times,hold))
    var sampler=preload("res://scripts/particle_color_sampler.gd").new();sampler.setup(spec,Solver.Curves)
    var ages=[-1.0,0.0,1.0/65535,.25,.5,.75,1.0,2.0]
    for key_time in times:ages.append_array([float(key_time)/65535.0-1e-8,float(key_time)/65535.0,float(key_time)/65535.0+1e-8])
    for at in ages:
     for mix_value in [0.0,.371,1.0]:
      assert(sampler.sample(at,mix_value)==Solver.sample_color(spec,at,mix_value),"exact color mode "+str(mode)+" at "+str(at));scalar_checks+=1
 var key="cab-69c88b234dfa427e02d1fcee9337ae34:6590410617251757833"
 var derived=Derived.new();derived.raw=assets.objects[key].data;assert(derived._frame_color_sampler()==null,"subclass callback fallback");derived.free()
 var record=assets.objects[key];var go=str(record.refs.get(".m_GameObject",""))
 for seed_value in [1,731,99001]:
  var node=Node3D.new();parent.add_child(node)
  var spec={"system":record,"renderer":assets.component(go,"ParticleSystemRenderer"),"node":node}
  var a=Solver.new();var b=Solver.new();b.color_snapshot_enabled=false;assert(a.constant_step_enabled and b.constant_step_enabled)
  a.setup(spec,assets,parent,seed_value);b.setup(spec,assets,parent,seed_value)
  for mode in range(5):
   var changed=record.data.duplicate(true);changed.ColorModule={"enabled":true,"gradient":color_spec(mode,gradient_for([0,0,65535],mode%2))}
   a.raw=changed;b.raw=changed
   for at in [.123,.137,.251,.311]:
    a.seek(at);b.seek(at);compare(a,b,"color dynamic "+str(seed_value)+"/"+str(mode)+"/"+str(at))
   changed.ColorModule.gradient.maxGradient=gradient_for([],0)
   a.seek(.337);b.seek(.337);compare(a,b,"empty gradient mutation")
   changed.ColorModule.enabled=false
   a.seek(.35);b.seek(.35);compare(a,b,"disabled color mutation")
  a.free();b.free();node.free()
 print("SUMMON_COLOR_DYNAMIC_PASS ",scalar_checks," exact scalar colors, 0-4 modes, empty/single/repeated/boundary/step keys, raw mutation and subclass fallback")