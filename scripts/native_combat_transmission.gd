extends Node
## Affine RGB transparency: destination = accumulated_C + RGB_T * background.
## C is the production scene, with actual blend_mul for colored source shaders.
## This node mirrors ONLY render geometry into a white transmission framebuffer.
## No scripts, input, audio, animations, lights or game rules are duplicated.
## Call sync() after ALL production scene animation/particle updates each frame.

const COMPOSITE = preload("res://shaders/native_combat_transmission_composite.gdshader")
static var _shared_shader_cache: Dictionary = {}
var _implicit_black_material: StandardMaterial3D
var source_view: SubViewport
var source_root: Node
var transmission_view: SubViewport
var camera: Camera3D
var geometry_root: Node3D
var mirrors: Dictionary = {}
var material_cache: Dictionary = {}
var shader_cache: Dictionary = {}
var shader_uniform_cache: Dictionary = {}
var warnings: Array[String] = []
var frame_number := 0
var perf_measure_enabled := false
var perf_samples: Array=[]
var _material_seen: Dictionary = {}
var _uniform_values: Dictionary = {}
var base_storage_cache_enabled := true
var _base_property_records: Dictionary = {}
var _base_source_values: Dictionary = {}
var _geometry_nodes:Array=[]
var _geometry_dirty:=true
var _geometry_source_id:=0
var _watched_tree:SceneTree

func _mark_geometry_dirty():
	_geometry_dirty=true

func setup(view: SubViewport, scene_root: Node = null) -> void:
	source_view=view
	source_root=scene_root if scene_root!=null else view
	if is_instance_valid(transmission_view): return
	name="NativeCombatRGBTransmission"
	transmission_view=SubViewport.new()
	transmission_view.name="RGBTransmissionTarget"
	transmission_view.own_world_3d=true
	transmission_view.transparent_bg=false
	transmission_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	transmission_view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	add_child(transmission_view)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color.WHITE
	world.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	transmission_view.add_child(world)
	geometry_root=Node3D.new()
	transmission_view.add_child(geometry_root)
	camera=Camera3D.new()
	transmission_view.add_child(camera)
	camera.current=true
	sync()

func get_texture() -> ViewportTexture:
	return transmission_view.get_texture()

func make_composite_material() -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=COMPOSITE
	material.set_shader_parameter("transmission_texture",get_texture())
	return material

func sync() -> void:
	if not is_instance_valid(source_view) or not is_instance_valid(source_root):return
	var perf_started: int=Time.get_ticks_usec() if perf_measure_enabled else 0
	frame_number+=1
	_material_seen.clear()
	for property in ["size","msaa_3d","screen_space_aa","use_debanding","scaling_3d_mode","scaling_3d_scale"]:
		var value = source_view.get(property)
		if transmission_view.get(property)!=value:transmission_view.set(property,value)
	var original_camera:=source_view.get_camera_3d()
	if original_camera!=null:
		for property in ["projection","keep_aspect","fov","size","frustum_offset","near","far","h_offset","v_offset","cull_mask"]:
			var value = original_camera.get(property)
			if camera.get(property)!=value:camera.set(property,value)
		var camera_pose := original_camera.global_transform
		if camera.global_transform!=camera_pose:camera.global_transform=camera_pose
	var seen: Dictionary={}
	if is_inside_tree() and _watched_tree==null:
		_watched_tree=get_tree();_watched_tree.tree_changed.connect(_mark_geometry_dirty)
	if _geometry_dirty or _geometry_source_id!=source_root.get_instance_id() or not is_inside_tree():
		_geometry_nodes.clear();_collect_geometry(source_root)
		_geometry_source_id=source_root.get_instance_id();_geometry_dirty=false
	for source in _geometry_nodes:
		if is_instance_valid(source):_sync_geometry(source,seen)
	for key in mirrors.keys():
		if not seen.has(key):
			mirrors[key].queue_free()
			mirrors.erase(key)
	for key in material_cache.keys():
		if not _material_seen.has(key):
			material_cache.erase(key);_uniform_values.erase(key);_invalidate_base_properties(key)

	if perf_measure_enabled:
		perf_samples.append({"frame":Engine.get_process_frames(),"sync":frame_number,"usec":Time.get_ticks_usec()-perf_started,"geometry":mirrors.size(),"materials":material_cache.size(),"shader_records":_source_shader_records.size(),"viewport_size":transmission_view.size})
		if perf_samples.size()>120:perf_samples.pop_front()

