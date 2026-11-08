extends RefCounted
## Original object identities, local hierarchy, mesh surfaces and runtime clips.
## Projection and Unity renderer compatibility are intentionally separate.
const BASE := "res://assets/original_summon_v31/"
const Curves = preload("res://scripts/native_summon_curves.gd")
const SourceManifest = preload("res://scripts/native_source_manifest.gd")
var manifest: Dictionary = {}
var objects: Dictionary = {}
var mesh_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var clips: Dictionary = {}
var missing: Array = []
var material_audit: Array = []
var renderer: Node

func setup(card_renderer: Node = null) -> void:
	renderer=card_renderer
	manifest=SourceManifest.load_manifest(BASE+"manifest.json")
	objects=manifest.get("objects",{})
	for key in objects:
		if objects[key].type=="AnimationClip": clips[objects[key].name]=objects[key]

func clip_length(clip_name: String) -> float:
	if not clips.has(clip_name): return 0.0
	var length := 0.0
	var d: Dictionary=clips[clip_name].data
	for kind in ["m_PositionCurves","m_RotationCurves","m_EulerCurves","m_ScaleCurves","m_FloatCurves"]:
		for track in d.get(kind,[]):
			for key in track.curve.get("m_Curve",[]):length=maxf(length,float(key.time))
	for event in d.get("m_Events",[]):length=maxf(length,float(event.time))
	return length

func component(go_key: String, kind: String) -> Dictionary:
	var go: Dictionary=objects.get(go_key,{})
	for target in go.get("refs",{}).values():
		if objects.has(target) and objects[target].type==kind:return objects[target]
	return {}

func load_texture(key: String) -> Texture2D:
	if texture_cache.has(key): return texture_cache[key]
	if not objects.has(key) or not objects[key].files.has("png"): return null
	var path: String=BASE+str(objects[key].files.png)
	var texture: Texture2D=load(path) if ResourceLoader.exists(path) else ImageTexture.create_from_image(preload("res://scripts/packed_png.gd").load_png(path))
	texture_cache[key]=texture
	return texture

