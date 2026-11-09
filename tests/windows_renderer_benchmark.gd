extends Node
## Formal renderer comparison, selected only by renderer_benchmark export feature.
## Runs the production game through a tiny fixed-clock subclass, never source copies.
## Capture runs write rendered frames but must not be used for timing comparisons.
var failed := false
const CombatParticles=preload("res://scripts/native_combat_particles.gd")
const Damage=preload("res://scripts/native_damage_splat.gd")
const EffectPreparer=preload("res://scripts/effect_material_preparer.gd")
const ShaderCache=preload("res://scripts/immutable_shader_cache.gd")
const Particles=preload("res://scripts/native_summon_particles.gd")
const Resident=preload("res://scripts/summon_resident.gd")
const Compute=preload("res://scripts/summon_compute.gd")
var root: Window:
 get: return get_tree().root
func require(ok: bool, label: String = "runtime check") -> void:
 if not ok:
  failed = true
  push_error("BENCH_FAIL " + label)
  Compute.enabled=false
  Compute.shutdown()
  get_tree().quit(1)
func quit() -> void:
 Compute.enabled=false
 Compute.shutdown()
 get_tree().quit(1 if failed else 0)
var game
var current_round := -1
var capture_dir := ""
func _ready():call_deferred("run")
func collect_viewports(node:Node,output:Array):
 if node is Viewport and (node==root or str(node.name) in ["OriginalBoardViewport","ClassicBoardSpatialObjects","RGBTransmissionTarget"]):
  RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(),true)
  output.append(node)
 for child in node.get_children():collect_viewports(child,output)
func stats(values:Array)->Dictionary:
 values.sort()
 if values.is_empty():return {"count":0}
 return {"count":values.size(),"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p50":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"max":values[-1]}
