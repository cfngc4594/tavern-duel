extends Node2D
## Original hand plane/silhouette/material projected with SAME card bake camera.
## No guessed contour. Dynamic time phase is a local compatibility clock.
var game
var rows:Dictionary={}
var geometry:Dictionary={}
var evidence:Dictionary={}
var source_materials:Dictionary={}
var audit:Dictionary={}
var seed_rng=RandomNumberGenerator.new()
const SHADER=preload("res://shaders/native_opening_highlight.gdshader")

func setup(host):
	game=host
	seed_rng.randomize()
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/OriginalCards/highlight_selection_evidence.json"))
	for profile in source.profiles:
		var refs={}
		for ref in profile.highlight_state_component.references:refs[ref.field]=ref.get("key","")
		profile.highlight_state_component["refs"]=refs
		evidence[profile.label]=profile
	source_materials=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/opening_highlight_materials.json"))

func clear_rows():
	for row in rows.values():
		row.root.visible=false;row.face.texture=null;row.root.queue_free()
	rows.clear()

func begin_frame():
	for row in rows.values():row.root.visible=false

func card_geometry(renderer,kind:String)->Dictionary:
	if geometry.has(kind):return geometry[kind]
	var prof=renderer.profiles[kind]
	var transforms:Dictionary={}
	var pending=prof.nodes.duplicate()
	while not pending.is_empty():
		var progress=false
		for n in pending.duplicate():
			if n.parentId!="" and not transforms.has(n.parentId):continue
			var local=Transform3D(Basis(Quaternion(n.rotation.x,n.rotation.y,n.rotation.z,n.rotation.w)).scaled(renderer.vec(n.scale)),Vector3.ZERO if n.parentId=="" else renderer.vec(n.position))
			transforms[n.id]=(Transform3D(Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK),Vector3.ZERO) if n.parentId=="" else transforms[n.parentId])*local
			pending.erase(n);progress=true
		if not progress:return {}
	var minion=kind=="minion_in_hand"
	var cam=Transform3D(Basis.from_euler(Vector3(-PI/2,0,0)),Vector3(-0.0553,7,-0.0408) if minion else Vector3(-0.05385,7,-0.04296))
	var height=3.35 if minion else 3.23
	var scale=242.0/height
	for r in prof.renderers:
		if not r.get("readyHighlight",false):continue
		var mesh=renderer._geometry(renderer.meshes[r.meshKey])
		var source=mesh.surface_get_arrays(0)
		var verts=PackedVector2Array();var colors=PackedColorArray()
		for i in source[Mesh.ARRAY_VERTEX].size():
			var point=cam.affine_inverse()*transforms[r.nodeId]*source[Mesh.ARRAY_VERTEX][i]
			verts.append(Vector2(point.x*scale,-point.y*scale))
			var red=source[Mesh.ARRAY_COLOR][i].r if source[Mesh.ARRAY_COLOR]!=null else 1.0
			var ux=source[Mesh.ARRAY_TEX_UV2][i].x if source[Mesh.ARRAY_TEX_UV2]!=null else source[Mesh.ARRAY_TEX_UV][i].x
			colors.append(Color(red,ux,0,1))
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_TEX_UV]=source[Mesh.ARRAY_TEX_UV];arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=source[Mesh.ARRAY_INDEX]
		var output=ArrayMesh.new();output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		geometry[kind]={"mesh":output,"source_plane":r.nodeId,"source_mesh":r.meshKey,"camera_height":height};return geometry[kind]
	return {}

func show_card(pose:Dictionary,hovered:bool)->bool:
	if not game.card_face_textures.has(pose.key) or not is_instance_valid(game.card_face_textures[pose.key]):return false
	var renderer=game.native_card_renderer
	var kind="minion_in_hand" if game.definitions[pose.key].kind=="minion" else "spell_in_hand"
	var shape=card_geometry(renderer,kind)
	if shape.is_empty():return false
	var state=7 if hovered else 5
	var record=evidence[kind].highlight_state_component
	var material_key=""
	for i in record.data.m_HighlightStates.size():
		if int(record.data.m_HighlightStates[i].m_StateType)==state:material_key=record.refs.get("/m_HighlightStates/%d/m_Material"%i,"");break
	if not source_materials.has(material_key):return false
	var mask_key=record.refs.get("/m_StaticSilouetteTexture","")
	if not renderer.textures.has(mask_key):return false
	var id=str(pose.key)+":"+str(pose.pos)
	if not rows.has(id):
		var holder=Node2D.new();add_child(holder)
		var glow=MeshInstance2D.new();glow.mesh=shape.mesh;holder.add_child(glow)
		var mat=ShaderMaterial.new();mat.shader=SHADER;glow.material=mat
		var face=Sprite2D.new();holder.add_child(face)
		rows[id]={"root":holder,"glow":glow,"face":face,"material":mat,"seed":seed_rng.randf()}
	var row=rows[id];row.root.visible=true;row.root.position=pose.pos;row.root.rotation=pose.angle;row.root.scale=Vector2(pose.scale*pose.get("flip",1.0),pose.scale)
	row.face.texture=game.card_face_textures[pose.key];row.face.scale=Vector2(164,242)/Vector2(row.face.texture.get_size())
	var md=source_materials[material_key];var uniforms={}
	for u in SHADER.get_shader_uniform_list():uniforms[u.name]=true
	for f in md.floats:
		if uniforms.has(f.name):row.material.set_shader_parameter(f.name,float(f.value))
	for c in md.colors:
		if uniforms.has(c.name):row.material.set_shader_parameter(c.name,renderer.col(c.value))
	for t in md.textures:
		if uniforms.has(t.name) and renderer.textures.has(t.key):row.material.set_shader_parameter(t.name,renderer.textures[t.key])
	row.material.set_shader_parameter("_Seed",row.seed)
	row.material.set_shader_parameter("_MainTex",renderer.textures[mask_key]);row.material.set_shader_parameter("_ShaderTime",fmod(float(game.elapsed)/20.0,65535.0))
	audit[kind]={"state":state,"material":material_key,"silhouette":mask_key,"plane":shape.source_plane,"source_camera_height":shape.camera_height,"backend":"Projected original mesh + canvas shader translation; not pixel-equivalence claim"}
	return true
