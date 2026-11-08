extends "res://scripts/native_opening_highlight.gd"
## Original static hand selection assets, on the existing card's projected plane.
## This adapter does not replace the still-unported card movement/DragRotator.
const HAND_SHADER=preload("res://shaders/native_hand_highlight.gdshader")
var spatial_geometry:Dictionary={}
func setup(host):
 super.setup(host)
 source_materials=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/hand_highlight_materials.json"))
func state_for(card:Dictionary,index:int)->int:
 if not game.player_turn or game.busy or game.game_over or not game.flow.accepts_actions() or not game.pending_battlecry.is_empty():return 1
 if card.get("drawing",false) or card.get("returning",false):return 1
 var d:Dictionary=game.definitions[card.key]
 if int(d.cost)>game.mana:return 1
 if (d.kind=="minion" or card.key=="CS2_027") and game.allies.size()>=7:return 1
 if game.rules.needs_target(card.key):
  var valid=false
  for side in [0,1]:
   for target in game.rules._characters(side):
    if game.rules.legal_target(card.key,target,0):valid=true;break
  if not valid:return 1
 # Source flag is over playfield, not simply held. Existing gameplay region
 # supplies the bounded friendly-playfield adapter; no new play rules here.
 if index==game.drag_index:
  if d.kind=="spell" and not game.rules.needs_target(card.key) and game.has_method("_phone_hand_enabled") and game._phone_hand_enabled():
   # PositionHeldCard sets ordinary untargeted Card.m_overPlayfield on layer12.
   if preload("res://scripts/native_phone_spell_input.gd").over_playfield(game.source_projection,game.pointer,game.native_phone_hand.targeting_mode):return 8
  elif game._source_play_contains(game.pointer) if game.has_method("_source_play_contains") else game.PLAY_RECT.has_point(game.pointer):return 8
 return 7 if index==game.hover_card and game.is_pointer_hover_allowed() else 6
func sync_piece(piece:Dictionary,card:Dictionary,index:int,preview:bool):
 var state=1 if preview else state_for(card,index)
 if piece.has("source_highlight"):piece.source_highlight.visible=false
 if state==1:
  audit[str(index)]={"state":1,"material":"","backend":"source idle disables selection"}
  return
 var renderer=game.native_card_renderer
 var kind="minion_in_hand" if game.definitions[card.key].kind=="minion" else "spell_in_hand"
 var shape=card_geometry(renderer,kind)
 if shape.is_empty():return
 if not spatial_geometry.has(kind):
  var arrays=shape.mesh.surface_get_arrays(0)
  var verts=PackedVector3Array()
  for point in arrays[Mesh.ARRAY_VERTEX]:verts.append(Vector3(point.x/100.0,-point.y/100.0,0.033))
  arrays[Mesh.ARRAY_VERTEX]=verts
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  spatial_geometry[kind]=mesh
 if not piece.has("source_highlight"):
  var glow=MeshInstance3D.new();glow.name="OriginalHandSelection";piece.root.add_child(glow)
  var mat=ShaderMaterial.new();mat.shader=HAND_SHADER;glow.material_override=mat
  piece.source_highlight=glow;piece.highlight_seed=seed_rng.randf()
 var glow:MeshInstance3D=piece.source_highlight
 glow.mesh=spatial_geometry[kind]
 var record=evidence[kind].highlight_state_component
 var key=""
 for i in record.data.m_HighlightStates.size():
  if int(record.data.m_HighlightStates[i].m_StateType)==state:key=record.refs.get("/m_HighlightStates/%d/m_Material"%i,"");break
 if not source_materials.has(key):return
 var mask=record.refs.get("/m_StaticSilouetteTexture","")
 if not renderer.textures.has(mask):return
 var mat:ShaderMaterial=glow.material_override
 var uniforms={}
 for u in HAND_SHADER.get_shader_uniform_list():uniforms[u.name]=true
 var md=source_materials[key]
 for f in md.floats:
  if uniforms.has(f.name):mat.set_shader_parameter(f.name,float(f.value))
 for c in md.colors:
  if uniforms.has(c.name):mat.set_shader_parameter(c.name,renderer.col(c.value))
 for t in md.textures:
  if uniforms.has(t.name) and renderer.textures.has(t.key):mat.set_shader_parameter(t.name,renderer.textures[t.key])
 mat.set_shader_parameter("_MainTex",renderer.textures[mask]);mat.set_shader_parameter("_Seed",piece.highlight_seed)
 mat.set_shader_parameter("_ShaderTime",fmod(float(game.elapsed)/20.0,65535.0))
 glow.visible=true
 audit[str(index)]={"state":state,"material":key,"mask":mask,"mesh":shape.source_mesh,"backend":"original selection geometry and assets; Godot spatial shader adapter"}
