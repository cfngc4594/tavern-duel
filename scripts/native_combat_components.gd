extends RefCounted
## Recovered build37 MonoBehaviour lifecycle, separate from SpellState/FSM.
## Source: references/combat_v32/current_component_lifecycles.cil.txt.
## Update runs before animation sampling; LateUpdate runs after animation.
## Equal-priority Unity script order and PCG random starts are compatibility.
const CLASSES=["RotateOverTime","Spinner","ScrollingUVs","SetRenderQue","ParticlePlaybackSpeed"]
var state: Dictionary={}
var assets
var records: Array=[]
var particle_speeds: Dictionary={}
var sorting_orders: Dictionary={}
var rng:=RandomNumberGenerator.new()
var last_age:=0.0
var frame_delta:=0.0
var disposed:=false
var warnings: Array=[]

func setup(source_state: Dictionary,source_assets,seed_value: int):
	state=source_state;assets=source_assets;rng.seed=seed_value
	for key in state.get("particles",{}):particle_speeds[key]=float(state.particles[key].system.data.get("simulationSpeed",1.0))
	for key in state.get("nodes",{}):
		var go: Dictionary=assets.objects.get(key,{})
		for ref in go.get("refs",{}).values():
			var source: Dictionary=assets.objects.get(ref,{})
			if not CLASSES.has(source.get("class_name","")):continue
			records.append({"source_key":source.key,"key":key,"class_name":source.class_name,"data":source.data.duplicate(true),"active":false,"started":false,"starts":0,"enables":0,"disables":0,"update_count":0,"offset":Vector2.ZERO,"previous_speed":1.0,"captured":{},"random_angles":[]})
	_sync_lifecycle(0.0)

func _is_active(record: Dictionary) -> bool:
	var node: Node3D=state.get("nodes",{}).get(record.key)
	return bool(record.data.get("m_Enabled",true)) and is_instance_valid(node) and node.is_visible_in_tree()

func _sync_lifecycle(age: float):
	for record in records:
		var active:=_is_active(record)
		if active and not record.active:
			record.active=true;record.enables+=1
			if record.class_name=="ParticlePlaybackSpeed":_capture_particles(record)
		if not active and record.active:
			_disable(record,age);record.active=false
		if active and not record.started:
			record.started=true;record.starts+=1
			match record.class_name:
				"RotateOverTime":
					var axes: Array=[Vector3.LEFT,Vector3.UP,Vector3.BACK]
					for index in range(3):
						if bool(record.data.get(["RandomStartX","RandomStartY","RandomStartZ"][index],false)):
							var angle:=rng.randi_range(0,359);record.random_angles.append({"axis":index,"degrees":angle});_rotate_local(state.nodes[record.key],axes[index],float(angle))
				"SetRenderQue":_set_sorting(record)
				"ParticlePlaybackSpeed":_capture_particles(record) # Start repeats Init after OnEnable.

func _inside(key: String,parent_key: String) -> bool:
	var child: Node3D=state.get("nodes",{}).get(key)
	var parent: Node3D=state.get("nodes",{}).get(parent_key)
	return is_instance_valid(child) and is_instance_valid(parent) and (child==parent or parent.is_ancestor_of(child))

func _capture_particles(record: Dictionary):
	record.captured.clear()
	for key in state.get("particles",{}):
		var node: Node3D=state.particles[key].node
		# Unity GetComponentsInChildren<T>() excludes inactive children.
		if _inside(key,record.key) and node.is_visible_in_tree():record.captured[key]=particle_speeds[key]

func _disable(record: Dictionary,age: float):
	record.disables+=1
	if record.class_name!="ParticlePlaybackSpeed":return
	if bool(record.data.get("m_RestoreSpeedOnDisable",true)):
		for key in record.captured:set_particle_speed(key,float(record.captured[key]),age)
	record.previous_speed=-10000000.0;record.captured.clear()

func _local_rotation(node: Node3D) -> Quaternion:
	# Unity localRotation survives zero localScale; a Godot Basis cannot encode it.
	# Preserve the recovered quaternion independently, updated by source clips/FSM.
	return state.get("source_rotations",{}).get(node.get_meta("source_key",""),Quaternion.IDENTITY)

func _write_rotation(node: Node3D,rotation: Quaternion):
	var key: String=node.get_meta("source_key","")
	if state.has("source_rotations"):state.source_rotations[key]=rotation
	node.quaternion=rotation

func _rotate_local(node: Node3D,axis: Vector3,degrees: float):
	if degrees==0.0:return
	_write_rotation(node,(_local_rotation(node)*Quaternion(axis,deg_to_rad(degrees))).normalized())

func _source_parent_rotation(node: Node3D) -> Quaternion:
	var chain: Array=[];var parent=node.get_parent()
	while parent is Node3D and parent.has_meta("source_key"):
		chain.push_front(_local_rotation(parent));parent=parent.get_parent()
	var rotation:=Quaternion.IDENTITY
	for q in chain:rotation=rotation*q
	return rotation

func _rotate_source_world(node: Node3D,axis: Vector3,degrees: float):
	if degrees==0.0:return
	# Exclude the Godot camera/handedness registration from Unity Space.World.
	var parent:=_source_parent_rotation(node)
	_write_rotation(node,(parent.inverse()*Quaternion(axis,deg_to_rad(degrees))*parent*_local_rotation(node)).normalized())