func measure(label:String,count:int,action:Callable):
 CombatParticles.setup_rows.clear()
 preload("res://scripts/native_archer_skin.gd").setup_rows.clear()
 CombatParticles.seek_rows.clear();CombatParticles.seek_source_totals.clear()
 game.native_summon.profile_rows.clear()
 Particles.source_times.clear()
 if Particles.profile_sources:
  game.native_combat.effect_player.profile_rows.clear()
  game.native_death.effects.profile_rows.clear()
  game.native_death.profile_rows.clear()
 var compute_before=Compute.get_stats()
 var viewports:Array=[];collect_viewports(root,viewports)
 var samples:Dictionary={"frame_ms":[],"process_ms":[],"physics_ms":[],"draw_calls":[],"render_objects":[],"primitives":[],"video_memory_bytes":[]}
 print("PROFILE_SCENE_BEGIN ",label)
 var frame_profile:Array=[]
 var frame_start_usec_trace:Array=[]
 var frame_end_usec_trace:Array=[]
 var particle_previous:=0
 var previous=Time.get_ticks_usec()
 action.call()
 var action_usec:int=Time.get_ticks_usec()-previous
 for i in count:
  await get_tree().process_frame
  var now=Time.get_ticks_usec();frame_start_usec_trace.append(previous);frame_end_usec_trace.append(now);samples.frame_ms.append((now-previous)/1000.0);previous=now
  if Particles.profile_sources:
   var particle_now:=0
   for row in Particles.source_times.values():particle_now+=int(row.usec)
   frame_profile.append({"frame":i,"frame_ms":samples.frame_ms[-1],"game_usec":game.last_process_usec,"particle_usec":particle_now-particle_previous,"stages":game.last_frame_stages.duplicate()})
   particle_previous=particle_now
  samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
  samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
  samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  samples.render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
  samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
  samples.video_memory_bytes.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
  if i>=4:
   for viewport in viewports:
    if not is_instance_valid(viewport):continue
    if viewport is SubViewport and viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED:continue
    var prefix=str(viewport.get_path())
    for metric in ["cpu","gpu"]:
     var key=prefix+"/"+metric+"_ms"
     if not samples.has(key):samples[key]=[]
     var value=RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()) if metric=="cpu" else RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
     samples[key].append(value)
  if not capture_dir.is_empty() and ((current_round==1 and ((label=="idle" and i==60) or (label=="play_senjin" and i==90) or (label=="attack_taunt" and i in [45,99,129,130,150]) or (label=="archer_battlecry" and i in [60,89,90,91,112,113,114,120,150]))) or (current_round==0 and label=="archer_battlecry" and i in [118,119,120])):
   await RenderingServer.frame_post_draw
   var filename=capture_dir+"/"+("cold_" if current_round==0 else "")+RenderingServer.get_current_rendering_method()+"_"+label+"_"+str(i)+".png"
   var error=root.get_texture().get_image().save_png(filename)
   print("CAPTURE ",filename," error=",error)
 var chronological_frame_ms:Array=samples.frame_ms.duplicate()
 var summary:Dictionary={}
 for key in samples:summary[key]=stats(samples[key])
 var compute_after=Compute.get_stats()
 var compute_delta:Dictionary={}
 for key in compute_after:
  if compute_after[key] is int:compute_delta[key]=compute_after[key]-int(compute_before.get(key,0))
 print("MONITOR_PHASE ",JSON.stringify({"phase":label,"round":current_round,"metrics":summary,"frame_ms_trace":chronological_frame_ms,"frame_start_usec_trace":frame_start_usec_trace,"frame_end_usec_trace":frame_end_usec_trace,"compute_delta":compute_delta,"compute_total":compute_after,"prepared_pool":game.native_combat.effect_player.prepared_pool.audit() if game.native_combat.effect_player.prepared_pool!=null else {"enabled":false},"resident_total":Resident.stats.duplicate(),"resident_gpu":Resident.get_gpu_stats(),"shader_cache":ShaderCache.audit(),"health":game.health,"hand":game.cards.size(),"units":game.allies.size()+game.enemies.size(),"busy":game.busy}))
 if Particles.profile_sources:
  print("SUMMON_BEGIN_PROFILE ",JSON.stringify({"phase":label,"rows":game.native_summon.profile_rows}))
  print("COMBAT_SEEK_PROFILE ",JSON.stringify({"phase":label,"rows":CombatParticles.seek_rows,"totals":CombatParticles.seek_source_totals}))
  print("PARTICLE_SETUP_PROFILE ",JSON.stringify({"phase":label,"rows":CombatParticles.setup_rows}))
  print("SKIN_SETUP_PROFILE ",JSON.stringify({"phase":label,"rows":preload("res://scripts/native_archer_skin.gd").setup_rows}))
  print("EFFECT_STAGE_PROFILE ",JSON.stringify({"phase":label,"combat":game.native_combat.effect_player.profile_rows,"death_effects":game.native_death.effects.profile_rows,"death":game.native_death.profile_rows}))
  print("PARTICLE_SOURCE_TIMES ",JSON.stringify({"phase":label,"sources":Particles.source_times}))
  frame_profile.sort_custom(func(a,b):return a.frame_ms>b.frame_ms)
  print("LONG_FRAME_PROFILE ",JSON.stringify({"phase":label,"action_usec":action_usec,"frames":frame_profile.slice(0,10)}))
 print("PROFILE_SCENE_END ",label)
func card_index(key):
 for i in game.cards.size():
  if game.cards[i].key==key:return i
 return -1
