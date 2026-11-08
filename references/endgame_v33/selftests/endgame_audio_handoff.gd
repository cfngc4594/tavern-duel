extends SceneTree
var game
var checks:=0
var failures: Array=[]
var evidence: Array=[]
class SpeedSpy:
 extends RefCounted
 var values: Dictionary={}
 func set_particle_speed(key: String,value: float,_age: float):values[key]=value
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 checks+=1
 if not value:failures.append(label)
 print(("PASS " if value else "FAIL ")+label)
func blank():
 game.start_match("normal",0,5834);game.flow.finish_opening();game.flow.test_clock_delta=0;game.set_process(false)
 game.cards.clear();game.enemy_hand.clear();game.allies.clear();game.enemies.clear();game.health=[22,22]
 game.busy=false;game.game_over=false;game.player_turn=true
func events(prefix: String) -> Array:
 return game.native_endgame.audio.history.filter(func(row):return str(row.event).begins_with(prefix) and row.scope==game.native_endgame.audio.scope)
func advance(seconds: float):
 var remaining:=seconds
 while remaining>0.000001:
  var dt:=minf(.02,remaining);remaining-=dt;game.native_endgame.advance(dt)
func run():
 game=load("res://main.tscn").instantiate();game.startup_mode="practice";root.add_child(game);game.set_process(false)
 await process_frame
 var router=root.get_node("SoundManager").original_audio
 for desired in [0,2,3]:
  blank();game.health=[3,3]
  for side in range(2):
   var unit=game._new_unit("CS2_182",side,Vector2(600,300+side*200));unit.hp=1
   (game.allies if side==0 else game.enemies).append(unit)
  var ids: Array=[game.allies[0].id,game.enemies[0].id,-1000,-1001]
  var seed:=0
  while true:
   var oracle:=RandomNumberGenerator.new();oracle.seed=seed
   if oracle.randi_range(0,3)==desired:break
   seed+=1
  router.random.seed=seed
  var rule_rng=game.flow.random.state
  game.rules.resolve_spell("CS2_062",{},1)
  var audit=game.native_endgame.get_audit();var wave=audit.death_voice_history[0]
  check(game.game_tied and game.health==[0,0] and game.allies.is_empty() and game.enemies.is_empty(),"Actual simultaneous two heroes/two minions lethal, selection "+str(desired))
  check(game.flow.random.state==rule_rng,"Death audio never consumes historical rules RNG "+str(desired))
  check(wave.candidate_ids==ids and wave.selected_id==ids[desired],"Original selector applied once to audio-only full wave "+str(desired))
  check(events("hero_death").size()==(1 if desired>=2 else 0),"Only selected eligible hero receives VO "+str(desired))
  var count=events("hero_death").size();var selections=audit.death_voice_history.size()
  game._check_victory();game._clear_dead();game._check_victory()
  check(events("hero_death").size()==count and game.native_endgame.death_voice_history.size()==selections,"Repeated terminal/clear cannot replay hero VO "+str(desired))
  evidence.append(audit.death_voice_history)
 blank();game.health[0]=1;game.deck.clear();game.fatigue[0]=0;game._draw_cards(1,0)
 check(game.game_over and game.health[0]==0 and events("hero_death_HERO_08").size()==1,"Fatigue without minion clear emits one original Jaina VO")
 blank();game.health[1]=2;game._cast_dual_spell("EX1_277",{},0,game.PLAYER_HERO)
 check(game.combat_replay.capturing==false and game.combat_replay.playing and events("hero_death").is_empty(),"Atomic Arcane death does not play VO before visible replay")
 for i in range(600):game.native_combat.advance(.02)
 check(not game.combat_replay.playing and events("hero_death_HERO_07").size()==1,"Arcane final replay handoff plays selected Guldan VO once")
 advance(10)
 check(game.native_endgame.state=="result" and events("victory_screen_audio").size()==1,"Original screen Action triggers its audio once")
 var generation=game.native_endgame.match_generation
 check(game.native_endgame.request_continue(),"Original unblocked screen accepts immediate continue")
 check(not game.native_endgame.request_continue() and events("victory_screen_close").size()==1,"Repeat click cannot duplicate source Death or shrink audio")
 game.native_endgame.advance(.25);await process_frame
 check(game.native_endgame.match_generation>generation and not game.game_over,"Source .25 close returns via existing no-menu restart")
 var routes=game.native_endgame.effects.routes
 for route in ["endgame_win/root","endgame_lose/root","endgame_draw_opponent/root"]:
  var step: Dictionary=routes[route].event_schedules.Action.state_enter_schedule.filter(func(s):return s.state_name=="State 3")[0]
  var action: Dictionary=step.actions.filter(func(a):return a.class_name=="SetProperty")[0]
  var spy=SpeedSpy.new();var effect: Dictionary={"variables":{},"components":spy,"particles":{},"events":[]}
  game.native_endgame.effects._action(effect,action,.5)
  check(spy.values.size()==1 and spy.values.values()[0]==.5 and effect.events[0].before_player_creation,"Source speed=.5 is applied before lazy ParticlePlay for "+route)
 FileAccess.open("res://references/endgame_v33/selftests/endgame_audio_handoff_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"death_wave_evidence":evidence,"scope":"Rule-driven local death-wave adapter and source event integration. Not GPU or original-server metadata equivalence."},"  "))
 game.queue_free();await process_frame;print("ENDGAME_HANDOFF ",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
