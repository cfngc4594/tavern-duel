extends Node
## Evidence-bound v30 adapter for original CardSoundData / SpellStateAudioSource.
## Uses source clip alternatives, weights and delays. It does not infer a card
## identity from filenames or reproduce an unverified global Unity audio mix.
const DEFAULT_MANIFEST = "res://assets/original_audio_v30/runtime_manifest.json"
var manager: Node
var manifest_path = DEFAULT_MANIFEST
var catalog: Dictionary = {}
var manifest_error = ""
var event_history: Array[Dictionary] = []
var random = RandomNumberGenerator.new()
var _generation = 0
var _request_id = 0
var _instances: Dictionary = {}
var _seen_tokens: Dictionary = {}
var _scope_states: Dictionary = {}
var _verified: Dictionary = {}
var _active_voices: Array[Dictionary] = []
var _instance_limit_times: Dictionary = {}
var _limit_clock = 0.0

var _pending_jobs: Array[Dictionary] = []
var _job_sequence = 0
var _timing_draws: Dictionary = {}
var _volume_controls: Dictionary = {}
var _envelopes: Dictionary = {}
var _finished_scopes: Dictionary = {}
var _duck_states: Array[Dictionary] = []
var _stage_states: Dictionary = {}
var _activations: Dictionary = {}
var _control_scopes: Dictionary = {}

func _process(delta: float):
	_limit_clock += delta
	for activation in _activations.values():
		if activation.has("origin") and not activation.get("origin_resolved",false):
			var origin = _activations.get(activation.origin,{})
			if float(origin.get("started",-1)) < 0: continue
			activation.due = float(origin.started) + activation.offset
			activation.origin_resolved = true
		if activation.started >= 0.0 or activation.due > _limit_clock: continue
		if activation.frame < 0:
			activation.frame = Engine.get_process_frames() + activation.frames
			if activation.frames == 0: activation.started = _limit_clock
		elif activation.frame <= Engine.get_process_frames(): activation.started = _limit_clock
	for job in _pending_jobs:
		if job.has("activation"):
			var activation = _activations.get(job.activation,{})
			job.due = float(activation.get("started",-1)) + job.local_delay if float(activation.get("started",-1)) >= 0 else INF
	_pending_jobs.sort_custom(func(a,b): return a.due < b.due or (is_equal_approx(a.due,b.due) and a.sequence < b.sequence))
	while true:
		var ready_index = -1
		for i in range(_pending_jobs.size()):
			if float(_pending_jobs[i].due) <= _limit_clock and int(_pending_jobs[i].get("not_before_frame",0)) <= Engine.get_process_frames(): ready_index = i; break
		if ready_index < 0: break
		var ready = _pending_jobs[ready_index]; _pending_jobs.remove_at(ready_index)
		_execute_job(ready)
	_update_envelopes()
	_update_ducking()
	for state in _instances.values(): _apply_volume(state)
	for scope in _finished_scopes.keys():
		var pending = _pending_jobs.any(func(job): return job.scope_id == scope)
		var playing = false
		for state in _instances.values():
			if state.scope_id == scope and _voice_alive(state):
				if state.loop and not _envelopes.has(state.instance_key) and float(_volume_controls.get(state.instance_key,state.code_volume)) <= 0.00001:
					_cancel_instance(state.instance_key,"silent_completed_loop")
				else: playing = true
		if not pending and not playing:
			stop_scope(scope)
			_finished_scopes.erase(scope)

func finish_scope(scope: String):
	# Retire only after authored delayed actions, fades and audible tails finish.
	_finished_scopes[scope] = true

func _voice_alive(state: Dictionary) -> bool:
	var player = state.get("player")
	return is_instance_valid(player) and player.playing and player.get_meta("sequence",-2) == state.get("voice_sequence",-1)

