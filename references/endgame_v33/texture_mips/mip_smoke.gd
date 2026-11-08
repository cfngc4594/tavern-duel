extends SceneTree
func _initialize():call_deferred("run")
func run():
 var assets=load("res://scripts/native_endgame_assets.gd").new();assets.setup()
 var helper=load("res://scripts/native_endgame_textures.gd").new()
 var rows=JSON.parse_string(FileAccess.get_file_as_string("res://assets/original_endgame_v33/data/original_oriented_mips.json"))
 var n=0
 for k in rows:
  var texture:Texture2D=helper.load_source_texture(k,assets);assert(texture!=null)
  var image:Image=texture.get_image();assert(image.has_mipmaps());assert(image.get_mipmap_count()+1==int(rows[k].mip_count))
  assert(image.get_data().size()==int(rows[k].bytes))
  var material:=ShaderMaterial.new();material.shader=load("res://shaders/native_combat_endgame_self_illumin.gdshader")
  helper.bind_source_sampler(material,"_MainTex",texture,assets)
  var code:String=material.shader.code
  if int(assets.objects[k].data.m_TextureSettings.m_FilterMode)==2:
   assert(code.contains("filter_linear_mipmap"))
   if float(assets.objects[k].data.m_TextureSettings.m_MipBias)!=0:assert(code.contains("_source_trilinear_MainTex"))
  helper.bind_source_sampler(material,"_MainTex",texture,assets);assert(material.shader.code==code)
  material.shader.get_shader_uniform_list();n+=1
 print("ORIGINAL_MIP_SMOKE ",n," passed")
 helper=null;assets=null;quit()
