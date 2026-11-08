extends Node
## Original BurnedCard Birth audio only. The host owns event timing and rules.
## Embers are source 2D; Fatigue spatialBlend=1 currently uses non-spatial SFX.
## Unity attenuation, category ducking and device listening parity are unverified.
const AUDIO_ROOT = "res://assets/original_hand_burn/audio/"
const FATIGUE_GAIN = 0.800000011920929
const SOURCE_LISTENER = Vector3(-7.801186561584473, 1.0, -4.937725067138672)
const SOURCE_MIN_DISTANCE = 100.0
const SOURCE_MAX_DISTANCE = 500.0
const CLIPS = [
 {"source":"credits_card_embers_1","file":"global_credits_card_embers_1_f57e5b10.wav","sha256":"01b9dfb0b06c4a5396128d73270f725aef325432902d997f59256551caf8e4b5"},
 {"source":"credits_card_embers_2","file":"global_credits_card_embers_2_c1571031.wav","sha256":"0d73d49acfebffc084d826b931789937289e07a1ae03c1c875e33cfc8689e5a8"},
 {"source":"credits_card_embers_3","file":"global_credits_card_embers_3_49b6da9d.wav","sha256":"8c44bab1d7ae4c282bee983c4ada36daa2ad7ab73fb64f748f7655d787b7c985"},
 {"source":"Fatigue_LastCard_02","file":"global_Fatigue_LastCard_02_758c7296.wav","sha256":"d9e284ec2b371ec02193355ae8498b888c68b9c04f316fe59316693129c8c8c1"}
]
var game: Node
var manager: Node
var cosmetic_rng = RandomNumberGenerator.new()
var history: Array[Dictionary] = []
var _streams: Dictionary = {}
var _errors: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _retirement_refs: Dictionary = {}
var _released = false

func setup(owner_game: Node):
 stop_all()
 game = owner_game
 manager = get_node_or_null("/root/SoundManager")
 cosmetic_rng.randomize() # Never consume the rules RNG or global random state.
 _released = false
 _streams.clear()
 _errors.clear()
 for clip in CLIPS:
  var path: String = AUDIO_ROOT + str(clip.file)
  var stream: AudioStream
  if FileAccess.file_exists(path):
   if FileAccess.get_sha256(path) != clip.sha256:
    _errors[clip.source] = "source_hash_mismatch"
    continue
   stream = AudioStreamWAV.load_from_file(path)
  elif ResourceLoader.exists(path):
   # Exported PCKs can remap WAVs to imported resources. Raw source hashes
   # are validated before export; no substitute or generated audio is used.
   stream = load(path) as AudioStream
  if stream == null:
   _errors[clip.source] = "source_missing"
  else:
   _streams[clip.source] = stream

func _muted() -> bool:
 if is_instance_valid(game) and game.get("sound_enabled") == false: return true
 if is_instance_valid(manager):
  return not bool(manager.get("sfx_enabled")) or float(manager.get("sfx_volume")) <= 0.0
 return false

func source_spatial_diagnostic(source_world_position: Vector3) -> Dictionary:
 # Original Unity coordinates, not reflected Godot coordinates or screen pixels.
 # Source rolloffMode=1 is linear, and gain remains 1 inside minDistance.
 var distance = source_world_position.distance_to(SOURCE_LISTENER)
 var attenuation_gain = clampf((SOURCE_MAX_DISTANCE - distance) / (SOURCE_MAX_DISTANCE - SOURCE_MIN_DISTANCE), 0.0, 1.0)
 return {"source_world_position":[source_world_position.x,source_world_position.y,source_world_position.z],"listener_prefab_position":[SOURCE_LISTENER.x,SOURCE_LISTENER.y,SOURCE_LISTENER.z],"distance":distance,"source_rolloff_mode":1,"min_distance":SOURCE_MIN_DISTANCE,"max_distance":SOURCE_MAX_DISTANCE,"distance_attenuation_gain":attenuation_gain,"inside_min_distance":distance <= SOURCE_MIN_DISTANCE,"position_semantics":"Snapshot at Birth; generated sound does not follow FX","scope":"Source distance-gain diagnostic only; Unity panning/doppler/reverb and runtime listener changes unverified"}

