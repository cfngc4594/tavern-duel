extends SceneTree
func _initialize():call_deferred("run")
func measure(label:String,action:Callable,count:int=200):
 for i in 10:action.call()
 var samples=[]
 for i in count:
  var start=Time.get_ticks_usec();action.call();samples.append(Time.get_ticks_usec()-start)
 samples.sort();var total=0.0
 for t in samples:total+=t
 print("PERF ",label," mean_us=",total/count," p50_us=",samples[count/2]," p95_us=",samples[int(count*.95)])
func run():
 preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.flow.phase="playing";game.player_turn=true;game.busy=false
 game.source_phone_layout.refresh();game.source_projection=game.source_phone_layout.context
 print("PHONE ",game.source_phone_layout.enabled," units=",game.allies.size()+game.enemies.size()," hand=",game.cards.size())
 measure("layout_refresh",func():game.source_phone_layout.refresh())
 measure("layout_reproject",func():game.source_phone_layout.reproject())
 measure("hand_update",func():game._update_hand(1.0/60))
 measure("board_advance",func():game.original_board_bridge.advance(1.0/60))
 var probe=game.original_board_bridge.probe
 for key in ["door_interaction","window_lamp_interaction","arch_interactions","kite_interactions","pumpkin_interaction","bush_interactions","water_interactions","water_particles"]:
  var item=probe.get(key)
  if is_instance_valid(item):measure(key,func():item.advance(1.0/60))
 measure("materials",func():probe.material_factory.advance(10))
 measure("native_status",func():game.native_status.sync_from_game(1.0/60))
 game.queue_free();quit()