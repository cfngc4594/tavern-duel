extends "res://scripts/native_combat_assets.gd"
## Bounded original phone mana resource set; same existing source material/mesh adapter.
const DIR="res://assets/native_phone_mana/"
var gem_material_factory:Callable
var strict_blockers:Array=[]
func setup(card_renderer:Node=null,source_base:String=DIR)->void:
	super.setup(card_renderer,source_base)
func material(key:String,texture_override:Texture2D=null)->Material:
	var record:Dictionary=objects.get(key,{})
	for field in record.get("refs",{}):
		if str(field).ends_with(".m_Texture") and load_texture(str(record.refs[field]))==null:
			var reason="Missing mana texture "+str(record.refs[field])
			if not strict_blockers.has(reason):strict_blockers.append(reason)
			return null
	if str(record.get("refs",{}).get(".m_Shader","")).ends_with(":9099378368919310605") and gem_material_factory.is_valid():return gem_material_factory.call(key)
	var shader_id=str(record.get("refs",{}).get(".m_Shader","")).get_slice(":",1)
	if shader_id in ["-870869104636564592","143677912420122213"]:
		var md={"key":key,"sourceShaderKey":record.refs[".m_Shader"],"floats":[],"colors":[],"textures":[]}
		var props:Dictionary=record.data.m_SavedProperties
		for f in props.m_Floats:md.floats.append({"name":f[0],"value":f[1]})
		for c in props.m_Colors:md.colors.append({"name":c[0],"value":c[1]})
		var tex:Texture2D
		for i in range(props.m_TexEnvs.size()):
			var entry=props.m_TexEnvs[i]
			md.textures.append({"name":entry[0],"scale":entry[1].m_Scale,"offset":entry[1].m_Offset})
			if entry[0]=="_MainTex":tex=load_texture(record.refs.get(".m_SavedProperties.m_TexEnvs[%d][1].m_Texture"%i,""))
		var special=preload("res://scripts/native_mana_source_material.gd").build(md,tex,renderer)
		if special!=null:
			var source_colors={}
			for c in props.m_Colors:source_colors[c[0]]=Curves.color(c[1])
			special.set_meta("source_colors",source_colors)
			_apply_source_samplers(special,record);_bind_render_order(special,record);return special
	var result=super.material(key,texture_override)
	if not result is ShaderMaterial:
		var reason="Unported mana source shader/material: "+key
		if not strict_blockers.has(reason):strict_blockers.append(reason)
		return null
	return result
func set_material_float(mat:Material,attribute:String,value:float)->void:
	var bits=attribute.split(".")
	if mat is ShaderMaterial and bits.size()==2 and bits[0] in ["_tint","_Fade"]:
		var parameter="scroll_tint" if bits[0]=="_tint" else "fade_rgb"
		var rgb=mat.get_shader_parameter(parameter)
		if rgb==null:rgb=Vector3.ONE
		var index=["r","g","b"].find(bits[1])
		if index>=0:rgb[index]=value;mat.set_shader_parameter(parameter,rgb)
		return
	super.set_material_float(mat,attribute,value)
func load_texture(key: String) -> Texture2D:
	if texture_cache.has(key): return texture_cache[key]
	if not objects.has(key) or not objects[key].files.has("png"): return null
	var path: String=DIR+str(objects[key].files.png)
	var texture: Texture2D=load(path) if ResourceLoader.exists(path) else packed_png(path)
	texture_cache[key]=texture
	return texture

func geometry(key: String) -> ArrayMesh:
	if mesh_cache.has(key):return mesh_cache[key]
	var record: Dictionary=objects.get(key,{})
	if not record.get("files",{}).has("mesh"):return null
	var d: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+record.files.mesh))
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
		for tri in surface:ix.append_array(PackedInt32Array([tri[0],tri[2],tri[1]]))
		var a: Array=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=ps;a[Mesh.ARRAY_INDEX]=ix
		if uv.size()==ps.size():a[Mesh.ARRAY_TEX_UV]=uv
		if uv2.size()==ps.size():a[Mesh.ARRAY_TEX_UV2]=uv2
		if normals.size()==ps.size():a[Mesh.ARRAY_NORMAL]=normals
		a[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	mesh_cache[key]=mesh
	return mesh


static func packed_png(path:String)->Texture2D:
	var image=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
	return ImageTexture.create_from_image(image)
