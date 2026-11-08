extends SceneTree
class Host extends Node:
 var board_render_target_size=Vector2i(2400,1080)
 var presentation_size=Vector2(2000,900)
 var presentation_offset=Vector2(200,0)
 var world_canvas=Node2D.new()
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host);host.add_child(host.world_canvas)
 var p=load("res://scripts/native_coin_presentation.gd").new();host.add_child(p);p.setup(host)
 var actor=Node3D.new();p.player.add_child(actor);p.card_actor={"root":actor}
 var max_error=0.0
 assert(p.source_hand_center_for_platform(true).is_equal_approx(Vector3(-2.800000190735,0.852410078049,-8.599999904633)))
 assert(p.source_hand_center_for_platform(false).is_equal_approx(Vector3(-8.149087906,2.871613026,-9.713716984)))
 var phone_depth=-(p.camera.global_transform.affine_inverse()*(p.player.global_transform*p.source_hand_center_for_platform(true))).z
 assert(phone_depth>p.camera.near and phone_depth<p.camera.far)
 for row in [[-1.0,0.0],[0.0,0.0],[0.25,0.0625],[0.5,0.5],[0.75,0.9375],[1.0,1.0],[2.0,1.0]]:
  assert(is_equal_approx(p.source_very_slow_ease(row[0]),row[1]))
 for canvas in [Vector2(1600,900),Vector2(2000,900),Vector2(1600,1200)]:
  host.presentation_size=canvas;host.presentation_offset=(canvas-Vector2(1600,900))*0.5;host.board_render_target_size=Vector2i(canvas*1.2);p.refresh_layout()
  for pose in [{"pos":Vector2(800,820),"scale":0.72,"angle":-0.2},{"pos":Vector2(1100,830),"scale":1.0,"angle":0.35},{"pos":Vector2(260,785),"scale":0.45,"angle":-0.4}]:
   actor.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.1),Vector3(-5.152,7.417,-6.067))
   p.begin_hand_transition(pose)
   p.sample_hand_transition(0.0);assert(actor.transform.is_equal_approx(p.gather_from))
   p.sample_hand_transition(0.5);assert(actor.position.is_equal_approx(p.gather_from.origin.lerp(p.gather_to.origin,0.5)))
   p.sample_hand_transition(1.0);assert(actor.transform.is_equal_approx(p.gather_to))
   await process_frame
   for point in [Vector2.ZERO,Vector2(-82,-121),Vector2(82,-121),Vector2(82,121),Vector2(-82,121)]:
    var source_point:Vector3=Vector3(-0.05385,0,0.04296)+Vector3(point.x,0,-point.y)*(3.23/242.0)
    var projected:Vector2=p.camera.unproject_position(actor.global_transform*source_point)*canvas/Vector2(p.viewport.size)-host.presentation_offset
    var expected:Vector2=pose.pos+point.rotated(pose.angle)*pose.scale
    max_error=maxf(max_error,projected.distance_to(expected))
   print("GATHER ",canvas," ",pose," max_error=",max_error," scale=",p.gather_to.basis.get_scale())
 print("GATHER_PROJECTION_MAX_ERROR=",max_error," PHONE_DEPTH=",phone_depth," EASING_BOUNDARIES_PASS")
 host.queue_free();await process_frame;quit(0 if max_error<0.02 else 1)
