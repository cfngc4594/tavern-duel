extends SceneTree
class Host extends Node:
 enum Interaction {IDLE,PLACEMENT_PREVIEW}
 var presentation_size=Vector2(2000,900)
 var presentation_offset=Vector2(200,0)
 var board_render_target_size=Vector2i(2000,900)
 var flow={"temporary_mana":[2,0]}
 var max_mana=4
 var mana=6
 var player_turn=true
 var interaction_state=Interaction.IDLE
 var preview_index=0
 var allies=[]
 var enemies=[]
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var controller=load("res://scripts/source_phone_layout_controller.gd").new();host.add_child(controller)
 controller.setup(host)
 assert(controller.snapshot.ready,str(controller.snapshot.blockers))
 assert(not controller.enabled)
 assert(controller.context==null)
 assert(not controller.contains("friendly_hero",controller.snapshot.items.friendly_hero.center))
 assert(controller.snapshot.items.friendly_mana.crystals.size()==6)
 host.allies=[{"animating":false,"pos":Vector2.ZERO}]
 host.enemies=[{"animating":false,"pos":Vector2.ZERO},{"animating":false,"pos":Vector2.ZERO}]
 controller.refresh()
 controller.enabled=true # Exercise source assignment without enabling production.
 controller.update_units()
 assert(host.allies[0].source_world_position.is_equal_approx(controller.snapshot.items.friendly_play.actors[0].source_world_position))
 assert(host.allies[0].source_world_rotation is Quaternion)
 assert(host.allies[0].source_hit_polygon.size()>=3)
 assert(host.enemies[0].pos.x<host.enemies[1].pos.x)
 assert(controller.contains("friendly_hero",controller.snapshot.items.friendly_hero.center))
 var initial:Vector3=host.allies[0].source_world_position
 host.allies.append({"animating":false,"pos":Vector2.ZERO})
 controller.refresh();controller.enabled=true
 var destination:Vector3=controller.snapshot.items.friendly_play.actors[0].source_world_position
 controller.update_units(.5)
 assert(host.allies[0].source_world_position.is_equal_approx(initial.lerp(destination,.96875)))
 controller.update_units(.5)
 assert(host.allies[0].source_world_position.is_equal_approx(destination))
 print("SOURCE_PHONE_CONTROLLER_GATE_PASS")
 host.queue_free();quit()
