extends Node
## Same-build RenderToTexture and OffScreenRenderFX local capture graphs.
## CIL: visual_param_transforms.cil, RenderToTexture 0x060153c9..0x060153df.
## Source RGBA is reconstructed from opaque RGB + independent framebuffer-alpha
## captures. Godot's transparent-viewport coverage is NEVER used as source alpha.
## No logic, animation, sound or RNG is copied. Only live geometry is mirrored.
const Curves = preload("res://scripts/native_summon_curves.gd")
const BLOOM = preload("res://shaders/native_combat_r2t_bloom.gdshader")
const BLUR = preload("res://shaders/native_combat_r2t_blur.gdshader")
const COMBINE = preload("res://shaders/native_combat_r2t_combine.gdshader")
const SOURCE_TO_CAPTURE := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP)
const EPSILON := 0.00001
static var offscreen_sequence := 0
static var _shared_capture_shaders:Dictionary={}
static var _shared_shader_created:=0
static var _shared_shader_reused:=0
var state: Dictionary = {}
var assets
var projection: Node3D
var owner_serial := 0
var root: Node
var entries: Array = []
var pending_offscreen: Array = []
var hidden: Dictionary = {}
var warnings: Array[String] = []
var disposed := false
var sync_count := 0
var age := 0.0
var quality := 1 # Explicit compatibility input. Original scene quality not recovered.
var capture_materials
var _last_audit: Dictionary = {}
var _capture_shader_cache: Dictionary = {}
var _capture_uniform_cache: Dictionary = {}

func setup(effect_state: Dictionary, source_assets, source_projection: Node3D, serial: int) -> void:
	state = effect_state; assets = source_assets; projection = source_projection; owner_serial = serial
	disposed = false
	if ResourceLoader.exists("res://scripts/native_combat_capture_materials.gd"):
		capture_materials = load("res://scripts/native_combat_capture_materials.gd").new()
	root = Node.new(); root.name = "OriginalRenderTextures_%d" % serial
	projection.add_child(root)
	for key in assets.objects:
		var record: Dictionary = assets.objects[key]
		if record.get("class_name", "") not in ["RenderToTexture","OffScreenRenderFX"]: continue
		var owner_key: String = record.get("refs", {}).get(".m_GameObject", "")
		if not state.nodes.has(owner_key): continue
		var source_key: String = record.refs.get(".ObjectToRender",owner_key) if record.get("class_name", "")=="OffScreenRenderFX" else record.refs.get(".m_ObjectToRender", owner_key)
		if not state.nodes.has(source_key):
			_warn("RT source is outside the instantiated closure: " + source_key); continue
		if record.get("class_name","")=="OffScreenRenderFX":
			pending_offscreen.append({"record":record.duplicate(true),"owner_key":owner_key,"source_key":source_key})
		else:_build_entry(record, owner_key, source_key)
	sync(0.0)

static func texture_size(data: Dictionary, source_scale := Vector3.ONE, render_quality := 1) -> Vector2i:
	var width := absf(float(data.get("m_Width", 1.0)) * source_scale.x)
	var height := absf(float(data.get("m_Height", 1.0)) * source_scale.y)
	var resolution := maxf(1.0, float(data.get("m_Resolution", 128)))
	var factor: float = [0.75, 1.0, 1.5][clampi(render_quality, 0, 2)]
	if maxf(width, height) <= EPSILON: return Vector2i.ONE
	return Vector2i(maxi(1, int(resolution * width / maxf(width, height) * factor)), maxi(1, int(resolution * height / maxf(width, height) * factor)))

static func plane_mesh(width: float, height: float) -> ArrayMesh:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-width,0,-height),Vector3(width,0,-height),Vector3(-width,0,height),Vector3(width,0,height)])
	for i in range(4): arrays[Mesh.ARRAY_VERTEX][i] *= 0.5
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
	# Unity lower-left UV to Godot upper-left render-target UV, exactly once.
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([3,1,2,2,1,0]) # Original FieldRVA 0x85d28b.
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func bloom_offsets(size: Vector2i, blur: float, pass_index: int) -> Array:
	var x := 1.0 / maxi(1, size.x); var y := 1.0 / maxi(1, size.y)
	if pass_index == 1:
		return [Vector4(1.5*x,1.5*y,-1.5*x,1.5*y),Vector4(-1.5*x,-1.5*y,1.5*x,-1.5*y)]
	if pass_index == 2:
		return [Vector4(6.0*blur*x,0,-6.0*blur*x,0),Vector4(2.0*blur*x,0,-2.0*blur*x,0)]
	return [Vector4(0,6.0*blur*y,0,-6.0*blur*y),Vector4(0,2.0*blur*y,0,-2.0*blur*y)]

