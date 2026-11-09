extends SceneTree
func _initialize():call_deferred("run")
func run():
 preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform=true
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 for i in 900:
  await process_frame
  if not game.native_initial_loading:break
 game.start_match("practice");game.flow.test_clock_delta=0
 for i in 120:await process_frame
 game.set_process(false)
 var reference_path="res://build/transmission-before.gd"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--reference="):reference_path=arg.substr(12)
 var old=load(reference_path).new();game.add_child(old);old.setup(game.spatial_view,game.spatial_scene)
 var current=game.native_transmission
 old.transmission_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 current.transmission_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for i in 5:old.sync();current.sync()
 var old_times=[];var new_times=[]
 for i in 160:
  for node in ([old,current] if i%2==0 else [current,old]):
   var t=Time.get_ticks_usec();node.sync();var elapsed=Time.get_ticks_usec()-t
   (old_times if node==old else new_times).append(elapsed)
 for label in ["old","new"]:
  var times=old_times if label=="old" else new_times;times.sort();var total=0.0
  for t in times:total+=t
  print("TRANSMISSION_BENCH ",label," mean_ms=",total/times.size()/1000.0," p50_ms=",times[80]/1000.0," p95_ms=",times[152]/1000.0)
 for key in old.mirrors:
  assert(current.mirrors.has(key))
  var a=old.mirrors[key];var b=current.mirrors[key]
  assert(a.visible==b.visible)
  if not a.visible:continue
  assert(a.global_transform.is_equal_approx(b.global_transform) and a.layers==b.layers)
  if a is MeshInstance3D and a.mesh!=null:
   assert(a.mesh==b.mesh)
   for i in a.mesh.get_surface_count():
    var am=a.get_active_material(i);var bm=b.get_active_material(i)
    if am is ShaderMaterial:
     assert(am.shader.code==bm.shader.code)
     for name in old._source_uniform_names(am.shader):assert(am.get_shader_parameter(name)==bm.get_shader_parameter(name),name)
 print("TRANSMISSION_BENCH_PASS same visible geometry, transforms, variants and uniform values")
 quit()