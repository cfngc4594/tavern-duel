extends SceneTree
var game
var failures=[]
var checks=0
func _initialize():call_deferred('run')
func check(value,label):
 checks+=1
 if not value:failures.append(label);push_error(label)
func run():
 game=load('res://main.tscn').instantiate();game.startup_mode='practice';root.add_child(game);game.set_process(false);game.sound_enabled=false
 var nc=game.native_combat
 for side in [0,1]:
  for key in ['CS2_029','CS2_024','CS2_034','CS2_022','CS2_061']:
   var ready=nc.effect_player.start_ready_time(key)
   for age in [0.0,0.25,1.25]:
    nc.cancel_all();game.health=[30,30];var result={'hits':0,'launches':0}
    nc.prepare_spell(key,game.PLAYER_HERO,side)
    if age>0:nc.advance(age)
    var source_id=nc.prepared_spell.effect.serial
    nc.begin_spell(key,game.PLAYER_HERO,{'type':'hero','side':1-side,'pos':game.ENEMY_HERO},side,func():result.hits+=1,func():pass,Callable(),func():result.launches+=1)
    var e=nc.instances[-1]
    check(e.start_effect.serial==source_id,'reuse '+key)
    check(absf(e.route.launch_delay-maxf(0,ready-age))<0.00001,'delay '+key)
    if e.route.launch_delay>0.001:
     nc.advance(e.route.launch_delay-.0001);check(result.launches==0,'no early launch '+key);nc.advance(.0001)
    check(result.launches==1,'once launch '+key)
    check(result.hits==0,'no early damage '+key)
    nc.advance(e.route.hit_time-float(e.age)+.00001);check(result.hits==1,'once damage '+key)
    nc.advance(10.0);check(result.hits==1 and nc.instances.is_empty(),'end '+key)
 for key in ['CS2_029','CS2_024','CS2_034','CS2_061']:
  nc.cancel_all();nc.prepare_spell(key,game.PLAYER_HERO,0);nc.advance(.1);var e=nc.prepared_spell.effect
  nc.cancel_prepared_spell();check(e.source_event=='Cancel','cancel '+key)
  nc.advance(5);check(nc.effect_player.effects.is_empty(),'cancel cleanup '+key)
 nc.cancel_all();game.queue_free();await process_frame
 print('V32_PREPARED_START ',JSON.stringify({'checks':checks,'failures':failures}));quit(0 if failures.is_empty() else 1)
