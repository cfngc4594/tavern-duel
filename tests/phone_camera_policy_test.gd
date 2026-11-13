extends SceneTree
const Policy=preload("res://scripts/source_board_camera_policy.gd")
const Probe=preload("res://original_board/scripts/board_probe.gd")
const Coin=preload("res://scripts/native_coin_presentation.gd")
func _initialize():call_deferred("run")
func run():
 # Source UI is shared, but cannot activate before layout registration succeeds.
 assert(not Policy.is_phone())
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var view=SubViewport.new();view.own_world_3d=true;root.add_child(view)
 var a=Node3D.new();var b=Node3D.new();view.add_child(a);view.add_child(b)
 var ca=Camera3D.new();var cb=Camera3D.new();a.add_child(ca);b.add_child(cb)
 var anchors=Policy.phone_data().aspect_anchors
 var cases=[Vector2(1500,1000),Vector2(1600,900),Vector2(2040,1000),Vector2(2100,900),Vector2(1200,900),Vector2(1600,900)]
 var ys=[17.649999618530273,15.0,16.100000381469727,16.100000381469727,17.649999618530273,15.0]
 for i in range(cases.size()):
  var canvas=cases[i];view.size=Vector2i(canvas)
  Policy.apply(ca,a,canvas);Policy.apply(cb,b,canvas)
  await process_frame
  assert(ca.get_meta("native_phone_registered",false))
  assert(absf(ca.position.y-ys[i])<0.00001)
  assert(ca.global_transform.is_equal_approx(cb.global_transform))
  assert(is_equal_approx(ca.fov,Policy.source_fov(canvas.x/canvas.y)))
  if canvas.x/canvas.y>=1.5:assert(is_equal_approx(ca.fov,34.870445251464844))
  else:assert(ca.fov>34.870445251464844)
  for uv in [Vector2.ZERO,Vector2(.5,.5),Vector2.ONE]:
   assert(ca.project_ray_normal(uv*canvas).is_equal_approx(cb.project_ray_normal(uv*canvas)))
  assert(ca.basis.is_equal_approx(Policy.raw_transform(Policy.phone_data().camera_transform).basis))
 assert(absf(Policy.phone_position((anchors[0]+anchors[1])*.5).y-(17.649999618530273+15.0)*.5)<.00001)
 assert(absf(Policy.phone_position((anchors[1]+anchors[2])*.5).y-(15.0+16.100000381469727)*.5)<.00001)
 _check_cached_recipe(ca,a,cb,b,view,cases)
 # Both integration points must route layout changes through the shared policy.
 assert(FileAccess.get_file_as_string("res://scripts/native_coin_presentation.gd").contains("CameraPolicy.apply(camera,camera_root,game.presentation_size"))
 assert(FileAccess.get_file_as_string("res://scripts/original_board_bridge.gd").contains("probe.refresh_source_camera(game.presentation_size)"))
 print("PHONE_CAMERA_POLICY_PASS: anchors, clamping, interpolation, resize, common board/coin rays, phone-only camera")
 view.queue_free();quit(0)

func _check_cached_recipe(ca:Camera3D,a:Node3D,cb:Camera3D,b:Node3D,view:SubViewport,cases:Array):
 var original_flag:bool=Policy.camera_recipe_cache_enabled
 var same_canvas:Vector2=cases.back()
 var returned:=Policy.phone_data()
 returned.camera['field of view']=1.0
 assert(Policy.phone_data().camera['field of view']!=1.0,"The source data remains caller-owned")
 for canvas:Vector2 in cases+[same_canvas,same_canvas]:
  view.size=Vector2i(canvas)
  # Each application must still restore the camera, including on a cache hit.
  a.position=Vector3(2,3,4);b.position=a.position
  ca.position=Vector3(5,6,7);cb.position=ca.position
  ca.fov=20.0;cb.fov=ca.fov
  ca.h_offset=0.25;cb.h_offset=ca.h_offset
  ca.set_meta("source_camera_shake_offset",Vector3.ONE)
  cb.set_meta("source_camera_shake_offset",Vector3.ONE)
  Policy.camera_recipe_cache_enabled=false
  Policy.apply(ca,a,canvas)
  Policy.camera_recipe_cache_enabled=true
  Policy.apply(cb,b,canvas)
  assert(a.transform==b.transform and ca.transform==cb.transform)
  assert(ca.global_transform==cb.global_transform and ca.get_camera_projection()==cb.get_camera_projection())
  assert(ca.projection==cb.projection and ca.keep_aspect==cb.keep_aspect)
  assert(ca.fov==cb.fov and ca.near==cb.near and ca.far==cb.far and cb.h_offset==0.25)
  for key in ["source_camera_platform","native_phone_registered","source_unshaken_global_transform","source_camera_shake_offset"]:
   assert(ca.get_meta(key)==cb.get_meta(key))
  assert(cb.get_meta("source_camera_shake_offset")==Vector3.ZERO)
  for uv in [Vector2.ZERO,Vector2(.5,.5),Vector2.ONE]:
   assert(ca.project_ray_normal(uv*canvas)==cb.project_ray_normal(uv*canvas))
  # The same cached recipe may be applied to another camera rig.
  Policy.apply(ca,a,canvas)
  assert(ca.global_transform==cb.global_transform)
 Policy.reset_phone_data_cache()
 Policy.apply(cb,b,same_canvas)
 assert(ca.global_transform==cb.global_transform and ca.fov==cb.fov)
 Policy.camera_recipe_cache_enabled=original_flag
 print("PHONE_CAMERA_RECIPE_CACHE_PASS: exact camera state, rays, shake reset, resize and public source data copies")