func _collect_geometry(node: Node) -> void:
	# Nested viewports are independent glyph/card RTTs, not geometry in this world.
	if node is SubViewport and node!=source_root:return
	if node is MeshInstance3D or node is MultiMeshInstance3D or node is Label3D:
		_geometry_nodes.append(node)
	elif node is GeometryInstance3D:
		_warn_once("Unsupported transmission geometry: "+node.get_class()+" "+str(node.get_path()))
	for child in node.get_children():_collect_geometry(child)

func _sync_geometry(source: GeometryInstance3D, seen: Dictionary) -> void:
	var key:=source.get_instance_id()
	seen[key]=true
	var target: GeometryInstance3D=mirrors.get(key)
	if target==null:
		if source is MeshInstance3D:target=MeshInstance3D.new()
		elif source is MultiMeshInstance3D:target=MultiMeshInstance3D.new()
		else:target=Label3D.new()
		target.name="Transmission_"+str(key)
		target.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry_root.add_child(target)
		mirrors[key]=target
	# Hidden geometry cannot contribute; resync all values when it becomes visible.
	if not source.is_visible_in_tree():
		target.visible=false
		return
	var source_transform := source.global_transform
	if target.global_transform != source_transform:target.global_transform=source_transform
	target.visible=true
	# These setters forward render-instance updates even for identical values.
	if target.layers!=source.layers:target.layers=source.layers
	if target.sorting_offset!=source.sorting_offset:target.sorting_offset=source.sorting_offset
	if target.sorting_use_aabb_center!=source.sorting_use_aabb_center:target.sorting_use_aabb_center=source.sorting_use_aabb_center
	if target.custom_aabb!=source.custom_aabb:target.custom_aabb=source.custom_aabb
	if target.extra_cull_margin!=source.extra_cull_margin:target.extra_cull_margin=source.extra_cull_margin
	if target.transparency!=source.transparency:target.transparency=source.transparency
	if target.visibility_range_begin!=source.visibility_range_begin:target.visibility_range_begin=source.visibility_range_begin
	if target.visibility_range_end!=source.visibility_range_end:target.visibility_range_end=source.visibility_range_end
	if target.visibility_range_begin_margin!=source.visibility_range_begin_margin:target.visibility_range_begin_margin=source.visibility_range_begin_margin
	if target.visibility_range_end_margin!=source.visibility_range_end_margin:target.visibility_range_end_margin=source.visibility_range_end_margin
	if target.visibility_range_fade_mode!=source.visibility_range_fade_mode:target.visibility_range_fade_mode=source.visibility_range_fade_mode
	if target.ignore_occlusion_culling!=source.ignore_occlusion_culling:target.ignore_occlusion_culling=source.ignore_occlusion_culling
	if source is MeshInstance3D:
		target.mesh=source.mesh
		if source.mesh!=null:
			for surface in range(source.mesh.get_surface_count()):
				var material := transmission_material(source.get_active_material(surface))
				if target.get_surface_override_material(surface) != material:
					target.set_surface_override_material(surface,material)
			for blend in range(source.get_blend_shape_count()):
				var weight: float=source.get_blend_shape_value(blend)
				if target.get_blend_shape_value(blend) != weight:target.set_blend_shape_value(blend,weight)
		if source.skin!=null:_warn_once("Skinned meshes require a mirrored Skeleton3D: "+str(source.get_path()))
	elif source is MultiMeshInstance3D:
		target.multimesh=source.multimesh
		var material := transmission_material(source.material_override)
		if target.material_override!=material:target.material_override=material
		if source.material_override==null and source.multimesh!=null and source.multimesh.mesh!=null:
			_warn_once("MultiMesh without material_override requires per-surface variants: "+str(source.get_path()))
	else:
		# Compatibility Label3D fallback. Native migrated glyphs are MeshInstance3D.
		for pname in _label_property_names(source):
			target.set(pname,source.get(pname))
		var tint: Color=source.modulate
		var outline: Color=source.outline_modulate
		target.modulate=Color(0,0,0,tint.a)
		target.outline_modulate=Color(0,0,0,outline.a)
		target.shaded=false
	var overlay := transmission_material(source.material_overlay) if source.material_overlay!=null else null
	if target.material_overlay!=overlay:target.material_overlay=overlay

