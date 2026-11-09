extends Node
## Formal renderer comparison, selected only by renderer_benchmark export feature.
## Runs the production game through a tiny fixed-clock subclass, never source copies.
## Capture runs write rendered frames but must not be used for timing comparisons.
var failed := false
var root: Window:
 get: return get_tree().root
func require(ok: bool, label: String = "runtime check") -> void:
 if not ok:
  failed = true
  push_error("BENCH_FAIL " + label)
  get_tree().quit(1)
func quit() -> void:
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
 var viewports:Array=[];collect_viewports(root,viewports)
 var samples:Dictionary={"frame_ms":[],"process_ms":[],"physics_ms":[],"draw_calls":[],"render_objects":[],"primitives":[],"video_memory_bytes":[]}
 print("PROFILE_SCENE_BEGIN ",label)
 var previous=Time.get_ticks_usec()
 action.call()
 for i in count:
  await get_tree().process_frame
  var now=Time.get_ticks_usec();samples.frame_ms.append((now-previous)/1000.0);previous=now
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
  if not capture_dir.is_empty() and current_round==1 and ((label=="idle" and i==60) or (label=="play_senjin" and i==90) or (label=="attack_taunt" and i==45) or (label=="archer_battlecry" and i in [60,120])):
   await RenderingServer.frame_post_draw
   var filename=capture_dir+"/"+RenderingServer.get_current_rendering_method()+"_"+label+"_"+str(i)+".png"
   var error=root.get_texture().get_image().save_png(filename)
   print("CAPTURE ",filename," error=",error)
 var summary:Dictionary={}
 for key in samples:summary[key]=stats(samples[key])
 print("MONITOR_PHASE ",JSON.stringify({"phase":label,"metrics":summary,"health":game.health,"hand":game.cards.size(),"units":game.allies.size()+game.enemies.size(),"busy":game.busy}))
 print("PROFILE_SCENE_END ",label)
func card_index(key):
 for i in game.cards.size():
  if game.cards[i].key==key:return i
 return -1
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
 if not capture_dir.is_empty():DirAccess.make_dir_recursive_absolute(capture_dir)
 print("RUNNER_MODE ",JSON.stringify({"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor"),"version":Engine.get_version_info()}))
 require(not preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 game=make_game()
 if "--smoke" in OS.get_cmdline_user_args():
  game.free();print("SUMMON_BENCH_SMOKE_PASS");quit();return
 root.add_child(game)
 for i in 1500:
  await get_tree().process_frame
  if not game.native_initial_loading:break
 require(not game.native_initial_loading)
 # No assets override.
 game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false
 for i in 180:await get_tree().process_frame
 require(not game._phone_hand_enabled())
 print("WINDOWS_SETUP ",JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"size":str(root.size),"phone":game._phone_hand_enabled(),"board_variant":game.original_board_bridge.probe.get("board_variant"),"vsync":DisplayServer.window_get_vsync_mode()}))
 var wp=game.original_board_bridge.probe.water_particles
 if is_instance_valid(wp):print("WINDOWS_PARTICLES ",JSON.stringify(wp.get_audit()))
 for round_index in 2:
  await run_round(round_index)
 quit()
func run_round(round_index:int):
 current_round=round_index
 if round_index>0:
  game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false
  for i in 180:await get_tree().process_frame
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
 print("WINDOWS_ACTIONS_PASS ",JSON.stringify(game.event_trace))


func make_game():
 return preload("res://tests/windows_renderer_benchmark_game.gd").new()
