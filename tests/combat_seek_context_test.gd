extends SceneTree
## Exact-output coverage and an optional real-source CPU microbenchmark.
## --benchmark measures synchronous Archer samples, not rendering or game FPS.
const Solver=preload("res://scripts/native_combat_particles.gd")
const Archer=preload("res://scripts/native_archer_effect.gd")
const Assets=preload("res://scripts/native_combat_assets.gd")
class Derived extends Solver:
 func _velocity_over_life(p:Dictionary,normalized:float)->Vector3:
  return super._velocity_over_life(p,normalized)
var failed:=false
var checks:=0
var meshes:=0
var serial_samples:=0
var worker_samples:=0
var game
func check(ok:bool,label:String):
 if not ok:failed=true;push_error("COMBAT_SEEK_CONTEXT_FAIL "+label)
func compare_solver(a,b,label:String):
 check(not a._seek_context_active and not b._seek_context_active,label+" context escaped seek")
 check(var_to_bytes(a.particles)==var_to_bytes(b.particles),label+" particles")
 check(a.rng.state==b.rng.state and a.death_rng.state==b.death_rng.state,label+" RNG")
 for field in ["emitted_count","live_count","active","collision_count","screen_size_clamped","simulation_time","stop_time","death_events","subemitter_emitted","pending_events","speed_segments","last_emitter","last_local_scale"]:
  check(var_to_bytes(a.get(field))==var_to_bytes(b.get(field)),label+" "+field)
 check(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces")
 for i in mini(a.mesh.get_surface_count(),b.mesh.get_surface_count()):
  check(var_to_bytes(a.mesh.surface_get_arrays(i))==var_to_bytes(b.mesh.surface_get_arrays(i)),label+" mesh "+str(i));meshes+=1
 check(a.mesh_instance.visible==b.mesh_instance.visible,label+" visibility")
 check(a.subemitter_templates.size()==b.subemitter_templates.size(),label+" templates")
 for i in mini(a.subemitter_templates.size(),b.subemitter_templates.size()):compare_solver(a.subemitter_templates[i].solver,b.subemitter_templates[i].solver,label+" child")
 if a.live_count>0:
  if a._worker_states.is_empty():serial_samples+=1
  else:worker_samples+=1
 checks+=1
func compare_effect(a:Dictionary,b:Dictionary,label:String):
 check(var_to_bytes(a.events)==var_to_bytes(b.events),label+" events")
 check(a.particles.keys()==b.particles.keys(),label+" particle keys")
 for key in a.particles:compare_solver(a.particles[key].node,b.particles[key].node,label+" "+key)
func new_fx():
 var fx=Archer.new();game.add_child(fx)
 var assets=Assets.new();assets.setup(game.native_card_renderer);fx.setup(game,assets)
 return fx
func context()->Dictionary:
 return {"key":"CS2_189","side":0,"source":Vector2(800,800),"target":{"type":"hero","side":1,"pos":game.ENEMY_HERO}}
func spawn(fx,route:String,enabled:bool,seed_value:int)->Dictionary:
 Solver.seek_context_enabled=enabled
 return fx._spawn_route(route,game.ENEMY_HERO,"Birth" if route.ends_with("missile") else "Death",seed_value,context())
func sample(fx,effect:Dictionary,at:float,enabled:bool):
 Solver.seek_context_enabled=enabled;effect.age=at;fx.clock_seconds=at;fx._sample(effect)
func _initialize():call_deferred("run")
func run():
 check(not Solver.seek_context_enabled,"experiment is disabled by default")
 game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.headless=false;game._setup_spatial_presentation()
 # Keep prepared-scene inventory work outside this focused comparison.
 preload("res://scripts/archer_prepared_scene_pool.gd").enabled=false
 if "--serial-source-benchmark" in OS.get_cmdline_user_args():
  benchmark_serial_sources();game.free();quit(1 if failed else 0);return
 if "--benchmark" in OS.get_cmdline_user_args():
  benchmark();game.free();quit(1 if failed else 0);return
 var reference=new_fx();var candidate=new_fx()
 for seed_value in [1,731,99001]:
  for route in ["CS2_189/missile","CS2_189/impact"]:
   var a=spawn(reference,route,false,seed_value);var b=spawn(candidate,route,true,seed_value)
   for frame in range(96):
    var at:float=frame/60.0
    if frame%2==0:sample(reference,a,at,false);sample(candidate,b,at,true)
    else:sample(candidate,b,at,true);sample(reference,a,at,false)
    compare_effect(a,b,route+" "+str(seed_value)+" frame "+str(frame))
   for at in [1.613,1.619,.437,.451,1.73]:
    sample(reference,a,at,false);sample(candidate,b,at,true);compare_effect(a,b,"fractional/rewind "+str(at))
   reference.cancel_all();candidate.cancel_all()
 dynamic_cases(reference.assets)
 reference.free();candidate.free();game.free()
 Solver.seek_context_enabled=false
 check(serial_samples>0 and worker_samples>0,"real-source serial and worker coverage")
 if not failed:print("COMBAT_SEEK_CONTEXT_PASS checks=",checks," meshes=",meshes," serial_samples=",serial_samples," worker_samples=",worker_samples," exact particle/RNG/events/mesh; dynamic/rewind/direct/subclass")
 quit(1 if failed else 0)
func dynamic_cases(assets):
 var key:String=""
 for candidate in assets.objects:
  if assets.objects[candidate].type=="ParticleSystem":key=candidate;break
 check(not key.is_empty(),"dynamic source exists")
 if key.is_empty():return
 var record:Dictionary=assets.objects[key]
 var world:=Node3D.new();root.add_child(world)
 var node:=Node3D.new();world.add_child(node)
 var spec:Dictionary={"system":record,"renderer":assets.component(str(record.refs.get(".m_GameObject","")),"ParticleSystemRenderer"),"node":node,"autoplay":false}
 var a=Solver.new();var b=Solver.new()
 Solver.seek_context_enabled=false;a.setup(spec,assets,world,993)
 Solver.seek_context_enabled=true;b.setup(spec,assets,world,993)
 # Use real spawn fields but enough particles to cover serial and worker thresholds.
 for world_mode in [0,1]:
  for count in [1,17,31,32,65]:
   a.particles.clear();b.particles.clear()
   for solver in [a,b]:
    solver.raw.moveWithTransform=world_mode
    solver.raw.InitialModule.startLifetime={"scalar":5.0}
    solver.raw.InitialModule.maxNumParticles=1000
    solver.emit_from_parent(Vector3(.2,.3,.4),0.0,count)
    check(solver.particles.size()==count,"requested dynamic particle count")
   for mode in ["zero","world_zero","constant","random_force","curve","drag","by_speed","collision"]:
    var changed:Dictionary=a.raw.duplicate(true)
    changed.VelocityModule={"enabled":true,"x":{"scalar":0.0},"y":{"scalar":0.0},"z":{"scalar":0.0},"speedModifier":{"scalar":1.0},"inWorldSpace":mode=="world_zero"}
    changed.ClampVelocityModule={"enabled":false}
    changed.RotationBySpeedModule={"enabled":false}
    changed.ForceModule={"enabled":false}
    if mode=="constant":changed.VelocityModule.x={"minMaxState":3,"minScalar":-.3,"scalar":.8}
    if mode=="random_force":changed.ForceModule={"enabled":true,"randomizePerFrame":true,"x":{"minMaxState":3,"minScalar":-.4,"scalar":.9},"y":{"scalar":.3},"z":{"scalar":-.7}}
    if mode=="curve":changed.VelocityModule.x={"minMaxState":1,"scalar":.4,"maxCurve":{"m_Curve":[{"time":0.0,"value":0.0},{"time":1.0,"value":1.0}]}}
    if mode=="drag":changed.ClampVelocityModule={"enabled":true,"drag":{"scalar":.3},"magnitude":{"scalar":3.0},"dampen":.2}
    if mode=="by_speed":changed.RotationBySpeedModule={"enabled":true,"curve":{"scalar":.7}}
    a.raw=changed.duplicate(true);b.raw=changed.duplicate(true)
    var plane:=Node3D.new();world.add_child(plane)
    a.collision_planes=[plane] if mode=="collision" else [];b.collision_planes=a.collision_planes
    for at in [.123,.137,.251,.311]:
     Solver.seek_context_enabled=false;a.seek(at)
     Solver.seek_context_enabled=true;b.seek(at)
     compare_solver(a,b,"dynamic "+str(world_mode)+"/"+str(count)+"/"+mode+"/"+str(at))
    # Mutating raw between public calls must never reuse seek-local decisions.
    a.raw.VelocityModule.x={"scalar":.91};b.raw.VelocityModule.x={"scalar":.91}
    if not a.particles.is_empty():
     var pa:Dictionary=a.particles[0].duplicate(true);var pb:Dictionary=b.particles[0].duplicate(true)
     Solver.seek_context_enabled=false;var expected:Vector3=a._position(pa,.319)
     Solver.seek_context_enabled=true;var actual:Vector3=b._position(pb,.319)
     check(var_to_bytes(expected)==var_to_bytes(actual) and var_to_bytes(pa)==var_to_bytes(pb),"direct helper fresh raw")
    a.collision_planes=[];b.collision_planes=[];plane.free()
 # Mesh clear/upload signals may edit modules between the worker stage and
 # serial geometry. Cache only after clear, and clear it before the upload.
 a.particles=a.particles.slice(0,17);b.particles=b.particles.slice(0,17)
 var changes:Array[int]=[0,0]
 var mutate_a:Callable=func():
  check(not a._seek_context_active,"reference mesh callback outside context")
  changes[0]+=1;a.raw.VelocityModule.x={"minMaxState":0,"scalar":float(changes[0])*.13}
 var mutate_b:Callable=func():
  check(not b._seek_context_active,"candidate mesh callback outside context")
  changes[1]+=1;b.raw.VelocityModule.x={"minMaxState":0,"scalar":float(changes[1])*.13}
 a.mesh.changed.connect(mutate_a);b.mesh.changed.connect(mutate_b)
 for at in [.401,.417,.433]:
  Solver.seek_context_enabled=false;a.seek(at)
  Solver.seek_context_enabled=true;b.seek(at);compare_solver(a,b,"mesh changed module mutation")
 a.mesh.changed.disconnect(mutate_a);b.mesh.changed.disconnect(mutate_b)
 check(changes[0]==changes[1],"matching mesh changed notifications")
 print("COMBAT_SEEK_CONTEXT_MESH_CHANGED callbacks=",changes[0])
 # Guard inputs are tested at a saved step boundary. Advancing a singular
 # basis would make the unchanged reference itself emit inverse-basis errors.
 a.raw.VelocityModule={"enabled":true,"inWorldSpace":true,"speedModifier":{"scalar":1.0}}
 b.raw=a.raw.duplicate(true)
 for basis in [Basis.from_scale(Vector3(0,1,1)),Basis.from_scale(Vector3(.000000001,1,1)),Basis(Vector3(NAN,0,0),Vector3.UP,Vector3.BACK),Basis(Vector3(INF,0,0),Vector3.UP,Vector3.BACK)]:
  var pa:Dictionary=a.particles[0].duplicate(true);var pb:Dictionary=b.particles[0].duplicate(true)
  pa.motion_basis=basis;pb.motion_basis=basis
  Solver.seek_context_enabled=false
  var expected:Dictionary=a._particle_state(pa,float(pa.sim_age))
  Solver.seek_context_enabled=true;b._prepare_seek_context()
  check(b._seek_context_active and b._seek_world_velocity and b._seek_zero_linear,"guard context prepared")
  var actual:Dictionary=b._particle_state(pb,float(pb.sim_age))
  b._seek_context_active=false
  check(var_to_bytes(expected)==var_to_bytes(actual) and var_to_bytes(pa)==var_to_bytes(pb),"degenerate saved-step state exact")
 for script in [Derived,preload("res://scripts/native_death_particles.gd"),preload("res://scripts/native_coin_drop_particles.gd")]:
  var derived=script.new();derived.raw=a.raw
  derived._prepare_seek_context();check(not derived._seek_context_active,"subclass fallback");derived.free()
 # Cleanup and empty-mesh exits must also leave public helpers unscoped.
 a.raw.VelocityModule={"enabled":false};b.raw=a.raw.duplicate(true)
 a.stop_emitting(.4);b.stop_emitting(.4)
 Solver.seek_context_enabled=false;a.seek(8.0)
 Solver.seek_context_enabled=true;b.seek(8.0);compare_solver(a,b,"stopped empty geometry")
 a.source_destroy();b.source_destroy()
 Solver.seek_context_enabled=false;a.seek(8.1)
 Solver.seek_context_enabled=true;b.seek(8.1)
 check(not a._seek_context_active and not b._seek_context_active,"destroyed early return cleared context")
 a.free();b.free();world.free()
func benchmark():
 var fx=new_fx()
 var order:Array=[false,true,true,false,false,true,true,false]
 var repeats:int=3
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--repeats="):repeats=int(arg.trim_prefix("--repeats="))
 check(repeats>0,"benchmark repeats must be positive")
 if failed:
  fx.free();return
 # Untimed warmup loads resources and compiled shaders in the dummy renderer.
 bench_sample(fx,false,1);bench_sample(fx,true,1)
 for enabled in order:
  var result:Dictionary=bench_sample(fx,enabled,repeats)
  print("COMBAT_SEEK_CONTEXT_BENCH ",JSON.stringify(result))
 fx.free();Solver.seek_context_enabled=false
func bench_sample(fx,enabled:bool,repeats:int)->Dictionary:
 var elapsed:int=0
 var samples:Array[int]=[]
 var route_samples:Dictionary={}
 for repetition in repeats:
  for route in ["CS2_189/missile","CS2_189/impact"]:
   var effect:Dictionary=spawn(fx,route,enabled,71)
   if not route_samples.has(route):route_samples[route]=[]
   for frame in 120:
    Solver.seek_context_enabled=enabled;effect.age=frame/60.0;fx.clock_seconds=effect.age
    var start:int=Time.get_ticks_usec();fx._sample(effect)
    var usec:int=Time.get_ticks_usec()-start
    elapsed+=usec;samples.append(usec);route_samples[route].append(usec)
   fx.cancel_all()
 check(not samples.is_empty(),"route benchmark must collect samples")
 if samples.is_empty():return {}
 return {"enabled":enabled,"repeats":repeats,"samples":samples.size(),"usec":elapsed,"sample_mean_usec":float(elapsed)/samples.size(),"samples_usec":samples,"route_samples_usec":route_samples,"headless_cpu_only":true}

func benchmark_serial_sources():
 # These three real Archer systems stay below the original 32-particle worker
 # threshold. No altered counts, lifetimes, curves or synthetic particle data.
 var keys:Array[String]=["cab-e988daf8172a43d0c6716d70aa00e51e:521423728619368968","cab-e988daf8172a43d0c6716d70aa00e51e:-2897796497230450168","cab-e988daf8172a43d0c6716d70aa00e51e:-2402744672199822840"]
 var fx=new_fx()
 var effects:Array=[]
 for route in ["CS2_189/missile","CS2_189/impact"]:effects.append(spawn(fx,route,false,71))
 var specs:Dictionary={}
 for effect in effects:
  for key in effect.state.particles:
   var spec:Dictionary=effect.state.particles[key]
   var source_key:String=str(spec.system.key)
   if source_key in keys:specs[source_key]={"spec":spec,"parent":effect.projection}
 check(specs.size()==keys.size(),"all real serial source specs found")
 if failed:
  fx.cancel_all();fx.free();return
 var repeats:int=20
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--repeats="):repeats=int(arg.trim_prefix("--repeats="))
 check(repeats>0,"benchmark repeats must be positive")
 if failed:
  fx.cancel_all();fx.free();return
 serial_source_sample(fx.assets,specs,false,2);serial_source_sample(fx.assets,specs,true,2)
 for enabled in [false,true,true,false,false,true,true,false]:
  print("COMBAT_SEEK_CONTEXT_SERIAL_BENCH ",JSON.stringify(serial_source_sample(fx.assets,specs,enabled,repeats)))
 fx.cancel_all();fx.free();Solver.seek_context_enabled=false
func serial_source_sample(assets,specs:Dictionary,enabled:bool,repeats:int)->Dictionary:
 var samples:Array[int]=[];var sources:Dictionary={};var total:int=0
 Solver.seek_context_enabled=enabled
 for key in specs:
  var info:Dictionary=specs[key]
  sources[key]={"samples_usec":[],"live_max":0,"emitted":0}
  for repetition in repeats:
   var solver=Solver.new();solver.setup(info.spec,assets,info.parent,71)
   for frame in 120:
    var start:int=Time.get_ticks_usec();solver.seek((frame+1)/60.0)
    var usec:int=Time.get_ticks_usec()-start
    total+=usec;samples.append(usec);sources[key].samples_usec.append(usec)
    sources[key].live_max=maxi(sources[key].live_max,solver.live_count)
    check(solver._worker_states.is_empty(),"serial real source remains below worker threshold")
   sources[key].emitted=solver.emitted_count
   solver.free()
 check(not samples.is_empty(),"serial benchmark must collect samples")
 if samples.is_empty():return {}
 return {"enabled":enabled,"repeats":repeats,"samples":samples.size(),"sample_mean_usec":float(total)/samples.size(),"samples_usec":samples,"sources":sources,"headless_cpu_only":true}