func geometry(key: String) -> ArrayMesh:
	if mesh_cache.has(key):return mesh_cache[key]
	var record: Dictionary=objects.get(key,{})
	if not record.get("files",{}).has("mesh"):return null
	var d: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+record.files.mesh))
	var ps:=PackedVector3Array();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
	for p in d.vertices:ps.append(Vector3(p[0],p[1],p[2]))
	for p in (d.get("uv0") if d.get("uv0") is Array else []):uv.append(Vector2(p[0],1.0-p[1]))
	for p in (d.get("uv1") if d.get("uv1") is Array else []):uv2.append(Vector2(p[0],1.0-p[1]))
	for n in (d.get("normals") if d.get("normals") is Array else []):normals.append(Vector3(n[0],n[1],n[2]))
	for c in (d.get("colors") if d.get("colors") is Array else []):colors.append(Color(c[0],c[1],c[2],c[3]))
	if colors.size()!=ps.size():colors.resize(ps.size());colors.fill(Color.WHITE)
	var mesh:=ArrayMesh.new()
	for surface in d.triangles:
		var ix:=PackedInt32Array()
		for tri in surface:ix.append_array(PackedInt32Array([tri[0],tri[1],tri[2]]))
		var a: Array=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=ps;a[Mesh.ARRAY_INDEX]=ix
		if uv.size()==ps.size():a[Mesh.ARRAY_TEX_UV]=uv
		if uv2.size()==ps.size():a[Mesh.ARRAY_TEX_UV2]=uv2
		if normals.size()==ps.size():a[Mesh.ARRAY_NORMAL]=normals
		a[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	mesh_cache[key]=mesh
	return mesh

func material(key: String, texture_override: Texture2D = null) -> Material:
	var record: Dictionary=objects.get(key,{})
	if record.is_empty():return null
	var source: Dictionary=record.data.get("m_SavedProperties",{})
	var floats: Dictionary={};var colors: Dictionary={};var textures: Dictionary={};var sts: Dictionary={}
	for entry in source.get("m_Floats",[]):floats[entry[0]]=entry[1]
	for entry in source.get("m_Colors",[]):colors[entry[0]]=Curves.color(entry[1])
	for i in range(source.get("m_TexEnvs",[]).size()):
		var entry=source.m_TexEnvs[i];var tex_key=record.refs.get(".m_SavedProperties.m_TexEnvs[%d][1].m_Texture"%i,"")
		textures[entry[0]]=load_texture(tex_key)
		sts[entry[0]]=Vector4(entry[1].m_Scale.x,entry[1].m_Scale.y,entry[1].m_Offset.x,1.0-float(entry[1].m_Scale.y)-float(entry[1].m_Offset.y))
	if texture_override!=null:textures["_MainTex"]=texture_override
	var shader_id: String=str(record.refs.get(".m_Shader","")).get_slice(":",1)
	var shader_file: String={"4454903573088140019":"flash","-8682043857861559096":"rays","-666151408197827071":"scroll","1610204260223125505":"dust","6322982158558142423":"portrait","3410991767739636778":"addmultiply","-230275896195282385":"hidden_glow","-2557555604182605517":"shadow","-1327719733717699995":"highlight"}.get(shader_id,"")
	if shader_file!="" and ResourceLoader.exists("res://shaders/native_summon_"+shader_file+".gdshader"):
		var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/native_summon_"+shader_file+".gdshader")
		if shader_file=="hidden_glow":mat.render_priority=99
		elif shader_file=="highlight":mat.render_priority=50
		# Runtime material/animation parameters keep their source spelling.
		for property in floats:mat.set_shader_parameter(property,floats[property])
		for property in colors:mat.set_shader_parameter(property,colors[property])
		for property in textures:
			if textures[property]!=null:mat.set_shader_parameter(property,textures[property])
			mat.set_shader_parameter(property+"_ST",sts[property])
		if textures.get("_MainTex")!=null:mat.set_shader_parameter("_MainTexClamp",textures["_MainTex"])
		mat.set_shader_parameter("_MainClamp",record.name=="GenFX_AllyInHand_ScryLines")
		mat.set_meta("source_colors",colors);mat.set_meta("source_floats",floats);mat.set_meta("source_key",key)
		return mat
	# Shader identity is sufficient for the existing verified translation; new
	# material objects keep their own recovered numeric properties and textures.
	if is_instance_valid(renderer) and shader_id in ["-4440234706065032223","3271891197657001233","-2508996697480494289","-1982294586754922726","9099378368919310605","-5812771937585292081"]:
		var md: Dictionary={"sourceShaderKey":record.refs.get(".m_Shader",""),"floats":[],"colors":[],"textures":[]}
		for item in source.get("m_Floats",[]):md.floats.append({"name":item[0],"value":item[1]})
		for item in source.get("m_Colors",[]):md.colors.append({"name":item[0],"value":item[1]})
		var base:=StandardMaterial3D.new();base.albedo_texture=textures.get("_MainTex")
		var result: ShaderMaterial=renderer._source_material(md,base)
		for name in textures:
			var uniform_name: String={"_MainTex":"main_tex","_SecondTex":"second_tex","_ScrollingTex":"scrolling_tex"}.get(name,"")
			if uniform_name!="" and textures[name]!=null:
				result.set_shader_parameter(uniform_name,textures[name]);result.set_shader_parameter(uniform_name+"_repeat",textures[name])
			if name in ["_MainTex","_SecondTex"]:result.set_shader_parameter("main_st" if name=="_MainTex" else "second_st",sts[name])
		result.set_meta("source_key",key);return result
	# Reuse already migrated original card shaders where their exact identity matches.
	if is_instance_valid(renderer):
		var original_key: String="CAB"+key.substr(3)
		if renderer.materials.has(original_key):
			var fallback:=StandardMaterial3D.new();fallback.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fallback.cull_mode=BaseMaterial3D.CULL_DISABLED
			fallback.albedo_texture=textures.get("_MainTex")
			var result: Material=renderer._source_material(renderer.materials[original_key],fallback)
			result.set_meta("source_key",key)
			return result
	var fallback:=StandardMaterial3D.new();fallback.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fallback.cull_mode=BaseMaterial3D.CULL_DISABLED
	fallback.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	fallback.albedo_texture=textures.get("_MainTex")
	fallback.albedo_color=colors.get("_Color",colors.get("_TintColor",Color.WHITE))
	fallback.set_meta("source_key",key);fallback.set_meta("compatibility","Untranslated source material; not a recovered shader")
	if not material_audit.has(key):material_audit.append(key)
	return fallback

func instantiate(prefab_key: String, parent: Node3D, allowed_renderers: Array = []) -> Dictionary:
	var state: Dictionary={"root":null,"nodes":{},"paths":{},"renderers":{},"materials":{},"particles":{},"source_key":prefab_key}
	_build_node(prefab_key,parent,"",state,allowed_renderers)
	return state

func _build_node(key: String,parent: Node3D,path: String,state: Dictionary,allowed: Array):
	var go: Dictionary=objects[key];var tr: Dictionary=component(key,"Transform")
	var node:=Node3D.new();node.name=str(go.name).replace("/","_");parent.add_child(node)
	if state.root==null:state.root=node
	state.nodes[key]=node;state.paths[path]=node
	node.set_meta("source_key",key);node.visible=bool(go.data.get("m_IsActive",true))
	var d: Dictionary=tr.get("data",{})
	node.position=Curves.vec(d.get("m_LocalPosition",{})) if path!="" else Vector3.ZERO
	node.quaternion=Quaternion(d.m_LocalRotation.x,d.m_LocalRotation.y,d.m_LocalRotation.z,d.m_LocalRotation.w)
	node.scale=Curves.vec(d.m_LocalScale)
	var filter: Dictionary=component(key,"MeshFilter");var render: Dictionary=component(key,"MeshRenderer")
	if not filter.is_empty() and not render.is_empty() and (allowed.is_empty() or key.get_slice(":",1) in allowed):
		var mesh_key: String=filter.refs.get(".m_Mesh","")
		var mesh:=geometry(mesh_key)
		if mesh!=null:
			var mi:=MeshInstance3D.new();mi.mesh=mesh;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mi.visible=bool(render.data.get("m_Enabled",true));node.add_child(mi)
			state.renderers[key]=mi;state.materials[key]=[]
			for surface in range(mesh.get_surface_count()):
				var mk: String=render.refs.get(".m_Materials[%d]"%surface,"")
				var mat:=material(mk)
				mi.set_surface_override_material(surface,mat);state.materials[key].append(mat)
	var ps: Dictionary=component(key,"ParticleSystem")
	if not ps.is_empty():state.particles[key]={"node":node,"system":ps,"renderer":component(key,"ParticleSystemRenderer")}
	for field in tr.get("refs",{}):
		if str(field).begins_with(".m_Children["):
			var child_transform: Dictionary=objects[tr.refs[field]]
			var child_key: String=child_transform.refs[".m_GameObject"]
			var child_path: String=str(objects[child_key].name) if path=="" else path+"/"+str(objects[child_key].name)
			_build_node(child_key,node,child_path,state,allowed)

func sample_clip(state: Dictionary, clip_name: String, time: float, target_path: String = "") -> void:
	if state.is_empty() or not clips.has(clip_name):return
	var root: Node3D=state.paths.get(target_path)
	if not is_instance_valid(root):return
	var d: Dictionary=clips[clip_name].data
	for kind in ["m_PositionCurves","m_RotationCurves","m_ScaleCurves","m_EulerCurves"]:
		for track in d.get(kind,[]):
			var path: String=target_path+("/" if target_path!="" and str(track.path)!="" else "")+str(track.path)
			var target: Node3D=state.paths.get(path)
			if not is_instance_valid(target):continue
			match kind:
				"m_PositionCurves":target.position=Curves.vector_curve(track.curve,time)
				"m_RotationCurves":target.quaternion=Curves.quaternion_curve(track.curve,time)
				"m_ScaleCurves":target.scale=Curves.vector_curve(track.curve,time,Vector3.ONE)
				"m_EulerCurves":target.rotation=Curves.vector_curve(track.curve,time)*PI/180.0
	for track in d.get("m_FloatCurves",[]):
		var path: String=target_path+("/" if target_path!="" and str(track.path)!="" else "")+str(track.path)
		var target: Node3D=state.paths.get(path)
		if not is_instance_valid(target):continue
		var key: String=target.get_meta("source_key","")
		var value: float=Curves.scalar_keys(track.curve.m_Curve,time)
		if track.attribute=="m_Enabled":
			if state.renderers.has(key):state.renderers[key].visible=value>=0.5
		elif int(track.classID)==21:
			for mat in state.materials.get(key,[]):set_material_float(mat,str(track.attribute),value)
		# m_LocalEulerAnglesHint is authoring metadata, never override quaternion.

func set_material_float(mat: Material,attribute: String,value: float) -> void:
	if not is_instance_valid(mat):return
	var bits:=attribute.split(".")
	if mat is ShaderMaterial:
		if bits.size()==2 and bits[1] in ["r","g","b","a"]:
			var colors: Dictionary=mat.get_meta("source_colors",{})
			var c: Color=colors.get(bits[0],Color.WHITE)
			c[["r","g","b","a"].find(bits[1])]=value
			colors[bits[0]]=c;mat.set_meta("source_colors",colors);mat.set_shader_parameter(bits[0],c)
		else:mat.set_shader_parameter(attribute,value)
	elif mat is StandardMaterial3D and bits.size()==2 and bits[1] in ["r","g","b","a"]:
		var c: Color=mat.albedo_color;c[["r","g","b","a"].find(bits[1])]=value;mat.albedo_color=c

func capture_float_pose(state: Dictionary,clip_name: String,target_path: String) -> Dictionary:
	var pose: Dictionary={}
	if not clips.has(clip_name):return pose
	for track in clips[clip_name].data.get("m_FloatCurves",[]):
		var path: String=target_path+("/" if target_path!="" and str(track.path)!="" else "")+str(track.path)
		var node=state.paths.get(path)
		if not is_instance_valid(node):continue
		var key: String=node.get_meta("source_key","")
		if track.attribute=="m_Enabled":
			if state.renderers.has(key):pose[str(track.path)+":"+track.attribute]=1.0 if state.renderers[key].visible else 0.0
		elif int(track.classID)==21 and not state.materials.get(key,[]).is_empty():
			var mat: Material=state.materials[key][0];var bits: PackedStringArray=str(track.attribute).split(".")
			if mat is ShaderMaterial:
				var value=mat.get_shader_parameter(bits[0])
				if bits.size()==2 and value is Color:pose[str(track.path)+":"+track.attribute]=value[["r","g","b","a"].find(bits[1])]
				elif value is float or value is int:pose[str(track.path)+":"+track.attribute]=float(value)
	return pose

func sample_float_crossfade(state: Dictionary,clip_name: String,time: float,target_path: String,previous: Dictionary,previous_time: float,weight: float,initial_pose: Dictionary):
	# Original Hidden clips animate only material floats and renderer visibility.
	# Source CrossFade duration is exact; linear property weights and unbound-pose
	# handling are an explicit compatibility model, not recovered Unity native code.
	var outgoing: Dictionary=initial_pose.duplicate()
	if previous.has("clip") and clips.has(previous.clip):
		for track in clips[previous.clip].data.get("m_FloatCurves",[]):outgoing[str(track.path)+":"+track.attribute]=Curves.scalar_keys(track.curve.m_Curve,previous_time)
	for track in clips[clip_name].data.get("m_FloatCurves",[]):
		var path: String=target_path+("/" if target_path!="" and str(track.path)!="" else "")+str(track.path)
		var node=state.paths.get(path)
		if not is_instance_valid(node):continue
		var key: String=node.get_meta("source_key","")
		var incoming: float=Curves.scalar_keys(track.curve.m_Curve,time)
		var value: float=lerpf(float(outgoing.get(str(track.path)+":"+track.attribute,incoming)),incoming,weight)
		if track.attribute=="m_Enabled":
			if state.renderers.has(key):state.renderers[key].visible=value>=0.5
		elif int(track.classID)==21:
			for mat in state.materials.get(key,[]):set_material_float(mat,str(track.attribute),value)