func _sample_delay(item: Dictionary, scope: String) -> float:
	var timing = item.get("timing",{})
	if timing.is_empty(): return maxf(0.0,float(item.get("delay_sec",0.0)))
	var total = float(timing.get("action_local_delay_sec",0.0))
	for wait in timing.get("preceding_waits",[]):
		var durations: Array[float] = []
		for action in wait.get("actions",[]):
			var low = float(action.get("min_sec",0.0)); var high = float(action.get("max_sec",low))
			var duration = low
			if not is_equal_approx(low,high):
				var key = scope + "|" + str(action.get("shared_draw_id",str(item.get("state_group",""))+str(wait.state)+str(action.action_index)))
				if not _timing_draws.has(key): _timing_draws[key] = random.randf_range(low,high)
				duration = _timing_draws[key]
			durations.append(duration)
		if not durations.is_empty(): total += durations.min() if wait.get("policy","") == "first_explicit_event" else durations.max()
	return maxf(0.0,total)

func _queue_job(job: Dictionary):
	_job_sequence += 1; job.sequence = _job_sequence; job.generation = _generation
	_pending_jobs.append(job)
	_pending_jobs.sort_custom(func(a,b): return a.due < b.due or (is_equal_approx(a.due,b.due) and a.sequence < b.sequence))

func _enter_stage(job: Dictionary):
	var group = str(job.get("group",""))
	if group.is_empty(): return
	var scope = str(job.scope_id)
	var phase = str(job.get("phase",""))
	var stage_key = scope + "|" + group
	if _stage_states.has(stage_key) and _stage_states[stage_key] != phase:
		_pending_jobs = _pending_jobs.filter(func(old): return not (old.scope_id == scope and old.get("group","") == group and old.get("phase","") != phase))
		for old in _instances.values():
			if old.scope_id == scope and old.state_group == group and old.stop_on_state_change: _cancel_instance(old.instance_key,"source_stage_change")
		for old_key in _envelopes.keys():
			if _envelopes[old_key].get("group_key","") == stage_key: _envelopes.erase(old_key)
	_stage_states[stage_key] = phase

func _execute_job(job: Dictionary):
	if job.generation != _generation: return
	_enter_stage(job)
	if job.kind == "control":
		_control_scopes[job.key] = job.scope_id
		var control: Dictionary = job.control.duplicate(true)
		control.group_key = job.scope_id + "|" + str(control.get("state_group",""))
		_stop_layer(job.key,control)
	elif job.kind == "play":
		var state: Dictionary = job.state
		if state.cancelled: return
		_cancel_instance(state.instance_key,"source_replay")
		_instances[state.instance_key] = state
		_play_layer(state)


func setup(owner_manager: Node):
	manager = owner_manager
	random.randomize()
	reload_manifest()

func reload_manifest() -> bool:
	stop_all()
	catalog.clear(); _verified.clear(); manifest_error = ""
	if not FileAccess.file_exists(manifest_path):
		manifest_error = "manifest_missing"
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1 or not parsed.get("cards") is Dictionary or not parsed.get("sound_defs") is Dictionary:
		manifest_error = "manifest_invalid"
		return false
	catalog = parsed
	return true

func _record(kind: String, details: Dictionary):
	var row = {"kind":kind, "time_ms":Time.get_ticks_msec(), "frame":Engine.get_process_frames()}
	row.merge(details, true)
	event_history.append(row)
	if event_history.size() > 4096: event_history.pop_front()

func has_event(card_id: String, event: String) -> bool:
	var card=catalog.get("cards",{}).get(card_id,{})
	if card_id=="@physical":card=catalog.get("systems",{}).get("physical_impact",{})
	elif card_id=="@attack":card=catalog.get("systems",{}).get("attack_launch",{})
	elif card_id.begins_with("@"):card=catalog.get("systems",{}).get(card_id.substr(1),{})
	return card.get("events",{}).has(event)

func play_impact(attack_value: int, context: Dictionary = {}) -> Dictionary:
	var system = catalog.get("systems",{}).get("physical_impact",{})
	var ranges = system.get("ranges",[])
	if ranges.is_empty(): return {"accepted":false,"reason":"attack_range_unbound"}
	var clamped = clampi(attack_value,int(ranges.front().min),int(ranges.back().max))
	var event = str(system.get("default_event",""))
	for boundary in ranges:
		if clamped >= int(boundary.min) and clamped <= int(boundary.max): event = boundary.event; break
	var details = context.duplicate(true); details.attack_value = attack_value
	return play_event("@physical",event,details)