func _set_sorting(record: Dictionary):
	var keys: Array=[record.key]
	if bool(record.data.get("includeChildren",false)):
		keys=[]
		for key in state.nodes:
			if _inside(key,record.key) and state.nodes[key].is_visible_in_tree():keys.append(key)
	for key in keys:
		var renderer: Dictionary=assets.component(key,"MeshRenderer")
		if renderer.is_empty():renderer=assets.component(key,"ParticleSystemRenderer")
		if renderer.is_empty():continue
		var current: int=int(sorting_orders.get(key,renderer.data.get("m_SortingOrder",0)))
		sorting_orders[key]=current+int(record.data.get("queue",1))
		state.nodes[key].set_meta("source_sorting_order",sorting_orders[key])
		_apply_sorting(key)
	if not record.data.get("queues",[]).is_empty():warnings.append("SetRenderQue per-material queues are outside the current 18 empty source arrays")

func _apply_sorting(key: String):
	var mesh: MeshInstance3D=state.get("renderers",{}).get(key)
	if state.get("particle_players",{}).has(key):mesh=state.particle_players[key].node.mesh_instance
	if is_instance_valid(mesh):mesh.set_meta("source_sorting_order",sorting_orders[key])
	for material in state.get("materials",{}).get(key,[]):
		if not material is Material:continue
		assets.apply_render_order(material,int(sorting_orders[key]))

func set_particle_speed(key: String,value: float,age: float):
	if not particle_speeds.has(key):return
	particle_speeds[key]=value
	if state.get("particle_players",{}).has(key):
		var player: Dictionary=state.particle_players[key]
		player.node.set_playback_speed(value,maxf(0.0,age-float(player.start)))

func on_particle_created(key: String,player: Dictionary):
	if particle_speeds.has(key) and float(player.node.playback_speed)!=float(particle_speeds[key]):player.node.set_playback_speed(particle_speeds[key],0.0)
	if sorting_orders.has(key):_apply_sorting(key)

func update(age: float):
	if disposed:return
	frame_delta=maxf(0.0,age-last_age);last_age=age
	_sync_lifecycle(age)
	for record in records:
		if not record.active:continue
		var node: Node3D=state.nodes[record.key];var data: Dictionary=record.data
		match record.class_name:
			"RotateOverTime":
				_rotate_local(node,Vector3.LEFT,frame_delta*float(data.get("RotateSpeedX",0.0)))
				_rotate_local(node,Vector3.UP,frame_delta*float(data.get("RotateSpeedY",0.0)))
				_rotate_local(node,Vector3.BACK,frame_delta*float(data.get("RotateSpeedZ",0.0)))
			"Spinner":
				_rotate_local(node,Vector3.RIGHT,frame_delta*float(data.get("SpeedX",0.0)))
				_rotate_source_world(node,Vector3.UP,frame_delta*float(data.get("SpeedY",0.0)))
			"ParticlePlaybackSpeed":
				var speed: float=float(data.get("m_ParticlePlaybackSpeed",1.0))
				if speed!=float(record.previous_speed):
					record.previous_speed=speed
					for key in record.captured:set_particle_speed(key,speed,maxf(0.0,age-frame_delta))
		record.update_count+=1

func late_update(age: float):
	if disposed:return
	_sync_lifecycle(age)
	for record in records:
		if not record.active or record.class_name!="ScrollingUVs":continue
		var renderer: MeshInstance3D=state.get("renderers",{}).get(record.key)
		if not is_instance_valid(renderer) or not renderer.visible:continue
		var materials: Array=state.get("materials",{}).get(record.key,[])
		var index: int=int(record.data.get("materialIndex",0))
		if index<0 or index>=materials.size() or not materials[index] is ShaderMaterial:continue
		record.offset+=Vector2(float(record.data.uvAnimationRate.x),float(record.data.uvAnimationRate.y))*frame_delta
		var material: ShaderMaterial=materials[index]
		var st=material.get_shader_parameter("_MainTex_ST")
		if not st is Vector4:st=Vector4(1,1,0,0)
		# Source texture UV is flipped vertically at upload, retaining authored scale.
		material.set_shader_parameter("_MainTex_ST",Vector4(st.x,st.y,record.offset.x,1.0-st.y-record.offset.y))

func set_enabled(key: String,class_type: String,enabled: bool,age: float):
	for record in records:
		if record.key==key and record.class_name==class_type:record.data.m_Enabled=enabled
	_sync_lifecycle(age)

func dispose(age: float):
	if disposed:return
	for record in records:
		if record.active:_disable(record,age);record.active=false
	disposed=true

func get_audit() -> Dictionary:
	var rows: Array=[]
	for record in records:
		rows.append({"source_key":record.source_key,"object_key":record.key,"class_name":record.class_name,"enabled":bool(record.data.get("m_Enabled",true)),"active":record.active,"starts":record.starts,"enables":record.enables,"disables":record.disables,"update_count":record.update_count,"captured_particles":record.captured.keys(),"random_angles":record.random_angles.duplicate(),"offset":[record.offset.x,record.offset.y]})
	return {"components":rows,"sorting_orders":sorting_orders.duplicate(),"particle_speeds":particle_speeds.duplicate(),"warnings":warnings.duplicate(),"compatibility":"Original lifecycle values and rotation spaces; Unity same-priority script order, Godot render-priority bridge, frame partition and visual PCG are compatibility"}
