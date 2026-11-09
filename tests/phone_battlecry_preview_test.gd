extends SceneTree
class Host extends Node:
 var native_card_renderer
 var cards=[{"key":"CS2_189"}]
 var definitions={"CS2_189":{"art":0,"atk":1,"hp":1}}
 var raw_portraits={0:null}
 var pending_battlecry={"index":0,"source_world_position":Vector3(-7.83,0,-5.6),"source_world_scale":Vector3.ONE*1.058}
func _initialize():call_deferred("run")
func run():
 var game=Host.new();root.add_child(game)
 game.native_card_renderer=load("res://scripts/native_card_renderer.gd").new();game.add_child(game.native_card_renderer)
 var renderer=load("res://scripts/native_phone_hand_renderer.gd").new();game.add_child(renderer);renderer.setup(game,null)
 renderer._sync_battlecry_preview()
 assert(renderer.battlecry_preview.root.visible)
 assert(renderer.battlecry_preview.actor.native_board_actor)
 assert(renderer.battlecry_preview.root.position.is_equal_approx(game.pending_battlecry.source_world_position))
 assert(renderer.battlecry_preview.root.scale.is_equal_approx(game.pending_battlecry.source_world_scale))
 assert(renderer.battlecry_preview.actor.stats.health==1)
 game.pending_battlecry.clear();renderer._sync_battlecry_preview()
 assert(not renderer.battlecry_preview.root.visible)
 renderer.clear();assert(renderer.battlecry_preview.is_empty())
 print("PHONE_BATTLECRY_PREVIEW_PASS native minion preview anchored to provisional board slot, hidden on cancel/commit")
 game.queue_free();quit()
