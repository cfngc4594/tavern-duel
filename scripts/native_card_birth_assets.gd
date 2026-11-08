extends "res://scripts/native_summon_assets.gd"
## Bounded original ActorSpell2 resource set; same existing source material/mesh adapter.
const DIR="res://assets/native_card_birth/"
func setup(card_renderer:Node=null)->void:
	renderer=card_renderer
	manifest=JSON.parse_string(FileAccess.get_file_as_string(DIR+"manifest.json"))
	objects=manifest.objects
	for key in objects:
		if objects[key].type=="AnimationClip":clips[objects[key].name]=objects[key]
func load_texture(key: String) -> Texture2D:
	if texture_cache.has(key): return texture_cache[key]
	if not objects.has(key) or not objects[key].files.has("png"): return null
	var path: String=DIR+str(objects[key].files.png)
	var texture: Texture2D=load(path) if ResourceLoader.exists(path) else ImageTexture.create_from_image(preload("res://scripts/packed_png.gd").load_png(path))
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
		for tri in surface:ix.append_array(PackedInt32Array([tri[0],tri[1],tri[2]]))
		var a: Array=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=ps;a[Mesh.ARRAY_INDEX]=ix
		if uv.size()==ps.size():a[Mesh.ARRAY_TEX_UV]=uv
		if uv2.size()==ps.size():a[Mesh.ARRAY_TEX_UV2]=uv2
		if normals.size()==ps.size():a[Mesh.ARRAY_NORMAL]=normals
		a[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	mesh_cache[key]=mesh
	return mesh

