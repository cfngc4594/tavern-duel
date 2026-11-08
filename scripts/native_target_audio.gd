extends "res://scripts/original_audio_router.gd"
## InputManager.CancelTargetMode source LoadAndPlay, not every arrow clear.
var game: Node
var cancel_serial:=0
var cancels: Array=[]
var error_serial:=0
var errors: Array=[]
func setup_target(owner_game: Node):
 game=owner_game;manifest_path="res://assets/original_targeting_audio_v34/runtime_manifest.json"
 super.setup(get_node("/root/SoundManager"))
func _clip_problem(clip: Dictionary) -> String:
 var path: String=str(clip.get("path",""));var digest: String=str(clip.get("sha256",""))
 if not path.begins_with("res://assets/original_targeting_audio_v34/clips/") or path.contains(".."):return "clip_path_invalid"
 if digest.length()!=64 or not digest.is_valid_hex_number() or not clip.get("identity_verified",false):return "clip_provenance_missing"
 if not _verified.has(path+digest):
  if FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=digest:return "clip_hash_mismatch"
  if not ResourceLoader.exists(path):return "clip_missing"
  _verified[path+digest]=true
 return ""
func trigger_cancel(interaction: String):
 cancel_serial+=1
 var scope: String="target-cancel:%d"%cancel_serial
 var row: Dictionary={"serial":cancel_serial,"interaction":interaction,"scope":scope,"source_order":"LoadAndPlay before DestroyFriendlyTargetArrow(true)"}
 if game.sound_enabled:
  row.request=play_event("targeting","cancel",{"scope_id":scope,"event_token":"cancel","source_side":0})
  finish_scope(scope)
 else:row.status="game_sound_disabled"
 cancels.append(row)
 while cancels.size()>128:cancels.pop_front()
func trigger_display_error(message: String):
 if message.is_empty():return
 error_serial+=1
 var scope: String="target-error:%d"%error_serial
 var row: Dictionary={"serial":error_serial,"message":message,"scope":scope,"boundary":"Original GameplayErrorCloud fixed sound with local 5834 reason; no network ErrorType or hero VO inferred"}
 if game.sound_enabled:
  row.request=play_event("targeting","display_error",{"scope_id":scope,"event_token":"display_error","source_side":0})
  finish_scope(scope)
 else:row.status="game_sound_disabled"
 errors.append(row)
 while errors.size()>128:errors.pop_front()
func get_audit() -> Dictionary:
 return {"errors":errors.duplicate(true),"cancels":cancels.duplicate(true),"events":event_history.duplicate(true),"active_voices":_active_voices.size(),"pending_jobs":_pending_jobs.size(),"manifest_error":manifest_error,"music_owned":false}
func _exit_tree():stop_all()
