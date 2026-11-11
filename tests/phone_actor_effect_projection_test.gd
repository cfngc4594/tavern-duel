extends SceneTree
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Policy=preload("res://scripts/source_board_camera_policy.gd")
const Combat=preload("res://scripts/native_combat_effects.gd")
const Player=preload("res://scripts/native_combat_player.gd")
const Summon=preload("res://scripts/native_summon_player.gd")
const Target=preload("res://scripts/native_targeting.gd")
const Damage=preload("res://scripts/native_damage_splat.gd")
const Death=preload("res://scripts/native_death_effects.gd")
const Status=preload("res://scripts/native_status_effects.gd")
const Highlight=preload("res://scripts/native_highlight.gd")
const Endgame=preload("res://scripts/native_endgame_screen.gd")
const Background=preload("res://scripts/native_endgame_background.gd")
class TestAssets:
 var objects:Dictionary={}
 var transforms:Dictionary={}
 func component(key:String,_kind:String)->Dictionary:return transforms.get(key,{})
class Host extends Node:
 var source_held_motion
 var original_board_bridge
 var presentation_size=Vector2(2000,900)
 var presentation_offset=Vector2(200,0)
class Bridge extends Node:
 var probe
 var viewport
class Probe extends Node3D:
 var camera
 var source_nodes:Dictionary={}
