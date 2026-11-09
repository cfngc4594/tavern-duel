extends Node
## Actor spell type 7. Original prefab, material, layout and coroutine parameters.
## This is presentation only: it never changes rule health, targets, RNG or sound.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Assets=preload("res://scripts/native_combat_assets.gd")
const Curves=preload("res://scripts/native_summon_curves.gd")
const BASE="res://assets/original_damage_v32_1/"
var game: Node
var assets=Assets.new()
var entries: Dictionary={}
var dying: Dictionary={}
var history: Array=[]
var events: Array=[]
var serial:=0
var clock_seconds:=0.0
var death_timing: Dictionary={}
var glyph_bundle: Dictionary={}
var unavailable: Array=[]
var reflected_shaders: Dictionary={}
static var retain_glyph_shader:bool=true

func setup(owner_game: Node):
 game=owner_game;assets.setup(game.native_card_renderer,BASE)
 # Same source tuple domain as combat, extended by each original damage text.
 for order in game.native_combat.assets.source_sorting_orders:
  if not assets.source_sorting_orders.has(order):assets.source_sorting_orders.append(order)
 for queue in game.native_combat.assets.source_render_queues:
  if not assets.source_render_queues.has(queue):assets.source_render_queues.append(queue)
 # UberText increments BOTH renderer.sortingOrder and its shader material's
 # cached queue (DoApplyToMaterial 0x06000159). Read every original component:
 # minion10 gives3010; hero1 gives3001. Register both before creating materials.
 for record in assets.objects.values():
  if record.get("class_name","")!="UberText":continue
  var increment: int=int(record.data.m_RenderQueue)
  var text_queue: int=clampi(3000+increment,1,5000)
  if not assets.source_sorting_orders.has(increment):assets.source_sorting_orders.append(increment)
  if not assets.source_render_queues.has(text_queue):assets.source_render_queues.append(text_queue)
 assets.source_sorting_orders.sort();assets.source_render_queues.sort()
 if FileAccess.file_exists(BASE+"data/death_release_timing.json"):
  death_timing=JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/death_release_timing.json"))
 if FileAccess.file_exists(BASE+"glyph_sample/glyphs.json"):
  var source=JSON.parse_string(FileAccess.get_file_as_string(BASE+"glyph_sample/glyphs.json"))
  var glyphs: Dictionary={}
  for glyph in source.glyphs:
   if glyph.get("available",true):glyphs[glyph.character]=glyph
  glyph_bundle={"source":source,"glyphs":glyphs,"atlas":ImageTexture.create_from_image(preload("res://scripts/packed_png.gd").load_png(BASE+"glyph_sample/atlas_rgba.png"))}
 else:unavailable.append("Exact selected damage font glyph sample pending; no substitute atlas")

func identity(target: Dictionary) -> String:
 return "hero:"+str(target.side) if target.type=="hero" else "unit:"+str(target.unit.id)

func record(target: Dictionary,amount: int,before: int,after: int,source: Dictionary={}):
 serial+=1
 var event={"serial":serial,"target_id":identity(target),"target_type":str(target.type),"side":int(target.get("side",target.get("unit",{}).get("side",-1))),"unit_id":int(target.get("unit",{}).get("id",-1)),"card_id":str(target.get("unit",{}).get("key","")),"amount":amount,"hp_before":before,"hp_after":after,"source":source.duplicate(true),"rule_time":clock_seconds}
 events.append(event.duplicate(true));if events.size()>256:events.pop_front()
 if game.combat_replay.capturing:
  if not game.combat_replay.current.has("damage_splats"):game.combat_replay.current.damage_splats=[]
  game.combat_replay.current.damage_splats.append(event)
 else:present(event)