func play_event(card_id: String, event: String, context: Dictionary = {}) -> Dictionary:
	_request_id += 1
	var request = {"accepted":false, "request_id":_request_id, "layers_scheduled":0, "card_id":card_id, "event":event}
	var card = catalog.get("cards", {}).get(card_id, {})
	if card_id == "@physical": card = catalog.get("systems",{}).get("physical_impact",{})
	elif card_id == "@attack": card = catalog.get("systems",{}).get("attack_launch",{})
	elif card_id.begins_with("@"): card = catalog.get("systems",{}).get(card_id.substr(1),{})
	if not card is Dictionary or card.get("card_id", "") != card_id:
		return _reject(request, "card_unbound")
	if card.has("source_side_only") and int(context.get("source_side",-1)) != int(card.source_side_only): return _reject(request,"source_side_condition")
	if context.get("card_does_nothing", false): return _reject(request, "card_does_nothing")
	if event == "play" and context.get("summoned", false) and card.get("suppress_play_on_summon", false): return _reject(request,"suppress_play_on_summon")
	var route = card.get("events", {}).get(event, {})
	if route.has("source_side_only") and int(context.get("source_side",-1)) != int(route.source_side_only): return _reject(request,"source_side_condition")
	if not route is Dictionary or not route.get("binding_verified", false):
		return _reject(request, "event_unbound")
	if route.get("status", "missing") != "available":
		return _reject(request, str(route.get("status", "missing")))
	if not manager.sfx_enabled or manager.sfx_volume <= 0.0:
		return _reject(request, "muted")
	var scope = str(context.get("scope_id", "request:%d" % _request_id))
	context = context.duplicate(true)
	var side_name = "friendly" if int(context.get("source_side",0)) == 0 else "opponent"
	context.selected_area_stage = card.get("stage_cardinality",{}).get("area_selection_by_source_side",{}).get(side_name,"")
	var token = str(context.get("event_token", ""))
	var token_key = scope + "|" + event + ":" + token
	# This explicit callback latch belongs to this prototype, not Unity RandomClips.
	if not token.is_empty() and _seen_tokens.has(token_key):
		return _reject(request, "duplicate_callback")
	if not token.is_empty(): _seen_tokens[token_key] = true
	if context.has("state") and not route.get("state_scoped",false): change_state(scope, str(context.state))
	var jobs: Array[Dictionary] = []
	for stop in route.get("stops",[]):
		if not _stage_matches(stop,context): continue
		jobs.append({"kind":"control","control":stop,"key":scope + ":" + str(stop.get("instance_id","")),"scope_id":scope,"due":_limit_clock + _source_event_delay(stop,scope,context) + float(context.get("delay_sec",0)),"order":stop.get("order",["",0,0]),"group":stop.get("state_group",""),"phase":stop.get("timing",{}).get("entry_event",event),"yield_frames":stop.get("yield_frames",0),"local_delay":_source_event_delay(stop,scope,context)})
	request.accepted = true
	var layers = route.get("layers", [])
	if not layers is Array: return _reject(request, "layers_invalid")
	for i in range(layers.size()):
		var layer = layers[i]
		if not layer is Dictionary or not layer.get("enabled", true) or not _stage_matches(layer,context): continue
		var instance_key = scope + ":" + str(layer.get("instance_id", event + ":" + str(i)))
		if not layer.get("restart_existing",true): instance_key += "@%d:%d" % [_request_id,i]
		# CardSoundSpell::Play stops its prior source and delayed coroutine first.
		if layer.get("source_kind","") == "CardSoundSpell":
			_cancel_instance(instance_key, "replay")
			_pending_jobs = _pending_jobs.filter(func(job): return not (job.kind == "play" and job.state.instance_key == instance_key))
		var state = {"generation":_generation, "request_id":_request_id, "scope_id":scope,
			"instance_key":instance_key, "card_id":card_id, "event":event, "layer":i,"source_name":str(layer.get("source_name","")),"generated_source":not bool(layer.get("restart_existing",true)),"instance_limit_override":layer.get("instance_limit_override"),
			"sound_def":str(layer.get("sound_def", "")), "sound_options":layer.get("sound_options",[]),"action_weights_present":bool(layer.get("action_weights_present",false)),"state":str(context.get("state", "")),
			"stop_on_state_change":bool(layer.get("stop_on_state_change", false)), "player":null,
			"context":context.duplicate(true), "cancelled":false,"code_volume":float(layer.get("code_volume",1.0)),"code_pitch":float(layer.get("code_pitch",1.0)),"code_volume_min":float(layer.get("code_volume_min",1.0)),"code_volume_max":float(layer.get("code_volume_max",1.0)),"code_pitch_min":float(layer.get("code_pitch_min",1.0)),"code_pitch_max":float(layer.get("code_pitch_max",1.0)),"state_group":str(layer.get("state_group","")),"source_volume":float(layer.get("source_volume",1.0)),"source_pitch":float(layer.get("source_pitch",1.0)),"loop":bool(layer.get("loop",false))}
		request.layers_scheduled += 1
		var delay = _source_event_delay(layer,scope,context) + maxf(0.0,float(context.get("delay_sec",0)))
		request.first_delay_sec = minf(float(request.get("first_delay_sec",delay)),delay)
		_record("scheduled", {"request_id":_request_id,"card_id":card_id,"event":event,"layer":i,"scope_id":scope,"delay_sec":delay})
		jobs.append({"kind":"play","state":state,"scope_id":scope,"due":_limit_clock + delay,"order":layer.get("order",["",0,i]),"group":layer.get("state_group",""),"phase":layer.get("timing",{}).get("entry_event",event),"yield_frames":layer.get("yield_frames",0),"local_delay":delay-maxf(0,float(context.get("delay_sec",0)))})
	jobs.sort_custom(func(a,b):
		if not is_equal_approx(a.due,b.due): return a.due < b.due
		for axis in range(3):
			if a.order[axis] != b.order[axis]: return a.order[axis] < b.order[axis]
		return a.kind == "play" and b.kind != "play"
	)
	for job in jobs:
		var yield_frames = maxi(int(context.get("defer_frames",0)),int(job.get("yield_frames",0)))
		if context.get("skip_spawn_delay",false): yield_frames = 0
		if yield_frames > 0 or context.has("origin_activation"):
			var activation_id = scope + "|" + str(_request_id) + ":" + str(job.group)
			var base_delay = maxf(0,float(context.get("delay_sec",0)))
			if not _activations.has(activation_id):
				_activations[activation_id] = {"scope_id":scope,"due":_limit_clock+base_delay,"frame":Engine.get_process_frames()+yield_frames if base_delay<=0 else -1,"frames":yield_frames,"started":-1.0}
				if context.has("origin_activation"):
					_activations[activation_id].origin = context.origin_activation
					_activations[activation_id].offset = base_delay
					_activations[activation_id].due = INF
					_activations[activation_id].frame = -1
			if not request.has("activation_id"): request.activation_id = activation_id
			job.activation = activation_id; job.due = INF
			_queue_job(job)
		elif job.due <= _limit_clock:
			job.generation = _generation; _execute_job(job)
		else: _queue_job(job)
	_record("request", request)
	return request

