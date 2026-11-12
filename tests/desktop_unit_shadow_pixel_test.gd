extends SceneTree
var before
var after
var views=[]
var nodes=[]
var units=[]
func _initialize():call_deferred("run")
func exact_geometry(game):
 for layer in range(1,game.GROUND_SHADOW_LAYERS+1):
  var spread=2.0*float(layer)/game.GROUND_SHADOW_LAYERS
  var radii=Vector2(49,61)+Vector2.ONE*spread
  var points=PackedVector2Array()
  for i in range(64):
   var a=i*TAU/64
   points.append(Vector2.ZERO+Vector2(cos(a)*radii.x,sin(a)*radii.y))
  var mesh=game._static_unit_shadow_mesh(layer)
  assert(mesh==game._static_unit_shadow_mesh(layer),"retained mesh identity")
  var arrays=mesh.surface_get_arrays(0)
  assert(arrays[Mesh.ARRAY_VERTEX]==points,"exact original ellipse vertices")
  assert(arrays[Mesh.ARRAY_INDEX]==Geometry2D.triangulate_polygon(points),"exact original triangulation")
 assert(game._static_unit_shadow_meshes.size()==12,"bounded twelve meshes")
 for lift in [0.0,-.001,.00001,13.0,54.0]:
  for scale in [1.0,.99999,1.00001,.7,1.3]:
   var u={"pos":Vector2(200,200),"lift":lift,"scale":scale}
   var pose=game.unit_shadow_pose(u)
   assert(game._unit_shadow_mesh_eligible(u,pose)==(lift==0.0 and scale==1.0),"strict dynamic fallback")
 var u={"pos":Vector2(200,200)}
 var pose=game.unit_shadow_pose(u)
 assert(game._unit_shadow_mesh_eligible(u,pose))
 pose.radii=Vector2(49.01,61);assert(not game._unit_shadow_mesh_eligible(u,pose))
 pose.radii=Vector2(49,61);pose.softness=2.01;assert(not game._unit_shadow_mesh_eligible(u,pose))
func draw_case(node,game):
 node.draw_rect(Rect2(0,0,800,600),Color(.4,.5,.6,1))
 game.draw_target=node
 for u in units:game._draw_projected_unit_shadow(u)
func run():
 before=load("res://scripts/game.gd").new();before.unit_shadow_mesh_enabled=false
 after=load("res://scripts/game.gd").new()
 exact_geometry(after)
 if "--geometry-only" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":
  print("UNIT_SHADOW_GEOMETRY_PASS 12 exact meshes + dynamic geometry guards")
  before.free();after.free();quit();return
 for game in [before,after]:
  var view=SubViewport.new();view.size=Vector2i(800,600);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(view);views.append(view)
  var node=Node2D.new();view.add_child(node);nodes.append(node)
  node.draw.connect(draw_case.bind(node,game))
 var differences=0
 for k in 40:
  if k==20:
   for node in nodes:
    var material=ShaderMaterial.new();material.shader=load("res://shaders/native_scene_composite.gdshader");node.material=material
  units=[]
  for i in 5:
   var lift=0.0 if k%3==0 else (k*.757+i*.123 if k%3==1 or i==0 else 0.0)
   units.append({"pos":Vector2(100+i*140,290+sin(i)*40),"rotation":(i-2)*.17+k*.037,"scale":1.0 if k%4!=1 else .5+k*.023,"lift":lift,"summon_shadow":k%2==0,"hidden":k%7==0 and i==0})
  for game in [before,after]:game.shake_offset=Vector2(k*.17,-k*.11)
  for node in nodes:node.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  var a=views[0].get_texture().get_image();var b=views[1].get_texture().get_image()
  var ad=a.get_data();var bd=b.get_data();var count=0;var max_delta=0
  for i in ad.size():
   if ad[i]!=bd[i]:count+=1;max_delta=max(max_delta,absi(int(ad[i])-int(bd[i])))
  if count:
   differences+=count;print("UNIT_SHADOW_PIXEL_DIFF case=",k," bytes=",count," max_delta=",max_delta)
   a.save_png("res://build/unit-shadow-before.png");b.save_png("res://build/unit-shadow-after.png")
 print("UNIT_SHADOW_PIXELS_RESULT differences=",differences," 40 scenes default+premultiplied, static/dynamic/mixed")
 for view in views:view.queue_free()
 await process_frame
 before.free();after.free();quit(0 if differences==0 else 1)