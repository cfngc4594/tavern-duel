extends SceneTree
class DrawProbe extends Node2D:
 var game
 var done=false
 func _draw():
  if done:return
  game.draw_target=self
  for i in 130:
   var fill=Color(.1,.2,float(i)/130,.6)
   var edge=Color(.7,.4,.1,.9)
   var radius=i%8;var width=i%4
   game._panel(Rect2(i,0,40,20),fill,edge,radius,width)
   var key=[fill,edge,radius,width]
   assert(game._panel_styles.has(key) and game._panel_styles.size()<=64)
   var style=game._panel_styles[key]
   assert(style.bg_color==fill and style.border_color==edge and style.anti_aliasing and style.anti_aliasing_size==1.0)
   for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:assert(style.get_border_width(side)==width)
   for corner in [CORNER_TOP_LEFT,CORNER_TOP_RIGHT,CORNER_BOTTOM_LEFT,CORNER_BOTTOM_RIGHT]:assert(style.get_corner_radius(corner)==radius)
   game._panel(Rect2(i,20,20,40),fill,edge,radius,width)
   assert(game._panel_styles[key]==style)
  game.cards=[{"pos":Vector2(50,50),"angle":.17,"scale":.8,"lift":.000000001}]
  game._draw_hand_underlay()
  assert(game._static_hand_shadow_meshes.is_empty()) # Exact zero only, not approximate zero.
  game.cards[0].lift=0.0
  game._draw_hand_underlay()
  assert(game._static_hand_shadow_meshes.size()==5)
  for layer in range(1,6):
   var mesh=game._static_hand_shadow_mesh(layer)
   assert(mesh==game._static_hand_shadow_mesh(layer))
   var arrays=mesh.surface_get_arrays(0)
   var points=game._card_surface_outline(1+layer*.018)
   assert(arrays[Mesh.ARRAY_VERTEX]==points)
   assert(arrays[Mesh.ARRAY_INDEX]==Geometry2D.triangulate_polygon(points))
  for lift in [-3.0,.001,1.0,50.0]:
   game.cards[0].lift=lift;game._draw_hand_underlay()
   assert(game._static_hand_shadow_meshes.size()==5)
  done=true
func _initialize():call_deferred("run")
func run():
 var game=load("res://scripts/game.gd").new()
 var factors=[0.0,-1.0,1.0,1.018,1.036,1.054,1.072,1.09,1.0000001,.7,1.5]
 for i in 1000:factors.append(1.0+(i%5+1)*.018+float(i)*.000173*.0005)
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
 for factor in factors:
  var canonical=game._card_surface_outline(factor)
  for k in canonical.size():canonical[k]=Vector2(0.0 if canonical[k].x==0.0 else canonical[k].x,0.0 if canonical[k].y==0.0 else canonical[k].y)
  hash.update(canonical.to_byte_array())
 # Captured from the pre-cache implementation, exact float32 vertex bytes (normalize equivalent signed zero).
 assert(hash.finish().hex_encode()=="9d08ba70600d821f0996ad6afc5f458b152e4215bd6e95dfac7642f3453902a7")
 var clean=game._card_surface_outline();var changed=game._card_surface_outline();changed[0]=Vector2(999,999)
 assert(game._card_surface_outline()==clean)
 var probe=DrawProbe.new();probe.game=game;root.add_child(probe)
 for i in 5:await process_frame
 assert(probe.done)
 print("DESKTOP_DRAW_CACHE_PASS 1011 exact outline factors, caller isolation, 130 dynamic styles, bounded cache and rect-independent reuse, static hand mesh geometry and exact-zero dynamic fallback")
 probe.queue_free();await process_frame;game.free();quit()