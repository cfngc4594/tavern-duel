extends RefCounted
## Compatibility sampling only for the recovered frozen hero FX_Shatter.
## Same-build managed enum is Vertex=0, Edge=1, Triangle=2. Unity's native
## serialized placement mapping, edge weighting/dedup and RNG are unavailable.
## Our explicit adapter uses unique indexed edges per surface, length weighting,
## linear endpoint interpolation and the existing visual-only instance RNG.
const SYSTEM_KEY := "cab-69c88b234dfa427e02d1fcee9337ae34:6318409310918042771"
const MESH_KEY := "cab-66e7137de3b79380e05eb711ae004556:4021318450489716359"
const EPSILON := 0.00000001
var edges: Array = []
var total_length := 0.0
var skipped_zero_length := 0

func add_surface(points: PackedVector3Array, normals, colors, indices: PackedInt32Array) -> void:
	var seen: Dictionary = {}
	for i in range(0, indices.size() - 2, 3):
		for pair in [Vector2i(indices[i], indices[i+1]), Vector2i(indices[i+1], indices[i+2]), Vector2i(indices[i+2], indices[i])]:
			var a: int=mini(pair.x,pair.y);var b: int=maxi(pair.x,pair.y)
			var key:=Vector2i(a,b)
			if seen.has(key):continue
			seen[key]=true
			if a<0 or b>=points.size():continue
			var length: float=points[a].distance_to(points[b])
			if length<=EPSILON:skipped_zero_length+=1;continue
			total_length+=length
			edges.append({"indices":key,"points":[points[a],points[b]],"normals":[normals[a],normals[b]] if normals!=null and normals.size()==points.size() else [Vector3.BACK,Vector3.BACK],"colors":[colors[a],colors[b]] if colors!=null and colors.size()==points.size() else [Color.WHITE,Color.WHITE],"length_end":total_length})

func build(source_mesh: ArrayMesh, shape: Dictionary) -> void:
	edges.clear();total_length=0.0;skipped_zero_length=0
	for surface in range(source_mesh.get_surface_count()):
		if bool(shape.get("m_UseMeshMaterialIndex",false)) and surface!=int(shape.get("m_MeshMaterialIndex",0)):continue
		var arrays: Array=source_mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices=arrays[Mesh.ARRAY_INDEX]
		if indices==null or indices.is_empty():
			indices=PackedInt32Array()
			for i in range(points.size()):indices.append(i)
		add_surface(points,arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_COLOR],indices)

func sample_at(edge_fraction: float, position_fraction: float) -> Dictionary:
	if edges.is_empty() or total_length<=EPSILON:return {}
	var choice: float=clampf(edge_fraction,0.0,1.0)*total_length
	var edge: Dictionary=edges[-1]
	for candidate in edges:
		if choice<=float(candidate.length_end):edge=candidate;break
	var t: float=clampf(position_fraction,0.0,1.0)
	return {"point":edge.points[0].lerp(edge.points[1],t),"direction":edge.normals[0].lerp(edge.normals[1],t).normalized(),"color":edge.colors[0].lerp(edge.colors[1],t)}

func sample(rng: RandomNumberGenerator) -> Dictionary:
	return sample_at(rng.randf(),rng.randf())
