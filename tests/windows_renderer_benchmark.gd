extends Node
## Formal renderer comparison, selected only by renderer_benchmark export feature.
## Runs the production game through a tiny fixed-clock subclass, never source copies.
## Capture runs write rendered frames but must not be used for timing comparisons.
var failed := false
const BenchmarkMetrics=preload("res://tests/renderer_benchmark_metrics.gd")
const CombatParticles=preload("res://scripts/native_combat_particles.gd")
const Damage=preload("res://scripts/native_damage_splat.gd")
const EffectPreparer=preload("res://scripts/effect_material_preparer.gd")
const ShaderCache=preload("res://scripts/immutable_shader_cache.gd")
const Particles=preload("res://scripts/native_summon_particles.gd")
const Resident=preload("res://scripts/summon_resident.gd")
const Compute=preload("res://scripts/summon_compute.gd")
const BoardSourceStore=preload("res://original_board/scripts/board_source_store.gd")
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
var benchmark_metrics=BenchmarkMetrics.new()
var benchmark_environment: Dictionary = {}
var profile_pipelines := false
var stress_board := false
var benchmark_rounds := 2
var native_profiler := false
var defer_highlight_arrays := false
var board_source_bundle := false
var stress_repetitions := 0
var stress_only := false
var headless_cpu_visuals := false
var battlecry_action_index := 0
var phase_context: Dictionary = {}
func _ready():call_deferred("run")
func collect_viewports(node:Node,output:Array):
 if node is Viewport and (node==root or str(node.name) in ["OriginalBoardViewport","ClassicBoardSpatialObjects","RGBTransmissionTarget"]):
  if benchmark_environment.get("rendering_active",false):RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(),true)
  output.append(node)
 for child in node.get_children():collect_viewports(child,output)
func stats(values:Array)->Dictionary:
 return BenchmarkMetrics.stats(values)