func _reject(request: Dictionary, reason: String) -> Dictionary:
	request.accepted = false; request.reason = reason
	_record("rejected", request)
	return request

func _source_event_delay(item:Dictionary,scope:String,context:Dictionary)->float:
	if context.has("source_fsm_state"):
		return maxf(0.0,float(item.get("timing",{}).get("action_local_delay_sec",0.0)))
	return _sample_delay(item,scope)

func _stage_matches(item: Dictionary, context: Dictionary) -> bool:
	if context.has("source_fsm_state"):
		var path:Array=item.get("timing",{}).get("state_path",[])
		var order:Array=item.get("order",[])
		if path.is_empty() or order.size()<3:return false
		if str(path[-1])!=str(context.source_fsm_state) or int(order[-1])!=int(context.source_fsm_action_index):return false
	if context.has("stage_filter") and not item.get("stage_role","") in context.stage_filter: return false
	if not str(item.get("area_stage","")).is_empty() and str(item.area_stage) != str(context.get("selected_area_stage","")): return false
	return true

func _clip_problem(clip: Dictionary) -> String:
	var path = str(clip.get("path", ""))
	var digest = str(clip.get("sha256", ""))
	if not path.begins_with("res://assets/original_audio_v30/") or path.contains(".."):
		return "clip_path_invalid"
	if digest.length() != 64 or not digest.is_valid_hex_number() or not clip.get("identity_verified", false):
		return "clip_provenance_missing"
	if not _verified.has(path + digest):
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != digest: return "clip_hash_mismatch"
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path): return "clip_missing"
		_verified[path + digest] = true
	return ""

