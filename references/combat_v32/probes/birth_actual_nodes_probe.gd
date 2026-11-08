extends SceneTree
func _initialize():call_deferred('run')
func run():
 var game=load('res://main.tscn').instantiate();game.startup_mode='practice';root.add_child(game);game.set_process(false);game.sound_enabled=false;game.scripted_pointer=true
 game.start_match('normal',0,5834);game.flow.finish_opening();game.headless=false
 game.spatial_view=SubViewport.new();game.add_child(game.spatial_view);game.spatial_scene=load('res://scripts/classic_spatial.gd').new();game.spatial_view.add_child(game.spatial_scene);game.spatial_scene.setup(game,Vector2i(1600,900))
 for key in ['EX1_277','CS2_029','CS2_024','CS2_034']:
  game.native_combat.cancel_all();game.combat_replay.cancel();game.health=[30,30];game.busy=false
  if key=='CS2_034':game._cast_projectile(game.POWER_POS,{'type':'hero','side':1,'pos':game.ENEMY_HERO},1,Color.ORANGE,false)
  else:game._cast_dual_spell(key,{'type':'hero','side':1,'pos':game.ENEMY_HERO} if key!='EX1_277' else {},0,game.PLAYER_HERO)
  for i in range(180):game.native_combat.advance(1.0/60)
  print('ACTUAL_NODE_BIRTH ',key,' busy=',game.busy)
 game.native_combat.cancel_all();game.queue_free();await process_frame;quit()
