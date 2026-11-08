extends 'res://scripts/native_combat_assets.gd'
## Exact rope material dispatch. Missing port is fatal, never fallback paint.
var rope_shaders:Dictionary={}
func setup(card_renderer:Node=null,source_base:String=BASE)->void:
 super.setup(card_renderer,source_base)
 # Original TurnTimerSpiral_Mesh channel3 format2 = UNorm8, dimension4.
 mesh_color_channels['cab-66e7137de3b79380e05eb711ae004556:1059280820689413847']={'normalization_divisor':255.0}

func material(key:String,texture_override:Texture2D=null)->Material:
 var r:Dictionary=objects.get(key,{})
 var shader_id:String=str(r.get('refs',{}).get('.m_Shader','')).get_slice(':',1)
 if shader_id not in ['3043880362771032956','5920048614804823613']:return super.material(key,texture_override)
 var path:String='res://shaders/native_rope_mask.gdshader' if shader_id=='3043880362771032956' else 'res://shaders/native_rope_spiral.gdshader'
 if not ResourceLoader.exists(path):push_error('Original rope shader recovery not installed: '+path);return null
 var mat:=ShaderMaterial.new();mat.shader=load(path);_bind_render_order(mat,r)
 var p:Dictionary=r.data.m_SavedProperties
 for value in p.get('m_Floats',[]):mat.set_shader_parameter(str(value[0]),value[1])
 for value in p.get('m_Colors',[]):mat.set_shader_parameter(str(value[0]),Curves.color(value[1]))
 for i in range(p.get('m_TexEnvs',[]).size()):
  var pair:Array=p.m_TexEnvs[i];var v:Dictionary=pair[1];var tex_key:String=r.refs.get('.m_SavedProperties.m_TexEnvs[%d][1].m_Texture'%i,'')
  var texture=load_texture(tex_key)
  if texture!=null:mat.set_shader_parameter(str(pair[0]),texture)
  mat.set_shader_parameter(str(pair[0])+'_ST',Vector4(v.m_Scale.x,v.m_Scale.y,v.m_Offset.x,v.m_Offset.y))
 mat.set_meta('source_key',key);return mat
