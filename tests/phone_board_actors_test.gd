extends SceneTree
class Host extends Node:
 var native_card_renderer
 var raw_portraits={}
 var health=[30,27]
 var source_projection={"test":true}
 var source_phone_layout={}
 var native_endgame=null
 var power_used=false
 var flow={"enemy_power_used":false}
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 host.native_card_renderer=load("res://scripts/native_card_renderer.gd").new();host.add_child(host.native_card_renderer)
 for art in [0,56,21,57]:host.raw_portraits[art]=null
 host.source_phone_layout={"snapshot":{"items":preload("res://scripts/source_phone_board_layout.gd").recovered_items(0,0,{"aspect":2.0})}}
 var board=load("res://scripts/native_phone_board_actors.gd").new();host.add_child(board);board.setup(host);board.sync()
 assert(board.actors.size()==4)
 assert(board.blockers.is_empty(),str(board.blockers))
 for key in board.actors:
  var entry=board.actors[key]
  assert(entry.actor.root.transform==Transform3D.IDENTITY if key.begins_with("hero") else entry.actor.power_animation.playing)
  assert(entry.root.visible)
 host.health[0]=19;board.sync()
 assert(board.actors["hero:0"].actor.stats.health==19)
 # The original phone Restore ends face-up. State must not be tied to mana;
 # the cost gem remains visible until the separate Used flip occurs.
 var renderer=host.native_card_renderer
 var profile=renderer.profiles.hero_power
 var mesh_record:Dictionary={}
 for record in profile.renderers:
  if str(record.nodeId)==str(profile.portraitNodeId):mesh_record=record
 var source_mesh=renderer.meshes[mesh_record.meshKey]
 var mesh=board.actors["power:0"].actor.renderers["cab-69c88b234dfa427e02d1fcee9337ae34:"+str(profile.portraitNodeId)].mesh
 for surface in source_mesh.submeshes.size():
  var actual=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
  var original=source_mesh.submeshes[surface].indices
  for i in range(0,actual.size(),3):
   assert(actual[i]==original[i] and actual[i+1]==original[i+2] and actual[i+2]==original[i+1],"Power front/back winding must be reflected")
 for side in 2:
  var power=board.actors["power:"+str(side)].actor
  renderer.advance_world_power_animation(power,1.0)
  assert(not power.power_exhausted and not power.power_animation.playing)
  assert(power.root.quaternion.is_equal_approx(Quaternion(0,0,0,-1)) or power.root.quaternion.is_equal_approx(Quaternion.IDENTITY))
 host.power_used=true;board.sync()
 var friendly=board.actors["power:0"].actor
 assert(friendly.power_exhausted and friendly.power_animation.name=="HeroPower_Used_phone")
 renderer.advance_world_power_animation(friendly,1.0)
 assert(absf(friendly.root.quaternion.z)>.99)
 assert(not board.actors["power:1"].actor.power_exhausted)
 host.power_used=false;board.sync();renderer.advance_world_power_animation(friendly,1.0)
 assert(not friendly.power_exhausted and absf(friendly.root.quaternion.w)>.99)
 print("PHONE_BOARD_ACTORS_PASS power front/back winding, initial Restore, Used, and refresh")
 host.queue_free();quit()
