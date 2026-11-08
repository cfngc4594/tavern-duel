extends Node3D
## Original ActorSpell2 Card_Hand_Ability_SummonIn, ordinary non-dragon card.
## Owns source effect only. Caller supplies actual card actor and world mapping.
const Assets=preload("res://scripts/native_card_birth_assets.gd")
const Particle=preload("res://scripts/native_combat_particles.gd")
const ROOT="cab-69c88b234dfa427e02d1fcee9337ae34:5104365459974360212"
const ECHO_PATH="GameObjectContainer/AbilityCard_Echo_Quad"
const WAIT_SECONDS=0.5 # Birth.Wait serialized FsmFloat, byte offset2.
signal finished
signal actor_revealed
var assets
var state:Dictionary={}
var actor:Dictionary={}
var particle_players:Array=[]
var phase="idle"
var age=0.0
var duration=0.0
var out_duration=0.0
var fade_duration=0.0
var initial_actor_visible=true
var initial_highlight_visible=true
var completed_emitted=false
var blockers:Array=[]
var history:Array=[]

func setup(card_renderer:Node,source_actor:Dictionary)->void:
 actor=source_actor
 if not is_instance_valid(actor.get("root")):
  blockers.append("A real source card actor root is required");return
 transform=actor.root.transform
 initial_actor_visible=actor.root.visible
 var original_highlight=_highlight_node()
 if is_instance_valid(original_highlight):initial_highlight_visible=original_highlight.visible
 assets=Assets.new();assets.setup(card_renderer)
 state=assets.instantiate(ROOT,self)
 out_duration=assets.clip_length("Secret_AbilityEchoOut")
 fade_duration=assets.clip_length("Secret_AbilityEchoFade")
 duration=WAIT_SECONDS+out_duration+fade_duration
 for key in state.particles:
  var player=Particle.new();player.setup(state.particles[key],assets,self,84173)
  particle_players.append(player);player.visible=false
  for unsupported in player.unsupported:blockers.append(str(unsupported))
 if not assets.material_audit.is_empty():blockers.append("Untranslated source material")
 state.root.visible=false

func begin()->void:
 if state.is_empty():return
 age=0.0;completed_emitted=false;phase="Birth";state.root.visible=true
 history.append({"event":"Birth","source_wait":WAIT_SECONDS})
 sample(0.0)

func _highlight_node()->Node3D:
 for path in actor.get("paths",{}):
  if str(path).get_file()=="Highlight_Card_Plane":return actor.paths[path]
 return null

func sample(seconds:float)->void:
 if state.is_empty():return
 age=maxf(0.0,seconds)
 var reveal_at=WAIT_SECONDS+out_duration
 var echo:Node3D=state.paths[ECHO_PATH]
 echo.visible=age<duration
 if age<reveal_at:
  var original_highlight=_highlight_node()
  if is_instance_valid(original_highlight):original_highlight.visible=initial_highlight_visible
 if age<WAIT_SECONDS:
  phase="Birth"
  assets.sample_clip(state,"Secret_AbilityEchoOut",0.0,ECHO_PATH)
  actor.root.visible=initial_actor_visible
 elif age<reveal_at:
  phase="State 2"
  assets.sample_clip(state,"Secret_AbilityEchoOut",age-WAIT_SECONDS,ECHO_PATH)
  actor.root.visible=initial_actor_visible
 elif age<duration:
  var reveal=phase!="State 1" and phase!="None"
  phase="State 1";actor.root.visible=true
  var highlight=_highlight_node()
  if is_instance_valid(highlight):highlight.visible=false
  assets.sample_clip(state,"Secret_AbilityEchoFade",age-reveal_at,ECHO_PATH)
  if reveal:actor_revealed.emit()
 else:
  phase="None";actor.root.visible=true
  var highlight=_highlight_node()
  if is_instance_valid(highlight):highlight.visible=false
  assets.sample_clip(state,"Secret_AbilityEchoFade",fade_duration,ECHO_PATH)
  echo.visible=false
 for player in particle_players:player.visible=true;player.seek(age)
 if phase=="None" and not completed_emitted:
  completed_emitted=true;history.append({"event":"SpellStateAction finished","at":duration});finished.emit()

func advance(delta:float)->void:
 if phase=="idle":return
 sample(age+maxf(0.0,delta))

func get_audit()->Dictionary:
 return {"source_guid":"58d7bdf9c104f4c1fb04bd97e3435ebc","source_root":ROOT,"phase":phase,"age":age,"duration":duration,"wait":WAIT_SECONDS,"out_clip":out_duration,"fade_clip":fade_duration,"actor_visible":actor.root.visible if is_instance_valid(actor.get("root")) else false,"source_actor":actor.get("source_key",""),"highlight_present":is_instance_valid(_highlight_node()),"particles":particle_players.map(func(p):return p.get_audit()),"blockers":blockers.duplicate(),"history":history.duplicate(true),"runtime":"Original FSM timing/clips/materials; existing Godot source-particle solver, not Unity pixel/RNG equivalence"}

func clear()->void:
 phase="idle"
 for player in particle_players:
  if is_instance_valid(player):player.source_destroy();player.queue_free()
 particle_players.clear()
 if is_instance_valid(state.get("root")):state.root.visible=false;state.root.queue_free()
 state.clear()
