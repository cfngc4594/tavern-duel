extends SceneTree
## Manual graphical benchmark, excluded from CI. Run with -- --reference for
## original integrator; --color-reference disables only the color snapshot
## (constant integrator stays enabled). --size-reference disables only size. Omit flags for optimized. Fixed 1/60 by
## default; --real-delta observes normal variable-delta behavior instead.
## Requires development checkout source. Only user:// temporary scripts are written.
var game
func _initialize():call_deferred("run")
func measure(label:String,count:int,action:Callable):
 var times=[];var draws=[];var previous=Time.get_ticks_usec()
 # No per-call counters in timing run.
 action.call()
 for i in count:
  await process_frame
  var now=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 # No resources summary.
 times.sort();draws.sort();var slow16=0;var slow33=0;var slow50=0
 for value in times:
  if value>16.667:slow16+=1
  if value>33.333:slow33+=1
  if value>50:slow50+=1
 print("WINDOWS_PHASE ",JSON.stringify({"phase":label,"frames":count,"mean_ms":times.reduce(func(total,value):return total+value,0.0)/count,"p50_ms":times[count/2],"p95_ms":times[int(count*.95)],"p99_ms":times[int(count*.99)],"over16_7_pct":100.0*slow16/count,"over33_3_pct":100.0*slow33/count,"over50_pct":100.0*slow50/count,"draw_p50":draws[count/2],"draw_p95":draws[int(count*.95)],"busy_end":game.busy,"summon_active_end":game.native_summon.instances.size(),"health":game.health,"hand":game.cards.size(),"units":game.allies.size()+game.enemies.size()}))
func card_index(key):
 for i in game.cards.size():
  if game.cards[i].key==key:return i
 return -1
func run():
 assert(not preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 game=make_game()
 if "--smoke" in OS.get_cmdline_user_args():
  game.free();print("SUMMON_BENCH_SMOKE_PASS");quit();return
 root.add_child(game)
 for i in 1500:
  await process_frame
  if not game.native_initial_loading:break
 assert(not game.native_initial_loading)
 # No assets override.
 game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false
 for i in 180:await process_frame
 assert(not game._phone_hand_enabled())
 print("WINDOWS_SETUP ",JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"size":str(root.size),"phone":game._phone_hand_enabled(),"board_variant":game.original_board_bridge.probe.get("board_variant"),"vsync":DisplayServer.window_get_vsync_mode()}))
 var wp=game.original_board_bridge.probe.water_particles
 if is_instance_valid(wp):print("WINDOWS_PARTICLES ",JSON.stringify(wp.get_audit()))
 for round_index in 2:
  await run_round(round_index)
 quit()
func run_round(round_index:int):
 if round_index>0:
  game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false
  for i in 180:await process_frame
 print("SUMMON_BENCH_ROUND ",round_index)
 await measure("idle",120,func():pass)
 await measure("play_senjin",180,func():assert(game.play_card(card_index("CS2_179"),Vector2(800,500),1)))
 assert(not game.busy and game.allies.size()==3)
 var attacker=game.allies[0];var target=game.enemies[0];var target_hp=target.hp
 await measure("attack_taunt",180,func():assert(game.attack(attacker,{"type":"unit","unit":target,"pos":target.pos})))
 assert(target.hp<target_hp and not game.busy)
 var hp=game.health[1]
 await measure("archer_battlecry",180,func():
  assert(game.play_card(card_index("CS2_189"),Vector2(800,500),1))
  assert(not game.pending_battlecry.is_empty())
  game._resolve_target(game.ENEMY_HERO))
 assert(game.health[1]==hp-1 and not game.busy)
 print("WINDOWS_ACTIONS_PASS ",JSON.stringify(game.event_trace))


func make_game():
 var size_reference="--size-reference" in OS.get_cmdline_user_args()
 var color_reference="--color-reference" in OS.get_cmdline_user_args()
 var reference=size_reference or color_reference or "--reference" in OS.get_cmdline_user_args()
 var fixed=not "--real-delta" in OS.get_cmdline_user_args()
 var source=FileAccess.get_file_as_string("res://scripts/game.gd")
 assert(not source.is_empty())
 if fixed:source=source.replace("func _process(dt):","func _process(dt):\n\tdt = 1.0 / 60.0")
 if reference:
  var player=FileAccess.get_file_as_string("res://scripts/native_summon_player.gd")
  var original="var particle=Particles.new();particle.setup"
  assert(player.contains(original),"Update reference injection if summon factory changes")
  player=player.replace(original,"var particle=Particles.new();particle."+("size_snapshot_enabled" if size_reference else "color_snapshot_enabled" if color_reference else "constant_step_enabled")+"=false;particle.setup")
  var out=FileAccess.open("user://summon_graphics_reference_player.gd",FileAccess.WRITE);out.store_string(player);out.close()
  source=source.replace("res://scripts/native_summon_player.gd","user://summon_graphics_reference_player.gd")
 var file=FileAccess.open("user://summon_graphics_game.gd",FileAccess.WRITE);file.store_string(source);file.close()
 var script=ResourceLoader.load("user://summon_graphics_game.gd","",ResourceLoader.CACHE_MODE_IGNORE)
 assert(script!=null)
 print("SUMMON_BENCH_MODE ",JSON.stringify({"reference":reference,"color_reference":color_reference,"size_reference":size_reference,"fixed_main_visual_dt":fixed,"dt":1.0/60.0 if fixed else -1,"window_frames":180,"note":"Compare second round; fixed window is 3 simulated seconds, including still-active tails. Main clock fixed, rendering remains real."}))
 return script.new()