func present(event: Dictionary):
 var id: String=event.target_id
 if not entries.has(id):entries[id]={"target_id":id,"state":{},"spells_parent":null,"hero_proxy":null,"restart_count":0}
 var entry: Dictionary=entries[id]
 entry.event=event.duplicate(true);entry.age=0.0;entry.pending_yield=true;entry.active=true;entry.restart_count+=1
 entry.scale=0.0;entry.alpha=1.0;entry.text=("+" if int(event.amount)<0 else "-")+str(absi(int(event.amount)))
 entry.source_root=assets.manifest.root_labels.hero_damage_splat if event.target_type=="hero" else assets.manifest.root_labels.minion_damage_splat
 # UpdateElements+DoSplatAnims cancels/restarts this one Actor's instance.
 if not entry.state.is_empty():_update_elements(entry)

func retain_dead(unit: Dictionary):
 var id: int=int(unit.id)
 var pending={"unit":unit.duplicate(true),"start":clock_seconds,"kind":"minion"}
 pending.unit.death_pending=true
 if game.combat_replay.capturing:
  if not game.combat_replay.current.has("dying_actors"):game.combat_replay.current.dying_actors=[]
  game.combat_replay.current.dying_actors.append(pending)
 else:_retain_dead(pending)

func _retain_dead(record: Dictionary):
 var copy: Dictionary=record.duplicate(true);copy.start=clock_seconds
 dying[int(copy.unit.id)]=copy

func append_dying(boards: Array) -> Array:
 var result: Array=[boards[0].duplicate(),boards[1].duplicate()]
 for item in dying.values():
  var unit: Dictionary=item.unit
  if not result[int(unit.side)].any(func(u):return int(u.id)==int(unit.id)):result[int(unit.side)].append(unit)
 return result

func advance(delta: float):
 var dt:=maxf(delta,0.0);clock_seconds+=dt
 for entry in entries.values():
  if not bool(entry.get("active",false)) or bool(entry.get("pending_yield",false)):continue
  entry.age+=dt
  entry.scale=elastic_out(minf(float(entry.age),1.0))
  entry.alpha=1.0-clampf(float(entry.age)-2.0,0.0,1.0)
  if float(entry.age)>=3.100000023841858:entry.active=false
 for id in dying.keys():
  var item: Dictionary=dying[id]
  if death_timing.has(item.kind) and clock_seconds-float(item.start)>=float(death_timing[item.kind].release_seconds):dying.erase(id)

func sync():
 _sync_dying_actors()
 for id in entries.keys():
  var entry: Dictionary=entries[id]
  var target: Dictionary=entry.event
  if target.target_type=="unit" and not _unit_exists(int(target.unit_id),str(target.card_id)):
   _dispose_entry(id,"actor_destroyed");continue
  if entry.state.is_empty() and not game.headless:_bind(entry)
  if bool(entry.get("pending_yield",false)):
   # Original UniTask Yield(PlayerLoopTiming8) crosses to the next source loop
   # phase, then OnSpellFinished refreshes Actor stat text before scale-in.
   entry.pending_yield=false;entry.callback_time=clock_seconds
  if not entry.state.is_empty():
   var actor: Node3D=entry.state.root
   actor.scale=Vector3.ONE*float(entry.scale)
   actor.visible=bool(entry.active)
   for materials in entry.state.materials.values():
    for material in materials:assets.set_material_float(material,"_Color.a",float(entry.alpha))
   if is_instance_valid(entry.get("text_node")):
    entry.text_node.visible=bool(entry.active)
    var mat: ShaderMaterial=entry.text_node.get_surface_override_material(0)
    var tint: Color=mat.get_shader_parameter("text_tint");tint.a=float(entry.alpha);mat.set_shader_parameter("text_tint",tint)
   if is_instance_valid(entry.hero_proxy):
    var source_projection=SourceProjection.from_game(game)
    if source_projection!=null:
     var anchor=source_projection.resolve_anchor("hero:"+str(target.side))
     var valid=not anchor.is_empty() and anchor.has("rotation") and anchor.has("scale")
     entry.hero_proxy.visible=valid
     if valid:
      entry.hero_proxy.position=SourceProjection.source_to_render(anchor.position)
      entry.hero_proxy.get_child(0).basis=SourceProjection.REFLECTION*Basis(anchor.rotation)*Basis.from_scale(anchor.scale)
     else:source_projection.block("Hero damage proxy requires full verified source pose")
    else:entry.hero_proxy.position=game.spatial_scene.screen_to_world((game.PLAYER_HERO if int(target.side)==0 else game.ENEMY_HERO)+game.shake_offset)