func choose_clip(sound_def: Dictionary) -> Dictionary:
	# SoundUtils::GetRandomClipFromDef, including <= boundaries and zero weights.
	# LoadClipForPlayback falls through a null random clip to the main clip.
	var alternatives = sound_def.get("random_clips", [])
	var selected: Dictionary = {}
	if alternatives is Array and not alternatives.is_empty():
		var total = 0.0
		for alternative in alternatives: total += float(alternative.get("weight", 0.0))
		var choice = random.randf_range(0.0, total)
		var accumulated = 0.0
		selected = alternatives.back().get("clip", {})
		for i in range(alternatives.size() - 1):
			accumulated += float(alternatives[i].get("weight", 0.0))
			if choice <= accumulated:
				selected = alternatives[i].get("clip", {})
				break
	if selected.is_empty(): return sound_def.get("main_clip", {})
	return selected

func choose_action_sound(options: Array, weights_present: bool) -> String:
	# PlayMaker ActionHelpers.GetRandomWeightedIndex uses subtraction and strict <.
	# Empty weights select index zero in AudioPlayRandomClipAction. A -1 result
	# would throw in the source client; this adapter safely emits no sound instead.
	if options.is_empty(): return ""
	if not weights_present: return str(options[0].get("sound_def",""))
	var total = 0.0
	for option in options: total += float(option.get("weight",0.0))
	var point = random.randf_range(0.0,total)
	for option in options:
		var weight = float(option.get("weight",0.0))
		if point < weight: return str(option.get("sound_def",""))
		point -= weight
	return ""

func _play_layer(state: Dictionary):
	if state.cancelled or not manager.sfx_enabled or manager.sfx_volume <= 0.0: return
	if not state.sound_options.is_empty():
		state.sound_def = choose_action_sound(state.sound_options,state.action_weights_present)
		if state.sound_def.is_empty():
			_record("missing",{"request_id":state.request_id,"reason":"playmaker_weighted_index_negative_safe_silence"}); return
	var definition = catalog.get("sound_defs", {}).get(state.sound_def, {})
	if not definition is Dictionary or not definition.get("identity_verified", false):
		_record("missing", {"request_id":state.request_id,"reason":"sound_def_unbound","sound_def":state.sound_def}); return
	var clip = choose_clip(definition)
	var problem = _clip_problem(clip)
	if not problem.is_empty():
		_record("missing", {"request_id":state.request_id,"reason":problem,"sound_def":state.sound_def}); return
	var volume = float(definition.get("volume", 1.0)) * state.source_volume
	var pitch = float(definition.get("pitch", 1.0)) * state.source_pitch * state.code_pitch
	volume *= random.randf_range(float(definition.get("volume_min", 1.0)), float(definition.get("volume_max", 1.0)))
	pitch *= random.randf_range(float(definition.get("pitch_min", 1.0)), float(definition.get("pitch_max", 1.0)))
	volume *= state.code_volume_min if is_equal_approx(state.code_volume_min,state.code_volume_max) else random.randf_range(state.code_volume_min,state.code_volume_max)
	pitch *= state.code_pitch_min if is_equal_approx(state.code_pitch_min,state.code_pitch_max) else random.randf_range(state.code_pitch_min,state.code_pitch_max)
	state.base_gain = volume
	state.category = int(definition.get("category",0))
	state.ignore_ducking = bool(definition.get("ignore_ducking",false))
	volume *= float(_volume_controls.get(state.instance_key,state.code_volume)) * _duck_gain(state.category,state.ignore_ducking)
	if not _process_clip_limits(clip,state): return
	var instance_limit = _check_instance_limit(definition,clip,state)
	if not instance_limit.allowed: return
	var clip_id = str(clip.get("clip_id", clip.sha256))
	var runtime_definition = {"path":clip.path,"gain_db":linear_to_db(maxf(volume,0.0001)),
		"fixed_pitch":pitch,"pitch_min":pitch,"pitch_max":pitch,"cooldown_ms":0,
		"loop":state.loop,"stream_key":"original:" + clip.sha256 + (":loop" if state.loop else ":once"),"original":str(clip.get("name",clip_id)),"mapping":"original_client_binding"}
	var player = manager._play_definition("original:" + state.card_id + ":" + state.event, runtime_definition,
		{"category":"original_client", "card_id":state.card_id,"action":state.event,"layer":state.layer,
		"sound_def":state.sound_def,"clip_id":clip_id,"scope_id":state.scope_id,"request_id":state.request_id,
		"source_category":definition.get("category", ""),"identity_verified":true,
		"source_build":catalog.get("source_build", ""),"owner_card_id":state.context.get("card_id",state.card_id),"attack_value":state.context.get("attack_value",null),"source_side":state.context.get("source_side",null),"target_id":state.context.get("target_id",null),"target_position":str(state.context.get("target_position","")),"timing_scope":"source FSM waits on prototype semantic boundary; native zero-delay coroutine yields adapted to process frames"})
	state.player = player
	if player != null:
		state.voice_sequence = player.get_meta("sequence", -1)
		_begin_ducking(state)
		if instance_limit.get("enabled",false):
			var times: Array = _instance_limit_times.get(instance_limit.name,[])
			times.append(_limit_clock + instance_limit.duration)
			_instance_limit_times[instance_limit.name] = times
		_active_voices.append({"player":player,"sequence":state.voice_sequence,"requested_clip":clip.get("requested_clip",""),"scope_id":state.scope_id,"request_id":state.request_id})
		_record("played", {"request_id":state.request_id,"card_id":state.card_id,"event":state.event,"layer":state.layer,"sound_def":state.sound_def,"clip_id":clip_id,"scope_id":state.scope_id})

