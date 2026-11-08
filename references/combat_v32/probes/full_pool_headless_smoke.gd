extends SceneTree
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();g.startup_mode='practice';root.add_child(g);await process_frame;g.sound_enabled=false
 for key in ['CS2_029','CS2_024','CS2_022','CS2_023','CS2_025','CS2_026','CS2_027','CS2_032','EX1_277','CS2_057','CS2_061','CS2_062','CS2_063','EX1_302','EX1_308','NEW1_003','GAME_005','CS2_034','CS2_056']:
  g.start_match('normal',0,5834);g.flow.finish_opening();g.flow.test_clock_delta=0;g.cards.clear();g.allies.clear();g.enemies.clear();g.game_over=false;g.busy=false;g.ai_timer=9999;g.health=[30,30]
  var u=g._new_unit('CS2_065',1,Vector2(800,g.ENEMY_Y));u.appear=0;g.enemies.append(u)
  var t={'type':'unit','unit':u,'pos':u.pos}
  if key=='CS2_034':g._cast_projectile(g.POWER_POS,t,1,Color.WHITE,false)
  elif key=='CS2_056':g._use_life_tap_with_audio(0)
  else:g._cast_dual_spell(key,t if g.rules.needs_target(key) else {},0,g.PLAYER_HERO)
  for i in 100:g.native_combat.advance(.1)
  print('CASE ',key,' busy=',g.busy,' active=',g.native_combat.instances.size(),' effects=',g.native_combat.effect_player.effects.size(),' health=',g.health)
 g.queue_free();await process_frame;quit()
