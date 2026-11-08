extends SceneTree
func _initialize():
 var controller=load("res://scripts/source_phone_layout_controller.gd")
 assert(controller!=null and controller.can_instantiate())
 var game=load("res://scripts/game.gd")
 assert(game!=null and game.can_instantiate())
 print("SOURCE_PHONE_CONTROLLER_PARSE_PASS")
 quit()
