extends RefCounted
const Curves=preload("res://scripts/native_summon_curves.gd")
var routes:Dictionary={}
func _init():
 for row in JSON.parse_string(FileAccess.get_file_as_string("res://references/endgame_v33/shader_routes.json")):
  routes[str(row.source_key)]=row
func build(key:String,assets,texture_override:Texture2D=null)->Material:
 var record:Dictionary=assets.objects.get(key,{})
 var shader_key:String=str(record.get("refs",{}).get(".m_Shader",""))
 if not routes.has(shader_key):return null
 var route:Dictionary=routes[shader_key]
 var mat:=ShaderMaterial.new();mat.shader=load(route.godot_shader)
 assets._bind_render_order(mat,record)
 assets._apply_source_samplers(mat,record)
 var source_shader:Dictionary=assets.objects.get(shader_key,{})
 for property in source_shader.get("data",{}).get("m_ParsedForm",{}).get("m_PropInfo",{}).get("m_Props",[]):
  var n:String=str(property.m_Name);var kind:int=int(property.m_Type)
  if kind in [2,3]:mat.set_shader_parameter(n,float(property.get("m_DefValue[0]",0.0)))
  elif kind==0:mat.set_shader_parameter(n,Color(float(property.get("m_DefValue[0]",0.0)),float(property.get("m_DefValue[1]",0.0)),float(property.get("m_DefValue[2]",0.0)),float(property.get("m_DefValue[3]",0.0))))
  elif kind==1:mat.set_shader_parameter(n,Vector4(float(property.get("m_DefValue[0]",0.0)),float(property.get("m_DefValue[1]",0.0)),float(property.get("m_DefValue[2]",0.0)),float(property.get("m_DefValue[3]",0.0))))
 var source:Dictionary=record.get("data",{}).get("m_SavedProperties",{})
 var floats:Dictionary={};var colors:Dictionary={}
 for entry in source.get("m_Floats",[]):floats[entry[0]]=entry[1];mat.set_shader_parameter(entry[0],entry[1])
 for entry in source.get("m_Colors",[]):colors[entry[0]]=Curves.color(entry[1]);mat.set_shader_parameter(entry[0],colors[entry[0]])
 for i in range(source.get("m_TexEnvs",[]).size()):
  var entry=source.m_TexEnvs[i];var tex_key:String=str(record.refs.get(".m_SavedProperties.m_TexEnvs[%d][1].m_Texture"%i,""))
  var texture:Texture2D=assets.load_texture(tex_key)
  if entry[0]=="_MainTex" and texture_override!=null:texture=texture_override
  if texture!=null:mat.set_shader_parameter(entry[0],texture)
  var st:=Vector4(entry[1].m_Scale.x,entry[1].m_Scale.y,entry[1].m_Offset.x,1.0-float(entry[1].m_Scale.y)-float(entry[1].m_Offset.y))
  mat.set_shader_parameter(str(entry[0])+"_ST",st)
 mat.set_meta("source_colors",colors);mat.set_meta("source_floats",floats);mat.set_meta("source_key",key)
 mat.set_meta("source_shader_route",route);mat.set_meta("source_blend",route.source_blend)
 mat.set_meta("source_base_shader_path",route.godot_shader)
 if str(route.suffix)=="endgame_diffuse_transparent":mat.set_meta("compatibility","Original lit arithmetic recovered; source scene SH/main/additional light globals not recovered")
 return mat
