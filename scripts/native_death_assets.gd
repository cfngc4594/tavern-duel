extends "res://scripts/native_state_assets.gd"
## Exact death shader routing is added independently of the v31-v34 shaders.
var portrait_by_card: Dictionary={}
var death_materials
func setup(card_renderer: Node=null,source_base: String="res://assets/original_death_v35/") -> void:
 super.setup(card_renderer,source_base)
 var bindings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://references/death_v35/card_pool_bindings.json")).cards
 for card_id in bindings:
  var binding: Dictionary=bindings[card_id]
  if binding.has("portrait_texture_key"):portrait_by_card[card_id]=binding.portrait_texture_key
 if ResourceLoader.exists("res://scripts/native_death_materials.gd"):death_materials=load("res://scripts/native_death_materials.gd").new()

func material(key: String,texture_override: Texture2D=null) -> Material:
 var result: Material
 if death_materials!=null:result=death_materials.build(key,self,texture_override)
 if result==null:result=super.material(key,texture_override)
 return result

func set_material_float(mat: Material,attribute: String,value: float) -> void:
 # Existing Actor gems use the v30 verified combined shader. Source clips still
 # name _tint/_Fade, so update its equivalent uniforms rather than unused names.
 if mat is ShaderMaterial and mat.has_meta("original_shader_id"):
  var bits:=attribute.split(".")
  var vector_name: String={"_tint":"scroll_tint","_Fade":"fade_rgb"}.get(bits[0],"")
  if vector_name!="" and bits.size()==2 and bits[1] in ["r","g","b"]:
   var color: Vector3=mat.get_shader_parameter(vector_name)
   color[["r","g","b"].find(bits[1])]=value;mat.set_shader_parameter(vector_name,color);return
 super.set_material_float(mat,attribute,value)

func load_texture(key: String) -> Texture2D:
 if texture_cache.has(key):return texture_cache[key]
 var record: Dictionary=objects.get(key,{})
 if record.get("files",{}).has("rgba8_mips"):
  var raw:=FileAccess.get_file_as_bytes(base_path+str(record.files.rgba8_mips))
  var image:=Image.create_from_data(int(record.data.m_Width),int(record.data.m_Height),true,Image.FORMAT_RGBA8,raw)
  var texture:=ImageTexture.create_from_image(image)
  texture.set_meta("original_texture_key",key);texture.set_meta("original_mip_count",int(record.data.m_MipCount))
  texture_cache[key]=texture;return texture
 var texture: Texture2D=super.load_texture(key)
 if texture!=null:texture.set_meta("original_texture_key",key)
 return texture
