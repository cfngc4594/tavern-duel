extends Node3D
## Source hierarchy and unweighted Hermite curves, not invented coin motion.
## Shader/particle compatibility is explicitly incomplete; unsupported material
## tracks are retained in sampled_properties, never replaced by fake sparkles.
const DIR="res://assets/native_coin/"
# CoinEffect.DoAnim addresses these specific Animation components. A clip may
# also be listed on other serialized components without being played there.
const CLIP_OWNERS={"CoinSpawn1_edit":"6286280539688441038","Coin2Card":"-1712065791383071538","MulliganCoinDrop1_Edit":"-7538021581227256626","MulliganCoinDrop2_Edit":"-7538021581227256626","MulliganCoinDropGo2Card":"-7538021581227256626","MulliganCoinDrop1Glow_Edit":"980181346625688782","MulliganCoinDrop2Glow_Edit":"980181346625688782"}
signal source_event(clip_name: String, event: Dictionary)
signal particle_requested(source_name: String, playing: bool)
signal clip_finished(clip_name: String)
var drop_source=preload("res://scripts/native_coin_drop_source.gd").new()
var manifest: Dictionary={}
var nodes: Dictionary={}
var meshes: Dictionary={}
var clips: Dictionary={}
var sampled_properties: Dictionary={}
var playing: Array=[]
var unmatched_material_tracks:Dictionary={}
var birth_emitters:Array=[]
var birth_age:float=-1.0
var audio_enabled=true
var audio_history:Array=[]
var audio: AudioStreamPlayer
var loaded=false
var coin_object_finished=false
# Production stays hidden until projection and shader render tests are verified.
var source_materials=preload("res://scripts/native_coin_materials.gd").new()

func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func setup() -> void:
	if loaded:return
	manifest=_json(DIR+"runtime.json")
	drop_source.setup()
	for record in manifest.nodes:
		var node=Node3D.new();node.name=record.name;nodes[record.id]=node
	for record in manifest.nodes:
		var node:Node3D=nodes[record.id]
		var parent:Node3D=nodes.get(record.parent,self);parent.add_child(node)
		node.position=_vec(record.position);node.quaternion=_quat(record.rotation);node.scale=_vec(record.scale)
		node.visible=record.active
		if record.has("mesh"):
			var instance=MeshInstance3D.new();instance.name="OriginalMesh";instance.mesh=_mesh(record.mesh)
			instance.visible=record.get("renderer_enabled",true);instance.set_meta("source_renderer_enabled",instance.visible);node.add_child(instance);meshes[record.id]=instance
			var material_name:String=record.get("materials",[""])[0]
			instance.material_override=source_materials.build(material_name)
			# Candidate shader arithmetic is source-derived, but camera/compositing
			# and source texture mip sampling still need graphical validation.
			instance.set_meta("unported_shader_hidden",true);instance.visible=false

	for clip_name in manifest.clips:clips[clip_name]=_json(DIR+manifest.clips[clip_name].file)
	audio=AudioStreamPlayer.new();audio.bus=&"SFX";audio.stream=AudioStreamWAV.load_from_file(DIR+"the_coin_card.wav");add_child(audio)
	drop_source.attach_runtime(self)
	loaded=true

func _vec(v: Dictionary) -> Vector3:return Vector3(v.x,v.y,v.z)
func _quat(v: Dictionary) -> Quaternion:return Quaternion(v.x,v.y,v.z,v.w).normalized()