func _check_instance_limit(definition: Dictionary, clip: Dictionary, state: Dictionary) -> Dictionary:
	var limits = state.get("instance_limit_override")
	if not limits is Dictionary:
		limits = {"enabled":definition.get("instance_limited",false),"duration":definition.get("instance_limited_duration",0.0),"maximum":definition.get("instance_limit_maximum",1),"max_out":definition.get("limit_max_out_option",0)}
	if not limits.get("enabled",false): return {"allowed":true,"enabled":false}
	var source_name = str(definition.get("generated_source_name","")) if state.generated_source else str(state.source_name)
	if source_name.is_empty():
		_record("missing",{"request_id":state.request_id,"reason":"instance_limit_source_name_missing"})
		return {"allowed":false}
	var times: Array = _instance_limit_times.get(source_name,[])
	times = times.filter(func(expiry): return float(expiry) > _limit_clock)
	_instance_limit_times[source_name] = times
	if times.size() >= maxi(1,int(limits.get("maximum",1))):
		var reason = "instance_skip_newest" if int(limits.get("max_out",0)) == 0 else "unused_stop_oldest_self_destruction_not_emulated"
		# All enabled limits in this recovered card pool use SKIP_NEWEST. The
		# client's STOP_OLDEST generated-source self-destruction bug is not guessed.
		_record("limited",{"request_id":state.request_id,"card_id":state.card_id,"event":state.event,"reason":reason,"source_name":source_name})
		return {"allowed":false}
	var duration = float(limits.get("duration",0.0))
	if duration <= 0.0: duration = float(clip.get("duration_sec",0.0))
	return {"allowed":true,"enabled":true,"name":source_name,"duration":duration}

