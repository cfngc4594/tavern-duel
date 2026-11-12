extends SceneTree
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 assert(ProjectSettings.get_setting("application/run/main_scene")=="res://main.tscn")
 assert(ProjectSettings.get_setting("rendering/renderer/rendering_method")=="gl_compatibility")
 assert(change_scene_to_file("res://main.tscn")==OK)
 await scene_changed
 var game=current_scene
 assert(game!=null and game.get_script()!=null)
 for i in 1500:
  await process_frame
  if not game.native_initial_loading:break
 assert(not game.native_initial_loading)
 if DisplayServer.get_name()!="headless":
  for i in 120:await process_frame
  await RenderingServer.frame_post_draw
  assert(args.size()>0)
  assert(root.get_texture().get_image().save_png(args[0])==OK)
 var manager=root.get_node("SoundManager")
 await manager.shutdown_audio()
 print("WINDOWS_PRODUCTION_MAIN_PASS ",JSON.stringify({"main_scene":current_scene.scene_file_path,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"headless":DisplayServer.get_name()=="headless"}))
 game.queue_free();await process_frame
 quit()
