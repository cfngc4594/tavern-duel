extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scripts/game.gd").new()
 game.face_render_mode=true;game.visible=false;game.native_initial_loading=true;root.add_child(game)
 game.world_canvas=Node2D.new();game.add_child(game.world_canvas)
 game.fixed_layer=CanvasLayer.new();game.add_child(game.fixed_layer)
 game.fixed_canvas=Node2D.new();game.fixed_layer.add_child(game.fixed_canvas)
 game.spatial_view=SubViewport.new();game.add_child(game.spatial_view)
 game.spatial_scene=load("res://scripts/classic_spatial.gd").new();game.spatial_view.add_child(game.spatial_scene);game.spatial_scene.setup(game,Vector2i(1600,900))
 var effect=load("res://scripts/native_endgame_background.gd").new();game.add_child(effect);effect.setup(game)
 var failed:=0
 for output in [Vector2i(2400,1080),Vector2i(3120,1440),Vector2i(2048,1536),Vector2i(1600,900)]:
  root.size=output;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  await process_frame
  game._refresh_render_resolution()
  game.world_canvas.position=game.presentation_offset+Vector2(12,-7)
  if not is_instance_valid(effect.board_view):effect._ensure_canvas();effect._make_result_view()
  else:effect.refresh_layout()
  await process_frame
  for point in [Vector2(0,0),Vector2(800,450),Vector2(1600,900),Vector2(352,171)]:
   if not game.screen_to_board(game.board_to_screen(point)).is_equal_approx(point):failed+=1
  var result_center:Vector2=effect.result_camera.unproject_position(Vector3.ZERO)*game.presentation_size/Vector2(effect.result_view.size)
  var expected:Vector2=game.presentation_size*0.5+Vector2(12,-7)
  if not result_center.is_equal_approx(expected):failed+=1
  if effect.board_view.size!=game.board_render_target_size or effect.overlay.size!=game.presentation_size:failed+=1
  var capture_center:Vector2=effect.board_view.canvas_transform*game.presentation_size*0.5
  if not capture_center.is_equal_approx(Vector2(effect.board_view.size)*0.5):failed+=1
  print("INTEGRATION ",output," result_center=",result_center," expected=",expected," errors=",failed)
 effect.dispose();game.queue_free();await process_frame
 print("MOBILE_INTEGRATION_FAILURES=",failed);quit(failed)
