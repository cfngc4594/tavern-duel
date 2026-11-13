extends RefCounted
## Prepare authored resources and detached prefabs during the hero-death sequence.
## Only Show attaches a prefab or starts the result background, clock and audio.

const SETTING := "render_quality/macos_result_preparation"
const FRAME_BUDGET_USEC := 1500

enum Job {MESH, TEXTURE, PREFAB, ACTOR, AUDIO_START, AUDIO_LOOP}

var _assets
var _audio: Node
var _parent: Node3D
var _outcome := ""
var _hero_card := ""
var _root_key := ""
var _actor_key := ""
var _portrait_key := ""
var _jobs: Array[Dictionary] = []
var _next_job := 0
var _planned := false
var _prefab: Dictionary = {}
var _actor: Dictionary = {}
var _audit: Dictionary = {}

static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return OS.has_feature("macos") and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and not args.has("--mac-skip-result-preparation") \
		and (args.has("--mac-result-preparation") or bool(ProjectSettings.get_setting(SETTING, false)))

func begin(assets, snapshot: Dictionary, root_key: String, binding: Dictionary, audio: Node = null) -> void:
	clear()
	_assets = assets
	_audio = audio
	_outcome = str(snapshot.get("outcome", ""))
	_hero_card = _card(snapshot)
	_root_key = root_key
	_actor_key = str(binding.get("actor_root", ""))
	for row in binding.get("portraits", []):
		if row.card_id == _hero_card:
			_portrait_key = str(row.portrait_texture)
			break
	_audit = {"chunks":[],"mesh_jobs":0,"texture_jobs":0,"prefab_ready":false,"actor_ready":false,
		"reused_prefab":false,"reused_actor":false,"audio_start_ready":false,"audio_loop_ready":false}

func advance() -> void:
	if _assets == null:return
	if not _planned:
		var started := Time.get_ticks_usec()
		var meshes: Dictionary = {}
		var textures: Dictionary = {}
		if not _portrait_key.is_empty():textures[_portrait_key] = true
		_collect(_root_key, meshes, textures)
		_collect(_actor_key, meshes, textures)
		for key in meshes:
			if not _assets.mesh_cache.has(key):_jobs.append({"kind":Job.MESH,"key":key})
		for key in textures:
			if not _assets.texture_cache.has(key):_jobs.append({"kind":Job.TEXTURE,"key":key})
		if _assets.objects.has(_root_key):_jobs.append({"kind":Job.PREFAB,"key":_root_key})
		if _assets.objects.has(_actor_key):_jobs.append({"kind":Job.ACTOR,"key":_actor_key})
		if is_instance_valid(_audio):
			_jobs.append({"kind":Job.AUDIO_START})
			_jobs.append({"kind":Job.AUDIO_LOOP})
		_planned = true
		_record_chunk("plan", started, 1)
		return
	if _next_job >= _jobs.size():return
	var started := Time.get_ticks_usec()
	var first := _next_job
	while _next_job < _jobs.size():
		var job := _jobs[_next_job]
		# Each prefab construction and audio load gets a separate frame.
		if job.kind >= Job.PREFAB and _next_job > first:break
		_next_job += 1
		match job.kind:
			Job.MESH:
				_assets.geometry(job.key)
				_audit.mesh_jobs += 1
			Job.TEXTURE:
				_assets.load_texture(job.key)
				_audit.texture_jobs += 1
			Job.PREFAB, Job.ACTOR:
				if not is_instance_valid(_parent):_parent = Node3D.new()
				var prepared: Dictionary = _assets.instantiate(job.key, _parent)
				if job.kind == Job.PREFAB:
					_prefab = prepared
					_audit.prefab_ready = true
				else:
					_actor = prepared
					_audit.actor_ready = true
				_record_chunk("prefab" if job.kind == Job.PREFAB else "actor", started, 1)
				return
			Job.AUDIO_START, Job.AUDIO_LOOP:
				var loop: bool = job.kind == Job.AUDIO_LOOP
				var stage := "audio_loop" if loop else "audio_start"
				_audit[stage + "_ready"] = is_instance_valid(_audio) and _audio.prepare_screen_stream(loop)
				_record_chunk(stage, started, 1)
				return
		if Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC:break
	_record_chunk("resources", started, _next_job - first)

