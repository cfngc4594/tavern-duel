extends SceneTree
const Solver=preload("res://original_board/scripts/source_particle_solver.gd")
func _initialize():call_deferred("run")
func check_equal(a,b,label:String):
 assert(a.live_count==b.live_count and a.emitted_count==b.emitted_count and a.rng.state==b.rng.state and a.screen_size_clamped==b.screen_size_clamped,label+" counts/RNG/clamp")
 assert(a.particles.size()==b.particles.size(),label+" storage")
 for i in a.particles.size():
  for key in ["birth","life","sim_age","displacement","sim_velocity","sim_rotation","sim_render_velocity","kill_age","collision_loss","collision_hits"]:
   var x=a.particles[i][key];var y=b.particles[i][key]
   if x is Vector3:assert(x.is_equal_approx(y),label+" "+key)
   elif x is float:assert(x==y or is_equal_approx(x,y),label+" "+key)
   else:assert(x==y,label+" "+key)
 assert(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces")
 if a.mesh.get_surface_count()>0:
  var aa=a.mesh.surface_get_arrays(0);var bb=b.mesh.surface_get_arrays(0)
  for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:
   assert(aa[channel]==bb[channel],label+" mesh channel "+str(channel))
func run():
 var reference=Solver
 preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.source_phone_layout.refresh()
 var probe=game.original_board_bridge.probe;var host=probe.water_particles
 var pairs=[]
 for key in host.entries:
  var e=host.entries[key]
  if not is_instance_valid(e.current):continue
  var current=e.current
  var old=reference.new();old.frame_draw_snapshot_enabled=false
  var spec={"system":e.row.system,"renderer":e.row.renderer,"node":e.proxy,"autoplay":true,"compatibility_basis":host.REFLECTION,"source_scope_root":probe.source_root}
  for option in e.row.get("solver_options",{}):spec[option]=e.row.solver_options[option]
  old.setup(spec,host,host,current.rng.seed)
  pairs.append({"name":e.row.name,"current":current,"old":old,"new_us":0,"old_us":0})
 assert(pairs.size()>0)
 for frame in 360:
  var at=(frame+1)/60.0
  for pair in pairs:
   # Alternate ordering to reduce clock/load bias. First120 frames warm up.
   for which in (["current","old"] if frame%2==0 else ["old","current"]):
    var solver=pair[which];var t=Time.get_ticks_usec();solver.seek(at)
    if frame>=120:pair["new_us" if which=="current" else "old_us"]+=Time.get_ticks_usec()-t
    var now=solver.simulation_time
    solver.particles=solver.particles.filter(func(p):return now-float(p.birth)<float(p.life))
   if frame%15==0 or frame==359:check_equal(pair.current,pair.old,str(pair.name)+" frame "+str(frame))
 var totals=Vector2.ZERO
 for pair in pairs:
  totals+=Vector2(pair.old_us,pair.new_us)
  print("DRAW_BENCH ",pair.name," live=",pair.current.live_count," old_us=",pair.old_us/240.0," new_us=",pair.new_us/240.0)
  # Retained public rewind and stop-tail contracts.
  pair.current.seek(5.9);pair.old.seek(5.9);check_equal(pair.current,pair.old,pair.name+" rewind")
  pair.current.stop_emitting();pair.old.stop_emitting()
  pair.current.seek(7.0);pair.old.seek(7.0);check_equal(pair.current,pair.old,pair.name+" stopped")
 # Empty batches and an explicitly larger batch retain the dispatch boundary.
 var pair=pairs[0]
 pair.current.particles.clear();pair.old.particles.clear()
 pair.current.seek(7.0);pair.old.seek(7.0);check_equal(pair.current,pair.old,"empty")
 # Restart timing is irrelevant here: emit_count is a supported explicit birth.
 pair.current.stop_time=INF;pair.old.stop_time=INF
 pair.current.emit_count(160,7.0);pair.old.emit_count(160,7.0)
 pair.current.seek(7.05);pair.old.seek(7.05);check_equal(pair.current,pair.old,"large")
 assert(pair.current.live_count>128)
 # Snapshots must be rebuilt when source data, emitter TRS or camera changes.
 for world in [0,1]:
  pair.current.raw.moveWithTransform=world;pair.old.raw.moveWithTransform=world
  for mode in [0,1,2]:
   pair.current.source_renderer.m_RenderMode=mode;pair.old.source_renderer.m_RenderMode=mode
   pair.current.source_node.position+=Vector3(.02,.01,0)
   probe.camera.rotation.y+=.001
   pair.current.seek(7.06);pair.old.seek(7.06)
   check_equal(pair.current,pair.old,"dynamic world/renderer/camera "+str(world)+"/"+str(mode))
 # The fixed UV corner table still reads runtime flip thresholds and defers
 # enabled atlas animation to the existing particle-specific sampling path.
 for flip_u in [0.0,1.0]:
  for flip_v in [0.0,1.0]:
   for solver in [pair.current,pair.old]:
    solver.raw.UVModule.flipU=flip_u;solver.raw.UVModule.flipV=flip_v
    solver.seek(7.07)
   check_equal(pair.current,pair.old,"UV orientation "+str(Vector2(flip_u,flip_v)))
 for solver in [pair.current,pair.old]:
  solver.raw.UVModule.enabled=true;solver.raw.UVModule.tilesX=2;solver.raw.UVModule.tilesY=2
  solver.seek(7.08)
 check_equal(pair.current,pair.old,"dynamic atlas")
 print("DRAW_BENCH_TOTAL old_us=",totals.x/240.0," new_us=",totals.y/240.0," warmup_frames=120 measured_frames=240 dt=1/60 alternating_order=true")
 print("PHONE_PARTICLE_DRAW_SNAPSHOT_PASS original seeds, counts, numerical states, exact mesh arrays, rewind and stop tails")
 game.queue_free();quit()
