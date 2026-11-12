extends SceneTree
var before
var after
var views=[]
var nodes=[]
func _initialize():call_deferred("run")
func draw_case(node,game):
 node.draw_rect(Rect2(0,0,800,600),Color(.4,.5,.6,1))
 game.draw_target=node
 if game==after:game._draw_hand_underlay()
 else:
  for c in game.cards:
   var lift=c.get("lift",0.0)
   node.draw_set_transform(c.pos+Vector2(7+lift*.24,8+lift*.32)+game.shake_offset,c.angle,Vector2.ONE*c.scale)
   for j in range(5,0,-1):node.draw_colored_polygon(game._card_surface_outline(1+j*.018+lift*.0005),Color(.018,.015,.012,.035))
  node.draw_set_transform(game.shake_offset)
func run():
 before=load("res://scripts/game.gd").new()
 after=load("res://scripts/game.gd").new()
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
  var cards=[]
  for i in 7:
   cards.append({"pos":Vector2(100+i*90,320+sin(i)*30),"angle":(i-3)*.09+float(k)*.013,"scale":.5+float(k)*.013,"lift":0.0 if k%3==0 else (float(k)*.757+i*.123 if k%3==1 or i==0 else 0.0)})
  for game in [before,after]:game.cards=cards;game.shake_offset=Vector2(k*.17,-k*.11)
  for node in nodes:node.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  var a=views[0].get_texture().get_image();var b=views[1].get_texture().get_image()
  var ad=a.get_data();var bd=b.get_data();var count=0;var max_delta=0
  for i in ad.size():
   if ad[i]!=bd[i]:count+=1;max_delta=max(max_delta,absi(int(ad[i])-int(bd[i])))
  if count:
   differences+=count
   print("MESH_PIXEL_DIFF case=",k," bytes=",count," max_delta=",max_delta)
   if k==0:a.save_png("res://build/mesh-before.png");b.save_png("res://build/mesh-after.png")
 print("MESH_PIXELS_RESULT differences=",differences," PIXEL_PASS 40 scenes, default and production premultiplied shader, static/dynamic/mixed")
 for view in views:view.queue_free()
 await process_frame
 before.free();after.free();quit(0 if differences==0 else 1)