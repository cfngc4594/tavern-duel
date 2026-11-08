extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scripts/game.gd").new();game.face_render_mode=true;game.visible=false;root.add_child(game)
 game.presentation_size=Vector2(2000,900);game.presentation_offset=Vector2(200,0);game.board_render_target_size=Vector2i(2000,900)
 game.allies=[{"animating":false,"pos":Vector2.ZERO,"dead":false}]
 game.enemies=[{"animating":false,"pos":Vector2.ZERO,"dead":false}]
 var controller=load("res://scripts/source_phone_layout_controller.gd").new();game.add_child(controller);controller.setup(game)
 game.source_phone_layout=controller;controller.enabled=true
 game.source_projection=load("res://scripts/source_board_projection.gd").install(game,controller.camera,Vector2(controller.viewport.size),game.presentation_size,game.presentation_offset,{})
 controller.update_units()
 var own=controller.snapshot.items.friendly_hero
 var enemy=controller.snapshot.items.opposing_hero
 assert(game.target_at(own.center,0).type=="hero")
 assert(game.target_at(enemy.center,1).type=="hero")
 assert(game.target_at(game.allies[0].pos,0).type=="unit")
 assert(game.target_at(Vector2(-10000,-10000),1).is_empty())
 assert(game._source_play_contains(game.allies[0].pos))
 assert(not game._source_play_contains(enemy.center))
 print("PHONE_GAME_TARGETING_PASS")
 game.queue_free();quit()