func _build_entry(record: Dictionary, owner_key: String, source_key: String) -> void:
	var offscreen:bool=record.get("class_name","")=="OffScreenRenderFX"
	var d: Dictionary = record.data.duplicate(true)
	if offscreen:
		record=record.duplicate(true);record.refs[".m_RenderToObject"]=owner_key
		d.merge({"m_Enabled":record.data.get("m_Enabled",true),"m_HideRenderObject":true,"m_RealtimeRender":true,"m_CreateRenderPlane":false,"m_RenderMaterial":0,"m_ClearColor":{"r":0,"g":0,"b":0,"a":1}})
	# These paths are absent from the 19 restored components. Surface them
	# explicitly rather than quietly treating future source records as equivalent.
	for flag in ["m_RenderMeshAsAlpha","m_OpaqueObjectAlphaFill","m_UsesStencilBuffer"]:
		if bool(d.get(flag,false)):_warn("Unsupported original alternate capture flag "+flag+": "+str(record.key))
	for reference in [".m_AlphaObjectToRender",".m_ReplacmentShader"]:
		if not str(record.refs.get(reference,"")).is_empty():_warn("Unsupported original alternate capture reference "+reference+": "+str(record.key))
	if int(d.get("m_LayerMask",{}).get("m_Bits",4294967295))!=4294967295:_warn("Source selective Unity layer mapping not available: "+str(record.key))
	var owner: Node3D = state.nodes[owner_key]; var source: Node3D = state.nodes[source_key]
	var entry: Dictionary = {"key":record.key,"owner_key":owner_key,"source_key":source_key,"data":d,"record":record,"owner":owner,"source":source,"captures":[],"passes":[],"plane":null,"bloom_plane":null,"mirrors":{},"updates":0,"dirty":true,"original_materials":[],"original_textures":[],"generated":false}
	entry.offscreen=offscreen
	entry.world_scale = _source_scale(owner, bool(d.get("m_UniformWorldScale", false)))
	entry.size = texture_size(d, entry.world_scale, quality)
	if offscreen:
		var output:MeshInstance3D=state.renderers.get(owner_key)
		if output==null or output.mesh==null:_warn("OffScreenRenderFX output mesh missing: "+str(record.key));return
		entry.size=Vector2i(maxi(1,int(d.get("RenderResolutionX",256))),maxi(1,int(d.get("RenderResolutionY",256))))
		entry.original_plane_visible=output.visible
		entry.offscreen_height=2.0*float(d.get("ForceSize",0)) if float(d.get("ForceSize",0))!=0 else owner.scale.x*(output.mesh.get_aabb().size.x if bool(d.get("UseBounds",true)) else 1.0)
		var offset:=Vector3(250,250+10*offscreen_sequence,0);offscreen_sequence+=1
		var source_parent:=_source_transform(source.get_parent())
		entry.offscreen_local_offset=source_parent.basis.inverse()*offset
		var initial_source:=_source_transform(source)
		var initial_camera:=Transform3D(initial_source.basis.orthonormalized()*(Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,PI/2)),initial_source.origin+offset)
		entry.offscreen_camera_local=_source_transform(owner).affine_inverse()*initial_camera
		var rect:Dictionary=d.get("CameraRect",{})
		if float(rect.get("x",0))!=0 or float(rect.get("y",0))!=0 or float(rect.get("width",1))!=1 or float(rect.get("height",1))!=1:_warn("Unsupported non-full OffScreenRenderFX camera rect: "+str(record.key))
	entry.initial_owner_rotation = _source_transform(owner).basis.orthonormalized()
	entry.initial_source_world_offset = _source_transform(source).origin - _source_transform(owner).origin
	entry.initial_source_relative_rotation = entry.initial_owner_rotation.inverse() * _source_transform(source).basis.orthonormalized()
	var clear := _color(d.get("m_ClearColor", {}))
	entry.main_capture = _capture(entry, entry.size, clear, "Main")
	entry.output = entry.main_capture.combined
	if float(d.get("m_BlurAmount", 0.0)) > 0.0:
		entry.blur = _pass(entry, entry.size, BLUR, entry.output, "SourceBlur")
		entry.output = entry.blur.view.get_texture()
	else: entry.blur = {}
	_build_plane(entry)
	var mode := int(d.get("m_RenderMaterial", 0))
	if mode in [3,5] and float(d.get("m_BloomIntensity",0.0)) != 0.0:
		var ratio := clampf(float(d.get("m_BloomResolutionRatio",0.75)),0.0,1.0)
		var bloom_size := Vector2i(int(entry.size.x*ratio),int(entry.size.y*ratio))
		if bloom_size.x < 1 or bloom_size.y < 1:
			_warn("Original bloom requested zero-size target: " + str(record.key))
		else:
			entry.bloom_size = bloom_size
			var input: Texture2D = entry.output
			if mode == 5:
				# The original captures the source geometry again at bloom resolution.
				# It does not downsample the alpha-clipped visible plane.
				entry.bloom_capture = _capture(entry, bloom_size, clear, "BloomSource")
				input = entry.bloom_capture.combined
			entry.bloom_steps = []
			for i in range(3):
				var pass_size: Vector2i = entry.size if mode == 3 and i == 2 else bloom_size
				var step := _pass(entry, pass_size, BLOOM, input, "Bloom_%d" % i)
				entry.bloom_steps.append(step); input = step.view.get_texture()
			if mode == 5:
				var bloom_plane := MeshInstance3D.new(); bloom_plane.name="OriginalBloomPlane"
				bloom_plane.mesh=plane_mesh(float(d.m_Width),float(d.m_Height))
				bloom_plane.set_meta("r2t_generated",true)
				var parent: Node3D = entry.plane if is_instance_valid(entry.plane) else owner
				parent.add_child(bloom_plane); bloom_plane.position=Vector3(0,0.15,0)
				bloom_plane.material_override=_plane_material(entry,true)
				bloom_plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				entry.bloom_plane=bloom_plane
				_bind_texture(bloom_plane.material_override,"_MainTex",input)
			else: entry.output=input
	_bind_output(entry)
	if offscreen and is_instance_valid(entry.plane):entry.plane.visible=true # Original Start enables only after SetupMaterial.
	entries.append(entry)

