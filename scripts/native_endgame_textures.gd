extends RefCounted
## Original BC1/BC3 endpoints and mip levels, losslessly row/index flipped for
## the existing PNG/mesh-UV convention. No recompression or generated mipmaps.
var rows:Dictionary={}
var loaded:Dictionary={}
func load_source_texture(key:String,assets)->Texture2D:
 if loaded.has(key):return loaded[key]
 if rows.is_empty():
  var p:String=assets.base_path+"data/original_oriented_mips.json"
  if not FileAccess.file_exists(p):return null
  rows=JSON.parse_string(FileAccess.get_file_as_string(p))
 if not rows.has(key):return null
 var r:Dictionary=rows[key]
 var bytes=FileAccess.get_file_as_bytes(assets.base_path+str(r.file))
 assert(bytes.size()==int(r.bytes))
 var image:=Image.create_from_data(int(r.width),int(r.height),true,Image.FORMAT_DXT1 if int(r.format)==10 else Image.FORMAT_DXT5,bytes)
 assert(image!=null and not image.is_empty())
 var texture:=ImageTexture.create_from_image(image)
 texture.set_meta("original_texture_key",key)
 texture.set_meta("original_mip_count",int(r.mip_count))
 texture.set_meta("original_oriented_sha256",r.sha256)
 loaded[key]=texture
 return texture
func bind_source_sampler(material:Material,slot:String,texture:Texture2D,assets):
 if not material is ShaderMaterial or texture==null or not texture.has_meta("original_texture_key"):return
 var key:String=str(texture.get_meta("original_texture_key"))
 var data:Dictionary=assets.objects.get(key,{}).get("data",{})
 if data.is_empty():return
 var settings:Dictionary=data.m_TextureSettings
 var bindings:Dictionary=material.get_meta("source_sampler_bindings",{}).duplicate(true)
 bindings[slot]={"source_key":key,"filter":int(settings.m_FilterMode),"wrap_u":int(settings.m_WrapU),"wrap_v":int(settings.m_WrapV),"mip_count":int(data.m_MipCount),"bias":float(settings.m_MipBias)}
 var previous:Dictionary=material.get_meta("source_sampler_bindings",{}).get(slot,{})
 var comparable:Dictionary=bindings[slot].duplicate(true);comparable.erase("source_key")
 var prior:Dictionary=previous.duplicate(true);prior.erase("source_key")
 if prior==comparable:
  material.set_meta("source_sampler_bindings",bindings);material.set_shader_parameter(slot,texture);return
 if not material.has_meta("source_base_shader_path") and not material.shader.resource_path.is_empty():material.set_meta("source_base_shader_path",material.shader.resource_path)
 material.set_meta("source_sampler_bindings",bindings)
 # Preserve every current material override across the generated shader swap.
 var values:Dictionary={}
 var expression:=RegEx.new();expression.compile("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)")
 for found in expression.search_all(material.shader.code):values[found.get_string(1)]=material.get_shader_parameter(found.get_string(1))
 material.shader=assets.samplers.variant(material.shader,bindings)
 for n in values:material.set_shader_parameter(n,values[n])
 material.set_shader_parameter(slot,texture)
