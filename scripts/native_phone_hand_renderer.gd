extends Node3D
## Source hand geometry/glyph clones in raw Unity coordinates below one Z reflection.
## No face bake, screen flattening, 100px/unit conversion, or extra hand pose.
const Hand=preload("res://scripts/native_phone_hand.gd")
const HighlightShader=preload("res://shaders/native_hand_highlight.gdshader")
var game
var selector
var pieces:Array[Dictionary]=[]
var blockers:Array[String]=[]
var audit:Dictionary={}
var battlecry_preview:Dictionary={}
func setup(host,highlight_selector):
 game=host;selector=highlight_selector
 basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
func clear():
 for piece in pieces:
  if piece.has("root"):piece.root.queue_free()
 pieces.clear()
 if not battlecry_preview.is_empty():battlecry_preview.root.queue_free();battlecry_preview={}
func profile_path(profile:Dictionary,id:String)->NodePath:
 var parts:Array[String]=[]
 while id!="":
  var found=false
  for node in profile.nodes:
   if str(node.id)!=id:continue
   if str(node.parentId)!="":parts.push_front(str(node.name))
   id=str(node.parentId);found=true;break
  if not found:return NodePath("__missing_source_node__")
 return NodePath("/".join(parts)) if not parts.is_empty() else NodePath(".")
func make_piece(key:String,kind:String)->Dictionary:
 var renderer=game.native_card_renderer
 if not renderer.cards.has(key):return {}
 var actor:Dictionary=renderer.clone_world_hand(key)
 var card_root=Node3D.new();card_root.name="SourceCardContainer";add_child(card_root);card_root.add_child(actor.root)
 actor.root.transform=Transform3D.IDENTITY
 var root_object=actor.root.get_node_or_null("RootObject")
 if root_object!=null:root_object.transform=Transform3D.IDENTITY
 var piece={"root":card_root,"actor":actor,"key":key,"kind":kind,"highlight":null,"seed":selector.seed_rng.randf()}
 var profile:Dictionary=renderer.profiles[kind]
 for spec in profile.renderers:
  if not spec.get("readyHighlight",false):continue
  var parent=actor.root.get_node_or_null(profile_path(profile,str(spec.nodeId)))
  if parent==null:break
  var mesh:ArrayMesh=renderer._geometry(renderer.meshes[spec.meshKey])
  var arrays=mesh.surface_get_arrays(0)
  var colors=PackedColorArray()
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var red=arrays[Mesh.ARRAY_COLOR][i].r if arrays[Mesh.ARRAY_COLOR]!=null else 1.0
   var uvx=arrays[Mesh.ARRAY_TEX_UV2][i].x if arrays[Mesh.ARRAY_TEX_UV2]!=null else arrays[Mesh.ARRAY_TEX_UV][i].x
   colors.append(Color(red,uvx,0,1))
  arrays[Mesh.ARRAY_COLOR]=colors
  var original_mesh=ArrayMesh.new();original_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var glow=MeshInstance3D.new();glow.name="SourceStaticSelection";glow.mesh=original_mesh
  var material=ShaderMaterial.new();material.shader=HighlightShader;glow.material_override=material;parent.add_child(glow)
  piece.highlight=glow;piece.source_plane=spec.nodeId;piece.source_mesh=spec.meshKey;break
 return piece
