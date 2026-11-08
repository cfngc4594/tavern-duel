extends SceneTree
func _initialize():call_deferred("run")
func run():
 var ui=load("res://scripts/native_turn_ui.gd").new();root.add_child(ui);ui.setup(null)
 var scene=Node3D.new();root.add_child(scene)
 var source=preload("res://scripts/source_phone_board_layout.gd").recovered_items(0,0,{"aspect":2.0})
 assert(ui.attach_source_scene(scene,source.end_turn.source_pose))
 assert(ui.dynamic_instance.source_root.transform.is_equal_approx(source.end_turn.source_pose))
 assert(ui.dynamic_instance.reflection_root.get_parent()==scene)
 assert(ui.dynamic_instance.reflection_root.transform.basis.determinant()<0)
 ui.request_state("green");ui.advance_animation(.5)
 assert(ui.dynamic_instance.source_root.transform.is_equal_approx(source.end_turn.source_pose))
 print("PHONE_TURN_SCENE_PASS")
 ui.queue_free();scene.queue_free();quit()
