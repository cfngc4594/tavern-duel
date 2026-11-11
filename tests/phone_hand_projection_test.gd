extends SceneTree
class Probe extends Node3D:
 var camera:Camera3D
class Bridge extends Node:
 var probe
 var viewport:SubViewport
class Spatial:
 func screen_to_world(p:Vector2,_lift:float):return Vector3((p.x-800.0)/100.0,(450.0-p.y)/100.0,0)
class Host extends Node:
 var source_projection
 var original_board_bridge
 var presentation_size=Vector2(1600,900)
 var presentation_offset=Vector2.ZERO
 var cards=[{"key":"YETI"},{"key":"YETI"},{"key":"YETI"},{"key":"YETI"}]
 var definitions={"YETI":{"kind":"minion"}}
 var mouse_down=false
 var active_touch_index=-1
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var bridge=Bridge.new();host.add_child(bridge);host.original_board_bridge=bridge
 bridge.viewport=SubViewport.new();bridge.add_child(bridge.viewport)
 var probe=Probe.new();bridge.viewport.add_child(probe);bridge.probe=probe
 var camera_root=Node3D.new();probe.add_child(camera_root)
 probe.camera=Camera3D.new();camera_root.add_child(probe.camera);probe.camera.current=true
 var policy=load("res://scripts/source_board_camera_policy.gd")
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var hand=load("res://scripts/native_phone_hand.gd").new();hand.setup(host)
 for size in [Vector2(1600,900),Vector2(2000,900),Vector2(1600,1200)]:
  host.presentation_size=size;host.presentation_offset=(size-Vector2(1600,900))*.5
  bridge.viewport.size=Vector2i(size)
  policy.apply(probe.camera,camera_root,size)
  await process_frame
  var projection=load("res://scripts/source_board_projection.gd").install(host,probe.camera,size,size,host.presentation_offset,{})
  host.source_projection=projection
  var pass_view=SubViewport.new();pass_view.size=Vector2i(size);root.add_child(pass_view)
  var spatial_pass=load("res://scripts/classic_spatial.gd").new();pass_view.add_child(spatial_pass)
  spatial_pass.game=host;spatial_pass.camera=Camera3D.new();spatial_pass.add_child(spatial_pass.camera)
  spatial_pass._sync_projection_camera()
  assert(spatial_pass.camera.projection==Camera3D.PROJECTION_PERSPECTIVE)
  assert(spatial_pass.camera.global_transform.is_equal_approx(probe.camera.global_transform))
  var raw=hand.center();var reflected=Vector3(raw.x,raw.y,-raw.z)
  assert(spatial_pass.camera.unproject_position(reflected).distance_to(probe.camera.unproject_position(reflected))<.001)
  host.source_projection=null;spatial_pass._sync_projection_camera()
  assert(spatial_pass.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
  pass_view.queue_free()
  assert(not hand.camera_context().is_empty())
  for enlarged in [false,true]:
   hand.set_enlarged(enlarged)
   for i in range(4):
    var pose=hand.source_pose(i,4,false)
    var poly=hand.card_polygon(pose,"minion")
    assert(poly.size()==4)
    for point in poly:assert(is_finite(point.x) and is_finite(point.y))
   print("PHONE_SOURCE_HAND ",size," enlarged=",enlarged," center=",hand.project(hand.center()))
   var all_cards=host.cards
   host.cards=[{"key":"YETI"}]
   assert(hand.hit_card(hand.project(hand.source_pose(0,1).position))==0)
   hand.set_focus(0)
   assert(hand.hit_card(hand.project(hand.source_pose(0,1).position))==0)
   assert(hand.hit_card(Vector2(-10000,-10000))==-1)
   hand.release_touch();host.cards=all_cards
   var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
   arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.82,1.21,0),Vector3(.82,1.21,0),Vector3(.82,-1.21,0),Vector3(-.82,1.21,0),Vector3(.82,-1.21,0),Vector3(-.82,-1.21,0)])
   var base=ArrayMesh.new();base.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var adapter=load("res://scripts/native_phone_card_projection.gd")
   var pose=hand.source_pose(0,4)
   var mesh=adapter.screen_mesh(base,hand,pose,"minion",Spatial.new(),1.0,Vector2.ZERO)
   var vertices=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var polygon=hand.card_polygon(pose,"minion")
   for k in range(6):
    var vertex=vertices[k];var projected=Vector2(vertex.x*100+800,450-vertex.y*100)
    assert(projected.distance_to(polygon[[0,1,2,0,2,3][k]])<0.001)
 probe.camera.set_meta("native_phone_registered",false)
 assert(hand.camera_context().is_empty())
 hand.set_enlarged(false)
 hand.sample(0,4,0)
 hand.set_enlarged(true)
 var transitioned=hand.sample(0,4,.25)
 assert(transitioned.position.is_equal_approx(hand.source_pose(0,4).position))
 hand.set_focus(0)
 var preview=hand.sample(0,4,.5)
 assert(preview.position.is_equal_approx(hand.source_pose(0,4,true).position))
 hand.release_touch();hand.sample(0,4,.5)
 assert(hand.focus==-1 and hand.touched_slot==-1)
 print("PHONE_HAND_PROJECTION_PASS original phone aspect camera, explicit world projection, original stand-in OBB, unregistered camera rejected, source expand/focus/release timings; no game integration")
 host.queue_free();quit()
