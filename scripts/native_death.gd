extends Node
## Ordinary Actor SpellTable type5. Presentation consumes retained death records;
## it never damages, selects a target, removes a unit, or uses the rules RNG.
const Assets=preload("res://scripts/native_death_assets.gd")
var game: Node
var assets=Assets.new()
var effects: Node
var routes: Dictionary={}
var active: Dictionary={}
var history: Array=[]
var source_missing: Array=[]
var serial:=0
var pending_voices: Array=[]
var audio_history: Array=[]
var timing: Dictionary={}

func setup(owner_game: Node):
 game=owner_game
 assets.setup(game.native_card_renderer,"res://assets/original_death_v35/")
 routes=JSON.parse_string(FileAccess.get_file_as_string("res://references/death_v35/runtime_routes.json")).get("routes",{})
 timing=JSON.parse_string(FileAccess.get_file_as_string("res://references/death_v35/death_release_timing.json")).minion
 effects=preload("res://scripts/native_death_effects.gd").new();add_child(effects);effects.setup_death(game,assets,self,routes)
 if not routes.has("minion_death/root"):source_missing.append("minion_death/root")

func sync():
 effects.clock_seconds=float(game.native_damage.clock_seconds)
 _dispatch_voices()
 for id in game.native_damage.dying:
  var retained: Dictionary=game.native_damage.dying[id]
  if not active.has(id):_begin(retained)
  if not active.has(id):continue
  var entry: Dictionary=active[id]
  entry.effect.age=maxf(0.0,float(game.native_damage.clock_seconds)-float(entry.start))
  effects._sample(entry.effect)
 for id in active.keys():
  if game.native_damage.dying.has(id):continue
  var entry: Dictionary=active[id]
  # The retained Actor is released at None, not at the intermediate body hide.
  # Sampling the last boundary also records DisableShadow/None on coarse frames.
  entry.effect.age=maxf(float(entry.effect.age),float(timing.release_seconds))
  effects._sample(entry.effect)
  _release(id,"actor_none_release")

func _begin(record: Dictionary):
 var unit: Dictionary=record.unit
 var actor: Dictionary={}
 if not game.headless:
  var piece: Dictionary=game.spatial_scene.pieces.get(int(unit.id),{})
  if piece.is_empty() or not piece.get("native_actor",false):return
  actor=piece.actor
 serial+=1
 var effect: Dictionary=effects.begin(record,actor,serial)
 if effect.is_empty():return
 active[int(unit.id)]={"unit":unit,"start":record.start,"effect":effect}
 history.append({"event":"birth","unit_id":unit.id,"card_id":unit.key,"side":unit.side,"origin":record.start,"serial":effect.serial,"source_root":effect.root_key})
 _trim_history()

func _release(id: int,reason: String):
 if not active.has(id):return
 var entry: Dictionary=active[id]
 effects.release(entry.effect)
 history.append({"event":"release","unit_id":id,"card_id":entry.unit.key,"reason":reason,"age":entry.effect.age})
 active.erase(id);_trim_history()

func _trim_history():
 while history.size()>128:history.pop_front()

func clear():
 for id in active.keys():_release(id,"new_match")
 if is_instance_valid(effects):effects.history.clear()
 history.clear();audio_history.clear();pending_voices.clear();serial=0

func get_audit() -> Dictionary:
 var rows: Array=[]
 for entry in active.values():
  rows.append({"unit_id":entry.unit.id,"card_id":entry.unit.key,"side":entry.unit.side,"origin":entry.start,"age":entry.effect.age,"source_root":entry.effect.root_key,"body_hidden":entry.effect.get("body_hidden",false),"actor_bound":not entry.effect.get("actor",{}).is_empty(),"portrait_bound":entry.effect.get("portrait_bound",false)})
 return {"active":rows,"active_count":rows.size(),"history":history.duplicate(true),"audio_history":audio_history.duplicate(true),"effects":effects.get_audit() if is_instance_valid(effects) else {},"source_missing":source_missing.duplicate(),"material_fallbacks":assets.material_audit.duplicate(),"rules_mutated":false,"compatibility":["Original prefab/material/clip/FSM/mesh/particle values under fixed board camera registration","Death Birth consumes the unchanged local death-wave/replay record; original server power-history timeline is unavailable","Unity particle integration/RNG and frame scheduling are a separately audited Godot compatibility solver","No fabricated portrait shards or dissolve noise; source portrait uses UnlitDesat before source mesh debris"]}

func queue_voice(unit: Dictionary):
 var event: Dictionary={"unit_id":int(unit.id),"card_id":str(unit.key),"side":int(unit.side)}
 if game.combat_replay.capturing:
  if not game.combat_replay.current.has("death_voice_events"):game.combat_replay.current.death_voice_events=[]
  game.combat_replay.current.death_voice_events.append(event)
 else:pending_voices.append(event)

func present_voice(event: Dictionary):
 pending_voices.append(event.duplicate(true))

func _dispatch_voices():
 # DeathSpellController selects VO before DoCurrentTaskList applies the visual
 # PLAY->GRAVEYARD transition. No source fixed-second or clip-finish wait exists.
 # The atomic historical engine exposes one presentation handoff, so preserve
 # that ordering at the same handoff rather than inventing a server timeline.
 for event in pending_voices:
  game._card_audio(str(event.card_id),"death",{"scope_id":"unit:"+str(event.unit_id),"event_token":"death","unit_id":int(event.unit_id)})
  audio_history.append({"event":"selected_character_voice_before_body","unit_id":event.unit_id,"card_id":event.card_id,"clock":game.native_damage.clock_seconds,"delay_adapter":0.0})
 pending_voices.clear()
 while audio_history.size()>128:audio_history.pop_front()

func dispatch_body_audio(effect: Dictionary,source_moment: float):
 if bool(effect.get("body_audio_dispatched",false)):return
 effect.body_audio_dispatched=true
 game._audio_actor(int(effect.unit_id),str(effect.card_id),5)
 audio_history.append({"event":"body_birth_sound","unit_id":effect.unit_id,"card_id":effect.card_id,"body_origin":effect.source_origin,"source_time":source_moment,"clock":game.native_damage.clock_seconds,"delay_adapter":0.0})
 while audio_history.size()>128:audio_history.pop_front()