func _capture(entry: Dictionary, size: Vector2i, clear: Color, label: String) -> Dictionary:
	var result: Dictionary = {"label":label,"mirrors":{},"size":size}
	for kind in ["color","alpha"]:
		var view := SubViewport.new(); view.name=label+"_"+kind
		view.size=size; view.own_world_3d=true; view.transparent_bg=false
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
		view.msaa_3d=Viewport.MSAA_DISABLED
		root.add_child(view)
		var env := WorldEnvironment.new(); env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color(clear.r,clear.g,clear.b,1) if kind=="color" else Color(clear.a,clear.a,clear.a,1)
		env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
		view.add_child(env)
		var geometry := Node3D.new(); geometry.name="GeometryOnly"; view.add_child(geometry)
		var camera := Camera3D.new(); camera.name="OriginalOrthoCamera"; view.add_child(camera)
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect=Camera3D.KEEP_HEIGHT; camera.current=true
		result[kind]={"view":view,"geometry":geometry,"camera":camera,"environment":env.environment}
	var combine := _pass(entry,size,COMBINE,result.color.view.get_texture(),label+"_RGBA")
	combine.material.set_shader_parameter("_AlphaTex",result.alpha.view.get_texture())
	combine.material.set_shader_parameter("_AddAlpha",false)
	result.combined=combine.view.get_texture()
	entry.captures.append(result)
	return result

func _pass(entry: Dictionary, size: Vector2i, shader: Shader, input: Texture2D, label: String) -> Dictionary:
	var view:=SubViewport.new(); view.name=label; view.size=size; view.disable_3d=true
	view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(view)
	var quad:=ColorRect.new(); quad.size=Vector2(size); quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mat:=ShaderMaterial.new(); mat.shader=shader; mat.set_shader_parameter("_MainTex",input)
	quad.material=mat; view.add_child(quad)
	var pass_state: Dictionary={"view":view,"material":mat,"quad":quad,"name":label}
	entry.passes.append(pass_state)
	return pass_state

func _build_plane(entry: Dictionary) -> void:
	var d: Dictionary=entry.data; var target_key: String=entry.record.refs.get(".m_RenderToObject","")
	if target_key!="":
		var target: MeshInstance3D=state.renderers.get(target_key)
		if target==null:
			_warn("RT output renderer missing: "+target_key); return
		entry.plane=target
		for i in range(target.mesh.get_surface_count()):
			entry.original_materials.append(target.get_surface_override_material(i))
			var active_material=target.get_active_material(i)
			var texture_property=str(d.get("m_ShaderTextureName",""))
			if texture_property.is_empty():texture_property="_MainTex"
			if active_material is ShaderMaterial:entry.original_textures.append({"material":active_material,"property":texture_property,"texture":active_material.get_shader_parameter(texture_property)})
			elif active_material is BaseMaterial3D:entry.original_textures.append({"material":active_material,"property":"_MainTex","texture":active_material.albedo_texture})
		if int(d.get("m_RenderMaterial",0))!=0:
			var mat:=_plane_material(entry,false)
			for i in range(target.mesh.get_surface_count()):target.set_surface_override_material(i,mat)
		return
	if not bool(d.get("m_CreateRenderPlane",true)):return
	var plane:=MeshInstance3D.new(); plane.name="OriginalRenderPlane"; plane.set_meta("r2t_generated",true)
	plane.mesh=plane_mesh(float(d.get("m_Width",1)),float(d.get("m_Height",1)))
	entry.owner.add_child(plane); plane.position=_vec(d.get("m_PositionOffset",{}))
	plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.material_override=_plane_material(entry,false)
	entry.plane=plane; entry.generated=true
	# GetRenderMaterial/Renderer material actions resolve the generated original plane.
	state.renderers[entry.owner_key]=plane
	if not state.materials.has(entry.owner_key):state.materials[entry.owner_key]=[]
	state.materials[entry.owner_key].append(plane.material_override)