func _unit_exists(id: int,card_id: String="") -> bool:
 for board in game._presentation_boards():
  for unit in board:
   if int(unit.id)==id:return card_id.is_empty() or str(unit.key)==card_id
 return false

func _bind(entry: Dictionary):
 var actor: Node3D
 if entry.event.target_type=="unit":
  var piece: Dictionary=game.spatial_scene.pieces.get(int(entry.event.unit_id),{})
  if piece.is_empty() or not piece.get("native_actor",false):return
  actor=piece.actor.root;entry.reflected_projection=piece.projection.basis.determinant()<0
 else:
  var proxy:=Node3D.new();proxy.name="DamageHeroCompatibilityAnchor";game.spatial_scene.add_child(proxy)
  var projection:=Node3D.new();proxy.add_child(projection)
  projection.basis=Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*(.78*.9)
  if SourceProjection.from_game(game)!=null:projection.basis=SourceProjection.REFLECTION
  actor=projection;entry.hero_proxy=proxy;entry.reflected_projection=projection.basis.determinant()<0
 var parent:=Node3D.new();parent.name="Spells";actor.add_child(parent);entry.spells_parent=parent
 entry.state=assets.instantiate(entry.source_root,parent)
 if entry.get("reflected_projection",false):
  for materials in entry.state.materials.values():
   for material in materials:_compensate_reflected_culling(material)
 var source_transform: Dictionary=assets.component(entry.source_root,"Transform").data
 entry.state.root.position=Curves.vec(source_transform.m_LocalPosition)
 _update_elements(entry)

func _update_elements(entry: Dictionary):
 var spell: Dictionary={}
 for object in assets.objects.values():
  if object.get("class_name","")=="DamageSplatSpell" and object.refs.get(".m_GameObject","")==entry.source_root:spell=object;break
 var state: Dictionary=entry.state
 for mesh in state.renderers.values():mesh.visible=false
 var chosen: String=spell.refs.get(".m_HealSplat","") if int(entry.event.amount)<0 else spell.refs.get(".m_StandardSplat","")
 if state.renderers.has(chosen):state.renderers[chosen].visible=true
 for materials in state.materials.values():
  for material in materials:assets.set_material_float(material,"_Color.a",1.0)
 var text_component: Dictionary=assets.objects[spell.refs[".m_DamageTextMesh"]]
 if is_instance_valid(entry.get("text_node")):
  var old: Node=entry.text_node;_retire_render_tree(old);old.get_parent().remove_child(old);old.queue_free()
 entry.text_node=null
 if not glyph_bundle.is_empty():entry.text_node=_make_text(state.nodes[text_component.refs[".m_GameObject"]],str(entry.text),text_component.data)
 state.root.scale=Vector3.ZERO;state.root.visible=true
 entry.chosen=chosen