func _process_clip_limits(clip: Dictionary, state: Dictionary) -> bool:
	# SoundManager::ProcessClipLimits compares fraction already played, not ms.
	# Sources beyond the exclusive window remain audible but stop counting.
	_active_voices = _active_voices.filter(func(v): return is_instance_valid(v.player) and v.player.playing and v.player.get_meta("sequence",-1) == v.sequence)
	var requested = str(clip.get("requested_clip",""))
	for group in catalog.get("playback_limit_groups",[]):
		if not group.clips.has(requested): continue
		var counted: Array[Dictionary] = []
		for voice in _active_voices:
			if not group.clips.has(voice.requested_clip): continue
			var length = voice.player.stream.get_length()
			var progress = voice.player.get_playback_position() / length if length > 0.0 else 1.0
			if progress > float(group.clips[voice.requested_clip].exclusive_fraction): continue
			var item = voice.duplicate(); item.progress = progress
			counted.append(item)
		if counted.size() < int(group.limit): continue
		var replacement: Dictionary = {}
		var best_progress = 1.0
		for voice in counted:
			if int(group.clips[voice.requested_clip].priority) < int(group.clips[requested].priority) and voice.progress < best_progress:
				replacement = voice; best_progress = voice.progress
		if replacement.is_empty():
			_record("limited",{"request_id":state.request_id,"card_id":state.card_id,"event":state.event,"group_id":group.id,"reason":"exclusive_playback_window"})
			return false
		replacement.player.stop()
		_record("limit_replaced",{"request_id":state.request_id,"previous_request_id":replacement.request_id,"group_id":group.id})
	return true

func _stop_layer(key: String, stop: Dictionary):
	var kind = str(stop.get("kind","stop"))
	if kind == "stop":
		_cancel_instance(key,"source_stop"); _envelopes.erase(key); return
	var target = float(stop.get("target_volume",1.0))
	var binding = stop.get("volume_binding")
	if binding is Dictionary and binding.get("mode","") == "same_state_animation_curve":
		var keys = binding.writers[0].curve.m_Curve
		_envelopes[key] = {"start":_limit_clock,"duration":float(keys.back().time),"keys":keys,"stop":false}
		_volume_controls[key] = float(keys[0].value)
	elif kind == "set_volume":
		_envelopes.erase(key); _volume_controls[key] = target
	elif kind == "fade":
		var seconds = float(stop.get("fade_sec",0.0))
		# Source FadeTime <= epsilon simply Finish, without setting volume/stop.
		if seconds <= 0.0000001: return
		var initial = float(_volume_controls.get(key,_instances.get(key,{}).get("code_volume",1.0)))
		_envelopes[key] = {"start":_limit_clock,"duration":seconds,"from":initial,"target":target,"stop":bool(stop.get("stop_when_done",true))}
	if _envelopes.has(key): _envelopes[key].group_key = str(stop.get("group_key",""))
	if _instances.has(key): _apply_volume(_instances[key])

func _curve_value(keys: Array, seconds: float) -> float:
	if seconds <= float(keys[0].time): return float(keys[0].value)
	for i in range(1,keys.size()):
		var left = keys[i-1]; var right = keys[i]
		if seconds <= float(right.time):
			var span = float(right.time)-float(left.time)
			var x = (seconds-float(left.time))/span
			return (2*x*x*x-3*x*x+1)*float(left.value)+(x*x*x-2*x*x+x)*span*float(left.outSlope)+(-2*x*x*x+3*x*x)*float(right.value)+(x*x*x-x*x)*span*float(right.inSlope)
	return float(keys.back().value)

func _update_envelopes():
	for key in _envelopes.keys():
		var envelope = _envelopes[key]
		var elapsed = maxf(0,_limit_clock-envelope.start)
		_volume_controls[key] = _curve_value(envelope.keys,elapsed) if envelope.has("keys") else lerpf(envelope.from,envelope.target,clampf(elapsed/envelope.duration,0,1))
		if elapsed >= envelope.duration:
			_envelopes.erase(key)
			if envelope.stop: _cancel_instance(key,"source_fade")

func _apply_volume(state: Dictionary):
	if _voice_alive(state) and state.has("base_gain"):
		var gain = state.base_gain * float(_volume_controls.get(state.instance_key,state.code_volume)) * _duck_gain(state.category,state.ignore_ducking)
		state.player.volume_db = linear_to_db(maxf(gain,0.00001))

func _begin_ducking(state: Dictionary):
	for rule in catalog.get("source_ducking_defs",[]):
		if int(rule.m_TriggerCategory) != state.category: continue
		for target in rule.m_DuckedCategoryDefs:
			_duck_states.append({"trigger":state,"category":int(target.m_Category),"gain":1.0,"from":1.0,"target":float(target.m_Volume),"start":_limit_clock,"duration":float(target.m_BeginSec),"restore":float(target.m_RestoreSec),"releasing":false})