func _plane_material(entry: Dictionary, bloom: bool) -> Material:
	var d: Dictionary=entry.data; var mode:=int(d.get("m_RenderMaterial",0))
	var suffix: String="transparent"
	if bloom or mode==3: suffix="additive" if int(d.get("m_BloomBlend",0))==0 else "transparent"
	elif mode==2:suffix="additive"
	elif mode in [4,5]:suffix="alpha_gradient" if int(d.get("m_AlphaClipRenderStyle",0))==1 else "alpha_clip"
	elif mode==0:
		var key: String=entry.record.refs.get(".m_Material","")
		var original: Material=assets.material(key)
		if original!=null:return _plane_culling(original,entry)
		_warn("RT custom material missing: "+str(entry.key))
	var material:=ShaderMaterial.new(); material.shader=preload("res://scripts/immutable_shader_cache.gd").load_shader("res://shaders/native_combat_r2t_"+suffix+".gdshader")
	material.set_meta("source_colors",{"_Color":Color.WHITE})
	material.set_meta("r2t_generated",true)
	return _plane_culling(material,entry)

func _plane_culling(material: Material, entry: Dictionary) -> Material:
	if material is ShaderMaterial and entry.owner.global_basis.determinant()<0:
		material.shader=_capture_shader(material.shader,true)
	return material

func _capture_shader(shader: Shader, reverse_cull: bool) -> Shader:
	if not reverse_cull:return shader
	var id:=shader.get_instance_id()
	if not _capture_shader_cache.has(id):
		# Share only immutable GLSL, never material parameters or viewport textures.
		# Weak scope sharing coexists with the bounded immutable Shader cache.
		var code:=shader.code.replace("cull_back","R2T_CULL_SWAP").replace("cull_front","cull_back").replace("R2T_CULL_SWAP","cull_front")
		for stale in _shared_capture_shaders.keys():
			if _shared_capture_shaders[stale].get_ref()==null:_shared_capture_shaders.erase(stale)
		var result:Shader=_shared_capture_shaders[code].get_ref() if _shared_capture_shaders.has(code) else null
		if result==null:
			result=preload("res://scripts/immutable_shader_cache.gd").get_or_create(code)
			_shared_capture_shaders[code]=weakref(result);_shared_shader_created+=1
		else:_shared_shader_reused+=1
		_capture_shader_cache[id]=result
	return _capture_shader_cache[id]

static func shared_shader_audit()->Dictionary:
	var live:=0
	for reference in _shared_capture_shaders.values():
		if reference.get_ref()!=null:live+=1
	return {"created":_shared_shader_created,"reused":_shared_shader_reused,"live_unique_codes":live,"ownership":"weak immutable shader sharing; no material or texture retention"}

func _bind_capture_material(base: Material, pair: Dictionary, kind: String, surface: int, mirror: MeshInstance3D, camera: Camera3D) -> Material:
	if not base is ShaderMaterial:return base
	var key:=kind+str(surface)
	if not pair.has("materials"):pair.materials={}
	var material: ShaderMaterial=pair.materials.get(key)
	var reverse_cull:=mirror.transform.basis.determinant()<0
	if material==null or material.get_meta("capture_base",0)!=base.get_instance_id() or material.get_meta("capture_reverse_cull",false)!=reverse_cull:
		material=ShaderMaterial.new();material.shader=_capture_shader(base.shader,reverse_cull)
		material.set_meta("capture_base",base.get_instance_id());material.set_meta("capture_reverse_cull",reverse_cull);pair.materials[key]=material
	var shader_id: int=base.shader.get_instance_id()
	if not _capture_uniform_cache.has(shader_id):
		# Shader introspection can be empty until the backend compiles its first
		# frame. Parse declared names so first-frame captures keep all overrides.
		var names: Array=[]
		var regex:=RegEx.new();regex.compile("uniform\\s+\\w+\\s+([A-Za-z_][A-Za-z_0-9]*)")
		for match_value in regex.search_all(base.shader.code):names.append({"name":match_value.get_string(1)})
		_capture_uniform_cache[shader_id]=names
	for uniform in _capture_uniform_cache[shader_id]:
		var value=base.get_shader_parameter(uniform.name)
		material.set_shader_parameter(uniform.name,value)
	material.render_priority=base.render_priority
	# Camera-dependent formulas must see this local source capture, not the
	# final board camera copied from the production material.
	material.set_shader_parameter("_SourceViewProjection",camera.get_camera_projection()*Projection(camera.global_transform.affine_inverse()))
	# URP lighting uniforms remain expressed in the actual board world. Map
	# the isolated capture geometry back there, without reprojecting vertices.
	var source_world:=Transform3D.IDENTITY
	if base.shader.resource_path.contains("urp_simple_lit") and absf(mirror.global_basis.determinant())>EPSILON:
		source_world=pair.source.global_transform*mirror.global_transform.affine_inverse()
	material.set_shader_parameter("_GodotToSourceWorld",source_world)
	material.set_shader_parameter("_SourceCameraObject",mirror.to_local(camera.global_position) if absf(mirror.global_basis.determinant())>EPSILON else Vector3.ZERO)
	material.set_shader_parameter("_GodotToSourceObject",Transform3D.IDENTITY)
	return material

func _bind_texture(material: Material, property: String, texture: Texture2D) -> void:
	if material is ShaderMaterial: material.set_shader_parameter(property,texture)
	elif material is BaseMaterial3D and property=="_MainTex":material.albedo_texture=texture

