extends SceneTree
var game
var failures: Array=[]
var checks:=0
var records: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func blank(first_side: int):
 game.start_match("normal",first_side,5834);game.flow.finish_opening();game.flow.test_clock_delta=0;game.set_process(false)
 game.cards.clear();game.enemy_hand.clear();game.allies.clear();game.enemies.clear();game.health=[22,22]
 game.busy=false;game.game_over=false;game.player_turn=true
func hero(side: int):return {"type":"hero","side":side,"pos":game.PLAYER_HERO if side==0 else game.ENEMY_HERO}
func step(seconds: float):
 var left=seconds
 while left>.00000001:
  var dt=minf(left,.02);left-=dt
  game.native_damage.advance(dt);game.native_combat.advance(dt);game.native_endgame.advance(dt);game.native_damage.sync();game.native_endgame.sync()
func run():
 game=load("res://main.tscn").instantiate();game.startup_mode="practice";root.add_child(game);game.set_process(false);game.sound_enabled=false
 await process_frame
 for first_side in [0,1]:
  for mode in ["win","lose","tie","arcane"]:
   blank(first_side)
   var before_generation: int=game.native_endgame.match_generation
   match mode:
    "win":game.health[1]=6;game._cast_dual_spell("CS2_029",hero(1),0,hero(0).pos)
    "lose":game.health[0]=4;game._cast_dual_spell("EX1_308",hero(0),1,hero(1).pos)
    "tie":game.health=[3,3];game._cast_dual_spell("CS2_062",{},1,hero(1).pos)
    "arcane":
     game.health[1]=2;game._cast_dual_spell("EX1_277",{},0,hero(0).pos)
     check(game.game_over and game.combat_replay.playing,"Arcane actual rule result precedes playback side"+str(first_side))
     check(game.native_endgame.activation_count==0,"Arcane does not show result during atomic capture side"+str(first_side))
   step(10)
   var audit=game.native_endgame.get_audit();var expected="win" if mode=="arcane" else mode
   check(game.game_over and audit.outcome==expected,"actual lethal "+mode+" side"+str(first_side))
   check(audit.activations==1 and audit.requests==1,"single presentation handoff "+mode+" side"+str(first_side))
   check(audit.dead_sides==([1] if expected=="win" else ([0] if expected=="lose" else [0,1])),"correct dead hero IDs "+mode+" side"+str(first_side))
   var hp=game.health.duplicate();game._check_victory();step(5)
   check(game.health==hp and game.native_endgame.activation_count==1,"no repeat health or terminal activation "+mode+" side"+str(first_side))
   records.append(audit)
   blank(first_side);step(15)
   check(game.native_endgame.match_generation>before_generation and game.native_endgame.state=="idle" and game.health==[22,22],"new match cancels terminal generation "+mode+" side"+str(first_side))
 blank(0);game.health[1]=0
 var expected_rng:=RandomNumberGenerator.new();expected_rng.state=game.rng.state
 for i in range(400):expected_rng.randf()
 game._check_victory()
 check(game.rng.state==expected_rng.state,"former100 handmade particles retain exactly400 cosmetic RNG draws")
 check(game.particles.is_empty(),"no replacement handmade gold explosion emitted")
 var audit=game.native_endgame.get_audit();game.native_endgame.request(audit.result)
 check(game.native_endgame.activation_count==1,"direct duplicate terminal request remains idempotent")
 FileAccess.open("res://references/endgame_v33/selftests/terminal_rules_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"records":records,"scope":"Real historical rule lethal calls and presentation handoff only. Source visual routes are not yet implemented and this is not GPU acceptance."},"  "))
 game.queue_free();await process_frame;print("V33_TERMINAL_RULES ",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
