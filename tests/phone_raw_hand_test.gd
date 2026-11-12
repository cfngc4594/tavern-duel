extends SceneTree
class Flow:
 func accepts_actions():return true
class Rules:
 func needs_target(_key):return false
class Host extends Node:
 var native_card_renderer
 var definitions={"GAME_005":{"kind":"spell","cost":0,"name":"幸运币","desc":"在本回合中，获得一个法力水晶。","art":0,"atk":0,"hp":0}}
 var enemy_hand=["?","?","?","?","?","?","?","?","?","?"]
 var source_projection
 var cards=[]
 var elapsed=0.5
 var player_turn=true
 var busy=false
 var game_over=false
 var flow=Flow.new()
 var rules=Rules.new()
 var pending_battlecry={}
 var mana=10
 var allies=[]
 var drag_index=-1
 var hover_card=-1
 var pointer=Vector2(800,450)
 const PLAY_RECT=Rect2(200,300,1200,400)
 func is_pointer_hover_allowed():return true
func _initialize():call_deferred("run")
func run():
 assert(load("res://scripts/classic_spatial.gd").can_instantiate())
 var host=Host.new();root.add_child(host)
 host.native_card_renderer=load("res://scripts/native_card_renderer.gd").new();host.add_child(host.native_card_renderer)
 host.definitions.GAME_005=load("res://scripts/classic_flow_cards.gd").additional_definitions().GAME_005
 host.definitions.GAME_005.frame="frame-spell-neutral"
 host.native_card_renderer.build_card("GAME_005",host.definitions.GAME_005,load("res://assets/original_classic_v13/art/GAME_005.png"))
 host.definitions.CS2_182=load("res://scripts/classic_flow_cards.gd").additional_definitions().CS2_182
 host.native_card_renderer.build_card("CS2_182",host.definitions.CS2_182,load("res://assets/original_classic_v13/art/CS2_182.png"))
 var selector=load("res://scripts/native_hand_highlight.gd").new();host.add_child(selector);selector.setup(host)
 var hand=load("res://scripts/native_phone_hand.gd").new();hand.setup(host)
 for i in 10:host.cards.append({"key":"GAME_005" if i%2==0 else "CS2_182","source_phone_pose":hand.source_pose(i,10)})
 var pass3d=load("res://scripts/native_phone_hand_renderer.gd").new();host.add_child(pass3d);pass3d.setup(host,selector)
 var start=Time.get_ticks_usec();pass3d.sync();var clone_usec=Time.get_ticks_usec()-start
 assert(pass3d.pieces.size()==10 and pass3d.audit.cards==10)
 assert(pass3d.blockers.is_empty())
 var mesh_count:=0
 var vertex_count:=0
 for i in 10:
  var piece=pass3d.pieces[i];var pose=host.cards[i].source_phone_pose
  assert(piece.root.position.is_equal_approx(pose.position))
  assert(piece.root.global_position.is_equal_approx(Vector3(pose.position.x,pose.position.y,-pose.position.z)))
  assert(piece.actor.renderers.size()>1 and is_instance_valid(piece.highlight) and piece.highlight.visible)
  assert(piece.highlight.mesh.surface_get_array_len(0)>4)
  for node in piece.actor.renderers.values():
   mesh_count+=1
   for surface in node.mesh.get_surface_count():vertex_count+=node.mesh.surface_get_array_len(surface)
 assert(pass3d.audit.meshes==mesh_count and pass3d.audit.vertices==vertex_count)
 var roots=pass3d.pieces.map(func(p):return p.root.get_instance_id())
 start=Time.get_ticks_usec()
 for i in 100:pass3d.sync()
 var sync_usec=(Time.get_ticks_usec()-start)/100.0
 assert(roots==pass3d.pieces.map(func(p):return p.root.get_instance_id()))
 host.cards[0].erase("source_phone_pose");pass3d.sync();assert(not pass3d.pieces[0].root.visible and pass3d.blockers.size()==1)
 assert(pass3d.audit.cards==9 and pass3d.audit.meshes==mesh_count-pass3d.pieces[0].mesh_count and pass3d.audit.vertices==vertex_count-pass3d.pieces[0].vertex_count)
 var opposing=load("res://scripts/native_phone_opposing_hand.gd").new();host.add_child(opposing);opposing.setup(host);opposing.sync()
 assert(opposing.pieces.size()==10 and opposing.blockers.is_empty())
 for i in 10:
  assert(opposing.pieces[i].meshes.size()==2)
  assert(opposing.pieces[i].meshes[0].mesh.surface_get_array_len(0)==460)
  assert(opposing.pieces[i].root.position.is_equal_approx(opposing.source_pose(i,10).position))
 assert(is_equal_approx(opposing.source_pose(0,10).rotation.y,20.0))
 assert(is_equal_approx(opposing.source_pose(9,10).rotation.y,-20.0))
 assert(opposing.source_pose(0,3).rotation.y==0)
 var view=SubViewport.new();view.size=Vector2i(1600,900);root.add_child(view)
 var rig=Node3D.new();view.add_child(rig);var camera=Camera3D.new();rig.add_child(camera)
 load("res://scripts/source_board_camera_policy.gd").apply(camera,rig,Vector2(1600,900))
 host.source_projection=load("res://scripts/source_board_projection.gd").install(host,camera,Vector2(1600,900),Vector2(1600,900),Vector2.ZERO,{})
 for i in 10:
  var point=host.source_projection.source_to_screen(opposing.source_pose(i,10).position)
  assert(opposing.contains(point))
 assert(not opposing.contains(Vector2(-10000,-10000)))
 opposing.visible=false;assert(not opposing.contains(host.source_projection.source_to_screen(opposing.source_pose(0,10).position)))
 opposing.visible=true
 opposing.enqueue_draw(8,26,0);opposing.enqueue_draw(9,25,1);opposing.sync()
 assert(opposing.draws_pending() and opposing.pieces[8].root.visible and not opposing.pieces[9].root.visible)
 host.elapsed+=.875;opposing.sync()
 assert(not opposing.pieces[8].root.position.is_equal_approx(opposing.source_pose(8,10).position))
 host.elapsed+=.875;opposing.sync()
 assert(opposing.draw_queue.size()==1 and opposing.pieces[9].root.visible)
 host.elapsed+=1.75;opposing.sync();assert(not opposing.draws_pending())
 assert(opposing.pieces[9].root.position.is_equal_approx(opposing.source_pose(9,10).position))
 print("PHONE_OPPOSING_DRAW_QUEUE_PASS hidden queued card, original source bones, serialized flights, hand endpoint")
 print("PHONE_OPPOSING_HAND_PASS original Card_Hidden460 vertices, defaultback shader/texture, shadow, enemy span40, scale .682/.125/.682")
 print("PHONE_RAW_HAND_PASS ten original geometry/glyph clones; source TRS/Z reflection, raw highlight, cache reuse, missing-pose refusal. CPU clone_us=",clone_usec," sync_us=",sync_usec," inventory=",pass3d.audit)
 await root.get_node("SoundManager").shutdown_audio()
 load("res://scripts/source_board_projection.gd").unregister(host)
 host.free();view.free()
 await process_frame
 quit()
