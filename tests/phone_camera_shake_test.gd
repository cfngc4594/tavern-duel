extends SceneTree
const Policy=preload("res://scripts/source_board_camera_policy.gd")
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Shake=preload("res://scripts/native_camera_shake.gd")
func _initialize():call_deferred("run")
func run():
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var view=SubViewport.new();view.size=Vector2i(2400,1080);root.add_child(view)
 var cr=Node3D.new();view.add_child(cr);var camera=Camera3D.new();cr.add_child(camera)
 var follower=Camera3D.new();view.add_child(follower)
 var canvas=Vector2(2000,900);Policy.apply(camera,cr,canvas)
 var context=SourceProjection.new();context.configure(camera,Vector2(view.size),canvas,Vector2(200,0),{})
 var base=camera.global_transform
 var shake=Shake.new();shake.request(Vector3(.1,.2,.3),1.0);shake.advance(.016)
 var offset=shake.world_offset
 assert(shake.present_source_camera(context))
 assert(shake.screen_offset==Vector2.ZERO)
 assert(camera.global_position.is_equal_approx(base.origin+Vector3(offset.x,offset.y,-offset.z)))
 var first=camera.global_transform
 assert(shake.present_source_camera(context));assert(camera.global_transform.is_equal_approx(first))
 context.sync_camera_followers([follower]);assert(follower.global_transform.is_equal_approx(camera.global_transform))
 assert(follower.get_meta("source_unshaken_global_transform").is_equal_approx(base))
 # Perspective camera motion produces depth-dependent displacement, not a UI warp.
 context.restore_camera_base()
 var a=Vector3(-7,0,-4);var b=Vector3(-7,5,-4)
 var before_a=context.source_to_screen(a);var before_b=context.source_to_screen(b)
 context.apply_camera_source_offset(Vector3(.1,0,0))
 var da=context.source_to_screen(a)-before_a;var db=context.source_to_screen(b)-before_b
 assert(not da.is_equal_approx(db))
 # Resize re-registers an unshaken base, then reapplies the same sample once.
 Policy.apply(camera,cr,Vector2(1600,900))
 var resized=camera.global_transform;shake.present_source_camera(context)
 assert(camera.global_position.is_equal_approx(resized.origin+Vector3(offset.x,offset.y,-offset.z)))
 shake.stop();assert(shake.present_source_camera(context));assert(camera.global_transform.is_equal_approx(resized))
 # A detached or unregistered camera must not be mutated.
 camera.set_meta("native_phone_registered",false);var detached=camera.global_transform
 shake.request(Vector3(.1,.2,.3),1.0);shake.advance(.016);var screen=shake.screen_offset
 assert(not shake.present_source_camera(context));assert(shake.screen_offset==screen)
 assert(camera.global_transform.is_equal_approx(detached))
 view.queue_free();print("PHONE_CAMERA_SHAKE_PASS: source WORLD xyz, once-only, follower copy, depth parallax, resize/recovery, unregistered camera rejected");quit()
