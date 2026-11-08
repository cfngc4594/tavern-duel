extends SceneTree
class FakeVisuals:
 func release_button(): return false
class FakeFlow:
 var visuals=FakeVisuals.new()
 func accepts_actions(): return true
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 await process_frame
 var game=load("res://tests/touch_input_fixture.gd").new();game.native_initial_loading=false;root.add_child(game)
 game.world_canvas=Node2D.new();game.add_child(game.world_canvas)
 var down=InputEventScreenTouch.new();down.index=0;down.position=Vector2(700,850);down.pressed=true
 game._unhandled_input(down)
 assert(game.presses==1 and game.active_touch_index==0 and game.touch_input_active)
 var duplicate=InputEventMouseButton.new();duplicate.device=InputEvent.DEVICE_ID_EMULATION;duplicate.button_index=MOUSE_BUTTON_LEFT;duplicate.pressed=true
 game._unhandled_input(duplicate);assert(game.presses==1)
 var second=InputEventScreenTouch.new();second.index=1;second.pressed=true
 game._unhandled_input(second);assert(game.presses==1 and game.active_touch_index==0)
 var move=InputEventScreenDrag.new();move.index=0;move.position=Vector2(700,600)
 game._unhandled_input(move);assert(game.begins==1)
 var up=InputEventScreenTouch.new();up.index=0;up.position=move.position;up.pressed=false
 game._unhandled_input(up)
 assert(game.releases==1 and game.active_touch_index==-1 and not game.mouse_down and game.hover_card==-1 and game.last_hover==-1)
 game._unhandled_input(down);up.canceled=true;game._unhandled_input(up);assert(game.cancels==1)
 game.flow=FakeFlow.new();game.drag_index=-1;game.pressed_card=2;game.touch_input_active=true
 var previous_begins=game.begins
 game.real_pointer_release();assert(game.pressed_card==-1 and game.begins==previous_begins)
 game.pressed_card=2;game.touch_input_active=false
 game.real_pointer_release();assert(game.begins==previous_begins+1)
 game.touch_input_active=true;game.active_touch_index=-1
 assert(not game.is_pointer_hover_allowed())
 game.active_touch_index=0;assert(game.is_pointer_hover_allowed())
 # Inject logical events reconstructed from window coordinates at real stretch scales.
 for output in [Vector2i(800,450),Vector2i(1600,900),Vector2i(2400,1080),Vector2i(3200,1800)]:
  root.size=output;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  await process_frame
  var to_viewport=root.get_stretch_transform().affine_inverse()
  var start_window=Vector2(500,400)
  for delta in [Vector2(0,-19),Vector2(20,0),Vector2(240,0),Vector2(240,-79),Vector2(0,-80),Vector2(0,-81),Vector2(0,120)]:
   game.active_touch_index=-1;game.drag_index=-1
   down.position=to_viewport*start_window
   game._unhandled_input(down)
   assert(game.touch_press_window_pos.is_equal_approx(start_window))
   var before=game.begins
   move.position=to_viewport*(start_window+delta)
   game._unhandled_input(move)
   var should_grab=delta.y < -80
   assert(game.begins==before+(1 if should_grab else 0), "Window threshold mismatch: %s delta=%s" % [output,delta])
   up.canceled=false;up.position=move.position;game._unhandled_input(up)
  print("TOUCH_WINDOW_THRESHOLD_PASS ",output," stretch=",root.get_stretch_transform())
 # Two real resting-fan hit boxes: slide to a new preview, reset Y only,
 # then accumulate the 80-window-pixel rise from that newly previewed card.
 root.size=Vector2i(1600,900);await process_frame
 game.real_hand_hit_test=true;game.cards=[]
 for i in range(2):
  var pose=game._resting_hand_pose(i,2)
  game.cards.append({"pos":pose.pos,"scale":pose.scale,"angle":pose.angle})
 game.active_touch_index=-1;game.drag_index=-1;game.last_hover=-1
 down.position=Vector2(700,850);game._unhandled_input(down)
 assert(game.pressed_card==0)
 var slide_before=game.begins
 move.position=Vector2(820,800);game._unhandled_input(move)
 assert(game.pressed_card==1 and game.hover_card==1 and game.begins==slide_before)
 assert(game.touch_press_window_pos==Vector2(700,800))
 move.position=Vector2(820,720);game._unhandled_input(move)
 assert(game.begins==slide_before)
 move.position=Vector2(820,719);game._unhandled_input(move)
 assert(game.begins==slide_before+1 and game.grabbed_index==1)
 print("TOUCH_PREVIEW_SWITCH_PASS: real two-card fan hits, preserved down.x, reset down.y, new card grabs only after >80")
 print("TOUCH_INPUT_PASS: single finger, emulation dedupe, >80 window-pixel upward grab, horizontal rejection, scaled boundaries, release, cancellation")
 game.flow=null;game.queue_free();quit()
