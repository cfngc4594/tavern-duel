extends SceneTree
func _initialize():call_deferred("run")
func run():
 for output in [Vector2i(1600,900),Vector2i(2400,1080),Vector2i(800,450)]:
  root.size=output;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  await process_frame
  print(output," stretch=",root.get_stretch_transform()," screen=",root.get_screen_transform()," final=",root.get_final_transform())
 quit()
