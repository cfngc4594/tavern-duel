extends SceneTree
func _initialize():
 for path in ['board_probe','board_materials','source_board_state','water_interactions','window_lamp_interaction']:
  var script=load('res://original_board/scripts/'+path+'.gd')
  assert(script!=null and script.can_instantiate(),path)
 print('SOURCE_BOARD_STATE_PARSE_PASS')
 quit()
