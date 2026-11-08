extends RefCounted
## Original localized GLEI00M_t_Outline, native Unity CharacterInfo/alpha atlas.
## Sampled in Unity 6000.3.10f1 on M3 Metal, not the original client runtime.
## RT0 branch uses TextOutline_Unlit directly. Serialized shadow is inactive:
## UberText.SetupShadow is called only by SetupRenderToTexture.
const Curves=preload("res://scripts/native_summon_curves.gd")
var assets
var specs: Dictionary={}
var bundles: Dictionary={}
var labels: Array=[]
var audit: Array=[]
var blockers: Array=[]
func setup(source_assets):
 assets=source_assets
 var path: String=assets.base_path+"data/result_text_zhcn.json"
 if FileAccess.file_exists(path):specs=JSON.parse_string(FileAccess.get_file_as_string(path))
 for size in [40,51]:
  var folder: String=assets.base_path+"unity_text/font%d/"%size
  if not FileAccess.file_exists(folder+"glyphs-bounds.json"):continue
  var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"glyphs-bounds.json"))
  var glyphs: Dictionary={}
  for glyph in data.glyphs:
   if glyph.available:glyphs[glyph.character]=glyph
  var atlas: Texture2D=load(folder+"atlas_rgba.png")
  bundles[size]={"data":data,"glyphs":glyphs,"atlas":atlas}
func build(state: Dictionary,screen: String,outcome: String):
 clear()
 for spec in specs.get("text_specs",[]):
  if spec.screen!=screen:continue
  var go: String=str(spec.transform_chain_leaf_to_root[0].game_object)
  var parent: Node3D=state.nodes.get(go)
  if parent==null:continue
  var text: String=str(spec.strings_zhCN[0])
  if spec.role=="banner" and outcome=="tie":text=str(spec.strings_zhCN[1])
  _build_label(parent,spec,text)
func _build_label(parent: Node3D,spec: Dictionary,text: String):
 var size: int=int(spec.runtime_textmesh_font_size)
 if not bundles.has(size):blockers.append("Missing Unity sampled font %d"%size);return
 var bundle: Dictionary=bundles[size];var glyphs: Dictionary=bundle.glyphs
 for ch in text:
  if not glyphs.has(ch):blockers.append("Missing original sampled glyph: "+ch);return
 var raw: Dictionary=spec.original_serialized_ubertext
 var character_size: float=spec.runtime_character_size_before_resize
 var source_bounds: Dictionary={}
 for measured in bundle.data.texts:
  if measured.text==text and absf(float(measured.characterSize)-character_size)<.000001:source_bounds=measured.localBounds;break
 var fit: float=1.0
 if spec.resize_to_fit and not source_bounds.is_empty():
  fit=minf(1.0,minf(float(raw.m_Width)/(float(source_bounds.m_Extent.x)*2.0),float(raw.m_Height)/(float(source_bounds.m_Extent.y)*2.0)))
 character_size*=fit
 var advance: float=0.0
 for ch in text:advance+=float(glyphs[ch].advance)
 # Original font's hhea: units1024/ascent900/descent-124/lineGap6.
 # TextMesh MiddleCenter anchor. CharacterInfo vertices and rotated UV corners
 # remain unmodified except source Unity-to-Godot V convention.
 var baseline: float=-float(size)*900.0/1024.0+float(size)*1030.0/1024.0*.5
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array();var cursor: float=0.0
 for ch in text:
  var glyph: Dictionary=glyphs[ch];var start: int=vertices.size()
  var points: Array=[Vector2(glyph.minX,glyph.minY),Vector2(glyph.maxX,glyph.minY),Vector2(glyph.maxX,glyph.maxY),Vector2(glyph.minX,glyph.maxY)]
  var corners: Array=[glyph.uvBottomLeft,glyph.uvBottomRight,glyph.uvTopRight,glyph.uvTopLeft]
  for i in range(4):
   vertices.append(Vector3(cursor+points[i].x-advance*.5,points[i].y+baseline,0)*character_size*.1)
   uv.append(Vector2(corners[i].x,1.0-float(corners[i].y)))
  for index in [0,1,2,0,2,3]:indices.append(start+index)
  cursor+=float(glyph.advance)
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=ShaderMaterial.new();material.shader=load("res://assets/native_cards/source_glyph_spatial.gdshader")
 material.set_shader_parameter("glyph_atlas",bundle.atlas)
 material.set_shader_parameter("atlas_texel",Vector2(1.0/float(bundle.data.atlasWidth),1.0/float(bundle.data.atlasHeight)))
 material.set_shader_parameter("text_mode",1 if raw.m_Outline else 0)
 material.set_shader_parameter("outline_texels",float(raw.m_OutlineSize))
 material.set_shader_parameter("outline_color",Curves.color(raw.m_OutlineColor))
 material.set_shader_parameter("text_tint",Curves.color(raw.m_TextColor))
 # Original UberText render queue is a relative offset in transparent text.
 material.set_meta("source_render_queue",3000+int(raw.m_RenderQueue))
 assets.apply_render_order(material,int(raw.m_RenderQueue))
 mesh.surface_set_material(0,material)
 var node:=MeshInstance3D.new();node.name="OriginalZhCN_"+str(spec.role);node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
 labels.append({"node":node,"parent":parent,"role":spec.role,"material":material,"color":Curves.color(raw.m_TextColor)})
 audit.append({"text":text,"role":spec.role,"source":spec.key,"font_size":size,"character_size":character_size,"resize_factor":fit,"original_bounds":source_bounds,"glyphs":text.length(),"shadow_active":false,"shadow_inactive_reason":"Source RT0 skips SetupShadow","render_queue_offset":raw.m_RenderQueue,"renderer":"Original direct outlined TextMesh with sampled Unity glyph atlas","sample_runtime":bundle.data.unityVersion+" "+bundle.data.graphicsBackend+" "+bundle.data.graphicsDevice})
func set_banner_alpha(alpha: float):
 for label in labels:
  if label.role=="banner":
   var color: Color=label.color;color.a=alpha;label.material.set_shader_parameter("text_tint",color)
func set_continue_visible(value: bool):
 for label in labels:
  if label.role=="continue":label.parent.visible=value
func clear():
 for label in labels:
  if is_instance_valid(label.node):label.node.queue_free()
 labels.clear();audit.clear();blockers.clear()
func get_audit() -> Dictionary:
 return {"labels":audit.duplicate(true),"blockers":blockers.duplicate(),"godot_font_rasterization":false,"invented_glyphs":false}
