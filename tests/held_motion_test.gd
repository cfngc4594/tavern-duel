extends SceneTree
class Probe extends Node3D:
 var source_nodes={}
 var camera:Camera3D
class Bridge extends Node:
 var probe
 var viewport:SubViewport
class Host extends Node:
 var original_board_bridge
 var presentation_offset=Vector2.ZERO
 var presentation_size=Vector2(1600,900)
 var definitions={"YETI":{"kind":"minion"}}
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var bridge=Bridge.new();host.add_child(bridge);host.original_board_bridge=bridge
 bridge.viewport=SubViewport.new();bridge.viewport.size=Vector2i(1600,900);bridge.add_child(bridge.viewport)
 var probe=Probe.new();bridge.viewport.add_child(probe);bridge.probe=probe
 var source=load("res://original_board/scripts/board_probe.gd")
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/assets/scene.json"))
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var transforms={}
 for n in data.nodes:
  transforms[n.id]=(Transform3D.IDENTITY if n.parent=="" else transforms[n.parent])*source.source_transform(n.position,n.rotation,n.scale)
 var motion=load("res://scripts/native_held_motion.gd").new();motion.setup(host)
 var plane=Node3D.new();probe.add_child(plane);plane.transform=transforms[motion.PLANE];probe.source_nodes[motion.PLANE]=plane
 var camera_root=Node3D.new();probe.add_child(camera_root);camera_root.transform=source.raw_transform(config.unity_camera_root.data)
 probe.camera=Camera3D.new();camera_root.add_child(probe.camera);probe.camera.transform=source.raw_transform(config.unity_camera.transform)
 probe.camera.keep_aspect=Camera3D.KEEP_HEIGHT;probe.camera.fov=config.unity_camera.data["field of view"];probe.camera.current=true
 await process_frame
 for point in [Vector2(800,450),Vector2(650,650),Vector2(1000,500)]:
  var sampled=motion.hit(point);assert(not sampled.is_empty(),str(point))
  var screen=motion.board_projection(probe.camera,sampled.world,Vector2(1600,900))
  assert(screen.distance_to(point)<0.01)
  var card={"key":"YETI","pos":Vector2.ZERO,"scale":1.0,"angle":0.0,"spring":Vector2(99,99)}
  assert(motion.apply(card,point,0.2))
  assert(card.pos.distance_to(point)<0.01 and card.spring==Vector2.ZERO)
  assert(is_equal_approx(motion.source_scale_at(1.55,motion.SCALE_SECONDS),0.7))
  print("SOURCE_HELD_HIT ",point," world=",sampled.source_world," scale=",card.source_held_face_pose.scale)
 assert(is_equal_approx(motion.source_scale_at(1.55,0),1.55))
 assert(is_equal_approx(motion.source_scale_at(1.55,0.1),0.7265625))
 print("HELD_MOTION_PASS: source DragPlane triangles/transforms/camera ray, exact screen roundtrip, no spring/offset, original .7/.2 easeOutExpo")
 host.queue_free();quit()