func memory_snapshot()->Dictionary:
 var result:Dictionary={"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resource_count":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
 for method in ["get_static_memory_usage","get_static_memory_peak_usage"]:
  var value=OS.call(method) if OS.has_method(method) else 0
  result[method]={"available":value>0,"bytes":value if value>0 else null,"reason":"" if value>0 else "unsupported_or_static_tracking_disabled"}
 result["video_memory_bytes"]={"available":benchmark_environment.get("rendering_active",false),"bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) if benchmark_environment.get("rendering_active",false) else null}
 return result
func append_memory_samples(samples:Dictionary)->void:
 samples.static_memory_bytes.append(Performance.get_monitor(Performance.MEMORY_STATIC))
 samples.node_count.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 samples.resource_count.append(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
func measure(label:String,count:int,action:Callable):
 if native_profiler:EngineDebugger.send_message("benchmark:phase",[label,current_round,Time.get_ticks_usec()])
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
 var pipeline_before=benchmark_metrics.pipeline_snapshot()
 var pipeline_trace:Array=[]
 var visual_evidence:Dictionary={"particle_systems_peak":0,"particle_mesh_vertices_peak":0,"archer_skin_vertices_peak":0}
 var viewports:Array=[];collect_viewports(root,viewports)
 var samples:Dictionary={"frame_ms":[],"game_process_ms":[],"process_ms":[],"physics_ms":[],"draw_calls":[],"render_objects":[],"primitives":[],"video_memory_bytes":[],"static_memory_bytes":[],"node_count":[],"resource_count":[]}
 var memory_before=memory_snapshot()
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
  samples.game_process_ms.append(game.last_process_usec/1000.0)
  samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
  samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
  append_memory_samples(samples)
  if profile_pipelines and benchmark_metrics.pipeline_status.available:pipeline_trace.append(benchmark_metrics.pipeline_snapshot())
  if headless_cpu_visuals:observe_cpu_visuals(visual_evidence)
  if benchmark_environment.rendering_active:
   samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
   samples.render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
   samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
   samples.video_memory_bytes.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
  if i>=4 and benchmark_environment.rendering_active:
   if not samples.has("frame_setup_cpu_ms"):samples["frame_setup_cpu_ms"]=[]
   samples.frame_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
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
 for key in samples:
  summary[key]=BenchmarkMetrics.stats(samples[key],"zero_only_viewport_timing_unavailable" if str(key).ends_with("_ms") and str(key).contains("/") else "")
  if key=="static_memory_bytes":summary[key]=BenchmarkMetrics.stats(samples[key],"static_tracking_unavailable_when_zero")
  if not benchmark_environment.rendering_active and key in ["draw_calls","render_objects","primitives","video_memory_bytes"]:
   summary[key]={"count":0,"available":false,"reason":benchmark_environment.unavailable_reason}
 var pipeline_after=benchmark_metrics.pipeline_snapshot()
 var compute_after=Compute.get_stats()
 var memory_after=memory_snapshot()
 var compute_delta:Dictionary={}
 for key in compute_after:
  if compute_after[key] is int:compute_delta[key]=compute_after[key]-int(compute_before.get(key,0))
 print("MONITOR_PHASE ",JSON.stringify({"phase":label,"round":current_round,"measurement_complete":true,"start_usec":frame_start_usec_trace[0],"ready_usec":frame_end_usec_trace[-1],"metrics":summary,"raw_samples":samples,"action_usec":action_usec,"measurement_scope":benchmark_environment.measurement_scope,"context":phase_context,"memory_before":memory_before,"memory_after":memory_after,"board_source_store":BoardSourceStore.get_audit(),"pipeline_compilations":{"status":benchmark_metrics.pipeline_status,"before":pipeline_before,"after":pipeline_after,"delta":BenchmarkMetrics.counter_delta(pipeline_before,pipeline_after),"frame_totals":pipeline_trace},"cpu_visual_evidence":visual_evidence,"frame_ms_trace":chronological_frame_ms,"frame_start_usec_trace":frame_start_usec_trace,"frame_end_usec_trace":frame_end_usec_trace,"compute_delta":compute_delta,"compute_total":compute_after,"prepared_pool":game.native_combat.effect_player.prepared_pool.audit() if game.native_combat.effect_player.prepared_pool!=null else {"enabled":false},"resident_total":Resident.stats.duplicate(),"resident_gpu":Resident.get_gpu_stats(),"shader_cache":ShaderCache.audit(),"health":game.health,"hand":game.cards.size(),"units":game.allies.size()+game.enemies.size(),"busy":game.busy}))
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
 return {"metrics":summary,"raw_samples":samples,"action_usec":action_usec,"cpu_visual_evidence":visual_evidence}
func card_index(key):
 for i in game.cards.size():
  if game.cards[i].key==key:return i
 return -1
func run():
 Resident.stats.clear()
 Compute.reset_stats()
 for arg in OS.get_cmdline_user_args():
  if arg=="--profile-pipelines":profile_pipelines=true
  if arg=="--native-profiler":native_profiler=true
  if arg=="--defer-highlight-arrays":defer_highlight_arrays=true
  if arg=="--no-defer-highlight-arrays":defer_highlight_arrays=false
  if arg=="--board-source-bundle":board_source_bundle=true
  if arg=="--no-board-source-bundle":board_source_bundle=false
  if arg=="--stress-board":stress_board=true
  if arg.begins_with("--benchmark-rounds="):
   var value=arg.trim_prefix("--benchmark-rounds=")
   require(value.is_valid_int() and int(value)>=2 and int(value)<=20,"benchmark-rounds must be an integer from 2 to 20")
   if failed:return
   benchmark_rounds=int(value)
  if arg=="--battlecry-stress-only":stress_only=true
  if arg=="--headless-cpu-visuals":headless_cpu_visuals=true
  if arg.begins_with("--battlecry-stress="):
   var value=arg.trim_prefix("--battlecry-stress=")
   require(value.is_valid_int() and int(value)>=2 and int(value)<=100,"battlecry-stress must be an integer from 2 to 100")
   if failed:return
   stress_repetitions=int(value)
  if arg=="--combat-seek-context":CombatParticles.seek_context_enabled=true
  if arg=="--no-combat-seek-context":CombatParticles.seek_context_enabled=false
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
 benchmark_environment=BenchmarkMetrics.environment()
 var privacy_guard=root.get_node_or_null("PrivacyTestGuard")
 var privacy_active:bool=privacy_guard!=null and privacy_guard.runtime_evidence().active
 benchmark_environment["privacy_mask_active"]=privacy_active
 if privacy_active and benchmark_environment.rendering_active:
  benchmark_environment.measurement_scope+="_privacy_mask"
  benchmark_environment["privacy_timing_limit"]="The opaque mask adds GPU work and can affect culling/overdraw. These are privacy-mode measurements, not unobstructed visible-game FPS."
 require(not native_profiler or EngineDebugger.is_active(),"native-profiler requires an attached remote debugger")
 require(not stress_only or stress_repetitions>0,"stress-only requires --battlecry-stress=N")
 require(not headless_cpu_visuals or benchmark_environment.headless,"CPU visual fixture requires --headless")
 require(capture_dir.is_empty() or benchmark_environment.rendering_active,"capture requires a real rendering backend")
 if failed:return
 if headless_cpu_visuals:
  benchmark_environment.measurement_scope="headless_partial_cpu_visuals"
  benchmark_environment.limitations="Dummy renderer. Spatial/effect CPU construction enabled explicitly; normal turn UI, completed card texture baking/startup and GPU/raster work are absent. Not full-game FPS."
 benchmark_environment["source_profiling"]=Particles.profile_sources
 benchmark_environment["pipeline_profiling"]=profile_pipelines
 benchmark_environment["capture_run"]=not capture_dir.is_empty()
 benchmark_environment["stress_repetitions"]=stress_repetitions
 benchmark_environment["stress_only"]=stress_only
 benchmark_environment["benchmark_rounds"]=benchmark_rounds
 benchmark_environment["stress_board"]=stress_board
 benchmark_environment["native_profiler"]=native_profiler
 benchmark_environment["defer_highlight_arrays"]=defer_highlight_arrays
 benchmark_environment["board_source_bundle"]=board_source_bundle
 benchmark_environment["load_memory_instrumentation"]=1
 benchmark_environment["memory_scope_note"]="Godot tracked allocation and object/resource counters, not OS working set. Static zero-only samples are unavailable; OS static/peak APIs are probed at runtime and zero is unavailable. Counters may lag frames."
 BoardSourceStore.enabled=board_source_bundle
 benchmark_environment["timestamp_query_capacity"]=ProjectSettings.get_setting_with_override("debug/settings/profiler/max_timestamp_query_elements")
 benchmark_environment["user_args"]=OS.get_cmdline_user_args()
 benchmark_environment["engine_args"]=OS.get_cmdline_args()
 benchmark_metrics.configure_pipelines(profile_pipelines,benchmark_environment)
 if not capture_dir.is_empty():DirAccess.make_dir_recursive_absolute(capture_dir)
 print("RUNNER_MODE ",JSON.stringify({"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor"),"version":Engine.get_version_info()}))
 require(not preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform)
 if benchmark_environment.rendering_active:DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 # Export templates can consume recognized engine arguments before this API.
 # Record the effective settings as well as whatever command-line args remain.
 benchmark_environment["effective_max_fps"]=Engine.max_fps
 benchmark_environment["effective_time_scale"]=Engine.time_scale
 benchmark_environment["effective_physics_ticks_per_second"]=Engine.physics_ticks_per_second
 benchmark_environment["effective_vsync"]=DisplayServer.window_get_vsync_mode() if benchmark_environment.rendering_active else null
 print("BENCHMARK_ENVIRONMENT ",JSON.stringify(benchmark_environment))
 var boot_memory_before=memory_snapshot()
 var boot_samples:Dictionary={"frame_ms":[],"static_memory_bytes":[],"node_count":[],"resource_count":[],"video_memory_bytes":[]}
 var boot_starts:Array=[]
 var boot_ends:Array=[]
 var loading_started:int=Time.get_ticks_usec()
 game=make_game()
 var game_created:int=Time.get_ticks_usec()
 game.profile_frame_stages=Particles.profile_sources
 preload("res://scripts/native_summon_player.gd").profile_begin=Particles.profile_sources
 if "--smoke" in OS.get_cmdline_user_args():
  game.free();print("SUMMON_BENCH_SMOKE_PASS");quit();return
 var add_child_started:int=Time.get_ticks_usec()
 root.add_child(game)
 var child_added:int=Time.get_ticks_usec()
 if headless_cpu_visuals:
  game.headless=false
  game._setup_spatial_presentation()
  # Build the actual source card geometry required by clone_world_hand. The
  # normal serialized queue waits for a raster bake between cards, which a
  # dummy renderer cannot finish. This explicit CPU fixture builds every card
  # synchronously, then skips only that impossible bake-completion wait.
  for key in game.definitions:
   if not game.native_card_renderer.cards.has(key):game._build_one_native_card(key)
   require(game.native_card_renderer.cards.has(key),"CPU visual fixture built source card "+str(key))
  if failed:return
  game.native_card_loader.reset()
  game.native_initial_loading=false
  game.world_canvas.visible=true
  require(is_instance_valid(game.spatial_scene),"CPU visual fixture created the actual spatial scene")
 var synchronous_ready:int=Time.get_ticks_usec()
 var boot_previous:int=loading_started
 for i in 1500:
  await get_tree().process_frame
  var boot_now:int=Time.get_ticks_usec()
  boot_starts.append(boot_previous);boot_ends.append(boot_now);boot_samples.frame_ms.append((boot_now-boot_previous)/1000.0);boot_previous=boot_now
  append_memory_samples(boot_samples)
  if benchmark_environment.rendering_active:boot_samples.video_memory_bytes.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
  if not game.native_initial_loading:break
 var loading_ready:int=Time.get_ticks_usec()
 require(not game.native_initial_loading)
 if failed:return
 var boot_memory_after=memory_snapshot()
 var boot_metrics:Dictionary={}
 for key in boot_samples:boot_metrics[key]=BenchmarkMetrics.stats(boot_samples[key],"static_tracking_unavailable_when_zero" if key=="static_memory_bytes" else "")
 print("BOOT_LOAD ",JSON.stringify({"schema_version":1,"measurement_scope":benchmark_environment.measurement_scope,"start_usec":loading_started,"ready_usec":loading_ready,"wall_usec":loading_ready-loading_started,"game_new_usec":game_created-loading_started,"add_child_usec":child_added-add_child_started,"synchronous_preparation_usec":synchronous_ready-loading_started,"native_initial_loading_complete":not game.native_initial_loading,"raw_samples":boot_samples,"metrics":boot_metrics,"frame_start_usec_trace":boot_starts,"frame_end_usec_trace":boot_ends,"memory_before":boot_memory_before,"memory_after":boot_memory_after,"board_source_store":BoardSourceStore.get_audit(),"scope_note":"Starts before game construction, not process launch or script/resource preloads. First interval includes synchronous constructor and add_child work; intervals end at process_frame, not presentation."}))
 if is_instance_valid(game.native_highlight) and is_instance_valid(game.native_highlight.renderer):
  game.native_highlight.renderer.defer_unchanged_surface_arrays=defer_highlight_arrays
  require(game.native_highlight.renderer.defer_unchanged_surface_arrays==defer_highlight_arrays,"highlight candidate mode applied")
 else:require(not defer_highlight_arrays,"highlight candidate requires real spatial presentation")
 print("STARTUP_PREPARATION ",JSON.stringify({"wall_usec":loading_ready-loading_started,"game_new_usec":game_created-loading_started,"add_child_usec":child_added-add_child_started,"synchronous_preparation_usec":synchronous_ready-loading_started,"ready_usec":loading_ready,"preparer":game.effect_material_preparer.audit() if game.effect_material_preparer!=null else {}}))
 # No assets override.
 await measure("startup_settle",180,func():
  game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false)
 if board_source_bundle:
  var store_audit=BoardSourceStore.get_audit()
  require(store_audit.loads>0 and store_audit.json_hits>0 and store_audit.image_hits>0 and store_audit.error.is_empty() and store_audit.misses==0,"board source bundle actually loaded and served complete source data")
  if failed:return
 require(not game._phone_hand_enabled())
 print("WINDOWS_SETUP ",JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"size":str(root.size),"phone":game._phone_hand_enabled(),"board_variant":game.original_board_bridge.probe.get("board_variant"),"vsync":DisplayServer.window_get_vsync_mode()}))
 var wp=game.original_board_bridge.probe.water_particles
 if is_instance_valid(wp):print("WINDOWS_PARTICLES ",JSON.stringify(wp.get_audit()))
 if not stress_only:
  for round_index in benchmark_rounds:
   await run_round(round_index)
 if stress_board:await run_board_stress()
 if stress_repetitions>0:await run_battlecry_stress()
 if Resident.enabled:require(int(Resident.stats.get("frames",0))>0,"Resident path actually ran")
 if Compute.enabled:require(int(Compute.get_stats().get("dispatches",0))>0,"GPU experiment actually dispatched")
 if native_profiler:
  EngineDebugger.send_message("benchmark:done",[Time.get_ticks_usec()])
  await get_tree().create_timer(2.0).timeout
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
 var archer_result:Dictionary=await measure("archer_battlecry",180,func():
  require(game.play_card(card_index("CS2_189"),Vector2(800,500),1))
  require(not game.pending_battlecry.is_empty())
  game._resolve_target(game.ENEMY_HERO))
 require(game.health[1]==hp-1 and not game.busy)
 if headless_cpu_visuals:
  var evidence:Dictionary=archer_result.cpu_visual_evidence
  require(evidence.particle_systems_peak>0 and evidence.particle_mesh_vertices_peak>0 and evidence.archer_skin_vertices_peak>0,"partial CPU visual fixture executed source particles and skinned meshes")
 battlecry_action_index+=1
 await measure("archer_recovery_idle",180,func():pass)
 print("WINDOWS_ACTIONS_PASS ",JSON.stringify(game.event_trace))


