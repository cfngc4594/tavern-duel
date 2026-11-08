extends SceneTree
func _initialize():call_deferred("run")
func run():
	var renderer=load("res://scripts/native_card_renderer.gd").new()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/OriginalCards/card_assets.json"))
	for p in data.profiles:renderer.profiles[p.name]=p
	for m in data.meshes:
		if str(m.key).ends_with(":-7756402925575413283"):renderer.meshes[m.key]=m
	var helper=load("res://scripts/native_opening_highlight.gd").new()
	var failed=0
	for kind in ["minion_in_hand","spell_in_hand"]:
		var viewport=SubViewport.new();viewport.size=Vector2i(328,484);viewport.own_world_3d=true;root.add_child(viewport)
		var flip=Node3D.new();flip.scale.z=-1;viewport.add_child(flip)
		var prof=renderer.profiles[kind];var nodes={}
		for n in prof.nodes:
			var node=Node3D.new();nodes[n.id]=node
		for n in prof.nodes:
			var node=nodes[n.id]
			if n.parentId=="":flip.add_child(node)
			else:nodes[n.parentId].add_child(node)
			node.position=Vector3.ZERO if n.parentId=="" else renderer.vec(n.position);node.quaternion=Quaternion(n.rotation.x,n.rotation.y,n.rotation.z,n.rotation.w);node.scale=renderer.vec(n.scale)
		var minion=kind=="minion_in_hand";var cam=Camera3D.new();viewport.add_child(cam);cam.position=Vector3(-0.0553,7,-0.0408) if minion else Vector3(-0.05385,7,-0.04296);cam.rotation_degrees=Vector3(-90,0,0);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3.35 if minion else 3.23;cam.current=true
		await process_frame
		var actual=helper.card_geometry(renderer,kind);var projected=actual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var mesh=renderer._geometry(renderer.meshes[actual.source_mesh]);var vertices=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var max_error=0.0
		for i in vertices.size():
			var expected=cam.unproject_position(nodes[actual.source_plane].global_transform*vertices[i])*0.5-Vector2(82,121)
			max_error=maxf(max_error,expected.distance_to(projected[i]))
		if max_error>0.001:failed+=1
		print("ORIGINAL_PLANE_SAME_CAMERA ",kind," vertices=",vertices.size()," max_error=",max_error)
		viewport.queue_free()
	print("OPENING_PROJECTION_FAILURES=",failed);renderer.free();helper.free();quit(failed)
