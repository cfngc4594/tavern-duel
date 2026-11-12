extends SceneTree
func _initialize():call_deferred("run")
func death_requests(audio)->Array:
 return audio.event_history.filter(func(e):return e.kind=="request" and ((e.get("card_id","")=="CS2_189" and e.get("event","")=="death") or (e.get("card_id","")=="@actor" and e.get("event","")=="type_5")))
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false);game.sound_enabled=true
 var manager=root.get_node("SoundManager");manager.sfx_enabled=true;manager.sfx_volume=1.0
 var audio=manager.original_audio;audio.set_process(false);audio.stop_all();audio.event_history.clear()
 var fx=game.native_combat.effect_player
 # Explicitly exercise the observed.deaths compatibility branch; the normal
 # native death player owns its original Birth/voice lifecycle separately.
 var native=game.native_death;game.native_death=null
 var unit=game._new_unit("CS2_189",0,Vector2(890,game.FRIEND_Y))
 var victim=game._new_unit("CS2_189",1,Vector2(890,game.ENEMY_Y));game.enemies.append(victim)
 game._resolve_battlecry(unit,{"type":"unit","unit":victim,"pos":victim.pos})
 assert(not victim.dead and game.enemies.has(victim))
 assert(death_requests(audio).is_empty())
 var shot=fx.archer_shots[0];var owner=fx.archer_audio_owners[shot.serial]
 assert(not owner.has("death_audio"))
 var impact_time:float=shot.route.impact_time
 fx.advance(impact_time-0.00001);assert(death_requests(audio).is_empty())
 fx.advance(0.00001)
 assert(victim.dead and not game.enemies.has(victim))
 assert(death_requests(audio).size()==2 and owner.death_audio_consumed)
 assert(not owner.has("death_audio"))
 for e in death_requests(audio):assert(e.accepted)
 fx.advance(5.0);assert(death_requests(audio).size()==2)
 var flushed=fx.archer_audio_history.filter(func(e):return e.get("event","")=="observed_death_audio_flushed")
 assert(flushed.size()==1 and is_equal_approx(float(flushed[0].visual_clock),impact_time))
 print("ARCHER_OBSERVED_DEATH_IMPACT_ONCE_PASS")
 audio.stop_all();audio.event_history.clear()
 var second=game._new_unit("CS2_189",1,Vector2(890,game.ENEMY_Y));game.enemies.append(second)
 game._resolve_battlecry(unit,{"type":"unit","unit":second,"pos":second.pos})
 assert(not second.dead and game.enemies.has(second))
 fx.advance(0.01);fx.cancel_all();fx.advance(5.0)
 assert(death_requests(audio).is_empty())
 assert(not second.dead and game.enemies.has(second) and not game.busy)
 assert(fx.archer_audio_owners.is_empty())
 print("ARCHER_OBSERVED_DEATH_CANCEL_BEFORE_IMPACT_PASS")
 game.native_death=native
 await manager.shutdown_audio()
 game.queue_free()
 await process_frame
 quit()