func _bind_output(entry: Dictionary) -> void:
	var plane: MeshInstance3D=entry.plane
	if not is_instance_valid(plane):return
	var property: String=entry.data.get("m_ShaderTextureName","")
	if property=="":property="_MainTex"
	if plane.material_override!=null:_bind_texture(plane.material_override,property,entry.output)
	elif plane.mesh!=null:
		for surface in range(plane.mesh.get_surface_count()):_bind_texture(plane.get_active_material(surface),property,entry.output)

func _source_transform(node: Node3D) -> Transform3D:
	# Local chains avoid inverse-projection float noise changing int RT dimensions
	# (e.g. an original 170-square target becoming 169x170). World-space particle
	# meshes explicitly bypass this chain because their vertices are world positions.
	var current: Node = node
	var result := Transform3D.IDENTITY
	while current != null and current != projection:
		if current is Node3D:
			if current.top_level: break
			result = current.transform * result
		current = current.get_parent()
	if current == projection: return result
	return projection.global_transform.affine_inverse()*node.global_transform

func _source_scale(node: Node3D, uniform: bool) -> Vector3:
	var scale: Vector3=_source_transform(node).basis.get_scale().abs()
	if uniform:scale=Vector3.ONE*maxf(scale.x,maxf(scale.y,scale.z))
	return scale

func _capture_transform(entry: Dictionary, geometry: Node3D) -> Transform3D:
	var source: Node3D=entry.source
	var source_space:=_source_transform(source)
	if bool(entry.get("offscreen",false)):
		# Original Start translates the source into an isolated region, then parents
		# the already-positioned Camera to the output plane (worldPositionStays).
		# Reconstruct those poses without moving the live animator or copying it.
		var virtual_local:=source.transform;virtual_local.origin+=entry.offscreen_local_offset
		var virtual_source:=_source_transform(source.get_parent())*virtual_local
		var camera_pose:Transform3D=_source_transform(entry.owner)*entry.offscreen_camera_local
		camera_pose.basis=camera_pose.basis.orthonormalized()
		return Transform3D(Basis.from_scale(Vector3(1,1,-1)),Vector3.ZERO)*camera_pose.affine_inverse()*virtual_source*source_space.affine_inverse()*_source_transform(geometry)
	var local:=source_space.affine_inverse()*_source_transform(geometry)
	var scale:=source_space.basis.get_scale().abs()
	var result:=Transform3D(Basis.from_scale(scale),Vector3.ZERO)*local
	if bool(entry.data.get("m_RealtimeTranslation",false)):
		# Init reparents source and camera under an identity offscreen root.
		# Their common later owner rotation cancels, leaving INITIAL relative
		# rotation. The three original missile source roots have no root curves.
		var inverse_owner:Basis=entry.initial_owner_rotation.inverse()
		var offset:Vector3=inverse_owner*(entry.initial_source_world_offset-_vec(entry.data.get("m_PositionOffset",{}))-_vec(entry.data.get("m_CameraOffset",{})))
		result=Transform3D(entry.initial_source_relative_rotation,offset)*result
	else:
		# PositionHiddenObjectsAndCameras resets source rotation to owner rotation
		# in this branch. Source/camera share the moved source origin.
		result.origin-=_vec(entry.data.get("m_CameraOffset",{}))
	return Transform3D(SOURCE_TO_CAPTURE,Vector3.ZERO)*result

func sync(seconds: float) -> void:
	if disposed or not is_instance_valid(root) or not is_instance_valid(projection):return
	age=seconds; sync_count+=1
	# Unity Start is delayed until the first active/enabled frame, then never
	# repeated after a disable/re-enable. Allocate and enable only at that point.
	for pending in pending_offscreen.duplicate():
		var owner:Node3D=state.nodes.get(pending.owner_key)
		var source:Node3D=state.nodes.get(pending.source_key)
		if not is_instance_valid(owner) or not is_instance_valid(source):
			pending_offscreen.erase(pending);continue
		if bool(pending.record.data.get("m_Enabled",true)) and owner.is_visible_in_tree():
			_build_entry(pending.record,pending.owner_key,pending.source_key)
			pending_offscreen.erase(pending)
	for entry in entries:
		if not is_instance_valid(entry.owner) or not is_instance_valid(entry.source):
			for capture in entry.captures:
				for kind in ["color","alpha"]:capture[kind].view.render_target_update_mode=SubViewport.UPDATE_DISABLED
			for pass_state in entry.passes:pass_state.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
			if is_instance_valid(entry.plane):entry.plane.visible=false
			if is_instance_valid(entry.bloom_plane):entry.bloom_plane.visible=false
			continue
		var enabled: bool=bool(entry.data.get("m_Enabled",true)) and entry.owner.is_visible_in_tree()
		var refresh: bool=enabled and (bool(entry.data.get("m_RealtimeRender",false)) or bool(entry.dirty) or entry.updates==0)
		for capture in entry.captures:
			_sync_camera(entry,capture)
			_sync_capture(entry,capture,refresh)
		for pass_state in entry.passes:pass_state.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if refresh else SubViewport.UPDATE_DISABLED
		_update_parameters(entry)
		if is_instance_valid(entry.plane) and entry.generated:entry.plane.visible=enabled
		if is_instance_valid(entry.bloom_plane):entry.bloom_plane.visible=enabled and float(entry.data.get("m_BloomIntensity",0))!=0.0
		if refresh:entry.updates+=1
		entry.dirty=false

