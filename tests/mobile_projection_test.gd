extends SceneTree
const Policy=preload("res://scripts/render_resolution_policy.gd")
func _initialize():call_deferred("run")
func run():
 var view:=SubViewport.new();view.size=Vector2i(1600,900);view.own_world_3d=true;root.add_child(view)
 var camera:=Camera3D.new();view.add_child(camera);camera.current=true;camera.fov=45.0;camera.keep_aspect=Camera3D.KEEP_HEIGHT
 await process_frame
 var points=[Vector2.ZERO,Vector2(800,450),Vector2(1600,900),Vector2(352,171),Vector2(1225,174)]
 var rays=[]
 for point in points:rays.append(camera.project_ray_normal(point))
 var failed:=0
 for output in [Vector2i(2400,1080),Vector2i(3120,1440),Vector2i(2048,1536),Vector2i(1600,900)]:
  var canvas:=Policy.canvas_size(output)
  var target:=Policy.scenery_size(canvas,Policy.target_size(output))
  var offset:=(canvas-Vector2(1600,900))*0.5
  view.size=target
  camera.fov=rad_to_deg(2.0*atan(tan(deg_to_rad(45.0)*0.5)*canvas.y/900.0))
  await process_frame
  for i in range(points.size()):
   var ray:=camera.project_ray_normal((points[i]+offset)*Vector2(target)/canvas)
   if not ray.is_equal_approx(rays[i]):failed+=1
  print("EXPANDED_RAYS ",output," errors=",failed)
  root.size=output;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  await process_frame
  print("ROOT_LAYOUT ",output," visible=",root.get_visible_rect().size," expected=",canvas)
  if not root.get_visible_rect().size.is_equal_approx(canvas):failed+=1
 view.queue_free()
 print("MOBILE_PROJECTION_FAILURES=",failed);quit(failed)