func _initialize():call_deferred("run")
func run():
 var owner=Host.new();root.add_child(owner)
 var vp=SubViewport.new();vp.size=Vector2i(2000,900);owner.add_child(vp)
 var cr=Node3D.new();vp.add_child(cr);var camera=Camera3D.new();cr.add_child(camera)
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 Policy.apply(camera,cr,Vector2(vp.size))
 var point=Vector3(-7.8,.3,-5.6)
 var anchors={}
 for key in ["hero:0","hero:1","power:0","power:1","play:0","play:1"]:
  anchors[key]={"position":point,"rotation":Quaternion.IDENTITY,"scale":Vector3.ONE,"verified":true,"source":"synthetic test only"}
 anchors.targeting_plane={"position":point,"plane":Plane(Vector3.UP,point.y),"verified":true,"source":"synthetic explicit test plane, not production evidence"}
 var projection=SourceProjection.install(owner,camera,Vector2(vp.size),Vector2(vp.size),Vector2(200,0),anchors)
 var combat=Combat.new();owner.add_child(combat);combat.game=owner
 assert(combat._source_location({"side":0,"key":"CS2_029"},2).position==point)
 assert(combat._source_location({"side":0,"key":"CS2_029"},0).is_empty())
 var source_assets=TestAssets.new();combat.assets=source_assets
 source_assets.transforms["test-root"]={"data":{"m_LocalPosition":{"x":point.x,"y":point.y,"z":point.z},"m_Father":{"m_PathID":0}}}
 assert(combat._source_location({"side":0,"key":"CS2_029"},0,"test-root").position==point)
 source_assets.transforms["test-root"].data.m_Father.m_PathID=1
 assert(combat._source_location({"side":0,"key":"CS2_029"},0,"test-root").is_empty())
 var container=Node3D.new();vp.add_child(container);var reflected=Node3D.new();container.add_child(reflected);reflected.basis=SourceProjection.REFLECTION
 var actor=Node3D.new();reflected.add_child(actor)
 var effect={"container":container,"projection":reflected,"source_anchor":projection.resolve_anchor("hero:0"),"unsupported":[],"state":{"root":actor,"paths":{},"source_rotations":{}},"root_key":"test","age":0.0}
 combat._project(effect);assert(container.position.is_equal_approx(SourceProjection.source_to_render(point)))
 var destination=point+Vector3(2,0,3)
 effect.motion={"source_start":point,"source_end":destination,"start":Vector2.ZERO,"end":Vector2.ONE,"begin":0.0,"flight":1.0,"ease":0,"center":.5,"center_height":0.0,"right":0.0,"left":0.0,"distance_scale":8.0,"height":0.0,"joint":"","orient":false}
 combat._project(effect);assert(actor.global_position.is_equal_approx(SourceProjection.source_to_render(point)))
 effect.age=1.0;combat._project(effect);assert(actor.global_position.is_equal_approx(SourceProjection.source_to_render(destination)))
 effect.erase("motion");effect.source_anchor={};effect.context={"target":{"source_world_position":point}}
 combat._project(effect);assert(not container.visible) # Unresolved location never silently falls back to target.
 var player=Player.new();owner.add_child(player);player.game=owner
 var unit={"source_world_position":point,"source_world_target":point,"pos":Vector2.ZERO}
 var attack={"unit":unit,"source_origin":point,"source_contact":destination}
 player._source_attack_position(attack,false,.5)
 assert(unit.source_world_position.is_equal_approx(point.lerp(destination,.5)))
 assert(unit.pos.distance_to(projection.source_to_screen(unit.source_world_position))<.001)
 player._source_attack_position(attack,true,1.0);assert(unit.source_world_position==point)
 var target=Target.new();owner.add_child(target);target.game=owner
 assert(target._source_point(projection.source_to_screen(point)).distance_to(point)<.0001)
 assert(target._projection_basis().is_equal_approx(SourceProjection.REFLECTION))
 anchors.erase("targeting_plane");assert(not target._source_point(Vector2(800,450)).is_finite())
 var bridge=Bridge.new();owner.add_child(bridge);owner.original_board_bridge=bridge;bridge.viewport=vp
 var probe=Probe.new();vp.add_child(probe);bridge.probe=probe;probe.camera=camera
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/assets/scene.json"))
 var transforms={}
 for node in data.nodes:
  var local=Policy.raw_transform({"m_LocalPosition":node.position,"m_LocalRotation":node.rotation,"m_LocalScale":node.scale})
  transforms[node.id]=(Transform3D.IDENTITY if node.parent=="" else transforms[node.parent])*local
 var held=load("res://scripts/native_held_motion.gd").new();held.setup(owner);owner.source_held_motion=held
 var drag_plane=Node3D.new();probe.add_child(drag_plane);drag_plane.transform=transforms[held.PLANE];probe.source_nodes[held.PLANE]=drag_plane
 for point_on_screen in [Vector2(800,450),Vector2(650,650),Vector2(1000,500)]:
  var source_hit=held.hit(point_on_screen);assert(not source_hit.is_empty())
  assert(target._source_point(point_on_screen).distance_to(source_hit.source_world)<.00001)
  assert(projection.source_to_screen(source_hit.source_world).distance_to(point_on_screen)<.001)
 var endgame=Endgame.new();owner.add_child(endgame);endgame.game=owner
 var spec={"m_Enabled":1,"m_screenCategory":[4,1],"m_localPosition":[{"x":0,"y":0,"z":0},{"x":0,"y":-1.5,"z":.6}],"m_localScale":[{"x":1,"y":1,"z":1},{"x":1,"y":1,"z":1}],"m_localRotation":[{"x":0,"y":0,"z":0,"w":1},{"x":0,"y":0,"z":0,"w":1}]}
 var disabled=spec.duplicate(true);disabled.m_Enabled=0;disabled.m_localPosition[1].x=999
 var assets=TestAssets.new();assets.objects={"root":{"refs":{"enabled":"on","disabled":"off"}},"on":{"key":"on","class_name":"TransformOverride","data":spec},"off":{"key":"off","class_name":"TransformOverride","data":disabled}}
 endgame.assets=assets
 var screen_root=Node3D.new();vp.add_child(screen_root)
 var scope={"nodes":{"root":screen_root},"source_rotations":{}}
 endgame._apply_screen_overrides(scope)
 assert(screen_root.position.is_equal_approx(Vector3(0,-1.5,.6)))
 assert(endgame.history.size()==1 and endgame.history[0].category==1)
 var background=Background.new();owner.add_child(background);background.game=owner
 background.result_camera=Camera3D.new();vp.add_child(background.result_camera)
 background._copy_camera(camera);assert(background.result_camera.global_transform.is_equal_approx(camera.global_transform))
 print("PHONE_ACTOR_EFFECT_PROJECTION_PASS raw source path endpoints, attack interpolation, actual layer9 reticle rays, enabled phone result overrides, missing anchor fails closed; no GPU equivalence claim")
 owner.queue_free();quit()