func _sync_camera(entry: Dictionary, capture: Dictionary) -> void:
	var d: Dictionary=entry.data
	var world_scale: Vector3=_source_scale(entry.owner,bool(d.get("m_UniformWorldScale",false)))
	var height:=absf(float(d.get("m_Height",1))*world_scale.y)
	var camera_height:=2.0*float(d.get("m_OverrideCameraSize",0)) if float(d.get("m_OverrideCameraSize",0))>0.0 else height
	# RenderTex's LightWeightCamera uses worldScale.z, even though CreateCamera
	# initially uses .y. The render command's projection wins (IL01dc..020c).
	var near_source:=float(d.get("m_NearClip",-1))*world_scale.z
	var far_source:=float(d.get("m_FarClip",3))*world_scale.z
	if bool(entry.get("offscreen",false)):
		camera_height=entry.offscreen_height
		near_source=-float(d.get("AboveClip",1));far_source=float(d.get("BelowClip",1))
	for kind in ["color","alpha"]:
		var camera: Camera3D=capture[kind].camera
		camera.size=maxf(EPSILON,camera_height); camera.near=0.01
		camera.far=maxf(0.02,far_source-near_source+0.01)
		camera.position=Vector3(0,0,-near_source+0.01)

func _collect_geometry(entry: Dictionary) -> Array:
	var result: Array=[]
	_collect_tree(entry.source,result)
	for record in state.get("particle_players",{}).values():
		var player=record.get("node") if record is Dictionary else record
		if not is_instance_valid(player) or not is_instance_valid(player.source_node):continue
		if player.source_node==entry.source or entry.source.is_ancestor_of(player.source_node):
			_collect_tree(player,result)
			# Optional particle-owner interface: original RTT camera's X/Z axes.
			var basis: Basis=entry.owner.global_basis.orthonormalized()
			if bool(entry.get("offscreen",false)):
				var capture_pose:Transform3D=_source_transform(entry.owner)*entry.offscreen_camera_local
				var camera_rotation:Basis=(projection.global_basis*capture_pose.basis).orthonormalized()
				basis=Basis(camera_rotation.x,camera_rotation.z,camera_rotation.y)
			if not player.capture_camera_right.is_equal_approx(basis.x) or not player.capture_camera_up.is_equal_approx(basis.z):
				player.capture_camera_right=basis.x; player.capture_camera_up=basis.z
				player.seek(player.elapsed_seconds)
	return result.filter(func(mesh):return mesh!=entry.plane and mesh!=entry.bloom_plane)

func _collect_tree(node: Node, result: Array) -> void:
	if node is SubViewport or node.get_meta("r2t_generated",false):return
	if node is MeshInstance3D and not result.has(node):result.append(node)
	for child in node.get_children():_collect_tree(child,result)

func _sync_capture(entry: Dictionary, capture: Dictionary, refresh: bool) -> void:
	var seen: Dictionary={}
	for source in _collect_geometry(entry):
		if source.mesh==null:continue
		var id: int=source.get_instance_id(); seen[id]=true
		if not capture.mirrors.has(id):
			var pair: Dictionary={"source":source}
			for kind in ["color","alpha"]:
				var mirror:=MeshInstance3D.new(); mirror.name="Capture_%s_%d"%[kind,id]
				capture[kind].geometry.add_child(mirror); mirror.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pair[kind]=mirror
			capture.mirrors[id]=pair
		var visible: bool=source.is_visible_in_tree()
		var pair: Dictionary=capture.mirrors[id]
		for kind in ["color","alpha"]:
			var mirror: MeshInstance3D=pair[kind]
			mirror.transform=_capture_transform(entry,source); mirror.mesh=source.mesh; mirror.visible=visible
			mirror.sorting_offset=source.sorting_offset; mirror.extra_cull_margin=source.extra_cull_margin
			for surface in range(source.mesh.get_surface_count()):
				var material: Material=source.get_active_material(surface)
				var capture_material: Material=null
				if capture_materials!=null:
					capture_material=capture_materials.color_material(material) if kind=="color" else capture_materials.alpha_material(material)
				elif kind=="color":capture_material=material
				else:_warn("Independent source-alpha factory unavailable; alpha capture disabled")
				if capture_material==null:
					capture_material=_invisible_material()
				mirror.set_surface_override_material(surface,_bind_capture_material(capture_material,pair,kind,surface,mirror,capture[kind].camera))
		if bool(entry.data.get("m_HideRenderObject",false)):
			if not hidden.has(id):hidden[id]={"node":source,"layers":source.layers}
			source.layers=0 # Preserve source/parent visibility for the animator and capture.
	for id in capture.mirrors.keys():
		if not seen.has(id):
			for kind in ["color","alpha"]:capture.mirrors[id][kind].queue_free()
			capture.mirrors.erase(id)
	for kind in ["color","alpha"]:capture[kind].view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if refresh else SubViewport.UPDATE_DISABLED

