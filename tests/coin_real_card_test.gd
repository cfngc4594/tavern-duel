extends SceneTree
class Host extends Node:
 var board_render_target_size=Vector2i(1920,1080)
 var presentation_size=Vector2(1600,900)
 var presentation_offset=Vector2.ZERO
 var world_canvas=Node2D.new()
 var native_card_renderer
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host);host.add_child(host.world_canvas)
 host.native_card_renderer=load("res://scripts/native_card_renderer.gd").new();host.add_child(host.native_card_renderer)
 var definitions=load("res://scripts/classic_flow_cards.gd").additional_definitions()
 var d:Dictionary=definitions.GAME_005;d.frame="frame-spell-neutral"
 host.native_card_renderer.build_card("GAME_005",d,load("res://assets/original_classic_v13/art/GAME_005.png"))
 var source=load("res://scripts/native_coin_presentation.gd").new();host.add_child(source);source.setup(host)
 source.begin_source_drop(false);source.begin_source_birth(false);source.begin_source_card()
 assert(not source.card_actor.root.visible)
 source.advance_card(1.5166667)
 assert(source.card_actor.root.visible)
 assert(source.card_birth.phase=="None")
 source.begin_hand_transition({"pos":Vector2(880,837),"scale":0.76,"angle":0.1})
 source.sample_hand_transition(1.0)
 assert(source.card_actor.root.transform.is_equal_approx(source.gather_to))
 print("COIN_REAL_CARD_PASS: actual renderer GAME005 clone, native birth, hidden->visible,1s source transition endpoint")
 host.queue_free();quit()
