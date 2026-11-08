extends RefCounted
## Source TargetDamageIndicator + CARD arrow text + localized FontDefinition.
## Uses the actual Unity GLEI40 glyph/UV/bounds sample with the already ported
## direct TextOutline shader. Does not infer damage numbers or rasterize fonts.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
var game: Node
var assets
var metadata: Dictionary={}
var spec: Dictionary={}
var root: Node3D
var projection: Node3D
var state: Dictionary={}
var renderer=preload("res://scripts/native_endgame_text.gd").new()
var current_text:=""
var audit: Dictionary={}

func setup(owner_game: Node,source_assets):
 game=owner_game;assets=source_assets
 for card in JSON.parse_string(FileAccess.get_file_as_string(assets.base_path+"data/target_arrow_card_text.json")).get("cards",[]):
  var localized=card.get("zhCN")
  metadata[str(card.card_id)]="" if localized==null else str(localized)
 spec=JSON.parse_string(FileAccess.get_file_as_string(assets.base_path+"data/target_damage_text_zhcn.json"))
 renderer.setup(assets)

func text_for(card_id: String,interaction: String,arrow_type: String) -> String:
 if arrow_type=="enemy" or interaction=="ATTACK_AIM":return ""
 return str(metadata.get(card_id,""))

func sync(active: Dictionary):
 current_text=text_for(str(active.get("card_id","")),str(active.get("interaction","")),str(active.get("type",""))) if not active.is_empty() else ""
 audit={"text":current_text,"visible":current_text!="","source":"CARD.m_targetArrowText→CardTextBuilder.GetTargetingArrowText→TargetDamageIndicator","font_source":spec.get("font_resolution",{}).get("localized_font",""),"font_size":spec.get("runtime",{}).get("font_size",0),"original_numeric_inference":false,"native_glyphs":true}
 if current_text=="":
  if is_instance_valid(root):root.visible=false
  return
 if game.headless:return
 if not is_instance_valid(root):_build()
 if not is_instance_valid(root):return
 root.visible=true
 var source: Vector3=active.rendered_endpoint+Vector3(0,0,0.75)
 var source_projection=SourceProjection.from_game(game)
 if source_projection!=null:root.position=SourceProjection.source_to_render(source)
 else:root.position=game.spatial_scene.screen_to_world(game.native_targeting._screen_point(source)+game.shake_offset)

func _build():
 root=Node3D.new();root.name="OriginalTargetDamageIndicator";game.spatial_scene.add_child(root)
 projection=Node3D.new();projection.basis=game.native_targeting._projection_basis();root.add_child(projection)
 state=assets.instantiate(assets.manifest.root_labels.damage_indicator,projection)
 state.root.scale=Vector3.ONE*2.5
 # Source prefab has the same +90X; mouse update changes position/scale only.
 for materials in state.materials.values():
  for material in materials:game.native_damage._compensate_reflected_culling(material)
 var source: Dictionary=spec.source_ubertext
 var parent: Node3D=state.nodes.get(str(source.refs.get(".m_GameObject","")))
 if not is_instance_valid(parent):return
 parent.visible=true
 var bang: Node3D=state.paths.get("TargetArrowBang")
 if is_instance_valid(bang):bang.visible=true
 var text_spec: Dictionary={"key":source.key,"role":"target_arrow_hint","runtime_textmesh_font_size":spec.runtime.font_size,"runtime_character_size_before_resize":spec.runtime.character_size,"original_serialized_ubertext":source.data,"resize_to_fit":spec.runtime.resize_to_fit}
 renderer._build_label(parent,text_spec,current_text)

func clear():
 current_text=""
 if is_instance_valid(root):root.visible=false
 audit.visible=false;audit.text=""

func get_audit() -> Dictionary:
 var result: Dictionary=audit.duplicate(true);result.renderer=renderer.get_audit()
 return result
