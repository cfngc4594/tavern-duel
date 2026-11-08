extends Node
## Only source-bound routes. State scheduling belongs to native_endgame.
const MANIFEST = "res://assets/original_endgame_audio_v33/runtime_manifest.json"
var game: Node
var manager: Node
var manifest: Dictionary = {}
var history: Array[Dictionary] = []
var scope = ""
var outcome = ""
var _seen: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _saved_music: Dictionary = {}
var _music_owned = false
var _generation = 0
var _fades: Array[Dictionary] = []
var _screen_shown = false
var _pending: Array[Dictionary] = []

func setup(owner_game: Node):
	game = owner_game
	manager = get_node_or_null("/root/SoundManager")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if parsed is Dictionary: manifest = parsed

func begin(new_scope: String, result: String, _dead_sides: Array = [], _heroes: Dictionary = {}):
	clear()
	scope = new_scope
	outcome = result
	# NotifyOfGameOver starts playlist 107 then its outcome option before blow-up.
	if manifest.get("routes",{}).has("playlist107"): trigger("playlist107")
	var event = "notify_win" if result in ["win","victory"] else "notify_lose"
	if manifest.get("routes",{}).has(event): trigger(event)

func screen_show():
	if _screen_shown: return
	_screen_shown=true
	var kind = "victory" if outcome in ["win","victory"] else "defeat"
	trigger(kind + "_screen_audio")
	trigger(kind + "_screen_loop")

func screen_close():
	if not _screen_shown: return
	_screen_shown=false
	_generation+=1 # Cancel an unentered screen loop while preserving audible tails.
	for player in _voices:
		if is_instance_valid(player) and player.has_meta("screen_loop"):
			_fades.append({"player":player,"from":db_to_linear(player.volume_db),"to":0.0,"elapsed":0.0,"duration":1.0,"stop":true})
	var kind = "victory" if outcome in ["win","victory"] else "defeat"
	trigger(kind + "_screen_close")

func trigger(source_event: String, context: Dictionary = {}) -> Dictionary:
	var event = source_event
	if source_event == "hero_death": event += "_" + str(context.get("card_id",""))
	var token = scope + "|" + event + "|" + str(context.get("side","global"))
	if _seen.has(token): return {"status":"duplicate", "event":event}
	_seen[token] = true
	var routes: Dictionary = manifest.get("routes",{})
	if not routes.has(event):
		var missing = {"status":"unbound", "event":event,"scope":scope}
		history.append(missing)
		return missing
	var route: Dictionary = routes[event]
	var record = {"status":"scheduled","event":event,"scope":scope,"side":context.get("side","global"),"clip":route.clip,"gain":route.gain,"delay_sec":route.get("delay_sec",0.0)}
	history.append(record)
	var delay = float(route.get("delay_sec",0.0))
	if delay > 0:
		_pending.append({"remaining":delay,"generation":_generation,"route":route,"record":record})
	else: _play(route,record)
	return record

func _stream(clip_name: String) -> AudioStream:
	if _streams.has(clip_name): return _streams[clip_name]
	var clip: Dictionary = manifest.get("clips",{}).get(clip_name,{})
	var path = str(clip.get("path",""))
	if not path.begins_with("res://assets/original_endgame_audio_v33/clips/") or path.contains(".."): return null
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != clip.get("export_sha256",""): return null
	if not ResourceLoader.exists(path): return null
	var stream = load(path) as AudioStream
	if stream != null: _streams[clip_name] = stream
	return stream

