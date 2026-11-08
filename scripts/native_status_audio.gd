extends "res://scripts/original_audio_router.gd"
## Source status actions use the existing recovered SoundDef random/gain/pitch
## implementation and SFX mix. Separate scopes cannot modify BGM or v30 events.
var game: Node
var action_history: Array=[]
var source_slots: Dictionary={}

func setup_status(owner_game: Node):
 game=owner_game
 manifest_path="res://assets/original_status_audio_v34/runtime_manifest.json"
 super.setup(get_node("/root/SoundManager"))

func _clip_problem(clip: Dictionary) -> String:
 var path: String=str(clip.get("path",""));var digest: String=str(clip.get("sha256",""))
 if not path.begins_with("res://assets/original_status_audio_v34/clips/") or path.contains(".."):return "clip_path_invalid"
 if digest.length()!=64 or not digest.is_valid_hex_number() or not clip.get("identity_verified",false):return "clip_provenance_missing"
 if not _verified.has(path+digest):
  if FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=digest:return "clip_hash_mismatch"
  if not ResourceLoader.exists(path):return "clip_missing"
  _verified[path+digest]=true
 return ""

func trigger_action(effect: Dictionary,action: Dictionary,moment: float) -> Dictionary:
 var state_name: String=""
 for i in range(effect.events.size()-1,-1,-1):
  if effect.events[i].event=="state_enter":state_name=str(effect.events[i].state);break
 var key: String="%s|%s|%d"%[effect.route_id,state_name,int(action.index)]
 var lookup: Dictionary=catalog.get("action_lookup",{}).get(key,{})
 var row: Dictionary={"key":key,"serial":effect.serial,"source_event":effect.source_event,"source_time":moment,"observed_age":effect.age,"activation":int(effect.get("status_activation",0)),"scope":"status:%d:%d"%[int(effect.serial),int(effect.get("status_activation",0))],"source":"Original FSM action; no repeated Birth delay"}
 if lookup.is_empty():row.status="source_unbound"
 elif not game.sound_enabled:row.status="game_sound_disabled"
 else:
  var context: Dictionary=effect.get("context",{})
  var unit: Dictionary=context.get("target",{}).get("unit",{})
  var gate: Dictionary=lookup.get("suppression_gate",{})
  # These modern suppression tags are absent in the bounded 5834 pool. If an
  # explicitly supplied source-equivalent tag appears, apply the original gate.
  var suppress_all: bool=bool(unit.get("SUPPRES_ALL_SOUNDS_FOR_ENTITY",false))
  var suppress_summon: bool=bool(unit.get("SUPPRESS_ALL_SUMMON_VO",false))
  var allow_keyword: bool=bool(game.get_meta("DONT_SUPPRESS_KEYWORD_VO",false))
  if gate.get("kind","")=="AudioPlayClipAction" and not gate.get("skip_suppress_entity_sound_check",false) and suppress_all:row.status="source_entity_suppressed"
  elif gate.get("is_minion_summon_vo",false) and suppress_summon and not (gate.get("is_keyword_vo",false) and allow_keyword):row.status="source_summon_vo_suppressed"
  else:
   # AudioPlaythrough reuses its original prefab AudioSource. A later Play
   # replaces that source's clip; leaving a state does not stop it. PlayClip
   # instead generates independent SceneObject sources and keeps each tail.
   if str(action.class_name)=="AudioPlaythroughAction":
    var slot: String="%d:%s"%[int(effect.serial),str(action.get("target_object_key",effect.route_id))]
    if source_slots.has(slot):stop_scope(str(source_slots[slot].scope))
    source_slots[slot]={"serial":int(effect.serial),"scope":row.scope}
    row.source_slot=slot
   var request: Dictionary=play_event(str(lookup.card_id),str(lookup.event),{"scope_id":row.scope,"event_token":key,"card_id":context.get("key",""),"unit_id":unit.get("id",-1),"source_side":context.get("side",-1)})
   row.status="dispatched" if request.get("accepted",false) else str(request.get("reason","rejected"))
   row.request=request
   # Generated PlayClip sources belong to SoundManager, so they outlive the
   # 1.2s shield visual. finish_scope waits for the original audible tail.
   finish_scope(row.scope)
 action_history.append(row)
 while action_history.size()>256:action_history.pop_front()
 return row

func release_owner(serial: int):
 for slot in source_slots.keys():
  if int(source_slots[slot].serial)==serial:
   stop_scope(str(source_slots[slot].scope));source_slots.erase(slot)

func clear():
 stop_all();source_slots.clear()

func get_audit() -> Dictionary:
 return {"source_slots":source_slots.duplicate(true),"actions":action_history.duplicate(true),"events":event_history.duplicate(true),"active_scopes":_scope_states.size(),"active_voices":_active_voices.size(),"pending_jobs":_pending_jobs.size(),"manifest_error":manifest_error,"source_routes":catalog.get("action_lookup",{}).keys(),"music_owned":false,"compatibility":"Source clips/gates/weights/gain/pitch, independent presentation RNG and existing prototype SFX bus/global mix"}

func _exit_tree():
 stop_all()
