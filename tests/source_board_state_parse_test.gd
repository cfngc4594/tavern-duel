extends SceneTree
func _initialize():
 for path in ['board_probe','board_materials','board_source_store','source_board_state','mill_door_interaction','arch_interactions','bush_interactions','pumpkin_interaction','water_interactions','source_particles','source_particle_solver','source_particle_curves','source_legacy_curves']:
  var script=load('res://original_board/scripts/'+path+'.gd')
  assert(script!=null and script.can_instantiate(),path)
 print('SOURCE_BOARD_STATE_PARSE_PASS')
 quit()