func _play(route: Dictionary, record: Dictionary):
	if not is_instance_valid(manager): record.status="manager_unavailable"; return
	var bus = str(route.get("bus","SFX"))
	if bus == "SFX" and (not manager.sfx_enabled or manager.sfx_volume <= 0): record.status="muted"; return
	var stream = _stream(str(route.clip))
	if stream == null: record.status="source_missing_or_hash_mismatch"; return
	var player: AudioStreamPlayer
	if route.get("replace_bgm",false):
		player = manager.music_player
		if player == null: record.status="music_player_missing"; return
		if not _music_owned:
			_saved_music = {"stream":player.stream,"position":player.get_playback_position(),"gain":player.volume_db,"pitch":player.pitch_scale,"playing":player.playing,"track":manager.music_track.duplicate(true)}
		_music_owned=true
		manager.music_track=manifest.clips[route.clip].duplicate(true)
		manager.music_track["source_kind"]="original_client_endgame_ambience"
		player.stop()
	else:
		player=AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
		player.finished.connect(func():
			_voices.erase(player)
			player.stream=null
			player.queue_free())
	if route.get("loop",false):
		stream=stream.duplicate()
		if stream is AudioStreamWAV:
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin=0
			stream.loop_end=int(manifest.clips[route.clip].sample_frames)
	player.bus=bus
	player.stream=stream
	player.volume_db=linear_to_db(maxf(0.00001,float(route.get("gain",1.0))))
	player.pitch_scale=float(route.get("pitch",1.0))
	player.play()
	if str(route.clip).ends_with("_screen_loop"): player.set_meta("screen_loop",true)
	if route.get("replace_bgm",false):
		player.volume_db=-80.0
		_fades.append({"player":player,"from":0.0,"to":float(route.gain),"elapsed":0.0,"duration":1.0,"stop":false})
	if bus == "Music": player.stream_paused=not manager.music_enabled
	record.status="playing" if player.playing else "backend_unavailable"
	record.player_id=player.get_instance_id()

func _process(delta: float):
	if not is_instance_valid(manager): return
	for job in _pending.duplicate():
		if job.generation != _generation: _pending.erase(job); continue
		job.remaining-=delta
		if job.remaining<=0:
			_pending.erase(job)
			_play(job.route,job.record)
	for fade in _fades.duplicate():
		var p = fade.player
		if not is_instance_valid(p): _fades.erase(fade); continue
		fade.elapsed += delta
		var fraction = clampf(float(fade.elapsed)/float(fade.duration),0.0,1.0)
		p.volume_db=linear_to_db(maxf(0.0001,lerpf(float(fade.from),float(fade.to),fraction)))
		if fraction >= 1.0:
			_fades.erase(fade)
			if fade.stop:
				p.stop(); p.stream=null; _voices.erase(p); p.queue_free()
	for p in _voices.duplicate():
		if not is_instance_valid(p): _voices.erase(p); continue
		if p.bus == &"SFX" and (not manager.sfx_enabled or manager.sfx_volume <= 0):
			p.stop(); p.stream=null; _voices.erase(p); p.queue_free()
		elif p.bus == &"Music": p.stream_paused=not manager.music_enabled

func clear(restore_bgm: bool = true):
	_generation+=1
	_screen_shown=false
	_fades.clear()
	_pending.clear()
	for p in _voices:
		if is_instance_valid(p): p.stop(); p.stream=null; p.queue_free()
	_voices.clear()
	_seen.clear()
	if _music_owned and is_instance_valid(manager) and is_instance_valid(manager.music_player):
		var player: AudioStreamPlayer = manager.music_player
		player.stop()
		player.stream=null
		if restore_bgm and not manager.shutdown_pending:
			player.stream=_saved_music.get("stream")
			player.volume_db=float(_saved_music.get("gain",0.0))
			player.pitch_scale=float(_saved_music.get("pitch",1.0))
			manager.music_track=_saved_music.get("track",{})
			if _saved_music.get("playing",false) and player.stream != null: player.play(float(_saved_music.get("position",0.0)))
			player.stream_paused=not manager.music_enabled
	_saved_music.clear()
	_music_owned=false
	scope=""

func get_audit() -> Dictionary:
	return {"scope":scope,"outcome":outcome,"history":history.duplicate(true),"active_voices":_voices.size(),"music_owned":_music_owned,"route_count":manifest.get("routes",{}).size()}

func _exit_tree():
	clear(false)
	_streams.clear()
