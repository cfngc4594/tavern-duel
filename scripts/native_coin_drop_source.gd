extends RefCounted
## Original activation adapter and gated, numerically verified Noise source port.
## Legacy missing bindings stay inert. Native scheduling/raster parity not claimed.
const PATH="res://assets/native_coin/drop_source_policy.json"
var source:Dictionary={}
var particle_source:Dictionary={}
var state:Dictionary={}
var effective:Dictionary={}
var requests:Array=[]
var rejected_bindings:Dictionary={}
var finished=false
var runtime_owner:Node3D
var runtime_enabled=false
var runtime_emitters:Dictionary={}
var completed_audits:Array=[]
var injected_seeds:Array=[]
var injected_seed_index=0
func attach_runtime(owner:Node3D) -> void:runtime_owner=owner
func set_source_ports_enabled(enabled:bool) -> void:runtime_enabled=enabled
func inject_source_seeds(seeds:Array) -> void:
	assert(runtime_emitters.is_empty())
	injected_seeds=seeds.duplicate();injected_seed_index=0
func _start_runtime(emitter:Dictionary,clip_name:String,time:float) -> bool:
	if not runtime_enabled or runtime_owner==null:return false
	if particle_source.is_empty():
		particle_source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/drop_particles.json"))
	for original in particle_source.emitters:
		if original.system.key!=emitter.id:continue
		var spec=original.duplicate(true)
		spec.node=runtime_owner.nodes[original.node_id];spec.autoplay=true
		var seed_value:int
		if injected_seed_index<injected_seeds.size():
			seed_value=int(injected_seeds[injected_seed_index]);injected_seed_index+=1
			spec.source_seed_provenance="explicit injected source seed for regression"
		else:
			seed_value=preload("res://scripts/native_coin_source_random.gd").next_auto_seed()
			spec.source_seed_provenance="original auto-seed xorshift; Godot Crypto initial entropy, not Unity same-session seed"
		var solver=preload("res://scripts/native_coin_drop_particles.gd").new()
		solver.setup(spec,runtime_owner.source_materials,runtime_owner,seed_value)
		runtime_emitters[emitter.id]={"solver":solver,"clip":clip_name,"start":time}
		return true
	return false
func sample_time(clip_name:String,time:float) -> void:
	if finished:return
	for item in runtime_emitters.values():
		if item.clip==clip_name:item.solver.seek(maxf(0.0,time-float(item.start)))
func _stop_runtime(id:String) -> void:
	if not runtime_emitters.has(id):return
	var solver=runtime_emitters[id].solver
	solver.source_destroy();completed_audits.append(solver.get_audit());solver.queue_free();runtime_emitters.erase(id)
func runtime_audits() -> Array:
	var result=completed_audits.duplicate(true)
	for item in runtime_emitters.values():result.append(item.solver.get_audit())
	return result

func setup(prepared_policy:Dictionary={},prepared_particles:Dictionary={}) -> void:
	source=JSON.parse_string(FileAccess.get_file_as_string(PATH)) if prepared_policy.is_empty() else prepared_policy
	particle_source=prepared_particles
	for node in source.nodes:state[node.id]=node.active
	# Initial activation is applied by the actual DoAnim call, not loading data.
	for emitter in source.emitters:effective[emitter.node_id]=false

func _node(id:String) -> Dictionary:
	for node in source.nodes:
		if node.id==id:return node
	return {}

func _active_in_hierarchy(id:String) -> bool:
	var visited={}
	while id!="0":
		if visited.has(id):return false
		visited[id]=true
		if not bool(state.get(id,false)):return false
		var record=_node(id)
		if record.is_empty():return false
		id=record.parent
	return true

func set_source_active(id:String,active:bool,clip_name:String,time:float) -> void:
	if finished:return
	state[id]=active
	_resolve_activation(clip_name,time)

func begin_drop() -> void:
	if finished:return
	_resolve_activation("CoinEffect.DoAnim",0.0)

func _resolve_activation(clip_name:String,time:float) -> void:
	for emitter in source.emitters:
		var now=_active_in_hierarchy(emitter.node_id)
		var before:bool=effective[emitter.node_id]
		if now==before:continue
		effective[emitter.node_id]=now
		if now and emitter.play_on_awake:
			# The .0 -> 1.0 source active track at3.866666555 starts both parent
			# and active child systems, using the verified source Noise math.
			var started=_start_runtime(emitter,clip_name,time)
			requests.append({"emitter":emitter.name,"source_key":emitter.id,"event":"play_on_awake","clip":clip_name,"source_time":time,"rendered":started,"status":"verified_noise_source_port" if started else "blocked_source_ports_disabled","reason":"source math and lifecycle inside explicit Godot solver bridge" if started else "source ports have not been enabled"})
		elif not now and before:
			sample_time(clip_name,time)
			_stop_runtime(emitter.id)
			requests.append({"emitter":emitter.name,"source_key":emitter.id,"event":"deactivate","clip":clip_name,"source_time":time,"rendered":false})

func record_unbound_track(clip_name:String,path:String,attribute:String,class_id:int) -> void:
	if attribute!="m_Emit":return
	var key=clip_name+":"+path+":"+attribute
	rejected_bindings[key]={"clip":clip_name,"path":path,"attribute":attribute,"class_id":class_id,"action":"ignored_missing_original_target","remapped_to_new":false}

func finish() -> void:
	if finished:return
	finished=true
	for id in runtime_emitters.keys():_stop_runtime(id)
	for id in effective:effective[id]=false

func get_audit() -> Dictionary:
	return {"source_build":source.source_build,"noise_algorithm_recovered":true,"noise_math_numeric_verified":true,"rendered_drop_emitters":runtime_emitters.size(),"runtime_source_ports_enabled":runtime_enabled,"particle_audits":runtime_audits(),"requests":requests.duplicate(true),"legacy_bindings":source.legacy_bindings.duplicate(true),"rejected_bindings":rejected_bindings.values().duplicate(true),"finished":finished,"claim":"Original Noise mathematics, settings and lifecycle port; Godot initial entropy/shape RNG/fixed-step/rasterization bridges, no Unity pixel or same-session seed equivalence claim."}