func transmission_material(source: Material) -> Material:
	if source==null:
		# Godot's implicit material is opaque, thus T=0 with the same geometry/depth.
		if _implicit_black_material==null:
			_implicit_black_material=StandardMaterial3D.new()
			_implicit_black_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			_implicit_black_material.albedo_color=Color.BLACK
		return _implicit_black_material
	var key:=source.get_instance_id()
	if _material_seen.has(key) and material_cache.has(key):return material_cache[key]
	_material_seen[key]=true
	var target: Material=material_cache.get(key)
	if target==null:
		# ShaderMaterial's shallow duplicate can share parameter storage while the
		# render backend compiles/replaces the shader. Never mutate that path:
		# source materials belong to the visible C scene and its animation system.
		target=ShaderMaterial.new() if source is ShaderMaterial else source.duplicate(false)
		material_cache[key]=target
	if source is ShaderMaterial:
		if source.shader==null:return target
		var record: Dictionary=_source_shader_record(source.shader)
		if target.shader!=record.variant:
			target.shader=record.variant;_uniform_values.erase(key)
		if not _uniform_values.has(key):_uniform_values[key]={}
		var previous:Dictionary=_uniform_values[key]
		for parameter in record.uniforms:
			# Null removes an override; skipping it would retain a stale animated
			# value when the production material resets to the shader default.
			var value=source.get_shader_parameter(parameter)
			if not previous.has(parameter) or previous[parameter]!=value:
				target.set_shader_parameter(parameter,value)
				previous[parameter]=value.duplicate(true) if value is Array or value is Dictionary else value
	elif source is BaseMaterial3D:
		# Preserve texture/vertex alpha, alpha scissor/hash, depth and culling.
		if base_storage_cache_enabled and source.get_script()==null and target.get_script()==null:
			var names:=_base_storage_names(source)
			if not _base_source_values.has(key):_base_source_values[key]={}
			var previous: Dictionary=_base_source_values[key]
			for property in names:
				var value=source.get(property)
				if not previous.has(property) or previous[property]!=value:
					target.set(property,value)
					# Cache the SOURCE value, before transmission-only overrides below.
					previous[property]=value.duplicate(true) if value is Array or value is Dictionary else value
		else:
			# Script properties can have side effects or dynamic storage semantics.
			_invalidate_base_properties(key)
			for property in source.get_property_list():
				if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0 and property.name not in ["next_pass","resource_path","resource_name","script"]:
					target.set(property.name,source.get(property.name))
		target.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		target.emission_enabled=false
		if source.blend_mode==BaseMaterial3D.BLEND_MODE_MUL:
			# MIX previously blackened the target even when the source color did
			# not change. Restoring MUL must restore its RGB independently.
			target.albedo_color=source.albedo_color
		else:
			var tint: Color=source.albedo_color
			target.albedo_color=Color(0,0,0,tint.a)
	else:
		_warn_once("Unsupported transmission material: "+source.get_class())
	for meta_name in source.get_meta_list():target.set_meta(meta_name,source.get_meta(meta_name))
	target.render_priority=source.render_priority
	target.next_pass=transmission_material(source.next_pass) if source.next_pass!=null else null
	return target