func make_game():
 return preload("res://tests/windows_renderer_benchmark_game.gd").new()

func mesh_vertices(mesh: Mesh) -> int:
 if mesh==null:return 0
 var total:=0
 for surface in mesh.get_surface_count():total+=mesh.surface_get_array_len(surface)
 return total

func observe_cpu_visuals(evidence: Dictionary) -> void:
 # Only this explicit diagnostic fixture pays for geometry inspection.
 var systems:=0
 var particle_vertices:=0
 var skin_vertices:=0
 for entry in game.native_summon.instances:
  for player in entry.particle_players.values():
   if is_instance_valid(player.node):
    systems+=1;particle_vertices+=mesh_vertices(player.node.mesh)
 for effects in [game.native_combat.effect_player.effects,game.native_death.effects.effects]:
  for effect in effects:
   for player in effect.particles.values():
    if is_instance_valid(player.node):
     systems+=1;particle_vertices+=mesh_vertices(player.node.mesh)
   if effect.has("archer_skin"):
    for skin in effect.archer_skin.skinned:skin_vertices+=mesh_vertices(skin.mesh)
 evidence.particle_systems_peak=maxi(evidence.particle_systems_peak,systems)
 evidence.particle_mesh_vertices_peak=maxi(evidence.particle_mesh_vertices_peak,particle_vertices)
 evidence.archer_skin_vertices_peak=maxi(evidence.archer_skin_vertices_peak,skin_vertices)

