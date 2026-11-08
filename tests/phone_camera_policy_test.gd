extends SceneTree
const Policy=preload("res://scripts/source_board_camera_policy.gd")
const Probe=preload("res://original_board/scripts/board_probe.gd")
const Coin=preload("res://scripts/native_coin_presentation.gd")
func _initialize():call_deferred("run")
func run():
 # Candidate project may enable phone mode; desktop stays gated by platform.
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
  Policy.apply(ca,a,config,canvas,true);Policy.apply(cb,b,config,canvas,true)
  await process_frame
  assert(ca.get_meta("native_phone_registered",false))
  assert(absf(ca.position.y-ys[i])<0.00001)
  assert(ca.global_transform.is_equal_approx(cb.global_transform))
  assert(is_equal_approx(ca.fov,34.870445251464844))
  for uv in [Vector2.ZERO,Vector2(.5,.5),Vector2.ONE]:
   assert(ca.project_ray_normal(uv*canvas).is_equal_approx(cb.project_ray_normal(uv*canvas)))
  assert(ca.basis.is_equal_approx(Policy.raw_transform(Policy.phone_data().camera_transform).basis))
 assert(absf(Policy.phone_position((anchors[0]+anchors[1])*.5).y-(17.649999618530273+15.0)*.5)<.00001)
 assert(absf(Policy.phone_position((anchors[1]+anchors[2])*.5).y-(15.0+16.100000381469727)*.5)<.00001)
 Policy.apply(ca,a,config,Vector2(1600,900),false)
 assert(not ca.get_meta("native_phone_registered",true))
 assert(ca.transform.is_equal_approx(Probe.raw_transform(config.unity_camera.transform)))
 # Both integration points must route layout changes through the shared policy.
 assert(FileAccess.get_file_as_string("res://scripts/native_coin_presentation.gd").contains("CameraPolicy.apply(camera,camera_root,camera_config,game.presentation_size"))
 assert(FileAccess.get_file_as_string("res://scripts/original_board_bridge.gd").contains("probe.refresh_source_camera(game.presentation_size)"))
 print("PHONE_CAMERA_POLICY_PASS: anchors, clamping, interpolation, resize, common board/coin rays, desktop preservation")
 view.queue_free();quit(0)
