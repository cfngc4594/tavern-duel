extends SceneTree
var game
var failures: Array=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func run():
 game=load("res://main.tscn").instantiate();game.startup_mode="practice";root.add_child(game);game.set_process(false)
 await process_frame
 for outcome in ["win","lose","tie"]:
  game.start_match("normal",0,5834);game.flow.finish_opening();game.set_process(false)
  game.health=[22,0] if outcome=="win" else ([0,22] if outcome=="lose" else [0,0]);game._check_victory()
  var controller=game.native_endgame
  check(controller.hero_details_visible==[true,true],outcome+" detail visibility unchanged at source activation")
  var early:=true
  for i in range(800):
   controller.advance(.005)
   for effect in controller.effects.effects:
    if float(effect.age)<.5 and not controller.hero_details_visible[int(effect.context.side)]:early=false
   if controller.effects.effects.all(func(e):return float(e.age)>=.51):break
  check(early,outcome+" WaitForSeconds does not hide before .5 scaled seconds")
  var expected: Array=[true,false] if outcome=="win" else ([false,true] if outcome=="lose" else [false,false])
  check(controller.hero_details_visible==expected,outcome+" only actual blown-up heroes hide their details")
  var rows=controller.history.filter(func(h):return h.event=="hero_details_hidden")
  check(rows.size()==controller.effects.effects.size() and rows.all(func(h):return h.source_scaled_age>=.5 and h.source_scaled_age<=.505001),outcome+" hide gate is .5 plus actual frame quantization")
  if outcome=="tie":check(controller.hero_body_visible[1],"Draw39 does not invent an enemy portrait-root hide")
  controller.clear();check(controller.hero_details_visible==[true,true],outcome+" clear restores independent hero details")
 var unknowns: Array=[]
 game.native_endgame.effects._surface_particle_unknowns({"source_key":"parent","unsupported":["ForceModule.randomizePerFrame"],"subemitter_audits":[{"source_key":"child","unsupported":["SubModule non-Birth emitter"]}]},unknowns)
 check(unknowns==["particle:parent:ForceModule.randomizePerFrame","particle:child:SubModule non-Birth emitter"],"Nested particle unknowns reach the top effect audit without loss")
 FileAccess.open("res://references/endgame_v33/selftests/endgame_aux_gate_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"source":"GameEntity.HideOtherElements06005568 WaitForSeconds(.5), called by BlowUpHero060054f2 immediately after activation","scope":"Clock/visibility and audit propagation, not GPU image acceptance"},"  "))
 game.queue_free();await process_frame;print("ENDGAME_AUX ",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