func _invisible_material() -> StandardMaterial3D:
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color=Color(0,0,0,0)
	material.no_depth_test=true; return material

func _update_parameters(entry: Dictionary) -> void:
	if bool(entry.get("offscreen",false)):return # OffScreenRenderFX does not rewrite the output material.
	var d: Dictionary=entry.data
	if not entry.blur.is_empty():
		entry.blur.material.set_shader_parameter("_BlurOffsets",Vector4.ONE*float(d.get("m_BlurAmount",0)))
		entry.blur.material.set_shader_parameter("_MainTex_TexelSize",Vector4(1.0/entry.size.x,1.0/entry.size.y,0,0))
		entry.blur.material.set_shader_parameter("_AlphaOnly",bool(d.get("m_BlurAlphaOnly",false)))
	var plane: MeshInstance3D=entry.plane
	if is_instance_valid(plane):
		var material: Material=plane.material_override if plane.material_override!=null else plane.get_active_material(0)
		_update_plane_parameters(material,entry,false)
	if is_instance_valid(entry.bloom_plane):_update_plane_parameters(entry.bloom_plane.material_override,entry,true)
	for i in range(entry.get("bloom_steps",[]).size()):
		var material: ShaderMaterial=entry.bloom_steps[i].material
		var offsets:=bloom_offsets(entry.bloom_size,float(d.get("m_BloomBlur",0)),i+1)
		material.set_shader_parameter("_OffsetA",offsets[0]); material.set_shader_parameter("_OffsetB",offsets[1])
		material.set_shader_parameter("_Pass",1 if i==0 else 2)
		material.set_shader_parameter("_BloomMode",1 if int(d.get("m_BloomRenderType",0))==1 else (2 if int(d.get("m_RenderMaterial",0))==5 else 0))
		material.set_shader_parameter("_Threshold",float(d.get("m_BloomThreshold",0)))
		var denominator:=1.0-float(d.get("m_BloomThreshold",0))
		material.set_shader_parameter("_Intensity",float(d.get("m_BloomIntensity",1))/denominator if denominator!=0.0 else 0.0)
		material.set_shader_parameter("_Cutoff",float(d.get("m_AlphaClip",1)))
		material.set_shader_parameter("_AlphaIntensity",float(d.get("m_BloomAlphaIntensity",1)) if int(d.get("m_BloomRenderType",0))==1 else float(d.get("m_AlphaClipAlphaIntensity",1)))
		# Original AlphaClipBloom _ColorIntensity is its shader default, NOT _Intensity.

func _update_plane_parameters(material: Material, entry: Dictionary, bloom: bool) -> void:
	if not material is ShaderMaterial:return
	var d: Dictionary=entry.data; var mode:=int(d.get("m_RenderMaterial",0))
	if bloom or mode==3:material.set_shader_parameter("_Color",_color(d.get("m_BloomColor",{})))
	elif mode!=0:material.set_shader_parameter("_Color",_color(d.get("m_TintColor",{})))
	if mode in [4,5] and not bloom:
		material.set_shader_parameter("_Cutoff",float(d.get("m_AlphaClip",1)))
		material.set_shader_parameter("_Intensity",float(d.get("m_AlphaClipIntensity",1)))
		material.set_shader_parameter("_AlphaIntensity",float(d.get("m_AlphaClipAlphaIntensity",1)))
		if int(d.get("m_AlphaClipRenderStyle",0))==1:
			material.set_shader_parameter("_GradientTex",assets.load_texture(entry.record.refs.get(".m_AlphaClipGradientMap","")))
	material.render_priority=clampi(int((int(d.get("m_RenderQueueOffset",3000))+int(d.get("m_RenderQueue",0))-3000)/2),-128,126)+(1 if bloom else 0)

func set_source_property(component_key: String, property: String, value) -> bool:
	if disposed:return false
	for pending in pending_offscreen:
		if str(pending.record.key)==component_key or str(pending.record.key).get_slice(":",1)==component_key:
			if pending.record.data.has(property):pending.record.data[property]=value;return true
	for entry in entries:
		if str(entry.key)!=component_key and str(entry.key).get_slice(":",1)!=component_key:continue
		if not entry.data.has(property):return false
		entry.data[property]=value; entry.dirty=true
		if property=="m_BlurAmount" and entry.blur.is_empty() and float(value)>0:
			entry.blur=_pass(entry,entry.size,BLUR,entry.main_capture.combined,"SourceBlurDynamic")
			entry.output=entry.blur.view.get_texture(); _bind_output(entry)
		return true
	return false