func _make_text(parent: Node3D,text: String,spec: Dictionary) -> MeshInstance3D:
 var size: float=float(glyph_bundle.source.requestSize)
 var advance:=0.0
 for ch in text:
  if not glyph_bundle.glyphs.has(ch):unavailable.append("Missing damage glyph: "+ch);return null
  advance+=float(glyph_bundle.glyphs[ch].advance)
 # Native selected-font sample supplies single-line baseline and line height.
 var metrics: Dictionary=glyph_bundle.source.get("layout_metrics",{})
 if metrics.is_empty():unavailable.append("Damage sample lacks validated layout_metrics");return null
 var character_size: float=float(spec.m_CharacterSize)*.01
 var steps:=0
 while (advance*character_size*.1>float(spec.m_Width) or float(metrics.line_height)*character_size*.1>float(spec.m_Height)) and steps<40:
  character_size=maxf(.01,character_size*.95);steps+=1
 var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array();var cursor:=0.0
 for ch in text:
  var glyph: Dictionary=glyph_bundle.glyphs[ch];var start:=vertices.size()
  var points=[Vector2(glyph.minX,glyph.minY),Vector2(glyph.maxX,glyph.minY),Vector2(glyph.maxX,glyph.maxY),Vector2(glyph.minX,glyph.maxY)]
  var corners=[glyph.uvBottomLeft,glyph.uvBottomRight,glyph.uvTopRight,glyph.uvTopLeft]
  for i in range(4):
   vertices.append(Vector3(cursor+points[i].x-advance*.5,points[i].y+float(metrics.middle_center_baseline),0)*character_size*.1)
   uvs.append(Vector2(corners[i].x,1.0-corners[i].y))
  for i in [0,1,2,0,2,3]:indices.append(start+i)
  cursor+=float(glyph.advance)
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=_make_text_material(spec)
 var node:=MeshInstance3D.new();node.name="OriginalDamageGlyphs";node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.set_surface_override_material(0,material);parent.add_child(node);return node

func _make_text_material(spec: Dictionary) -> ShaderMaterial:
 var material:=ShaderMaterial.new();material.shader=preload("res://scripts/immutable_shader_cache.gd").load_shader("res://shaders/native_damage_text_outline.gdshader") if retain_glyph_shader else load("res://shaders/native_damage_text_outline.gdshader")
 material.set_shader_parameter("glyph_atlas",glyph_bundle.atlas);material.set_shader_parameter("atlas_texel",Vector2(1.0/glyph_bundle.source.atlasWidth,1.0/glyph_bundle.source.atlasHeight))
 material.set_shader_parameter("outline_texels",float(spec.m_OutlineSize));material.set_shader_parameter("text_mode",1 if spec.m_Outline else 0)
 material.set_shader_parameter("text_tint",Curves.color(spec.m_TextColor));material.set_shader_parameter("outline_color",Curves.color(spec.m_OutlineColor))
 var source_increment: int=int(spec.m_RenderQueue)
 material.set_meta("source_render_queue",clampi(3000+source_increment,1,5000));assets.apply_render_order(material,source_increment)
 return material

static func elastic_out(t: float) -> float:
 if t<=0.0:return 0.0
 if t>=1.0:return 1.0
 var period: float=0.30000001192092896
 return pow(2.0,-10.0*t)*sin((t-period*.25)*6.2831854820251465/period)+1.0

func _dispose_entry(id: String,reason: String):
 var entry: Dictionary=entries[id]
 history.append({"target_id":id,"event":entry.event,"reason":reason,"age":entry.get("age",0.0),"restart_count":entry.restart_count})
 if history.size()>128:history.pop_front()
 if is_instance_valid(entry.hero_proxy):_retire_render_tree(entry.hero_proxy);entry.hero_proxy.queue_free()
 elif is_instance_valid(entry.spells_parent):_retire_render_tree(entry.spells_parent);entry.spells_parent.queue_free()
 entries.erase(id)

func clear():
 for id in entries.keys():_dispose_entry(id,"new_match")
 dying.clear();events.clear();history.clear();serial=0;clock_seconds=0.0