func sync():
 # One reflection snapshot per synchronous hand update; never retained across frames.
 var highlight_uniforms:Dictionary={}
 blockers.clear();audit={"cards":0,"meshes":0,"vertices":0,"backend":"source geometry and glyphs; Godot material translations"}
 _sync_battlecry_preview()
 while pieces.size()>game.cards.size():
  var removed=pieces.pop_back()
  if removed.has("root"):removed.root.queue_free()
 for i in game.cards.size():
  var card:Dictionary=game.cards[i]
  var kind="minion_in_hand" if game.definitions[card.key].kind=="minion" else "spell_in_hand"
  while pieces.size()<=i:pieces.append({})
  if not pieces[i].is_empty() and pieces[i].key!=card.key:
   pieces[i].root.queue_free();pieces[i]={}
  var piece:Dictionary=pieces[i] if i<pieces.size() else {}
  if piece.is_empty():
   piece=make_piece(card.key,kind)
   if piece.is_empty():blockers.append("Source hand clone unavailable: "+str(card.key));continue
   if i<pieces.size():pieces[i]=piece
   else:pieces.append(piece)
  piece.root.visible=false
  var pose:Dictionary=card.get("source_phone_pose",{})
  if not pose.has("position") or not pose.has("rotation") or not pose.has("scale"):
   blockers.append("Source pose missing for hand slot %d"%i);continue
  var b=Hand.source_basis(pose.rotation)
  piece.root.transform=Transform3D(Basis(b.x*pose.scale.x,b.y*pose.scale.y,b.z*pose.scale.z),pose.position)
  var pending=not game.pending_battlecry.is_empty() and int(game.pending_battlecry.index)==i
  piece.root.visible=not card.get("source_phone_hidden",false) and not pending
  sync_highlight(piece,selector.state_for(card,i),highlight_uniforms)
  audit.cards+=1
  for mesh in piece.actor.renderers.values():
   audit.meshes+=1
   for surface in mesh.mesh.get_surface_count():audit.vertices+=mesh.mesh.surface_get_array_len(surface)
func _sync_battlecry_preview():
 var pending:Dictionary=game.pending_battlecry
 if pending.is_empty() or pending.has("unit"):
  if not battlecry_preview.is_empty():battlecry_preview.root.visible=false
  return
 var key:String=game.cards[int(pending.index)].key
 if not battlecry_preview.is_empty() and battlecry_preview.key!=key:
  battlecry_preview.root.queue_free();battlecry_preview={}
 if battlecry_preview.is_empty():
  var definition:Dictionary=game.definitions[key]
  var actor:Dictionary=game.native_card_renderer.build_world_minion(key,definition,game.raw_portraits[int(definition.art)])
  var container=Node3D.new();container.name="PendingBattlecryMinion";add_child(container);container.add_child(actor.root)
  actor.root.transform=Transform3D.IDENTITY
  var root_object=actor.root.get_node_or_null("RootObject")
  if root_object!=null:root_object.transform=Transform3D.IDENTITY
  battlecry_preview={"root":container,"actor":actor,"key":key}
 battlecry_preview.root.position=pending.source_world_position
 battlecry_preview.root.scale=pending.source_world_scale
 battlecry_preview.root.visible=true
func sync_highlight(piece:Dictionary,state:int,shared_uniforms:Variant=null):
 if not is_instance_valid(piece.highlight):return
 var glow:MeshInstance3D=piece.highlight;glow.visible=false
 if state==1:return
 var renderer=game.native_card_renderer
 var record=selector.evidence[piece.kind].highlight_state_component
 var key=""
 for i in record.data.m_HighlightStates.size():
  if int(record.data.m_HighlightStates[i].m_StateType)==state:key=record.refs.get("/m_HighlightStates/%d/m_Material"%i,"");break
 var mask=record.refs.get("/m_StaticSilouetteTexture","")
 if not selector.source_materials.has(key) or not renderer.textures.has(mask):return
 var material:ShaderMaterial=glow.material_override
 var uniforms:Dictionary={} if shared_uniforms==null else shared_uniforms
 if uniforms.is_empty():
  for uniform in HighlightShader.get_shader_uniform_list():uniforms[uniform.name]=true
 var source=selector.source_materials[key]
 for f in source.floats:
  if uniforms.has(f.name):material.set_shader_parameter(f.name,float(f.value))
 for c in source.colors:
  if uniforms.has(c.name):material.set_shader_parameter(c.name,renderer.col(c.value))
 for t in source.textures:
  if uniforms.has(t.name) and renderer.textures.has(t.key):material.set_shader_parameter(t.name,renderer.textures[t.key])
 material.set_shader_parameter("_MainTex",renderer.textures[mask]);material.set_shader_parameter("_Seed",piece.seed)
 material.set_shader_parameter("_ShaderTime",fmod(float(game.elapsed)/20.0,65535.0));glow.visible=true
