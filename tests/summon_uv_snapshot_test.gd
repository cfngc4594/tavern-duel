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
  var a=Solver.new();var b=Solver.new();b.uv_snapshot_enabled=false;b.fraction_snapshot_enabled=false;require(a.constant_step_enabled and b.constant_step_enabled)
  a.setup(spec,assets,parent,1900+index);b.setup(spec,assets,parent,1900+index)
  pairs.append({"a":a,"b":b,"key":key,"max_live":0,"eligible":a._frame_uv_snapshot()!=null});index+=1
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
 print("SUMMON_UV_STEP_PASS exact particles/RNG/all mesh arrays, all 16 sources, fractional steps, rewind and stop")
 parent.free();quit()

func exercise_dynamic(assets,parent):
 var scalar_checks=0
 var probe=Solver.new()
 var particle={"life":.713,"tile_mix":.371,"tile_start_mix":.829,"row_mix":.76,"flip_u":.35,"flip_v":.72}
 for key in assets.objects:
  var record=assets.objects[key]
  if record.type!="ParticleSystem":continue
  probe.raw=record.data.duplicate(true)
  var snapshot=probe._frame_uv_snapshot()
  require(snapshot!=null,"all actual modules supported")
  for at in [-.001,0.0,.0001,.17825,.3565,.712999,.713,1.427]:
   for speed in [0.0,.4,1.0,2.4]:
    var sampled=snapshot.sample(particle,at,speed)
    require(sampled==probe._uv_corners(particle,at,speed),"actual exact UV "+key)
    require(sampled.is_read_only(),"cached quad immutable")
    scalar_checks+=1
 # Same dictionary mutated between seeks: each new snapshot sees new flip values.
 probe.raw={"UVModule":{"enabled":false,"flipU":0.0,"flipV":0.0}}
 for flip in [0.0,.35,1.0,INF,-INF,NAN]:
  probe.raw.UVModule.flipU=flip
  var fresh=probe._frame_uv_snapshot()
  require(fresh.sample(particle,.2,.4)==probe._uv_corners(particle,.2,.4),"in-place/nonfinite flip exact")
 var key="cab-69c88b234dfa427e02d1fcee9337ae34:817477473431060233"
 var record=assets.objects[key]
 var go=str(record.refs.get(".m_GameObject",""))
 var node=Node3D.new();parent.add_child(node)
 var spec={"system":record,"renderer":assets.component(go,"ParticleSystemRenderer"),"node":node}
 for seed in [1,731,99001]:
  var a=Solver.new();var b=Solver.new();b.uv_snapshot_enabled=false;b.fraction_snapshot_enabled=false
  a.setup(spec,assets,parent,seed);b.setup(spec,assets,parent,seed)
  for index in 24:
   var changed=record.data.duplicate(true)
   var uv=changed.UVModule
   uv.enabled=index%4!=0;uv.mode=1 if index%7==0 else 0
   uv.tilesX=3 if index%5==0 else 2;uv.tilesY=2
   uv.flipU=[0.0,.35,1.0][index%3];uv.flipV=[.72,1.0,0.0][index%3]
   uv.timeMode=index%3;uv.animationType=index%2;uv.rowMode=index%2
   uv.rowIndex=index%4-1;uv.cycles=.7+index*.11;uv.fps=13.5
   uv.speedRange={"x":.3,"y":.3 if index%3==0 else 2.0}
   a.raw=changed;b.raw=changed;probe.raw=changed
   var snapshot=probe._frame_uv_snapshot()
   if snapshot!=null:
    for at in [-.1,0.0,.17825,.3565,.713,1.427]:
     for speed in [0.0,.3,.7,2.0]:
      require(snapshot.sample(particle,at,speed)==probe._uv_corners(particle,at,speed),"dynamic exact UV")
      scalar_checks+=1
   else:require(uv.enabled and uv.mode==0 and uv.tilesX==3,"unsupported grid fallback")
   for at in [.123,.137,.137,.251,.119,.311]:
    a.seek(at);b.seek(at);compare(a,b,"raw mutation "+str(seed)+"/"+str(index)+"/"+str(at))
  a.free();b.free()
 var derived=Derived.new();derived.raw=record.data
 require(derived._frame_uv_snapshot()==null,"unknown subclass fallback")
 derived.free();probe.free();node.free()
 print("SUMMON_UV_DYNAMIC_PASS ",scalar_checks," exact UV samples; 3 seeds, dynamic enable/mode/tiles/flip/time/row, repeated/rewind, immutable quads and subclass fallback")
func require(condition:bool,message:String="exact check failed")->void:
 if not condition:
  push_error(message)
  quit(1)
  assert(condition,message)