func get_audit() -> Dictionary:
 var active=[]
 for entry in entries.values():
  active.append({"target_id":entry.target_id,"event":entry.event,"root":entry.source_root,"age":entry.age,"active":entry.active,"scale":entry.scale,"alpha":entry.alpha,"pending_yield":entry.pending_yield,"text":entry.text,"restart_count":entry.restart_count,"bound":not entry.state.is_empty(),"chosen":entry.get("chosen",""),"attachment_path":str(entry.spells_parent.get_path()) if is_instance_valid(entry.spells_parent) else "","splat_screen":_screen_position(entry),"cull_adapter":"source_back_to_backend_front" if entry.get("reflected_projection",false) else "none"})
 return {"active":active,"active_count":active.filter(func(e):return e.active).size(),"cached_count":entries.size(),"events":events.duplicate(true),"dying_ids":dying.keys(),"dying":dying.values().map(func(d):return {"unit_id":d.unit.id,"age":clock_seconds-float(d.start),"body_hidden":d.get("body_hidden",false)}),"history":history.duplicate(true),"unavailable":unavailable.duplicate(),"compatibility":[("Source phone camera; hero splat inherits verified source Card pose" if SourceProjection.from_game(game)!=null else "Fixed-board registration and 2D-hero proxy are not recovered original camera/hero Actor"),"Unity native glyph rasterization sample is identified separately","Original Death body-hide and Actor-release gates; native_death owns the source body material/animation/mesh particles","Death Birth origin is the historical simulator death-wave event, not reconstructed original server timing"]}

func _screen_position(entry: Dictionary) -> Array:
 if game.headless or entry.state.is_empty() or not is_instance_valid(entry.state.root):return []
 var projection=SourceProjection.from_game(game)
 var p: Vector2=projection.render_to_screen(entry.state.root.global_position) if projection!=null else game.spatial_scene.camera.unproject_position(entry.state.root.global_position)
 return [p.x,p.y]

func _retire_render_tree(root_node: Node):
 if root_node is Node3D:root_node.visible=false
 var pending: Array=[root_node]
 while not pending.is_empty():
  var node: Node=pending.pop_back()
  if node is GeometryInstance3D and is_instance_valid(game.native_transmission):
   var mirror=game.native_transmission.mirrors.get(node.get_instance_id())
   if is_instance_valid(mirror):mirror.visible=false
  pending.append_array(node.get_children())

func _sync_dying_actors():
 if game.headless or not death_timing.has("minion"):return
 for id in dying:
  var item: Dictionary=dying[id]
  var piece: Dictionary=game.spatial_scene.pieces.get(id,{})
  if piece.is_empty() or not piece.get("native_actor",false):continue
  var hide_body: bool=clock_seconds-float(item.start)>=float(death_timing.minion.hide_body_seconds)
  var body: Node3D=piece.actor.paths.get("RootObject")
  if is_instance_valid(body):body.visible=not hide_body
  if hide_body:
   for shield in piece.get("shield_nodes",[]):shield.visible=false
  item.body_hidden=hide_body

func _compensate_reflected_culling(material: Material):
 if not material is ShaderMaterial or material.shader==null:return
 var code: String=material.shader.code
 if not code.contains("cull_back"):return
 # The fixed source→board registration has negative determinant. Godot also
 # flips front faces for negative transforms. Undo that backend flip, retaining
 # the source's front-face selection; this is not a change to source CullBack.
 # GPU isolation: source back=0 pixels, front/disabled=the identical15249 pixels;
 # disabling depth changes neither result. Original vertices/indices stay intact.
 var values: Dictionary={}
 var declaration:=RegEx.new();declaration.compile("\\buniform\\s+(?:(?:lowp|mediump|highp)\\s+)?[A-Za-z_][A-Za-z_0-9]*\\s+([A-Za-z_][A-Za-z_0-9]*)")
 for found in declaration.search_all(code):
  var name: String=found.get_string(1);values[name]=material.get_shader_parameter(name)
 if not reflected_shaders.has(code):
  var shader:=Shader.new();shader.code=code.replace("cull_back","cull_front");reflected_shaders[code]=shader
 material.shader=reflected_shaders[code]
 # A shader swap may reset overrides. Restore each value, including textures/ST.
 for name in values:material.set_shader_parameter(name,values[name])
 material.set_meta("source_cull_mode","Back")
 material.set_meta("backend_winding_adapter","negative_projection_front_face_compensation")
