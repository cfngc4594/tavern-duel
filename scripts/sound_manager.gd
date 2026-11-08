extends Node
## Original Hearthstone audio: archive WAV conversions and untouched card OGGs.
## Mapping accuracy is explicit: exact_named means filename matches the event;
## adapted means a borrowed original effect, not a verified 1:1 event match.
## Card slots never fall back to another character or a generic effect.
## No new procedural/AI audio or generic non-Hearthstone fallback. Music uses a separately verified original-client manifest.

const VOICE_COUNT = 16
# Godot mix safety after real 7+7 death-wave PCM overload; not source normalization.
const SFX_HEADROOM_DB = -6.0
const CARD_ACTIONS = ["play", "attack", "death"]
const DEFAULT_CARD_AUDIO_MANIFEST = "res://assets/audio/cards/card_audio_manifest.json"
const ABILITY_EVENTS = {
	"charge_ready": {"path":"res://assets/audio/abilities/Charge_Summon.wav","gain_db":-4.0,
		"pitch_min":1.0,"pitch_max":1.0,"cooldown_ms":0,"original":"Charge_Summon.wav",
		"mapping":"exact_named","sha256":"53f86605126b1459a94a7194e8021b6d4bd54ed7e0f0c9d96954d44dfe885091",
		"source_url":"https://storage.googleapis.com/hearthsounds/Charge_Summon.wav"}
}
const EVENTS = {
	"hover": {"path":"res://assets/audio/sfx/hover.wav","gain_db":-13,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":90,"original":"collection_manager_card_mouse_over.ogg","mapping":"adapted"},
	"pickup": {"path":"res://assets/audio/sfx/pickup.wav","gain_db":-7,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":60,"original":"collection_manager_pick_up_card.ogg","mapping":"adapted"},
	"return": {"path":"res://assets/audio/sfx/return.wav","gain_db":-7,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":60,"original":"Card_Transition_Out.ogg","mapping":"adapted"},
	"draw": {"path":"res://assets/audio/sfx/draw.wav","gain_db":-4,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":60,"original":"draw_card_and_add_to_hand_1.ogg","mapping":"exact_named"},
	"card_play": {"path":"res://assets/audio/sfx/card_play.wav","gain_db":-4,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":40,"original":"play_card_from_hand_1.ogg","mapping":"exact_named"},
	"whoosh": {"path":"res://assets/audio/sfx/whoosh.wav","gain_db":-6,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":40,"original":"FX_MinionSummon01_DrawFromHand_01.ogg","mapping":"exact_named"},
	"summon": {"path":"res://assets/audio/sfx/summon.wav","gain_db":-3,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":30,"original":"collection_manager_drop_card.ogg","mapping":"adapted"},
	"attack_whoosh": {"enabled":false,"disabled_reason":"Unrelated two-second whirlwind is not a minion attack voice or movement cue.","path":"res://assets/audio/sfx/attack_whoosh.wav","gain_db":-10,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":40,"original":"WoW_whirlwindshort.ogg","mapping":"adapted"},
	"attack": {"category":"generic_physical_impact","assignment_note":"Original double-claw impact adapted to physical contact; never a character attack voice or verified universal attack sample.","path":"res://assets/audio/sfx/attack.wav","gain_db":-3,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":30,"original":"Shared_DoubleClawSlash_Impact_1.ogg","mapping":"adapted"},
	"magic": {"enabled":false,"disabled_reason":"Exact Fireball and Fireblast cast sources are missing.","path":"res://assets/audio/sfx/magic.wav","gain_db":-9,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":40,"original":"Shared_Fire_Precast_Large_1.ogg","mapping":"adapted"},
	"spell_hit": {"enabled":false,"disabled_reason":"Warlock skull-bolt is not Fireball or Fireblast impact.","path":"res://assets/audio/sfx/spell_hit.wav","gain_db":-5,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":30,"original":"FX_Warlock_J_SkullBolt_Impact.ogg","mapping":"adapted"},
	"frost_cast": {"path":"res://assets/audio/sfx/frost_cast.wav","gain_db":-7,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":40,"original":"FX_FreezeEvent_SpellCast.ogg","mapping":"adapted"},
	"frost_hit": {"path":"res://assets/audio/sfx/frost_hit.wav","gain_db":-4,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":30,"original":"FrostBoltHit1.ogg","mapping":"exact_named"},
	"death": {"enabled":false,"disabled_reason":"Old custom death is retained only; each minion uses its own card-specific death source.","path":"res://assets/audio/sfx/death.wav","gain_db":-5,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":0,"original":"HarvestGolem_CustomDeath_1.ogg","mapping":"adapted"},
	"mana": {"path":"res://assets/audio/sfx/mana.wav","gain_db":-8,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":80,"original":"mana_crystal_expend.ogg","mapping":"exact_named"},
	"mana_refresh": {"path":"res://assets/audio/sfx/mana_refresh.wav","gain_db":-8,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":80,"original":"mana_crystal_refresh.ogg","mapping":"exact_named"},
	"click": {"path":"res://assets/audio/sfx/click.wav","gain_db":-5,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":40,"original":"UI_MouseClick_01.ogg","mapping":"exact_named"},
	"turn": {"path":"res://assets/audio/sfx/turn.wav","gain_db":-6,"pitch_min":1,"pitch_max":1,"cooldown_ms":100,"original":"ALERT_YourTurn_0v2.ogg","mapping":"exact_named"},
	"end": {"path":"res://assets/audio/sfx/end.wav","gain_db":-4,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":100,"original":"FX_EndTurn_Down.ogg","mapping":"exact_named"},
	"error": {"path":"res://assets/audio/sfx/error.wav","gain_db":-7,"pitch_min":0.995,"pitch_max":1.005,"cooldown_ms":130,"original":"collection_manager_card_move_invalid_or_click.ogg","mapping":"adapted"},
	"corner": {"path":"res://assets/audio/sfx/corner.wav","gain_db":-8,"pitch_min":0.99,"pitch_max":1.01,"cooldown_ms":100,"original":"board_common_dirt_poke_1.ogg","mapping":"adapted"},
	"victory": {"path":"res://assets/audio/sfx/victory.wav","gain_db":-5,"pitch_min":1,"pitch_max":1,"cooldown_ms":1000,"original":"victory_screen_start.ogg","mapping":"exact_named"},
	"defeat": {"path":"res://assets/audio/sfx/defeat.wav","gain_db":-5,"pitch_min":1,"pitch_max":1,"cooldown_ms":1000,"original":"defeat_screen_start.ogg","mapping":"exact_named"},
}
var players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var sfx_volume = 0.8
var music_volume = 0.35
var music_enabled = true
var music_error = ""
var music_track = {}
var music_start_count = 0
var shutdown_pending = false
signal shutdown_finished
var shutdown_complete = false
var _quit_requested = false
var _retirement_refs: Dictionary = {}
var shutdown_audit: Dictionary = {}
const MUSIC_MANIFEST = "res://assets/audio/music/music_manifest.json"
var sfx_enabled = true
var play_history: Array[Dictionary] = []
## Missing requests are diagnostics, never successful playback entries.
var missing_card_sound_history: Array[Dictionary] = []
## Keyword effects are independent of the character voice and wolf-entry layer.
## Exact named archive source; exact client version/mix is not claimed.
var missing_ability_sound_history: Array[Dictionary] = []
@export_file("*.json") var card_audio_manifest_path = DEFAULT_CARD_AUDIO_MANIFEST
var _card_catalog: Dictionary = {}
var card_manifest_error = ""
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _voice_sequence = 0
var _rng = RandomNumberGenerator.new()
var original_audio: Node

func _ready():
	get_tree().auto_accept_quit=false
	_rng.randomize() # Only generic/UI playback uses this RNG; never card sounds/gameplay.
	reload_card_audio_manifest()
	for i in range(VOICE_COUNT):
		var player = AudioStreamPlayer.new()
		player.name = "OriginalSFX%02d" % i
		player.bus = &"SFX"
		add_child(player)
		players.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.bus = &"Music"
	add_child(music_player)
	original_audio = preload("res://scripts/original_audio_router.gd").new()
	original_audio.name = "OriginalClientAudio"
	add_child(original_audio)
	original_audio.setup(self)
	set_sfx_volume(sfx_volume)
	set_music_volume(music_volume)
	set_sfx_enabled(sfx_enabled)
	start_music()

func get_event_catalog() -> Dictionary:
	return EVENTS.duplicate(true)

func set_sfx_volume(value: float):
	sfx_volume = clampf(value,0.0,1.0)
	if sfx_volume <= 0.0: stop_all_sfx()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"),linear_to_db(maxf(sfx_volume,0.0001)) + SFX_HEADROOM_DB)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"),not sfx_enabled or sfx_volume <= 0.0)

func set_music_volume(value: float):
	music_volume = clampf(value,0.0,1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"),linear_to_db(maxf(music_volume,0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"),not music_enabled or music_volume <= 0.0)

func set_sfx_enabled(value: bool):
	sfx_enabled = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"),not sfx_enabled or sfx_volume <= 0.0)
	if not sfx_enabled: stop_all_sfx()

func stop_all_sfx():
	_track_tree_playbacks(self)
	if is_instance_valid(original_audio):
		_track_tree_playbacks(original_audio)
		original_audio.stop_all()
	for player in players:
		_track_playback(player)
		player.stop()
	_last_played.clear()

func play_original_event(card_id: String, event: String, context: Dictionary = {}) -> Dictionary:
	if shutdown_pending: return {"accepted":false,"reason":"shutdown"}
	if not is_instance_valid(original_audio): return {"accepted":false,"reason":"router_unavailable"}
	return original_audio.play_event(card_id, event, context)

func play_original_impact(attack_value: int, context: Dictionary = {}) -> Dictionary:
	if shutdown_pending: return {"accepted":false,"reason":"shutdown"}
	if not is_instance_valid(original_audio): return {"accepted":false,"reason":"router_unavailable"}
	return original_audio.play_impact(attack_value,context)

func get_original_audio_catalog() -> Dictionary:
	return original_audio.catalog.duplicate(true) if is_instance_valid(original_audio) else {}

func reload_original_audio_manifest() -> bool:
	return original_audio.reload_manifest() if is_instance_valid(original_audio) else false

func has_original_event(card_id: String, event: String) -> bool:
	return is_instance_valid(original_audio) and original_audio.has_event(card_id, event)

func stop_original_scope(scope_id: String):
	if is_instance_valid(original_audio): original_audio.stop_scope(scope_id)

func change_original_state(scope_id: String, state: String):
	if is_instance_valid(original_audio): original_audio.change_state(scope_id, state)

func reload_card_audio_manifest() -> bool:
	# Replacing a local original-audio pack is explicit and never a network fetch.
	_card_catalog.clear()
	card_manifest_error = ""
	for key in _streams.keys():
		if str(key).begins_with("card:"): _streams.erase(key)
	if not FileAccess.file_exists(card_audio_manifest_path):
		card_manifest_error = "manifest_missing"
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(card_audio_manifest_path))
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1 or not parsed.get("cards") is Dictionary:
		card_manifest_error = "manifest_invalid"
		return false
	_card_catalog = parsed.cards.duplicate(true)
	return true

func get_card_audio_catalog() -> Dictionary:
	return _card_catalog.duplicate(true)

func _missing_card_sound(card_id: String, action: String, reason: String, slot: Dictionary = {}):
	var expected_ids = slot.get("expected_source_ids", [])
	if not expected_ids is Array: expected_ids = []
	missing_card_sound_history.append({
		"card_id":card_id, "action":action, "reason":reason,
		"expected_source_ids":expected_ids.duplicate(),
		"time_ms":Time.get_ticks_msec(), "frame":Engine.get_process_frames()
	})
	if missing_card_sound_history.size() > 2048: missing_card_sound_history.pop_front()

func play_card_sound(card_id: String, action: String) -> AudioStreamPlayer:
	# No guessed identity, wildcard, name, token-parent, or generic sound fallback.
	if not action in CARD_ACTIONS:
		_missing_card_sound(card_id, action, "unsupported_action")
		return null
	if not _card_catalog.has(card_id):
		_missing_card_sound(card_id, action, "unknown_card_id")
		return null
	var card = _card_catalog[card_id]
	if not card is Dictionary or card.get("card_id", "") != card_id:
		_missing_card_sound(card_id, action, "card_identity_mismatch")
		return null
	var slots = card.get("actions", {})
	if not slots is Dictionary or not slots.get(action) is Dictionary:
		_missing_card_sound(card_id, action, "slot_missing")
		return null
	var slot: Dictionary = slots[action]
	var primary = _play_card_slot(card_id, action, slot)
	if primary == null: return null
	# Some originals (Wolfrider) have separately sourced voice and creature layers.
	# Play intact files concurrently, never synthesize or render a new combined asset.
	var layers = slot.get("layers", [])
	if layers is Array:
		for i in range(layers.size()):
			if layers[i] is Dictionary:
				_play_card_slot(card_id, action, layers[i], ":layer_%d" % (i + 1))
			else:
				_missing_card_sound(card_id, action, "layer_invalid")
	return primary

func _play_card_slot(card_id: String, action: String, slot: Dictionary, layer_suffix: String = "") -> AudioStreamPlayer:
	if slot.get("status", "missing") != "available":
		_missing_card_sound(card_id, action, str(slot.get("status", "missing")), slot)
		return null
	if slot.get("source_card_id", "") != card_id or slot.get("action", "") != action or not slot.get("identity_verified", false):
		_missing_card_sound(card_id, action, "source_identity_unverified", slot)
		return null
	if not slot.get("source_kind", "") in ["character_voice", "character_effect", "spell_effect"]:
		_missing_card_sound(card_id, action, "source_kind_invalid", slot)
		return null
	var path = str(slot.get("path", ""))
	var is_harvest_death = card_id == "EX1_556" and action == "death" and path == "res://assets/audio/sfx/death.wav" and slot.get("original", "") == "HarvestGolem_CustomDeath_1.ogg"
	if not is_harvest_death and (not path.begins_with("res://assets/audio/cards/" + card_id + "/") or path.contains("..")):
		_missing_card_sound(card_id, action, "source_path_identity_mismatch", slot)
		return null
	var digest = str(slot.get("sha256", ""))
	if digest.length() != 64 or not digest.is_valid_hex_number() or str(slot.get("original", "")).is_empty():
		_missing_card_sound(card_id, action, "source_provenance_missing", slot)
		return null
	# Exported imported resources may omit the raw input. Verify raw bytes when present;
	# packaged imported resources retain the same card-bound path and provenance.
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != digest:
		_missing_card_sound(card_id, action, "source_hash_mismatch", slot)
		return null
	if not ResourceLoader.exists(path):
		_missing_card_sound(card_id, action, "source_file_missing", slot)
		return null
	if not sfx_enabled or sfx_volume <= 0.0: return null
	var definition = {
		"path":path, "gain_db":float(slot.get("gain_db", -5.0)),
		"pitch_min":1.0, "pitch_max":1.0, "cooldown_ms":0,
		"original":slot.original, "mapping":slot.get("mapping", "exact_character_source")
	}
	var event_key = "card:" + card_id + ":" + action + layer_suffix
	var playback = _play_definition(event_key, definition, {
		"card_id":card_id, "action":action, "source_kind":slot.source_kind,
		"category":"card_specific", "identity_verified":true,
		"layer":"primary" if layer_suffix.is_empty() else layer_suffix.trim_prefix(":"),
		"language":slot.get("language", "not_applicable"), "source_url":slot.get("source_url", "")
	})
	if playback == null and not _streams.has(event_key):
		_missing_card_sound(card_id, action, "source_load_failed", slot)
	return playback

func play_sfx(event_name: String) -> AudioStreamPlayer:
	if not sfx_enabled or sfx_volume <= 0.0 or not EVENTS.has(event_name): return null
	var definition: Dictionary = EVENTS[event_name]
	if not definition.get("enabled", true): return null
	return _play_definition(event_name, definition, {"category":definition.get("category", "generic_ui_board_effect")})

func play_ability_sound(event_name: String, card_id: String, unit_id: int) -> AudioStreamPlayer:
	if not ABILITY_EVENTS.has(event_name): return null
	var definition: Dictionary=ABILITY_EVENTS[event_name]
	var reason=""
	if FileAccess.file_exists(definition.path) and FileAccess.get_sha256(definition.path)!=definition.sha256:
		reason="source_hash_mismatch"
	elif not ResourceLoader.exists(definition.path): reason="source_file_missing"
	if not reason.is_empty():
		missing_ability_sound_history.append({"event":event_name,"card_id":card_id,"unit_id":unit_id,
			"reason":reason,"time_ms":Time.get_ticks_msec(),"frame":Engine.get_process_frames()})
		if missing_ability_sound_history.size()>2048: missing_ability_sound_history.pop_front()
		return null # No substituted character voice, unrelated generic effect, or synthesis.
	if not sfx_enabled or sfx_volume<=0.0: return null
	return _play_definition(event_name,definition,{"category":"keyword_specific","card_id":card_id,
		"unit_id":unit_id,"source_name_verified":true,"source_url":definition.source_url})

func _play_definition(event_name: String, definition: Dictionary, details: Dictionary) -> AudioStreamPlayer:
	if shutdown_pending: return null
	var now = Time.get_ticks_msec()
	if _last_played.has(event_name) and now - _last_played[event_name] < definition.cooldown_ms: return null
	var stream_key = str(definition.get("stream_key", event_name))
	if not _streams.has(stream_key):
		var stream:AudioStream
		if ResourceLoader.exists(definition.path):stream=load(definition.path)
		elif str(definition.path).get_extension().to_lower()=="wav" and FileAccess.file_exists(definition.path):
			stream=AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(definition.path))
		else:return null
		if not stream is AudioStream: return null
		if definition.get("loop",false):
			stream = stream.duplicate()
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_end = int(stream.get_length() * stream.mix_rate)
			elif stream is AudioStreamOggVorbis: stream.loop = true
		_streams[stream_key] = stream
	var chosen: AudioStreamPlayer = null
	for player in players:
		if not player.playing:
			chosen = player
			break
	if chosen == null:
		# Bounded voice stealing: only the oldest effect voice, never a result cue.
		var oldest = 2147483647
		for player in players:
			if player.get_meta("event", "") in ["victory", "defeat"]: continue
			if player.get_meta("sequence", 0) < oldest:
				chosen = player
				oldest = player.get_meta("sequence", 0)
		if chosen == null: return null
		_track_playback(chosen)
		chosen.stop()
	_track_playback(chosen)
	chosen.stream = _streams[stream_key]
	chosen.volume_db = definition.gain_db
	# Character audio always plays at original pitch; it does not consume RNG.
	chosen.pitch_scale = float(definition.fixed_pitch) if definition.has("fixed_pitch") else (1.0 if details.get("category", "") == "card_specific" else _rng.randf_range(definition.pitch_min,definition.pitch_max))
	chosen.set_meta("event",event_name)
	chosen.set_meta("sequence",_voice_sequence)
	_voice_sequence += 1
	chosen.play()
	_track_playback(chosen)
	_last_played[event_name] = now
	var record = {"event":event_name,"time_ms":now,"pitch":chosen.pitch_scale,"path":definition.path,"original":definition.original,"mapping":definition.mapping,"frame":Engine.get_process_frames()}
	record.merge(details)
	play_history.append(record)
	if play_history.size() > 2048: play_history.pop_front()
	return chosen

func start_music() -> bool:
	if shutdown_pending: return false
	# Singleton-owned player survives mode/match changes. Repeated start never seeks.
	if music_player == null:return false
	if music_player.stream != null and (music_player.playing or music_player.stream_paused):return true
	music_error = ""
	if not FileAccess.file_exists(MUSIC_MANIFEST):music_error="manifest_missing";return false
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(MUSIC_MANIFEST))
	if not manifest is Dictionary or manifest.get('schema_version',0)!=1 or not manifest.get('track') is Dictionary:music_error='manifest_invalid';return false
	var track:Dictionary=manifest.track
	var path=str(track.get('path',''));var digest=str(track.get('sha256',''))
	if track.get('source_kind','')!='original_client_music' or not track.get('identity_verified',false) or str(track.get('original','')).is_empty():music_error='source_unverified';return false
	if not path.begins_with('res://assets/audio/music/') or path.contains('..') or digest.length()!=64 or not digest.is_valid_hex_number():music_error='source_invalid';return false
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=digest:music_error='source_hash_mismatch';return false
	if not ResourceLoader.exists(path):music_error='source_missing';return false
	music_track=track.duplicate(true)
	# A silent fallback driver has no live sink. Official MovieWriter supplies its own mixer.
	if AudioServer.get_driver_name()=='Dummy' and Engine.get_write_movie_path().is_empty():
		music_error='backend_unavailable';return false
	var stream=load(path)
	if not stream is AudioStream:music_error='source_not_audio';return false
	stream=stream.duplicate()
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:stream.loop=true
	elif stream is AudioStreamWAV:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0;stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	else:music_error='unsupported_loop_stream';return false
	music_track=track.duplicate(true)
	_track_playback(music_player)
	music_player.stream=stream;music_player.volume_db=float(track.get('gain_db',-6.0));music_player.pitch_scale=1.0
	music_player.play();music_start_count+=1
	_track_playback(music_player)
	music_player.stream_paused=not music_enabled
	return true

func set_music_enabled(value:bool):
	music_enabled=value
	set_music_volume(music_volume)
	if music_player != null:
		if music_player.stream==null and value:start_music()
		music_player.stream_paused=not value

func get_music_audit() -> Dictionary:
	return {'backend':AudioServer.get_driver_name(),'movie_writer':not Engine.get_write_movie_path().is_empty(),'source_verified':not music_track.is_empty(),'available':music_player!=null and music_player.stream!=null,'enabled':music_enabled,'volume':music_volume,'error':music_error,'track':music_track.duplicate(true),'start_count':music_start_count,'player_id':music_player.get_instance_id() if music_player!=null else 0,'playing':music_player.playing if music_player!=null else false,'paused':music_player.stream_paused if music_player!=null else false,'position':music_player.get_playback_position() if music_player!=null else 0.0}

func _exit_tree():
	if music_player != null:
		music_player.stream_paused=false
		_track_playback(music_player)
		music_player.stop()
		music_player.stream=null
	stop_all_sfx()

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:request_shutdown()

func _track_playback(player: Node):
	if not is_instance_valid(player) or not player.has_method("has_stream_playback") or not player.has_stream_playback(): return
	var playback = player.get_stream_playback()
	_retirement_refs[playback.get_instance_id()] = weakref(playback)

func _track_tree_playbacks(node: Node):
	_track_playback(node)
	for child in node.get_children(): _track_tree_playbacks(child)

func pending_disposals() -> int:
	for id in _retirement_refs.keys():
		if _retirement_refs[id].get_ref() == null: _retirement_refs.erase(id)
	return _retirement_refs.size()

func _process(_delta: float):
	pending_disposals()

func _quiesce_and_stop_tree(node: Node):
	# Final-exit boundary only. Do not use this for reset or Android Back.
	# Keep all owners in the tree so their asynchronous disposal can complete.
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		_track_playback(node)
		node.stream_paused = false
		node.stop()
		node.stream = null
		# Spatial players retain their playback object until the player is freed,
		# even after stop/stream=null. Only final exit disposes these nodes.
		if node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.queue_free()
	for child in node.get_children(): _quiesce_and_stop_tree(child)

func shutdown_audio():
	if shutdown_complete: return
	if shutdown_pending:
		await shutdown_finished
		return
	shutdown_pending = true
	sfx_enabled = false
	music_enabled = false
	# Snapshot before any owner release can erase the only accessible playback.
	_track_tree_playbacks(get_tree().root)
	shutdown_audit = {"tracked_before_release":_retirement_refs.size(),"participants":[],"completed":false}
	_quiesce_and_stop_tree(get_tree().root)
	stop_all_sfx()
	for participant in get_tree().get_nodes_in_group("audio_shutdown_participants"):
		if is_instance_valid(participant) and participant.has_method("shutdown_presentation_audio"):
			shutdown_audit.participants.append(str(participant.get_path()))
			await participant.shutdown_presentation_audio()
	# Owners are still alive here. Catch any late synchronous cleanup playback,
	# stop it, and await real AudioServer retirement rather than a fixed delay.
	_track_tree_playbacks(get_tree().root)
	_quiesce_and_stop_tree(get_tree().root)
	_streams.clear()
	while pending_disposals() > 0: await get_tree().process_frame
	shutdown_complete = true
	shutdown_audit.completed = true
	shutdown_audit.pending_disposals = pending_disposals()
	shutdown_finished.emit()

func request_shutdown():
	if _quit_requested: return
	_quit_requested = true
	await shutdown_audio()
	get_tree().quit()

func play_phone_source_audio(event:String,context:Dictionary={}) -> Dictionary:
	if not event in ["temporary_mana_birth","temporary_mana_destroy","opposing_draw","mana_add","mana_spend","mana_refresh"]:
		return {"accepted":false,"reason":"unsupported_phone_source_event"}
	var result=play_original_event("@phone_audio",event,context)
	# These recovered source calls are one-shot scopes. Retire after audible tails,
	# not at actor deletion, and do not retain their mixer instances indefinitely.
	if result.get("accepted",false):original_audio.finish_scope(str(context.get("scope_id","request:%d"%int(result.request_id))))
	return result