func play_burn(serial: int, source_world_position: Variant = null) -> Dictionary:
 var ember: Dictionary = CLIPS[cosmetic_rng.randi_range(0, 2)]
 var record: Dictionary = {"serial":serial,"event":"Birth","sources":[],"bus":"SFX","spatial_adapter":"Embers source 2D; Fatigue source 3D adapted to 2D SFX"}
 if source_world_position is Vector3:
  record.source_spatial = source_spatial_diagnostic(source_world_position)
 else:
  record.source_spatial = {"status":"source_world_position_not_supplied"}
 for request in [{"clip":ember,"gain":1.0},{"clip":CLIPS[3],"gain":FATIGUE_GAIN}]:
  var clip: Dictionary = request.clip
  var row: Dictionary = {"source":clip.source,"path":AUDIO_ROOT + str(clip.file),"sha256":clip.sha256,"gain":request.gain,"pitch":1.0,"status":"playing","source_spatial_blend":1.0 if clip.source == "Fatigue_LastCard_02" else 0.0,"source_category":1,"runtime_spatial_blend":0.0}
  if _released: row.status = "released"
  elif _muted(): row.status = "muted"
  elif not is_inside_tree(): row.status = "outside_tree"
  elif not _streams.has(clip.source): row.status = _errors.get(clip.source,"source_missing")
  elif AudioServer.get_bus_index(&"SFX") < 0: row.status = "sfx_bus_missing"
  else:
   var player = AudioStreamPlayer.new()
   player.bus = &"SFX"
   player.stream = _streams[clip.source]
   player.volume_linear = float(request.gain)
   player.pitch_scale = 1.0
   add_child(player)
   _voices.append(player)
   player.play()
   row.player_id = player.get_instance_id()
   if not player.playing: row.status = "backend_unavailable"
  record.sources.append(row)
 history.append(record.duplicate(true))
 if history.size() > 128: history.pop_front()
 return record

func _track_playback(player: AudioStreamPlayer):
 if not player.has_stream_playback(): return
 var playback = player.get_stream_playback()
 _retirement_refs[playback.get_instance_id()] = weakref(playback)

func _dispose(player: AudioStreamPlayer):
 _voices.erase(player)
 if not is_instance_valid(player): return
 # AudioServer can retain playback beyond stop, stream=null and queue_free.
 _track_playback(player)
 player.stop()
 player.stream = null
 player.queue_free()

func advance(_delta: float):
 pending_disposals()
 var muted = _muted()
 for player in _voices.duplicate():
  if not is_instance_valid(player): _voices.erase(player)
  elif muted or not player.playing: _dispose(player)

func stop_all():
 for player in _voices.duplicate(): _dispose(player)
 pending_disposals()

func pending_disposals() -> int:
 for id in _retirement_refs.keys():
  if _retirement_refs[id].get_ref() == null: _retirement_refs.erase(id)
 return _retirement_refs.size()

func release():
 _released = true
 stop_all()
 _streams.clear()
 game = null
 manager = null

func drain_disposals():
 assert(is_inside_tree(), "Keep burn audio in the tree until drain_disposals completes.")
 while pending_disposals() > 0: await get_tree().process_frame

func shutdown():
 ## Await before freeing the owning scene or quitting. This frees the sink.
 release()
 await drain_disposals()
 queue_free()

func get_audit() -> Dictionary:
 return {"active_voices":_voices.size(),"loaded_sources":_streams.keys(),"errors":_errors.duplicate(),"history":history.duplicate(true),"pending_disposals":pending_disposals(),"released":_released,"source_spatial_evidence":{"embers_spatial_blend":0.0,"fatigue_spatial_blend":1.0,"fatigue_rolloff_mode":1,"fatigue_min_distance":100.0,"fatigue_max_distance":500.0,"fatigue_doppler_level":1.0,"fatigue_position_semantics":"Snapshot FX world position at Birth, parent generated source to SoundManager.SceneObject","listener_prefab_position":[-7.801186561584473,1.0,-4.937725067138672],"runtime_position_mapping_verified":false,"position_contract":"Optional play_burn serial + original Unity world position; per-event source_spatial contains the diagnostic"},"compatibility":"Original clips/gains/pitch; independent cosmetic RNG; embers source 2D preserved; Fatigue 3D attenuation/panning/reverb and category ducking not reproduced by 2D SFX adapter"}

func _exit_tree():
 # Safety only. A synchronous tree exit cannot await AudioServer retirement;
 # the owner must await shutdown(), or release()+drain_disposals(), first.
 release()
