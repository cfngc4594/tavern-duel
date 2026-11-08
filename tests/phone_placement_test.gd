extends SceneTree
func _initialize():
 var helper=load("res://scripts/native_phone_placement.gd")
 var row=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/phone_board_layout_runtime.json")).rows.Zone_Friendly_Play
 var center=float(row.phone_world_position[0])
 for count in range(0,7):
  for previous in [-1,0,1,3]:
   var width=helper.slot_width(row,count,previous)
   var left=center-(count+1)*width*.5
   for i in range(count+1):
    assert(helper.source_slot(row,count,previous,left+(i+.5)*width,center)==i+1)
   assert(helper.source_slot(row,count,previous,left-10,center-1)==1)
   assert(helper.source_slot(row,count,previous,left+100,center+1)==count+1)
 print("PHONE_PLACEMENT_PASS original ceil/1based slots, width modifiers and prior-gap branch; no screen hysteresis")
 quit()
