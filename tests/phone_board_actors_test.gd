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
 print("PHONE_BOARD_ACTORS_PASS")
 host.queue_free();quit()