func run():
 Resident.stats.clear()
 Compute.reset_stats()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
  if arg=="--gpu-compute":Compute.enabled=true
  if arg=="--gpu-resident":Resident.enabled=true
  if arg=="--archer-prepared-scenes":preload("res://scripts/archer_prepared_scene_pool.gd").enabled=true
  if arg=="--no-archer-prepared-scenes":preload("res://scripts/archer_prepared_scene_pool.gd").enabled=false
  if arg=="--archer-skin-inputs":preload("res://scripts/native_archer_skin.gd").cache_inputs=true
  if arg=="--archer-skin-unchanged":preload("res://scripts/native_archer_skin.gd").skip_unchanged=true
  if arg=="--no-archer-skin-inputs":preload("res://scripts/native_archer_skin.gd").cache_inputs=false
  if arg=="--no-archer-skin-unchanged":preload("res://scripts/native_archer_skin.gd").skip_unchanged=false
  if arg=="--profile-sources":Particles.profile_sources=true;CombatParticles.profile_setup=true;CombatParticles.profile_seek=true;preload("res://scripts/native_archer_skin.gd").profile_setup=true
  if arg=="--skip-hidden-geometry":Particles.skip_hidden_geometry=true
  if arg=="--no-cache-mesh-surfaces":CombatParticles.mesh_surface_cache_enabled=false
  if arg=="--no-prepare-effect-materials":EffectPreparer.enabled=false
  if arg=="--no-retain-damage-shader":Damage.retain_glyph_shader=false
  if arg=="--no-prepare-transmission-materials":EffectPreparer.extended=false
  if arg=="--no-defer-death-geometry":CombatParticles.death_initial_geometry_defer_enabled=false
  if arg=="--defer-death-geometry":CombatParticles.death_initial_geometry_defer_enabled=true
  if arg=="--cache-mesh-surfaces":CombatParticles.mesh_surface_cache_enabled=true
  if arg=="--prepare-effect-materials":EffectPreparer.enabled=true
  if arg=="--no-prepare-summon-materials":EffectPreparer.summon_enabled=false;preload("res://scripts/native_summon_assets.gd").retain_shader=false
  if arg=="--prepare-summon-materials":EffectPreparer.summon_enabled=true;preload("res://scripts/native_summon_assets.gd").retain_shader=true
  if arg=="--retain-damage-shader":Damage.retain_glyph_shader=true
  if arg=="--prepare-transmission-materials":EffectPreparer.enabled=true;EffectPreparer.extended=true
  if arg=="--retain-shaders":ShaderCache.enabled=true
  if arg=="--no-retain-shaders":ShaderCache.enabled=false
  if arg=="--resident-profile-gpu":Resident.profile_gpu=true
 if not capture_dir.is_empty():DirAccess.make_dir_recursive_absolute(capture_dir)
 print("RUNNER_MODE ",JSON.stringify({"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor"),"version":Engine.get_version_info()}))
 require(not preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var loading_started:int=Time.get_ticks_usec()
 game=make_game()
 game.profile_frame_stages=Particles.profile_sources
 preload("res://scripts/native_summon_player.gd").profile_begin=Particles.profile_sources
 if "--smoke" in OS.get_cmdline_user_args():
  game.free();print("SUMMON_BENCH_SMOKE_PASS");quit();return
 root.add_child(game)
 for i in 1500:
  await get_tree().process_frame
  if not game.native_initial_loading:break
 require(not game.native_initial_loading)
 print("STARTUP_PREPARATION ",JSON.stringify({"wall_usec":Time.get_ticks_usec()-loading_started,"preparer":game.effect_material_preparer.audit() if game.effect_material_preparer!=null else {}}))
 # No assets override.
 await measure("startup_settle",180,func():
  game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false)
 require(not game._phone_hand_enabled())
 print("WINDOWS_SETUP ",JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"size":str(root.size),"phone":game._phone_hand_enabled(),"board_variant":game.original_board_bridge.probe.get("board_variant"),"vsync":DisplayServer.window_get_vsync_mode()}))
 var wp=game.original_board_bridge.probe.water_particles
 if is_instance_valid(wp):print("WINDOWS_PARTICLES ",JSON.stringify(wp.get_audit()))
 for round_index in 2:
  await run_round(round_index)
 if Resident.enabled:require(int(Resident.stats.get("frames",0))>0,"Resident path actually ran")
 if Compute.enabled:require(int(Compute.get_stats().get("dispatches",0))>0,"GPU experiment actually dispatched")
 quit()
func run_round(round_index:int):
 current_round=round_index
 if round_index>0:
  await measure("round_reset_settle",180,func():
   game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false)
 print("SUMMON_BENCH_ROUND ",round_index)
 await measure("idle",120,func():pass)
 await measure("play_senjin",180,func():require(game.play_card(card_index("CS2_179"),Vector2(800,500),1)))
 require(not game.busy and game.allies.size()==3)
 var attacker=game.allies[0];var target=game.enemies[0];var target_hp=target.hp
 await measure("attack_taunt",180,func():require(game.attack(attacker,{"type":"unit","unit":target,"pos":target.pos})))
 require(target.hp<target_hp and not game.busy)
 var hp=game.health[1]
 await measure("archer_battlecry",180,func():
  require(game.play_card(card_index("CS2_189"),Vector2(800,500),1))
  require(not game.pending_battlecry.is_empty())
  game._resolve_target(game.ENEMY_HERO))
 require(game.health[1]==hp-1 and not game.busy)
 await measure("archer_recovery_idle",180,func():pass)
 print("WINDOWS_ACTIONS_PASS ",JSON.stringify(game.event_trace))


func make_game():
 return preload("res://tests/windows_renderer_benchmark_game.gd").new()