func _mesh(filename: String) -> ArrayMesh:
	var data=_json(DIR+filename);var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var normals=PackedVector3Array();var indices=PackedInt32Array()
	for v in data.vertices:vertices.append(Vector3(v[0],v[1],v[2]))
	for uv in data.uv0:uvs.append(Vector2(uv[0],1.0-uv[1]))
	for n in data.normals:normals.append(Vector3(n[0],n[1],n[2]))
	var colors=PackedColorArray()
	for color in (data.get("colors") if data.get("colors") is Array else []):colors.append(Color(color[0],color[1],color[2],color[3]))
	if colors.size()!=vertices.size():colors.resize(vertices.size());colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh=ArrayMesh.new()
	for sub in data.triangles:
		indices=PackedInt32Array()
		for tri in sub:indices.append_array(PackedInt32Array([int(tri[0]),int(tri[1]),int(tri[2])]))
		arrays[Mesh.ARRAY_INDEX]=indices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func scalar(keys: Array, time: float, component: String="") -> float:
	if keys.is_empty():return 0.0
	var a:Dictionary=keys[0];var b:Dictionary=keys[-1]
	if time<=float(a.time):return _value(a.value,component)
	if time>=float(b.time):return _value(b.value,component)
	for i in range(keys.size()-1):
		if time<float(keys[i+1].time):a=keys[i];b=keys[i+1];break
	var dt=float(b.time)-float(a.time);var t=(time-float(a.time))/dt
	var av=_value(a.value,component);var bv=_value(b.value,component)
	var sa=_value(a.outSlope,component);var sb=_value(b.inSlope,component)
	if not is_finite(sa) or not is_finite(sb):return av
	return (2*t*t*t-3*t*t+1)*av+(t*t*t-2*t*t+t)*dt*sa+(-2*t*t*t+3*t*t)*bv+(t*t*t-t*t)*dt*sb

static func _value(v: Variant, component: String) -> float:
	if component!="":v=v[component]
	if v is String:return INF if "Infinity" in v else NAN
	return float(v)

func _target(owner: Node3D, path: String) -> Node3D:
	return owner if path=="" else owner.get_node_or_null(NodePath(path))

func sample_clip(clip_name: String,time: float, owner_id: String="") -> void:
	if coin_object_finished:return
	if not loaded:setup()
	if not clips.has(clip_name):return
	var data:Dictionary=clips[clip_name]
	var owners:Array=[CLIP_OWNERS[clip_name]] if owner_id=="" else [owner_id]
	for id in owners:
		var owner:Node3D=nodes[id]
		for group in ["m_PositionCurves","m_ScaleCurves","m_RotationCurves"]:
			for track in data[group]:
				var node=_target(owner,track.path)
				if node==null:continue
				var keys:Array=track.curve.m_Curve
				var v=Vector3(scalar(keys,time,"x"),scalar(keys,time,"y"),scalar(keys,time,"z"))
				if group=="m_PositionCurves":node.position=v
				elif group=="m_ScaleCurves":node.scale=v
				else:node.quaternion=Quaternion(v.x,v.y,v.z,scalar(keys,time,"w")).normalized()
		for track in data.m_FloatCurves:
			var node=_target(owner,track.path)
			if node==null:
				drop_source.record_unbound_track(clip_name,track.path,track.attribute,int(track.classID))
				continue
			var value=scalar(track.curve.m_Curve,time)
			sampled_properties[str(id)+"/"+track.path+":"+track.attribute]=value
			if track.attribute=="m_IsActive":
				node.visible=value>=0.5
				for source_id in nodes:
					if nodes[source_id]==node:drop_source.set_source_active(source_id,value>=0.5,clip_name,time);break
			elif track.attribute=="m_Enabled":
				var instance=node.get_node_or_null("OriginalMesh")
				if instance!=null and not instance.get_meta("unported_shader_hidden",false):instance.visible=value>=0.5
			elif track.attribute.begins_with("_") or track.attribute.begins_with("["):
				_apply_material_track(node,track.attribute,value)

	drop_source.sample_time(clip_name,time)

func _apply_material_track(node:Node3D,attribute:String,value:float) -> void:
	var instance=node.get_node_or_null("OriginalMesh")
	if instance==null:return
	var slot=0;var property=attribute
	if property.begins_with("["):
		var end=property.find("]");slot=int(property.substr(1,end-1));property=property.substr(end+2)
	# This source prefab has one material per renderer. Old slot1 animation
	# tracks remain in native clips; do not fabricate extra materials for them.
	if slot!=0:unmatched_material_tracks[str(node.get_path())+":"+attribute]="source renderer has one material";return
	var material:ShaderMaterial=instance.material_override
	if material==null:return
	if property.begins_with("_Color."):
		var color=Color.WHITE;var existing=material.get_shader_parameter("_Color")
		if existing is Color:color=existing
		elif existing is Vector4:color=Color(existing.x,existing.y,existing.z,existing.w)
		match property.get_slice(".",1):
			"r":color.r=value
			"g":color.g=value
			"b":color.b=value
			"a":color.a=value
		material.set_shader_parameter("_Color",color)
	else:material.set_shader_parameter(property,value)

