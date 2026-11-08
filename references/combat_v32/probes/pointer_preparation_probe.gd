extends SceneTree
var failures=[]
var checks=0
func _initialize():call_deferred('run')
func ck(v,label):
 checks+=1
 if not v:failures.append(label);push_error(label)
func run():
 var game=load('res://main.tscn').instantiate();game.startup_mode='practice';root.add_child(game);game.set_process(false);game.sound_enabled=false;game.scripted_pointer=true
 for key in ['CS2_029','CS2_024','CS2_022']:
  game.start_match('normal',0,5834);game.flow.finish_opening();game.cards.clear();game.player_turn=true;game.mana=10;game.busy=false
  game._add_card(key,false);game.cards[0].pos=Vector2(600,800);game.pointer=Vector2(600,800);game._begin_card_drag(0)
  ck(game.native_combat.prepared_spell.is_empty(),key+' no mouseover Birth')
  game.pointer=Vector2(600,500);game._update_interaction();var effect=game.native_combat.prepared_spell.effect
  game.native_combat.advance(.25);game._update_interaction()
  ck(game.native_combat.prepared_spell.effect.serial==effect.serial,key+' repeated aim reuses')
  if key=='CS2_022':game.enemies.append(game._new_unit('CS2_182',1,Vector2(800,340)))
  var target=game.ENEMY_HERO if key!='CS2_022' else game.enemies[0].pos
  game.drag_index=-1
  ck(game.play_card(0,target),key+' legal drop')
  game._clear_selection()
  ck(game.native_combat.prepared_spell.is_empty(),key+' transfer ownership')
  ck(game.native_combat.instances[-1].start_effect.serial==effect.serial,key+' accepted effect reused')
  ck(game.native_combat.instances[-1].route.prepared_age>=.25,key+' readiness credit')
 game.start_match('normal',0,5834);game.flow.finish_opening();game.cards.clear();game.player_turn=true;game.mana=10;game.busy=false;game.pointer=game.POWER_POS
 game._pointer_press();ck(game.native_combat.prepared_spell.key=='CS2_034','power click prepares')
 var effect=game.native_combat.prepared_spell.effect
 game.native_combat.advance(.25);game._resolve_target(game.ENEMY_HERO)
 ck(game.native_combat.instances[-1].start_effect.serial==effect.serial,'power acceptance preserves prep')
 ck(absf(game.native_combat.instances[-1].route.launch_delay-.75)<.000001,'power remaining readiness')
 game.start_match('normal',0,5834);game.flow.finish_opening();game.cards.clear();game.player_turn=true;game.mana=10;game.busy=false
 game._add_card('EX1_277',false);game.cards[0].pos=Vector2(600,800);game.pointer=Vector2(600,800);game._begin_card_drag(0);game.pointer=Vector2(600,500);game._update_interaction()
 ck(game.native_combat.prepared_spell.is_empty(),'untargeted no drag preparation')
 game._clear_selection();game.queue_free();await process_frame
 print('V32_POINTER_PREPARATION ',JSON.stringify({'checks':checks,'failures':failures}));quit(0 if failures.is_empty() else 1)
