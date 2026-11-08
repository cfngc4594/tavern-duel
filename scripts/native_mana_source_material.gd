extends RefCounted
## Exact two source shader identities, with explicit existing backend/light compatibility.
static func build(md:Dictionary,main_texture:Texture2D,card_renderer:Node)->Material:
 var id:String=str(md.sourceShaderKey).get_slice(":",1)
 if id=="-870869104636564592":return card_renderer._power_source_surface_material(md,main_texture)
 if id!="143677912420122213":return null
 var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/native_mana_unlit_texture.gdshader")
 mat.set_shader_parameter("_MainTex",main_texture)
 for item in md.floats:mat.set_shader_parameter(item.name,item.value)
 for item in md.textures:
  if item.name=="_MainTex":mat.set_shader_parameter("_MainTex_ST",Vector4(item.scale.x,item.scale.y,item.offset.x,1.0-item.scale.y-item.offset.y))
 mat.set_meta("source_key",md.key);mat.set_meta("source_shader",md.sourceShaderKey)
 mat.set_meta("lighting_compatibility","Original shader arithmetic; Unity scene light globals unresolved")
 return mat
