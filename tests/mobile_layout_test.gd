extends SceneTree
const Policy=preload("res://scripts/render_resolution_policy.gd")
func _initialize():call_deferred("run")
func run():
 var failed:=0
 for output in [Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(3120,1440),Vector2i(2560,1440),Vector2i(2048,1536),Vector2i(1280,720)]:
  var canvas:=Policy.canvas_size(output)
  var target:=Policy.target_size(output)
  var scenery:=Policy.scenery_size(canvas,target)
  var offset:=(canvas-Vector2(1600,900))*0.5
  if not is_equal_approx(float(target.x)/target.y,1600.0/900.0):failed+=1
  if scenery.x*scenery.y>Policy.MAX_SCENERY_PIXELS*1.005:failed+=1
  for point in [Vector2.ZERO,Vector2(800,450),Vector2(1600,900),Vector2(352,171)]:
   var pixel:Vector2=(point+offset)*Vector2(scenery)/canvas
   if not (pixel*canvas/Vector2(scenery)-offset).is_equal_approx(point):failed+=1
  print("MOBILE ",output," canvas=",canvas," spatial=",target," scenery=",scenery," offset=",offset)
 for path in ["res://scripts/game.gd","res://scripts/original_board_bridge.gd","res://scripts/native_endgame_background.gd","res://scripts/native_combat_screen_effects.gd"]:
  var script=load(path)
  if script==null or not script.can_instantiate():failed+=1
  print("LOAD ",path," ",script!=null and script.can_instantiate())
 print("MOBILE_LAYOUT_FAILURES=",failed);quit(failed)
