extends "res://scripts/native_endgame_assets.gd"
## Status/target assets retain original object keys; common material/particle
## implementation is shared with combat, not replacement status illustrations.
func setup(card_renderer: Node=null,source_base: String="res://assets/original_status_v34/") -> void:
 super.setup(card_renderer,source_base)
 var path: String=source_base+"data/mesh_color_channels.json"
 if FileAccess.file_exists(path):
  var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  mesh_color_channels.merge(data.get("meshes",data),true)

func material(key: String,texture_override: Texture2D=null) -> Material:
 var source: Dictionary=objects.get(key,{})
 var shader_id: String=str(source.get("refs",{}).get(".m_Shader","")).get_slice(":",1)
 var paths: Dictionary={"143677912420122213":"native_status_unlit_texture","-34040995226017085":"native_status_card_unlit_tint","-1939901832466623549":"native_status_hero_unlit_transparent"}
 if not paths.has(shader_id):
  var translated: Material=super.material(key,texture_override)
  if translated is ShaderMaterial and not translated.has_meta("source_base_shader_path"):translated.set_meta("source_base_shader_path",translated.shader.resource_path)
  return translated
 var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/"+str(paths[shader_id])+".gdshader")
 _bind_render_order(mat,source);_apply_source_samplers(mat,source)
 var props: Dictionary=source.data.get("m_SavedProperties",{})
 var colors: Dictionary={};var floats: Dictionary={}
 for entry in props.get("m_Floats",[]):floats[entry[0]]=entry[1];mat.set_shader_parameter(entry[0],entry[1])
 for entry in props.get("m_Colors",[]):colors[entry[0]]=Curves.color(entry[1]);mat.set_shader_parameter(entry[0],colors[entry[0]])
 for i in range(props.get("m_TexEnvs",[]).size()):
  var entry: Array=props.m_TexEnvs[i]
  var texture: Texture2D=texture_override if texture_override!=null and entry[0]=="_MainTex" else load_texture(str(source.refs.get(".m_SavedProperties.m_TexEnvs[%d][1].m_Texture"%i,"")))
  if texture!=null:mat.set_shader_parameter(entry[0],texture)
  mat.set_shader_parameter(str(entry[0])+"_ST",Vector4(entry[1].m_Scale.x,entry[1].m_Scale.y,entry[1].m_Offset.x,1.0-float(entry[1].m_Scale.y)-float(entry[1].m_Offset.y)))
 mat.set_meta("source_key",key);mat.set_meta("source_shader_key",source.refs.get(".m_Shader",""));mat.set_meta("source_colors",colors);mat.set_meta("source_floats",floats)
 mat.set_meta("source_base_shader_path","res://shaders/"+str(paths[shader_id])+".gdshader")
 mat.set_meta("source_blend","SrcAlpha OneMinusSrcAlpha" if shader_id=="-1939901832466623549" else "One Zero")
 mat.set_meta("compatibility","Original DXBC equations and render state; fixed-board ambient/light, GL color bridge and alpha capture are compatibility")
 return mat

func instantiate(prefab_key: String,parent: Node3D,allowed_renderers: Array=[]) -> Dictionary:
 var state: Dictionary=super.instantiate(prefab_key,parent,allowed_renderers)
 # Actor.LoadSpell→AttachAndPreserveLocalTransform. These original state
 # prefabs have no SetSource call; taunt's location2 fallback returns null
 # and therefore does NOT erase its authored(-.483978,.095947,0) offset.
 # Do not alter arrow/editor placement or any v31/v32/v33 instantiate path.
 if base_path=="res://assets/original_status_v34/" and not state.is_empty():
  var transform: Dictionary=component(prefab_key,"Transform")
  state.root.position=Curves.vec(transform.get("data",{}).get("m_LocalPosition",{}))
  state.root.set_meta("source_root_position_preserved",true)
 return state