func prepare_stress_board(lethal: bool) -> void:
 # Set up the board only. The measured summon, aiming, projectile, damage and
 # death all use production play_card/_resolve_target and normal frame updates.
 game.unit_uid=1
 game.rng.seed=8372
 game.start_match("practice")
 game.flow.test_clock_delta=0
 game.flow.random.seed=8372
 game.mana=10;game.max_mana=10;game.tutorial_hint=false
 game.allies.clear();game.enemies.clear()
 for side in 2:
  var board: Array = game.allies if side==0 else game.enemies
  var count:=6 if side==0 else 7
  for index in count:
   var key: String = "CS2_189" if lethal and side==1 and index==3 else "CS2_179"
   var unit=game._new_unit(key,side,Vector2(800+(index-(count-1)*0.5)*118,game.FRIEND_Y if side==0 else game.ENEMY_Y))
   unit.ready=side==0;unit.summoning_sick=false
   board.append(unit)

func stress_outcome(event_start: int, start_frame: int) -> Dictionary:
 var result:Dictionary={"health":game.health.duplicate(),"mana":game.mana,"hand":[],"allies":[],"enemies":[],"events":[],"event_frame_offsets":[],"busy":game.busy,"pending":not game.pending_battlecry.is_empty(),"game_over":game.game_over}
 for card in game.cards:result.hand.append(card.key)
 for side in ["allies","enemies"]:
  for unit in game.get(side):result[side].append({"key":unit.key,"hp":unit.hp,"dead":unit.dead})
 for event in game.event_trace.slice(event_start):
  result.events.append(event.event)
  result.event_frame_offsets.append(int(event.frame)-start_frame)
 return result

