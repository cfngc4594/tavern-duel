extends RefCounted
## Source texture-import sampler state. Shader formulas are unchanged.
## Current scope: seven clamp textures and the sole original seven-mip texture.
# Immutable generated GLSL is shared across helpers. Materials/uniforms remain per instance.
static var shared_shaders: Dictionary={}
static var created_variants:=0
static var reused_variants:=0
var cache: Dictionary={}
func variant(shader: Shader,bindings: Dictionary) -> Shader:
	if shader==null or bindings.is_empty():return shader
	var signature: String=shader.code+JSON.stringify(bindings)
	if cache.has(signature):return cache[signature]
	var code: String=shader.code
	var helpers: String=""
	for property in bindings:
		var spec: Dictionary=bindings[property]
		var declaration:=RegEx.new();declaration.compile("uniform\\s+sampler2D\\s+"+str(property)+"\\s*:[^;]*;")
		var found=declaration.search(code)
		if found==null:continue # A stale serialized material slot is not a shader binding.
		var before: String=found.get_string()
		var hints: String=before.get_slice(":",1).trim_suffix(";").strip_edges()
		var filter: int=int(spec.get("filter",1));var mips: int=int(spec.get("mip_count",1))
		var filter_hint: String="filter_nearest" if filter==0 else "filter_linear"
		if mips>1:filter_hint+="_mipmap"
		var wrap: String="repeat_disable" if int(spec.get("wrap_u",0))==1 else "repeat_enable"
		var parts: Array[String]=[]
		for hint in hints.split(","):
			var item: String=hint.strip_edges()
			if not item.begins_with("filter_") and not item.begins_with("repeat_"):parts.append(item)
		parts.append(filter_hint);parts.append(wrap)
		code=code.replace(before,"uniform sampler2D "+str(property)+" : "+", ".join(parts)+";")
		if mips>1 and filter==1:
			# Unity Bilinear uses a nearest mip level with bilinear texels. Godot's
			# linear_mipmap hint is trilinear. Compatibility has no textureQueryLod,
			# so derive the isotropic footprint from fragment derivatives and select
			# an integer level. Driver LOD tie/footprint rounding remains a declared
			# compatibility boundary. No mip pixels are regenerated.
			var sample:=RegEx.new();sample.compile("texture\\s*\\(\\s*"+str(property)+"\\s*,")
			var name: String="_source_sample"+str(property)
			code=sample.sub(code,name+"(",true)
			helpers+="vec4 "+name+"(vec2 source_uv) { vec2 size=vec2(textureSize("+str(property)+",0)); vec2 dx=dFdx(source_uv)*size; vec2 dy=dFdy(source_uv)*size; float level=clamp(floor(0.5*log2(max(max(dot(dx,dx),dot(dy,dy)),0.000000000001))+"+str(float(spec.get("bias",0.0)))+"+0.5),0.0,"+str(float(mips-1))+"); return textureLod("+str(property)+",source_uv,level); }\n"
		elif mips>1 and filter==2 and not is_zero_approx(float(spec.get("bias",0.0))):
			# Original Trilinear sampler bias is a texture import property. Keep it
			# distinct from the original shader's global sample bias (zero here).
			var sample:=RegEx.new();sample.compile("texture\\s*\\(\\s*"+str(property)+"\\s*,")
			var name:String="_source_trilinear"+str(property)
			code=sample.sub(code,name+"(",true)
			helpers+="vec4 "+name+"(vec2 source_uv) { return texture("+str(property)+",source_uv,"+str(float(spec.get("bias",0.0)))+"); }\n"
	if helpers!="":
		var at: int=code.find("void vertex()")
		if at<0:at=code.find("void fragment()")
		code=code.insert(at,helpers)
	if code==shader.code:cache[signature]=shader;return shader
	var result: Shader
	if shared_shaders.has(code):result=shared_shaders[code].get_ref()
	if is_instance_valid(result):reused_variants+=1
	else:
		result=preload("res://scripts/immutable_shader_cache.gd").get_or_create(code);shared_shaders[code]=weakref(result);created_variants+=1
		# Prune weak scope entries; the bounded cache owns only immutable shaders.
		for old_code in shared_shaders.keys():
			if shared_shaders[old_code].get_ref()==null:shared_shaders.erase(old_code)
	cache[signature]=result
	return result

static func get_cache_audit() -> Dictionary:
	var live:=0
	for ref in shared_shaders.values():
		if ref.get_ref()!=null:live+=1
	return {"created":created_variants,"reused":reused_variants,"live_unique_codes":live,"weak_entries":shared_shaders.size()}