# Cache only derived source-shader metadata. Animated uniforms are still copied
# on every sync. Resource.changed invalidates the record, including same-object edits.
var _source_shader_records: Dictionary = {}
func _invalidate_source_shader(id: int) -> void:
	var record: Dictionary=_source_shader_records.get(id,{})
	var source_shader=record.reference.get_ref() if record.has("reference") else null
	var invalidate: Callable=_invalidate_source_shader.bind(id)
	if is_instance_valid(source_shader) and source_shader.changed.is_connected(invalidate):source_shader.changed.disconnect(invalidate)
	_source_shader_records.erase(id)

func _invalidate_base_properties(id: int) -> void:
	var record: Dictionary=_base_property_records.get(id,{})
	var source=record.reference.get_ref() if record.has("reference") else null
	var callback:=_invalidate_base_properties.bind(id)
	if is_instance_valid(source) and source.property_list_changed.is_connected(callback):
		source.property_list_changed.disconnect(callback)
	_base_property_records.erase(id)
	_base_source_values.erase(id)

func _base_storage_names(source: BaseMaterial3D) -> Array:
	var id:=source.get_instance_id()
	if _base_property_records.has(id):
		if _base_property_records[id].reference.get_ref()==source:
			return _base_property_records[id].names
		_invalidate_base_properties(id)
	var names: Array=[]
	for property in source.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0 and property.name not in ["next_pass","resource_path","resource_name","script"]:
			names.append(property.name)
	_base_property_records[id]={"reference":weakref(source),"names":names}
	var callback:=_invalidate_base_properties.bind(id)
	if not source.property_list_changed.is_connected(callback):
		source.property_list_changed.connect(callback)
	return names

func _exit_tree() -> void:
	for id in _base_property_records.keys():_invalidate_base_properties(id)
	if is_instance_valid(_watched_tree) and _watched_tree.tree_changed.is_connected(_mark_geometry_dirty):_watched_tree.tree_changed.disconnect(_mark_geometry_dirty)
	_watched_tree=null;_geometry_nodes.clear();_geometry_dirty=true;_geometry_source_id=0
	for id in _label_property_records.keys():_invalidate_label_properties(id)
	for id in _source_shader_records.keys():_invalidate_source_shader(id)

func _source_shader_record(source_shader: Shader) -> Dictionary:
	var id: int=source_shader.get_instance_id()
	if _source_shader_records.has(id):
		if _source_shader_records[id].reference.get_ref()==source_shader:return _source_shader_records[id]
		_invalidate_source_shader(id)
	var code: String=source_shader.code
	if not shader_cache.has(code):
		var transformed_code: String=_transmission_shader(code)
		if not _shared_shader_cache.has(code):
			var variant:=Shader.new()
			variant.code=transformed_code
			_shared_shader_cache[code]=variant
		shader_cache[code]=_shared_shader_cache[code]
		shader_uniform_cache[code]=_source_uniform_names(source_shader)
	var record: Dictionary={"variant":shader_cache[code],"uniforms":shader_uniform_cache[code],"reference":weakref(source_shader)}
	# Bounded lookup cache, independent of original code-keyed asset cache.
	if _source_shader_records.size()>=256:
		for old_id in _source_shader_records.keys():_invalidate_source_shader(old_id)
	_source_shader_records[id]=record
	var invalidate: Callable=_invalidate_source_shader.bind(id)
	if not source_shader.changed.is_connected(invalidate):source_shader.changed.connect(invalidate)
	return record

# Cache only the enumerated names, not any label value. Property-list changes
# invalidate synchronously; fades, text, fonts and all values still copy every sync.
var _label_property_records: Dictionary={}
func _invalidate_label_properties(id: int) -> void:
	var record: Dictionary=_label_property_records.get(id,{})
	var label=record.reference.get_ref() if record.has("reference") else null
	var callback: Callable=_invalidate_label_properties.bind(id)
	if is_instance_valid(label) and label.property_list_changed.is_connected(callback):label.property_list_changed.disconnect(callback)
	_label_property_records.erase(id)

