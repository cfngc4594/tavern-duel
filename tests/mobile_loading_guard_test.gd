extends SceneTree
class Layout extends Node:
 var enabled=true
 var blockers=[]
class PhoneProjection extends RefCounted:
 var enabled=true
 func is_enabled():return enabled
class Cache extends Node:
 var enabled=true
 var auto_bake=true
 var errors=[]
class Renderer extends Node:
 var texture_cache_controller
func _initialize():call_deferred("run")
func run():
 var game=load("res://tests/phone_hand_game_fixture.gd").new()
 assert(not game._native_loading_problem().is_empty())
 var layout=Layout.new();game.source_phone_layout=layout
 assert(not game._native_loading_problem().is_empty())
 var projection=PhoneProjection.new();game.source_projection=projection
 game.definitions={"fixture":{}}
 var renderer=Renderer.new();var cache=Cache.new()
 renderer.texture_cache_controller=cache;game.native_card_renderer=renderer
 var bridge=Node.new();game.original_board_bridge=bridge
 assert(game._native_loading_problem().is_empty())
 layout.enabled=false;assert(not game._native_loading_problem().is_empty());layout.enabled=true
 projection.enabled=false;assert(not game._native_loading_problem().is_empty());projection.enabled=true
 layout.blockers=["unverified fixture layout"];assert(not game._native_loading_problem().is_empty());layout.blockers.clear()
 assert(game._native_loading_problem().is_empty())
 game.free();layout.free();renderer.free();cache.free();bridge.free()
 print("MOBILE_LOADING_GUARD_PASS missing, disabled and blocked phone layouts fail closed; complete registration succeeds")
 quit()
