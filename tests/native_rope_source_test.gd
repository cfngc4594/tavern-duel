extends SceneTree
const Rope=preload('res://scripts/native_rope.gd')
const Policy=preload('res://scripts/source_board_camera_policy.gd')
func _initialize():call_deferred('run')
func run():
 var view:=SubViewport.new();view.size=Vector2i(1600,900);view.own_world_3d=true;view.transparent_bg=false;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.2,.2,.2);env.environment=environment;view.add_child(env)
 var source:=Node3D.new();source.basis=Policy.REFLECTION;view.add_child(source)
 var camera_root:=Node3D.new();view.add_child(camera_root);var camera:=Camera3D.new();camera_root.add_child(camera);camera.current=true
 Policy.apply(camera,camera_root,Vector2(1600,900))
 var rope=Rope.new();source.add_child(rope);rope.setup();rope.begin(20.0)
 var frames:Array=[]
 for at in [0.0,0.2,0.5,0.75,0.88]:
  rope.sample_birth(at)
  await process_frame;await process_frame
  var bounds:AABB=rope.skinned[0].mesh.get_aabb()
  frames.append({'at':at,'min':str(bounds.position),'max':str(bounds.end),'fuse':rope.fuse_animation})
  if DisplayServer.get_name()!='headless':
   await RenderingServer.frame_post_draw
   view.get_texture().get_image().save_png('user://rope-'+str(at)+'.png')
 var finish:Vector3=rope.state.paths['Bones/SparksFinishBone'].position;var start:Vector3=rope.state.paths['Bones/SparksStartBone'].position
 assert(start.distance_to(Vector3(-14.243833541870117,.19836211204528809,-4.463869094848633))<.000001)
 assert(finish.distance_to(Vector3(-2.425497531890869,0,-4.460000038146973))<.000001)
 assert(rope.skinned.size()==1 and rope.skinned[0].data.vertices.size()==319 and rope.skinned[0].bones.size()==10)
 print('NATIVE_ROPE_SOURCE_TEST ',JSON.stringify({'frames':frames,'start_pixel':str(camera.unproject_position(Policy.REFLECTION*start)),'finish_pixel':str(camera.unproject_position(Policy.REFLECTION*finish)),'audit':rope.get_audit()}))
 rope.begin(20.0)
 for i in range(120):rope.update_timer(.01,20.0-float(i+1)*.01)
 assert(rope.stage=='countdown' and rope.solvers.size()==4)
 var particle_reports:Array=[]
 for solver in rope.solvers:particle_reports.append({'source':solver.source_key,'unsupported':solver.unsupported,'enabled_modules':solver.enabled_modules,'live':solver.live_count})
 print('NATIVE_ROPE_COUNTDOWN_TEST ',JSON.stringify({'audit':rope.get_audit(),'particles':particle_reports}))
 rope.cancel();assert(rope.stage=='hidden')
 print('NATIVE_ROPE_SOURCE_PASS')
 view.queue_free();quit(0)
