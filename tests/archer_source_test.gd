extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false)
 var fx=game.native_combat.effect_player
 assert(fx.supports_spell("CS2_189"))
 if "--instantiate" in OS.get_cmdline_user_args():
  game.headless=false;game._setup_spatial_presentation()
 var hp=game.health[1]
 var unit=game._new_unit("CS2_189",0,Vector2(890,game.FRIEND_Y))
 game._resolve_battlecry(unit,{"type":"hero","side":1,"pos":game.ENEMY_HERO})
 assert(game.health[1]==hp-1)
 for i in range(300):fx.advance(1.0/60.0)
 var audit=fx.get_audit()
 print("ARCHER_AUDIT ",JSON.stringify(audit))
 assert(fx.archer_shots.is_empty())
 assert(fx.effects.is_empty())
 for entry in fx.history:assert(entry.unsupported.is_empty())
 print("ARCHER_RULE_AND_LIFECYCLE_PASS")
 for i in range(3):fx.play_archer(unit,{"type":"hero","side":1,"pos":game.ENEMY_HERO})
 assert(fx.archer_shots.size()==3)
 fx.advance(0.05);fx.cancel_all()
 assert(fx.archer_shots.is_empty() and fx.effects.is_empty())
 assert(game.health[1]==hp-1)
 print("ARCHER_REPEAT_CANCEL_NO_EXTRA_DAMAGE_PASS")
 game.queue_free();quit()
