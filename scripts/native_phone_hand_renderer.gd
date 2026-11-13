extends Node3D
## Source hand geometry/glyph clones in raw Unity coordinates below one Z reflection.
## No face bake, screen flattening, 100px/unit conversion, or extra hand pose.
const Hand=preload("res://scripts/native_phone_hand.gd")
const HighlightShader=preload("res://shaders/native_hand_highlight.gdshader")
const Transmission=preload("res://scripts/native_combat_transmission.gd")
const HIGHLIGHT_CACHE_SETTING="render_quality/macos_hand_highlight_cache"
var game
var selector
var pieces:Array[Dictionary]=[]
var blockers:Array[String]=[]
var audit:Dictionary={}
var battlecry_preview:Dictionary={}
var highlight_cache_enabled:=false
var _highlight_meshes:Dictionary={}
func setup(host,highlight_selector):
 game=host;selector=highlight_selector
 basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
 var args:=OS.get_cmdline_user_args()
 highlight_cache_enabled=OS.has_feature("macos") and DisplayServer.get_name()!="headless" \
  and RenderingServer.get_current_rendering_method()=="gl_compatibility" \
  and not args.has("--mac-skip-hand-highlight-cache") \
  and (args.has("--mac-hand-highlight-cache") or bool(ProjectSettings.get_setting(HIGHLIGHT_CACHE_SETTING,false)))
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
 # The cloned hand geometry is fixed for the lifetime of this piece.
 var vertices:=0
 for renderer_node in actor.renderers.values():
  # Card cost changes replace the original viewport glyph, not these bindings.
  Transmission.register_fixed_source(renderer_node)
  var mesh:Mesh=renderer_node.mesh
  for surface in mesh.get_surface_count():vertices+=mesh.surface_get_array_len(surface)
 var piece={"root":card_root,"actor":actor,"key":key,"kind":kind,"highlight":null,"seed":selector.seed_rng.randf(),"mesh_count":actor.renderers.size(),"vertex_count":vertices}
 var profile:Dictionary=renderer.profiles[kind]
 for spec in profile.renderers:
  if not spec.get("readyHighlight",false):continue
  var parent=actor.root.get_node_or_null(profile_path(profile,str(spec.nodeId)))
  if parent==null:break
  var glow=MeshInstance3D.new();glow.name="SourceStaticSelection";glow.mesh=_highlight_mesh(renderer,spec.meshKey)
  var material=ShaderMaterial.new();material.shader=HighlightShader;glow.material_override=material;parent.add_child(glow)
  piece.highlight=glow;piece.source_plane=spec.nodeId;piece.source_mesh=spec.meshKey;break
 return piece

func _highlight_mesh(renderer: Node,key: String) -> ArrayMesh:
 if highlight_cache_enabled and _highlight_meshes.has(key):return _highlight_meshes[key]
 var mesh:ArrayMesh=renderer._geometry(renderer.meshes[key])
 var arrays:=mesh.surface_get_arrays(0)
 var colors:=PackedColorArray()
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var red=arrays[Mesh.ARRAY_COLOR][i].r if arrays[Mesh.ARRAY_COLOR]!=null else 1.0
  var uvx=arrays[Mesh.ARRAY_TEX_UV2][i].x if arrays[Mesh.ARRAY_TEX_UV2]!=null else arrays[Mesh.ARRAY_TEX_UV][i].x
  colors.append(Color(red,uvx,0,1))
 arrays[Mesh.ARRAY_COLOR]=colors
 var result:=ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 if highlight_cache_enabled:_highlight_meshes[key]=result
 return result
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
  var card_root:Node3D=piece.root
  var pose:Dictionary=card.get("source_phone_pose",{})
  if not pose.has("position") or not pose.has("rotation") or not pose.has("scale"):
   if card_root.visible:card_root.visible=false
   blockers.append("Source pose missing for hand slot %d"%i);continue
  var b=Hand.source_basis(pose.rotation)
  card_root.transform=Transform3D(Basis(b.x*pose.scale.x,b.y*pose.scale.y,b.z*pose.scale.z),pose.position)
  var pending=not game.pending_battlecry.is_empty() and int(game.pending_battlecry.index)==i
  var show_card:bool=not card.get("source_phone_hidden",false) and not pending
  if card_root.visible!=show_card:card_root.visible=show_card
  sync_highlight(piece,selector.state_for(card,i),highlight_uniforms)
  audit.cards+=1
  audit.meshes+=piece.mesh_count
  audit.vertices+=piece.vertex_count
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
 var glow:MeshInstance3D=piece.highlight
 if state==1:
  if glow.visible:glow.visible=false
  return
 var material:ShaderMaterial=glow.material_override
 var shader_time:=fmod(float(game.elapsed)/20.0,65535.0)
 # Each glow owns its material. The imported source selection presets and
 # texture bindings are fixed after loading, while shader time stays live.
 if highlight_cache_enabled and piece.get("bound_highlight_state",-1)==state:
  material.set_shader_parameter("_ShaderTime",shader_time)
  if not glow.visible:glow.visible=true
  return
 var renderer=game.native_card_renderer
 var record=selector.evidence[piece.kind].highlight_state_component
 var key=""
 for i in record.data.m_HighlightStates.size():
  if int(record.data.m_HighlightStates[i].m_StateType)==state:key=record.refs.get("/m_HighlightStates/%d/m_Material"%i,"");break
 var mask=record.refs.get("/m_StaticSilouetteTexture","")
 if not selector.source_materials.has(key) or not renderer.textures.has(mask):
  if glow.visible:glow.visible=false
  return
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
 material.set_shader_parameter("_ShaderTime",shader_time)
 if highlight_cache_enabled:piece.bound_highlight_state=state
 if not glow.visible:glow.visible=true