func run_battlecry_stress():
 var expected:Dictionary={}
 var pooled:Dictionary={}
 var pooled_cpu:Dictionary={}
 var action_times:Dictionary={}
 var action_rows:Array=[]
 for repetition in stress_repetitions:
  current_round=repetition
  for lethal in [false,true]:
   var case_name: String = "full_board_lethal" if lethal else "full_board_survivor"
   phase_context={"suite":"battlecry_stress","case":case_name,"repetition":repetition,"temperature":"first_case_use" if repetition==0 else ("warm" if repetition==1 else "repeated"),"battlecry_action_index":battlecry_action_index,"process_first_archer_use":battlecry_action_index==0,"fixture_seed":8372,"units_before":13,"units_after_summon":14}
   await measure("stress_"+case_name+"_setup",180,func():prepare_stress_board(lethal))
   require(game.allies.size()==6 and game.enemies.size()==7 and not game.busy,"stress board has six allies, seven enemies and accepts a real play")
   if failed:return
   var target:Dictionary=game.enemies[3]
   var hp_before:int=target.hp
   var hand_before:int=game.cards.size()
   var event_start:int=game.event_trace.size()
   var start_frame:int=Engine.get_process_frames()
   var result:Dictionary=await measure("stress_"+case_name+"_battlecry",240,func():
    var index:int=card_index("CS2_189")
    require(index>=0 and game.play_card(index,Vector2(800,500),3),"stress real Archer play accepted")
    require(not game.pending_battlecry.is_empty(),"stress Archer enters target selection")
    if failed:return
    game._resolve_target(target.pos)
    require(game.pending_battlecry.is_empty() and game.allies.size()==7 and game.mana==9,"stress target commits real full-board summon"))
   require(target.hp==hp_before-1,"stress projectile damages intended target exactly once")
   require(game.health==[30,30] and game.cards.size()==hand_before-1,"stress leaves heroes unchanged and consumes one card")
   require(game.allies.size()==7 and game.enemies.size()==(6 if lethal else 7),"stress board count and lethal removal")
   require(not game.busy and game.pending_battlecry.is_empty() and not game.game_over,"stress action completed")
   if headless_cpu_visuals:
    var evidence:Dictionary=result.cpu_visual_evidence
    require(evidence.particle_systems_peak>0 and evidence.particle_mesh_vertices_peak>0 and evidence.archer_skin_vertices_peak>0,"partial CPU visual fixture executed source particles and skinned meshes")
   if failed:return
   var outcome:=stress_outcome(event_start,start_frame)
   require(outcome.events.count("battlecry_damage1")==1 and outcome.events.count("battlecry_aim_begin")==1,"stress exactly one aim and damage event")
   var deterministic:=outcome.duplicate(true)
   deterministic.erase("event_frame_offsets")
   if expected.has(case_name):require(deterministic==expected[case_name],"stress repeated action outcome and event order match")
   else:expected[case_name]=deterministic
   if failed:return
   print("BATTLECRY_STRESS_ACTION_PASS ",JSON.stringify({"context":phase_context,"outcome":outcome,"cpu_visual_evidence":result.cpu_visual_evidence}))
   if not pooled.has(case_name):pooled[case_name]=[];pooled_cpu[case_name]=[];action_times[case_name]=[]
   pooled[case_name].append_array(result.raw_samples.frame_ms)
   pooled_cpu[case_name].append_array(result.raw_samples.game_process_ms)
   action_times[case_name].append(result.action_usec)
   action_rows.append({"case":case_name,"repetition":repetition,"frame_ms":result.metrics.frame_ms,"game_process_ms":result.metrics.game_process_ms,"action_usec":result.action_usec})
   battlecry_action_index+=1
   await measure("stress_"+case_name+"_recovery",180,func():pass)
   require(not game.busy and game.native_summon.instances.is_empty() and game.native_combat.effect_player.archer_shots.is_empty() and game.native_combat.effect_player.effects.is_empty() and game.native_death.effects.effects.is_empty(),"stress effects finish before reset")
   if failed:return
 var totals:Dictionary={}
 for case_name in pooled:totals[case_name]={"all_action_frames_ms":stats(pooled[case_name]),"all_action_game_process_ms":stats(pooled_cpu[case_name]),"synchronous_action_usec":stats(action_times[case_name]),"frame_ms_trace":pooled[case_name],"game_process_ms_trace":pooled_cpu[case_name],"action_usec_trace":action_times[case_name]}
 print("BATTLECRY_STRESS_PASS ",JSON.stringify({"measurement_scope":benchmark_environment.measurement_scope,"repetitions_per_case":stress_repetitions,"actions":action_rows,"pooled":totals,"note":"Per-action first/warm/repeated tails are in actions; pooled tails are frame-weighted, include first-use, and exclude setup/recovery. Setup and recovery remain measured in MONITOR_PHASE."}))
 phase_context={}

