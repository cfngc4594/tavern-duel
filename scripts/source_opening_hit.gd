extends RefCounted
## Original ordinary hand-actor BoxColliders, build37.0.0.255130.254477.
## SetupCardCollider0x06005bfa only calls TurnOnCollider. Actor.ToggleCollider
## 0x0601281b toggles collider on GetMeshRenderer(0), i.e. m_cardMesh.
## Evidence motion_contract/hand_colliders.json; card_assets.json mesh ancestors.
const Rotation=preload("res://scripts/source_itween_rotation.gd")

static func local_box(is_spell:bool)->AABB:
	var center:=Vector3(0.029999971389770508,0.09999999403953552,-0.024262428283691406) if is_spell else Vector3(0.02392953634262085,0.060690730810165405,-0.07000000029802322)
	var size:=Vector3(2.0399999618530273,0.1854100227355957,2.841475248336792) if is_spell else Vector3(2.1600000858306885,0.2229873538017273,3.0899999141693115)
	return AABB(center-size*0.5,size)

static func mesh_local(is_spell:bool)->Transform3D:
	# RootObject and spell NonQuestObjects are identity. Both mesh rotations
	# serialize Quaternion(0,1,0,-4.371138828673793e-08), not a face-plane guess.
	var offset:=Vector3(0,0,-0.035999998450279236) if is_spell else Vector3(0,-0.03158736228942871,-0.01141214370727539)
	return Transform3D(Basis(Quaternion(0,1,0,-4.371138828673793e-08)),offset)

static func collider_transform(pose:Dictionary,is_spell:bool)->Transform3D:
	# Source Unity coordinates; caller must reflect source/world exactly once.
	var rotation:Basis=Rotation.source_basis(pose.rotation)
	var size:Vector3=pose.scale
	var actor:=Transform3D(Basis(rotation.x*size.x,rotation.y*size.y,rotation.z*size.z),pose.position)
	return actor*mesh_local(is_spell)

static func source_corners(pose:Dictionary,is_spell:bool)->PackedVector3Array:
	var box:=local_box(is_spell)
	var transform:=collider_transform(pose,is_spell)
	var result:=PackedVector3Array()
	for i in range(8):result.append(transform*box.get_endpoint(i))
	return result

static func projected_polygon(pose:Dictionary,is_spell:bool,project_source:Callable)->PackedVector2Array:
	# For UI hit regions, project ALL8 corners and convex-hull them. A4-corner
	# baked artwork rectangle ignores collider thickness and authored offsets.
	var points:=PackedVector2Array()
	for point in source_corners(pose,is_spell):points.append(project_source.call(point))
	return Geometry2D.convex_hull(points)

static func ray_distance(source_origin:Vector3,source_direction:Vector3,pose:Dictionary,is_spell:bool)->float:
	# Exact ray/OBB slab intersection. Input direction should be normalized for
	# returned distance to be Unity-world distance. Return-1 if no forward hit.
	var inverse:=collider_transform(pose,is_spell).affine_inverse()
	var origin:Vector3=inverse*source_origin
	var direction:Vector3=inverse.basis*source_direction
	var box:=local_box(is_spell)
	var near:float=0.0
	var far:float=INF
	for axis in range(3):
		if absf(direction[axis])<1.0e-12:
			if origin[axis]<box.position[axis] or origin[axis]>box.end[axis]:return -1.0
			continue
		var first:float=(box.position[axis]-origin[axis])/direction[axis]
		var second:float=(box.end[axis]-origin[axis])/direction[axis]
		near=maxf(near,minf(first,second))
		far=minf(far,maxf(first,second))
		if far<near:return -1.0
	return near
