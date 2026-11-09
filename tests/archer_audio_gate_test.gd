extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false);game.sound_enabled=true
 var manager=root.get_node("SoundManager");manager.sfx_enabled=true;manager.sfx_volume=1.0
 var audio=manager.original_audio;audio.set_process(false);audio.stop_all()
 var fx=game.native_combat.effect_player
 var unit=game._new_unit("CS2_189",0,Vector2(890,game.FRIEND_Y))
 var hp=game.health[1]
 game._resolve_battlecry(unit,{"type":"hero","side":1,"pos":game.ENEMY_HERO})
 assert(game.health[1]==hp)
 assert(fx.archer_audio_history.is_empty())
 var shot=fx.archer_shots[0]
 var birth:float=shot.missile_effect.motion.begin
 assert(birth>=0.15 and birth<=0.45)
 fx.advance(birth-0.00001)
 assert(fx.archer_audio_history.is_empty())
 fx.advance(0.00001)
 assert(fx.archer_audio_history.size()==1)
 var launch=fx.archer_audio_history[0]
 assert(launch.state=="ActionState" and is_equal_approx(launch.local_visual_time,birth))
 assert(launch.request.accepted and launch.request.layers_scheduled==1)
 assert(launch.request.first_delay_sec==0.0 and not launch.request.has("activation_id"))
 fx.advance(float(shot.route.flight))
 assert(fx.archer_audio_history.size()==3)
 assert(game.health[1]==hp-1)
 for entry in fx.archer_audio_history.slice(1):
  assert(entry.state=="DeathState" and entry.request.layers_scheduled==1 and entry.request.first_delay_sec==0.0)
 fx.advance(0.6333333253860474)
 assert(fx.archer_audio_history.size()==4)
 assert(fx.archer_audio_history[-1].state=="WaitState")
 var impact=fx.effects.filter(func(e):return e.route_id=="CS2_189/impact")[0]
 var explode_at:float=0.0
 for schedule in impact.schedules:
  for step in schedule.data:
   if step.state_name=="DeathState 2":explode_at=float(step.at)
 fx.advance(explode_at-float(impact.age))
 assert(fx.archer_audio_history.size()==5)
 assert(fx.archer_audio_history[-1].state=="DeathState 2")
 for entry in fx.archer_audio_history:
  assert(entry.request.accepted and entry.request.layers_scheduled==1)
  assert(entry.request.first_delay_sec==0.0 and not entry.request.has("activation_id"))
 assert(audio._timing_draws.is_empty()) # No second RNG draw for either source wait.
 fx.advance(4.0);assert(fx.effects.is_empty() and game.health[1]==hp-1)
 print("ARCHER_AUDIO_GATE_PASS ",JSON.stringify(fx.archer_audio_history))
 var count=fx.archer_audio_history.size()
 fx.play_archer(unit,{"type":"hero","side":1,"pos":game.ENEMY_HERO},"cancelled_archer")
 fx.cancel_all();fx.advance(2.0)
 assert(fx.archer_audio_history.size()==count)
 print("ARCHER_AUDIO_CANCEL_PASS")
 var victim=game._new_unit("CS2_189",1,Vector2(890,game.ENEMY_Y));game.enemies.append(victim)
 game._resolve_battlecry(unit,{"type":"unit","unit":victim,"pos":victim.pos})
 assert(not victim.dead and game.enemies.has(victim))
 assert(fx.archer_shots.size()==1)
 fx.advance(5.0)
 assert(victim.dead and not game.enemies.has(victim))
 assert(fx.archer_shots.is_empty() and fx.archer_audio_owners.is_empty())
 print("ARCHER_LETHAL_IMPACT_RULE_PASS")
 # The final lethal impact leaves real audio playbacks alive. Keep owners in
 # the tree until the existing AudioServer retirement barrier completes.
 await manager.shutdown_audio()
 assert(manager.shutdown_complete and manager.pending_disposals()==0)
 assert(manager.shutdown_audit.completed)
 game.queue_free()
 await process_frame
 assert(not is_instance_valid(game))
 print("ARCHER_AUDIO_TEARDOWN_PASS")
 quit()