func run_board_stress():
 # Synthetic occupancy fixture; the measured action still uses production play,
 # target resolution, summon, battlecry, rendering, cleanup and pool refill.
 current_round=benchmark_rounds
 await measure("stress_setup_settle",180,func():
  game.start_match("practice");game.flow.test_clock_delta=0
  game.mana=10;game.max_mana=10;game.tutorial_hint=false
  while game.allies.size()<6:
   var unit=game._new_unit("CS2_120",0,Vector2(800,game.FRIEND_Y))
   unit.ready=true;unit.summoning_sick=false;game.allies.append(unit)
  while game.enemies.size()<7:
   game.enemies.append(game._new_unit("CS2_120",1,Vector2(800,game.ENEMY_Y)))
  while game.cards.size()<10:game._add_card("CS2_120",false))
 require(game.allies.size()==6 and game.enemies.size()==7 and game.cards.size()==10,"stress occupancy")
 await measure("stress_full_board_idle",120,func():pass)
 var hp=game.health[1]
 await measure("stress_archer_battlecry",180,func():
  require(game.play_card(card_index("CS2_189"),Vector2(800,500),3))
  require(not game.pending_battlecry.is_empty())
  game._resolve_target(game.ENEMY_HERO))
 require(game.health[1]==hp-1 and not game.busy and game.allies.size()==7 and game.enemies.size()==7 and game.cards.size()==9,"stress action outcome")
 await measure("stress_recovery_idle",180,func():pass)
 print("WINDOWS_STRESS_PASS ",JSON.stringify(game.event_trace))
