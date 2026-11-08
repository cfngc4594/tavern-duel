extends RefCounted
## Exact source identities + original numeric bindings. No StandardMaterial fallback.
const DIR="res://assets/native_coin/"
const SHADERS={
	"2114911788129993780":"native_coin_reflection",
	"-230275896195282385":"native_summon_hidden_glow",
	"240134070624251049":"native_coin_additive",
	"4625158185646996402":"native_coin_fresnel",
	"-3072726488366958506":"native_coin_dissolve",
	"-2418971604062054018":"native_combat_endgame_scrolling_manual",
	"-666151408197827071":"native_summon_scroll"
}
var records:Dictionary={}
var textures:Dictionary={}
var missing:Array=[]
func setup():records=JSON.parse_string(FileAccess.get_file_as_string(DIR+"materials.json"))
func build(material_name:String) -> ShaderMaterial:
	if records.is_empty():setup()
	if not records.has(material_name):missing.append(material_name);return null
	var record:Dictionary=records[material_name]
	if not SHADERS.has(record.shader_id):missing.append(record.shader_id);return null
	var material=ShaderMaterial.new();material.shader=load("res://shaders/"+SHADERS[record.shader_id]+".gdshader")
	for name in record.floats:material.set_shader_parameter(name,record.floats[name])
	for name in record.colors:
		var c:Dictionary=record.colors[name];material.set_shader_parameter(name,Color(c.r,c.g,c.b,c.a))
	for name in record.textures:
		var binding:Dictionary=record.textures[name];var texture:Texture2D
		if binding.file!="":
			if not textures.has(binding.file):textures[binding.file]=ImageTexture.create_from_image(preload("res://scripts/packed_png.gd").load_png(DIR+binding.file))
			texture=textures[binding.file]
		elif name=="_EdgeDetailTex" and binding.path_id=="0":
			# Original ShaderLab property defaults to white, explicit source default.
			if not textures.has("source_default_white"):
				var white=Image.create(1,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE);textures.source_default_white=ImageTexture.create_from_image(white)
			texture=textures.source_default_white
		else:missing.append(material_name+":"+name);return null
		material.set_shader_parameter(name,texture)
		var s:Dictionary=binding.scale;var o:Dictionary=binding.offset
		# Both decoded PNG UVs and original source ST are conjugated by Y flip.
		var offset_y:float=float(o.y) if record.shader_id=="2114911788129993780" else 1.0-float(s.y)-float(o.y)
		material.set_shader_parameter(name+"_ST",Vector4(s.x,s.y,o.x,offset_y))
	material.set_meta("source_shader_id",record.shader_id)
	material.set_meta("original_material",material_name)
	material.set_meta("source_floats",record.floats.duplicate(true))
	material.set_meta("source_colors",record.colors.duplicate(true))
	material.set_meta("native_shader_translation",true)
	material.set_meta("runtime_parity_verified",false)
	return material

# Original-particle solver adapter, material keys are native names.
func material(key:String) -> Material:return build(key)