func take_prefab(snapshot: Dictionary, parent: Node3D) -> Dictionary:
	if not _matches(snapshot) or _prefab.is_empty():return {}
	_prefab.root.reparent(parent, false)
	var prepared := _prefab
	_prefab = {}
	_audit.reused_prefab = true
	return prepared

func take_actor(snapshot: Dictionary, parent: Node3D) -> Dictionary:
	if not _matches(snapshot) or _actor.is_empty():return {}
	_actor.root.reparent(parent, false)
	var prepared := _actor
	_actor = {}
	_audit.reused_actor = true
	return prepared

func audit() -> Dictionary:
	return _audit.duplicate(true)

func cancel() -> void:
	if is_instance_valid(_parent):_parent.free()
	_parent = null
	_assets = null
	_audio = null
	_prefab = {}
	_actor = {}
	_jobs.clear()

func clear() -> void:
	cancel()
	_outcome = ""
	_hero_card = ""
	_root_key = ""
	_actor_key = ""
	_portrait_key = ""
	_next_job = 0
	_planned = false
	_audit.clear()

func _record_chunk(stage: String, started: int, jobs: int) -> void:
	_audit.chunks.append({"stage":stage,"usec":Time.get_ticks_usec()-started,"jobs":jobs})

func _matches(snapshot: Dictionary) -> bool:
	return _outcome == str(snapshot.get("outcome", "")) and _hero_card == _card(snapshot)

func _card(snapshot: Dictionary) -> String:
	var heroes: Array = snapshot.get("hero_cards", [])
	return "HERO_08" if heroes.is_empty() else str(heroes[0])

func _collect(key: String, meshes: Dictionary, textures: Dictionary) -> void:
	if not _assets.objects.has(key):return
	var filter: Dictionary = _assets.component(key, "MeshFilter")
	var renderer: Dictionary = _assets.component(key, "MeshRenderer")
	if not filter.is_empty() and not renderer.is_empty():
		_add_asset(filter, ".m_Mesh", "Mesh", meshes)
		_collect_textures(renderer, textures)
	var particle: Dictionary = _assets.component(key, "ParticleSystem")
	if not particle.is_empty():
		_add_asset(particle, ".ShapeModule.m_Mesh", "Mesh", meshes)
		var particle_renderer: Dictionary = _assets.component(key, "ParticleSystemRenderer")
		_add_asset(particle_renderer, ".m_Mesh", "Mesh", meshes)
		_collect_textures(particle_renderer, textures)
	var transform: Dictionary = _assets.component(key, "Transform")
	for field in transform.get("refs", {}):
		if not str(field).begins_with(".m_Children["):continue
		var child: Dictionary = _assets.objects.get(transform.refs[field], {})
		_collect(str(child.get("refs", {}).get(".m_GameObject", "")), meshes, textures)

func _collect_textures(renderer: Dictionary, textures: Dictionary) -> void:
	for field in renderer.get("refs", {}):
		if not str(field).begins_with(".m_Materials["):continue
		var material: Dictionary = _assets.objects.get(renderer.refs[field], {})
		for slot in material.get("refs", {}):
			if str(slot).begins_with(".m_SavedProperties.m_TexEnvs["):
				_add_asset(material, slot, "Texture2D", textures)

func _add_asset(record: Dictionary, field: String, type: String, output: Dictionary) -> void:
	var key: String = str(record.get("refs", {}).get(field, ""))
	if _assets.objects.get(key, {}).get("type", "") == type:output[key] = true