func _update_ducking():
	for duck in _duck_states:
		if not duck.releasing and not _voice_alive(duck.trigger):
			duck.releasing = true; duck.from = duck.gain; duck.target = 1.0; duck.start = _limit_clock; duck.duration = duck.restore
		duck.gain = lerpf(duck.from,duck.target,clampf((_limit_clock-duck.start)/maxf(duck.duration,0.00001),0,1))
	_duck_states = _duck_states.filter(func(duck): return not (duck.releasing and duck.gain >= 1.0))

func _duck_gain(category: int, ignore: bool = false) -> float:
	if ignore: return 1.0
	var gain = 1.0
	for duck in _duck_states:
		if duck.category == category: gain = minf(gain,duck.gain)
	return gain

func _cancel_instance(key: String, reason: String):
	if not _instances.has(key): return
	var state: Dictionary = _instances[key]
	state.cancelled = true
	var player = state.get("player")
	# A reused pooled voice may now belong to a different request.
	if is_instance_valid(player) and player.get_meta("sequence", -2) == state.get("voice_sequence", -1): player.stop()
	_record("cancelled", {"request_id":state.request_id,"scope_id":state.scope_id,"reason":reason})
	_instances.erase(key)

func change_state(scope_id: String, state: String):
	if _scope_states.get(scope_id, "") == state: return
	_scope_states[scope_id] = state
	_pending_jobs = _pending_jobs.filter(func(job): return not (job.scope_id == scope_id and job.kind == "play" and job.state.stop_on_state_change))
	for key in _instances.keys():
		var instance: Dictionary = _instances[key]
		if instance.scope_id == scope_id and instance.stop_on_state_change: _cancel_instance(key, "state_change")

func _can_play_death(unit: Dictionary) -> bool:
	return unit.get("deathrattle_return_zone",0) == 0 and not unit.get("suppress_death_sound",false)

func choose_death_index(wave: Array, combat_pair: Array = []) -> int:
	# Preserve the CIL branch order, including its asymmetric mutual-kill fallback.
	if wave.size() == 1: return 0 if _can_play_death(wave[0].get("unit",wave[0])) else -1
	if wave.size() == 2 and combat_pair.size() == 2:
		var attacker = -1; var defender = -1
		for i in range(2):
			var id = wave[i].get("unit",wave[i]).get("id",-1)
			if id == combat_pair[0]: attacker = i
			if id == combat_pair[1]: defender = i
		if attacker >= 0 and defender >= 0:
			return defender if _can_play_death(wave[defender].get("unit",wave[defender])) else attacker
	var eligible: Array[int] = []
	for i in range(wave.size()):
		if _can_play_death(wave[i].get("unit",wave[i])): eligible.append(i)
	if eligible.is_empty(): return -1
	return eligible[random.randi_range(0,eligible.size()-1)]

func stop_scope(scope_id: String):
	_pending_jobs = _pending_jobs.filter(func(job): return job.scope_id != scope_id)
	for key in _envelopes.keys():
		if _control_scopes.get(key,"") == scope_id: _envelopes.erase(key)
	for key in _volume_controls.keys():
		if _control_scopes.get(key,"") == scope_id: _volume_controls.erase(key)
	for key in _instances.keys():
		if _instances[key].scope_id == scope_id: _cancel_instance(key, "scope_end")
	for key in _control_scopes.keys():
		if _control_scopes[key] == scope_id: _control_scopes.erase(key)
	_scope_states.erase(scope_id)
	_finished_scopes.erase(scope_id)
	for cache in [_timing_draws,_seen_tokens,_stage_states,_activations]:
		for key in cache.keys():
			if str(key).begins_with(scope_id + "|"): cache.erase(key)

func stop_all():
	_generation += 1
	_pending_jobs.clear(); _envelopes.clear(); _volume_controls.clear(); _timing_draws.clear(); _finished_scopes.clear(); _duck_states.clear(); _stage_states.clear(); _activations.clear(); _control_scopes.clear()
	for key in _instances.keys(): _cancel_instance(key, "stop_all")
	_seen_tokens.clear(); _scope_states.clear(); _active_voices.clear(); _instance_limit_times.clear()