func dispose() -> void:
	if disposed:return
	_last_audit=get_audit(); disposed=true
	# Disable before queue_free: no later GPU frame or callback may revive an old scope.
	for entry in entries:
		if bool(entry.get("offscreen",false)) and is_instance_valid(entry.plane):entry.plane.visible=entry.original_plane_visible
		for capture in entry.captures:
			for kind in ["color","alpha"]:capture[kind].view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		for pass_state in entry.passes:pass_state.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if is_instance_valid(entry.bloom_plane):entry.bloom_plane.visible=false; entry.bloom_plane.queue_free()
		if entry.generated and is_instance_valid(entry.plane):
			entry.plane.visible=false; entry.plane.queue_free()
			if state.renderers.get(entry.owner_key)==entry.plane:state.renderers.erase(entry.owner_key)
		elif is_instance_valid(entry.plane):
			for snapshot in entry.original_textures:_bind_texture(snapshot.material,snapshot.property,snapshot.texture)
			for i in range(entry.original_materials.size()):entry.plane.set_surface_override_material(i,entry.original_materials[i])
	for item in hidden.values():
		if is_instance_valid(item.node):item.node.layers=item.layers
	hidden.clear()
	if is_instance_valid(root):root.queue_free()
	entries.clear(); pending_offscreen.clear(); capture_materials=null; _capture_shader_cache.clear(); _capture_uniform_cache.clear()

func _warn(message: String) -> void:
	if not warnings.has(message):warnings.append(message)

static func _color(value) -> Color:
	return value if value is Color else Color(float(value.get("r",1)),float(value.get("g",1)),float(value.get("b",1)),float(value.get("a",1)))

static func _vec(value) -> Vector3:
	return value if value is Vector3 else Vector3(float(value.get("x",0)),float(value.get("y",0)),float(value.get("z",0)))

func _output_texture_is_bound(entry: Dictionary) -> bool:
	if not is_instance_valid(entry.plane):return false
	var property:=str(entry.data.get("m_ShaderTextureName",""))
	if property.is_empty():property="_MainTex"
	for surface in range(entry.plane.mesh.get_surface_count()):
		var material=entry.plane.get_active_material(surface)
		if material is ShaderMaterial:
			if material.get_shader_parameter(property)!=entry.output:return false
		elif material is BaseMaterial3D:
			if material.albedo_texture!=entry.output:return false
		else:return false
	return true

func _output_material_audit(entry: Dictionary) -> Dictionary:
	if not is_instance_valid(entry.plane):return {}
	var material=entry.plane.get_active_material(0)
	if not material is ShaderMaterial:return {"material":"non-shader"}
	var uniforms:Dictionary={}
	for parameter in ["_Color","_ColorMul","_Intensity","_Alpha","_AlphaIntensity","_Cutoff"]:
		var value=material.get_shader_parameter(parameter)
		if value!=null:uniforms[parameter]=str(value) if value is Color or value is Vector4 else value
	return {"source_key":material.get_meta("source_key",""),"shader":material.shader.resource_path,"uniforms":uniforms}

func get_audit() -> Dictionary:
	if disposed:
		var previous:=_last_audit.duplicate(true); previous.disposed=true; previous.live_viewports=0
		return previous
	var components: Array=[]; var viewport_count:=0
	for entry in entries:
		var geometries:=0
		for capture in entry.captures:geometries+=capture.mirrors.size(); viewport_count+=2
		viewport_count+=entry.passes.size()
		components.append({"key":entry.key,"component_class":entry.record.get("class_name","RenderToTexture"),"source_key":entry.source_key,"owner_key":entry.owner_key,"size":[entry.size.x,entry.size.y],"bloom_size":[entry.get("bloom_size",Vector2i.ZERO).x,entry.get("bloom_size",Vector2i.ZERO).y],"material_mode":entry.data.get("m_RenderMaterial"),"source_geometry_count":geometries,"updates":entry.updates,"blur":entry.data.get("m_BlurAmount"),"tint":str(entry.data.get("m_TintColor")),"realtime_translation":bool(entry.data.get("m_RealtimeTranslation",false)),"generated_plane":entry.generated,"output_texture_bound":_output_texture_is_bound(entry),"output_material":_output_material_audit(entry)})
	return {"owner_serial":owner_serial,"disposed":disposed,"shared_capture_shader_cache":shared_shader_audit(),"component_count":entries.size(),"pending_offscreen_start":pending_offscreen.size(),"components":components,"hidden_originals":hidden.size(),"live_viewports":viewport_count,"sync_count":sync_count,"age":age,"warnings":warnings.duplicate(),"capture_material_unsupported":capture_materials.unsupported.values() if capture_materials!=null else [],"capture_material_unsupported_keys":capture_materials.unsupported.duplicate() if capture_materials!=null else {},"quality_input":quality,"rgba":"opaque RGB capture + independent source framebuffer alpha, combine raw RGBA","source_formula":"same-build CIL and DXBC","source_projection":"local XZ capture; board projection removed once, final plane inherits once","native_pixel_equivalence":false,"compatibility":["Godot rasterization and depth; not original Unity runtime","Original scene quality and lighting globals not recovered","Source format 0/7 mapped to Godot RGBA8; native texture filter/wrap/gamma defaults not independently recovered","Godot render_priority compresses original queues into available range"]}
