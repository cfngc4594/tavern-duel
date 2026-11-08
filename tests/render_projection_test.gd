extends SceneTree
const Policy=preload("res://scripts/render_resolution_policy.gd")
func _initialize():call_deferred("run")
func run():
	var view:=SubViewport.new();view.size=Vector2i(1600,900);view.own_world_3d=true;root.add_child(view)
	var camera:=Camera3D.new();view.add_child(camera);camera.current=true;camera.fov=45.0
	await process_frame
	var points=[Vector2.ZERO,Vector2(800,450),Vector2(1600,900),Vector2(352,171),Vector2(1225,174)]
	var rays=[]
	for point in points:rays.append(camera.project_ray_normal(point))
	var failed:=0
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1350)]:
		view.size=size
		await process_frame
		for i in range(points.size()):
			var ray=camera.project_ray_normal(Policy.logical_to_target(points[i],size))
			if not ray.is_equal_approx(rays[i]):failed+=1
		print("CAMERA_RAY_REGISTRATION ",size," errors=",failed)
	view.queue_free()
	print("PROJECTION_TEST_FAILURES=",failed);quit(failed)