func enable_source_ports(enabled:bool=true) -> void:
	if coin_object_finished:return
	if not loaded:setup()
	drop_source.set_source_ports_enabled(enabled)
	# Explicit source-port candidate, never an assertion of rendered equivalence.
	for instance in meshes.values():
		instance.set_meta("unported_shader_hidden",not enabled)
		instance.visible=enabled and instance.get_meta("source_renderer_enabled",true) and instance.material_override!=null

func place_at_source_bone() -> void:
	if coin_object_finished:return
	if not loaded:setup()
	var root_node:Node3D=nodes["-6567163448337853234"]
	# DealStartingCards MoveNext 0735..075e assigns this board bone position
	# and localEulerAngles; its Bones/BoardStandardGame ancestors are identity.
	var bone:Dictionary=manifest.coin_bone
	root_node.position=_vec(bone.m_LocalPosition);root_node.quaternion=_quat(bone.m_LocalRotation)

func play_clip(clip_name: String) -> void:
	if coin_object_finished:return
	if not loaded:setup()
	playing.append({"name":clip_name,"age":0.0});sample_clip(clip_name,0.0)

func play_drop(friendly_goes_first: bool=false,play_sound:bool=true) -> void:
	if coin_object_finished:return
	if not loaded:setup()
	for id in ["6286280539688441038","-7538021581227256626","980181346625688782"]:nodes[id].visible=true
	drop_source.begin_drop()
	play_clip("CoinSpawn1_edit")
	play_clip("MulliganCoinDrop2_Edit" if friendly_goes_first else "MulliganCoinDropGo2Card")
	play_clip("MulliganCoinDrop2Glow_Edit" if friendly_goes_first else "MulliganCoinDrop1Glow_Edit")
	if play_sound:_play_source_audio("FX_MulliganCoin03_CoinFlip.wav",0.699999988079071)

func send_birth(play_sound: bool=true) -> void:
	if coin_object_finished:return
	play_clip("Coin2Card")
	_start_birth_particles()
	particle_requested.emit("FX_Motes",true);particle_requested.emit("FX_Motes2",true)
	if play_sound and audio_enabled:
		audio_history.append({"file":"the_coin_card.wav","volume":0.35,"event":"Birth"})
		audio.volume_db=linear_to_db(0.35);audio.play()

func advance(delta: float) -> void:
	if coin_object_finished:return
	var next_birth_age=birth_age+maxf(delta,0.0) if birth_age>=0.0 else -1.0
	if birth_age>=0.0 and birth_age<0.1 and next_birth_age>=0.1:
		# Split both native animation and emission at the exact Wait boundary.
		sample_clip("Coin2Card",0.1)
		for emitter in birth_emitters:emitter.seek(0.1);emitter.stop_emitting(0.1)
	var finished:Array=[]
	for item in playing:
		var previous:float=item.age;item.age+=maxf(delta,0.0);_sample_with_activation_boundaries(item.name,previous,item.age)
		for event in clips[item.name].m_Events:
			if float(event.time)>previous and float(event.time)<=item.age:
				source_event.emit(item.name,event)
				var sound_id=str(event.objectReferenceParameter.m_PathID)
				if event.functionName=="PlaySound":
					if sound_id=="2366902551377018339":_play_source_audio("FX_GameStart21_CoinShimmer.wav",1.0)
					elif sound_id=="6172895029883473079":_play_source_audio("FX_GameStart25_CoinPoof_FULL.wav",1.0)
		if item.name=="Coin2Card" and previous<0.1 and item.age>=0.1:
			particle_requested.emit("FX_Motes",false);particle_requested.emit("FX_Motes2",false)
		if item.age>=clip_duration(item.name):finished.append(item)
	for item in finished:playing.erase(item);clip_finished.emit(item.name)
	if next_birth_age>=0.0:
		for emitter in birth_emitters:emitter.seek(next_birth_age)
		birth_age=next_birth_age

