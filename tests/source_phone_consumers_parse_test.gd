extends SceneTree
func _initialize():
 for path in ["source_phone_layout_controller","source_board_projection","native_phone_board_actors","classic_spatial","native_turn_ui","classic_flow_visuals","native_phone_hand","native_phone_hand_renderer","native_summon_player","native_combat_player","native_combat_effects","native_targeting","native_camera_shake","native_hand_highlight","game"]:
  var script=load("res://scripts/"+path+".gd")
  if script==null or not script.can_instantiate():push_error("Cannot instantiate "+path);quit(1);return
 print("SOURCE_PHONE_CONSUMERS_PARSE_PASS")
 quit()
