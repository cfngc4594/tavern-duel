extends SceneTree
class Flow:
 func accepts_actions():return true
class Rules:
 func needs_target(_key):return false
class Host extends Node:
 var native_card_renderer
 var definitions={"YETI":{"kind":"minion","cost":4},"FIREBALL":{"kind":"spell","cost":4}}
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
 var host=Host.new();root.add_child(host)
 var renderer=load("res://scripts/native_card_renderer.gd").new()
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/OriginalCards/card_assets.json"))
 for p in data.profiles:renderer.profiles[p.name]=p
 for m in data.meshes:
  if str(m.key).ends_with(":-7756402925575413283"):renderer.meshes[m.key]=m
 for t in data.textures:
  if str(t.key).ends_with(":-3103092934676384505") or str(t.key).ends_with(":-6423977007338542110") or str(t.key).ends_with(":575926003976946273"):renderer.textures[t.key]=load("res://assets/native_cards/"+t.resource+".png")
 host.native_card_renderer=renderer
 var glow=load("res://scripts/native_hand_highlight.gd").new();host.add_child(glow);glow.setup(host)
 var piece={"root":Node3D.new()};host.add_child(piece.root)
 for key in ["YETI","FIREBALL"]:
  var card={"key":key}
  host.hover_card=-1;host.drag_index=-1
  assert(glow.state_for(card,0)==6)
  glow.sync_piece(piece,card,0,false);assert(piece.source_highlight.visible)
  assert(glow.audit["0"].state==6)
  assert(piece.source_highlight.material_override.get_shader_parameter("_FlareTex")!=null)
  host.hover_card=0;assert(glow.state_for(card,0)==7)
  host.drag_index=0;host.pointer=Vector2(800,450);assert(glow.state_for(card,0)==8)
  glow.sync_piece(piece,card,0,false);assert(glow.audit["0"].material.ends_with(":4797490737768935072"))
  host.pointer=Vector2(800,850);host.hover_card=-1;assert(glow.state_for(card,0)==6)
  host.mana=0;glow.sync_piece(piece,card,0,false);assert(not piece.source_highlight.visible);host.mana=10
  glow.sync_piece(piece,card,0,true);assert(not piece.source_highlight.visible)
 print("HAND_HIGHLIGHT_PASS: source minion/spell mesh masks, material states6/7/8/idle, flare, insufficient mana, preview suppression")
 var second={"root":Node3D.new()};host.add_child(second.root)
 host.hover_card=-1;host.drag_index=-1
 glow.sync_piece(piece,{"key":"YETI"},0,false);glow.sync_piece(second,{"key":"YETI"},1,false)
 assert(piece.source_highlight!=second.source_highlight)
 assert(piece.source_highlight.material_override!=second.source_highlight.material_override)
 var first_mesh=piece.source_highlight.mesh
 var first_mask=piece.source_highlight.material_override.get_shader_parameter("_MainTex")
 glow.sync_piece(second,{"key":"FIREBALL"},1,false)
 assert(piece.source_highlight.mesh==first_mesh)
 assert(piece.source_highlight.material_override.get_shader_parameter("_MainTex")==first_mask)
 assert(second.source_highlight.mesh!=first_mesh)
 var view=SubViewport.new();view.size=Vector2i(2560,1440);view.own_world_3d=true;root.add_child(view)
 var camera=Camera3D.new();view.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=9.0;camera.position=Vector3(0,0,30);camera.current=true
 piece.root.reparent(view);second.root.reparent(view)
 var face_mesh=ArrayMesh.new()
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.82,1.21,.034),Vector3(.82,1.21,.034),Vector3(.82,-1.21,.034),Vector3(-.82,-1.21,.034)])
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
 face_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var face_vertices=face_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var max_error=0.0
 for pair in [[piece,"minion_in_hand"],[second,"spell_in_hand"]]:
  var item=pair[0];var kind=pair[1]
  var source_points=glow.card_geometry(renderer,kind).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var vertices=item.source_highlight.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var face=MeshInstance3D.new();face.mesh=face_mesh;item.root.add_child(face)
  for rotation in [Vector3.ZERO,Vector3(deg_to_rad(7.5),deg_to_rad(-4),-0.25)]:
   item.root.position=Vector3(-2.1,-1.9,1.8);item.root.rotation=rotation;item.root.scale=Vector3(1.28,1.17,1.2)
   await process_frame
   for i in vertices.size():
    var uv=source_points[i]/Vector2(164,242)+Vector2(0.5,0.5)
    var on_face=face_vertices[0]+(face_vertices[1]-face_vertices[0])*uv.x+(face_vertices[3]-face_vertices[0])*uv.y
    var expected=camera.unproject_position(face.global_transform*on_face)
    var actual=camera.unproject_position(item.source_highlight.global_transform*vertices[i])
    max_error=maxf(max_error,expected.distance_to(actual))
    assert(vertices[i].z<face_vertices[0].z)
 assert(max_error<0.04)
 print("HAND_SAME_PARENT_PROJECTION_PASS max_error_pixels=",max_error,"; duplicate and mixed card instances isolated")
 var shader_source=FileAccess.get_file_as_string("res://shaders/native_hand_highlight.gdshader")
 assert(shader_source.contains("ALBEDO=source_backend_inverse(result.rgb)"))
 assert(shader_source.contains("uniform sampler2D _MainTex : source_color"))
 assert(shader_source.contains("uniform sampler2D _FlareTex : source_color"))
 renderer.free();view.queue_free();host.queue_free();quit()