func _label_property_names(label: Label3D) -> Array:
	var id: int=label.get_instance_id()
	if _label_property_records.has(id):
		if _label_property_records[id].reference.get_ref()==label:return _label_property_records[id].names
		_invalidate_label_properties(id)
	var names:Array=[]
	for property in label.get_property_list():
		var pname: String=property.name
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0 and pname not in ["script","material_override","material_overlay","name","owner","transform","position","rotation","rotation_degrees","quaternion","basis","scale","visible"]:names.append(pname)
	if _label_property_records.size()>=64:
		for old_id in _label_property_records.keys():_invalidate_label_properties(old_id)
	_label_property_records[id]={"reference":weakref(label),"names":names}
	var callback: Callable=_invalidate_label_properties.bind(id)
	if not label.property_list_changed.is_connected(callback):label.property_list_changed.connect(callback)
	return names

func _source_uniform_names(shader: Shader) -> Array[String]:
	# On the first frame the renderer's reflected list may still be empty.
	# Source declarations are available synchronously, including texture/ST and
	# animated parameters. Reflection is supplementary, never the sole source.
	var names: Array[String]=[]
	var comments:=RegEx.new()
	comments.compile("(?s)/\\*.*?\\*/|//[^\\n]*")
	var code:=comments.sub(shader.code,"",true)
	var declarations:=RegEx.new()
	declarations.compile("\\buniform\\s+(?:(?:lowp|mediump|highp)\\s+)?[A-Za-z_][A-Za-z_0-9]*\\s+([A-Za-z_][A-Za-z_0-9]*)")
	for declaration in declarations.search_all(code):
		var uniform_name:=declaration.get_string(1)
		if not names.has(uniform_name):names.append(uniform_name)
	for parameter in shader.get_shader_uniform_list():
		var uniform_name: String=parameter.name
		if not names.has(uniform_name):names.append(uniform_name)
	return names

func _transmission_shader(code: String) -> String:
	# T propagates through exactly the same fixed-function destination blend:
	# mix/premul: T*(1-alpha), additive/subtractive: T, opaque: 0, multiply: T*RGB.
	# Preserve ALL source calculations, vertex displacement, alpha and discard.
	# In particular, do not introduce ALPHA into an opaque source shader.
	var mode_at:=code.find("render_mode")
	var mode_end:=code.find(";",mode_at)
	var modes:=code.substr(mode_at,mode_end-mode_at) if mode_at>=0 else ""
	if not modes.contains("unshaded"):
		if mode_at>=0:code=code.insert(mode_at+"render_mode".length()," unshaded,")
		else:code=code.replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
	if modes.contains("blend_mul"):return code
	var fragment_at:=code.find("void fragment()")
	if fragment_at<0:
		_warn_once("Source shader has no recognized fragment entry point")
		return code
	var open_at:=code.find("{",fragment_at)
	var depth:=1
	var close_at:=open_at+1
	while close_at<code.length() and depth>0:
		if code[close_at]=="{":depth+=1
		elif code[close_at]=="}":depth-=1
		close_at+=1
	if depth!=0:
		_warn_once("Could not locate source fragment closing brace")
		return code
	return code.insert(close_at-1,"\n // Transmission pass: remove only the source radiance term.\n ALBEDO=vec3(0.0); EMISSION=vec3(0.0);\n")

func _warn_once(message: String) -> void:
	if not warnings.has(message):
		warnings.append(message)
		push_warning(message)

func audit() -> Dictionary:
	return {"geometry_count":mirrors.size(),"material_count":material_cache.size(),"shader_count":shader_cache.size(),"warnings":warnings.duplicate(),"frame":frame_number,"equation":"C + RGB_T * background","copies_game_logic":false}