func _sample_with_activation_boundaries(clip_name:String,previous:float,time:float) -> void:
	var boundaries:Array=[]
	for track in clips[clip_name].m_FloatCurves:
		if track.attribute!="m_IsActive":continue
		for key in track.curve.m_Curve:
			var at=float(key.time)
			if at>previous and at<time and not boundaries.has(at):boundaries.append(at)
	boundaries.sort()
	for at in boundaries:sample_clip(clip_name,at)
	sample_clip(clip_name,time)

func clip_duration(clip_name:String) -> float:
	var duration=0.0
	for group in ["m_PositionCurves","m_ScaleCurves","m_RotationCurves","m_FloatCurves"]:
		for track in clips[clip_name][group]:
			for key in track.curve.m_Curve:duration=maxf(duration,float(key.time))
	return duration

func bind_source_scene_clock(scene_seconds:float) -> void:
	# Unity _Time.x is time/20, not the individual clip age. Caller owns this clock.
	for instance in meshes.values():
		var material:ShaderMaterial=instance.material_override
		if material!=null:
			material.set_shader_parameter("_UnityTimeX",scene_seconds/20.0)
			material.set_shader_parameter("_GodotToSourceWorld",global_transform.affine_inverse())


func source_spawn_bone() -> Dictionary:
	if not loaded:setup()
	return manifest.spawn_bone.duplicate(true)

func _start_birth_particles() -> void:
	if coin_object_finished:return
	for emitter in birth_emitters:
		emitter.source_destroy();emitter.queue_free()
	birth_emitters.clear();birth_age=0.0
	var data=_json(DIR+"particles.json")
	for i in range(data.emitters.size()):
		var original:Dictionary=data.emitters[i]
		var spec=original.duplicate(true);spec.node=nodes[original.node_id];spec.autoplay=true
		var emitter=load("res://scripts/native_combat_particles.gd").new()
		emitter.setup(spec,source_materials,self,370100+i)
		birth_emitters.append(emitter)

func particle_audit() -> Array:
	var report:Array=[]
	for emitter in birth_emitters:report.append(emitter.get_audit())
	return report

func _play_source_audio(filename:String,source_volume:float) -> void:
	if not audio_enabled:return
	var voice=AudioStreamPlayer.new();voice.bus=&"SFX";voice.stream=AudioStreamWAV.load_from_file(DIR+filename)
	voice.volume_db=linear_to_db(source_volume);voice.pitch_scale=1.0;add_child(voice)
	voice.finished.connect(voice.queue_free);voice.play()
	audio_history.append({"file":filename,"volume":source_volume,"pitch":1.0})

func finish_coin_object() -> void:
	# Mirrors Destroy(coinObject), not Destroy(this presentation container).
	# Actual card actor/card-birth helpers may be independent siblings here.
	if coin_object_finished:return
	coin_object_finished=true
	drop_source.finish()
	playing.clear();birth_age=-1.0
	for emitter in birth_emitters:
		if is_instance_valid(emitter):
			# These wrappers are top_level and not children of the original Coin
			# root. Hide/clear synchronously before deferred resource release.
			emitter.source_destroy();emitter.visible=false;emitter.queue_free()
	birth_emitters.clear()
	var coin_root:Node3D=nodes.get("-6567163448337853234")
	if is_instance_valid(coin_root):
		coin_root.visible=false;coin_root.queue_free()
	nodes.clear();meshes.clear()

func drop_source_audit() -> Dictionary:
	return drop_source.get_audit()

func is_coin_object_active()->bool:
	# MulliganManager.HandleCoinCard reads Unity GameObject.activeSelf, not
	# activeInHierarchy. Node3D.visible represents that source object's own flag.
	var coin_root:Node3D=nodes.get("-6567163448337853234")
	return not coin_object_finished and is_instance_valid(coin_root) and coin_root.visible
