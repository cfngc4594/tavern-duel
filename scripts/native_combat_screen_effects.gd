extends Node
## Current-cardpool ScreenEffects camera chain, separate from ordinary RTT.
## Same-build ScreenEffectsPass 0x060162b9 / callbacks 0x060162c7.
## The two enabled Flamestrike ScreenEffectGlow components gate this graph.
## Existing Godot scene depth is rebuilt from depth-writing geometry only.
const GLOW = preload('res://shaders/native_combat_screen_glow.gdshader')
const COMBINE = preload('res://shaders/native_combat_r2t_combine.gdshader')
const PREPASS = preload('res://shaders/native_combat_screen_mask_prepass.gdshader')
var game: Node
var assets
var registrations:Array=[]
var graph:Node
var views:Array=[]
var masks:Dictionary={}
var passes:Array=[]
var overlay:ColorRect
var helper
var prepass_material:ShaderMaterial
var depth_shaders:Dictionary={}
var depth_materials:Dictionary={}
var glow_materials:Dictionary={}
var uniform_names:Dictionary={}
var mirrors:Dictionary={}
var warnings:Array=[]
var active_components:Array=[]
var frame_serial:=0
var scope_serial:=0
var disposed:=false
var enabled:=false
var dimensions:=Vector2i.ZERO
var source_dimensions:=Vector2i.ZERO
var target_scale:=0.5 if OS.has_feature('android') else 1.0
var counters:Dictionary={}

func setup(owner_game:Node,source_assets)->void:
	game=owner_game;assets=source_assets;disposed=false
	prepass_material=ShaderMaterial.new();prepass_material.shader=PREPASS
	for record in assets.objects.values():
		if record.get('class_name','')=='ScreenEffectGlow' and bool(record.data.get('m_Enabled',false)):
			registrations.append(record)
	if ResourceLoader.exists('res://scripts/native_combat_screen_materials.gd'):
		helper=load('res://scripts/native_combat_screen_materials.gd').new()
	# The original pass1 is base+blur with One/Zero. The production canvas has
	# already composed C+T*background and is opaque. One/(1-0) adds exactly the
	# recovered blur RGB after that composition, without multiplying it by T again.
	var shader:=Shader.new()
	shader.code='shader_type canvas_item; render_mode unshaded, blend_premul_alpha; uniform sampler2D glow_texture: filter_linear, repeat_disable; void fragment(){COLOR=vec4(texture(glow_texture,UV).rgb,0.0);}'
	var material:=ShaderMaterial.new();material.shader=shader
	overlay=ColorRect.new();overlay.name='OriginalScreenGlowAfterComposite';overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.material=material;overlay.visible=false
	game.world_canvas.add_child(overlay)

func _make_graph(size:Vector2i,source_view:SubViewport)->void:
	graph=Node.new();graph.name='ScreenEffectsScope_%d'%scope_serial;add_child(graph)
	dimensions=size;source_dimensions=source_view.size
	for kind in ['color','alpha']:
		var view:=SubViewport.new();view.name='SE_Mask_'+kind;view.size=size;view.own_world_3d=true
		view.transparent_bg=false;view.msaa_3d=Viewport.MSAA_DISABLED if target_scale<1.0 else source_view.msaa_3d
		view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		graph.add_child(view);views.append(view)
		var world:=WorldEnvironment.new();world.environment=Environment.new()
		world.environment.background_mode=Environment.BG_COLOR
		world.environment.background_color=Color.BLACK if kind=='color' else Color.WHITE
		world.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;view.add_child(world)
		var geometry:=Node3D.new();view.add_child(geometry)
		var camera:=Camera3D.new();view.add_child(camera);camera.current=true
		masks[kind]={'view':view,'geometry':geometry,'camera':camera}
	var rgba:=_pass(COMBINE,masks.color.view.get_texture(),'SE_Mask_RGBA')
	rgba.material.set_shader_parameter('_AlphaTex',masks.alpha.view.get_texture());rgba.material.set_shader_parameter('_AddAlpha',false)
	var texture:Texture2D=rgba.view.get_texture()
	for i in range(2):
		var blur:=_pass(GLOW,texture,'SE_Blur_%d'%(i+1))
		blur.material.set_shader_parameter('_Pass',0);blur.material.set_shader_parameter('_BlurOffset',float(i+1));blur.material.set_shader_parameter('_MipLevel',0)
		# Preserve the UV-space glow radius when the sampling grid is reduced.
		blur.material.set_shader_parameter('_BlitTexture_TexelSize',Vector4(1.0/source_dimensions.x,1.0/source_dimensions.y,source_dimensions.x,source_dimensions.y))
		texture=blur.view.get_texture()
	overlay.size=game.presentation_size if game.get('source_projection')!=null else Vector2(1600,900)
	overlay.position=-game.presentation_offset if game.get('source_projection')!=null else Vector2.ZERO
	overlay.material.set_shader_parameter('glow_texture',texture)

func _pass(shader:Shader,texture:Texture2D,label:String)->Dictionary:
	var view:=SubViewport.new();view.name=label;view.size=dimensions;view.disable_3d=true;view.transparent_bg=true
	view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	graph.add_child(view);views.append(view)
	var quad:=ColorRect.new();quad.size=Vector2(dimensions);quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter('_MainTex' if shader==COMBINE else '_BlitTexture',texture)
	quad.material=material;view.add_child(quad)
	var result={'view':view,'material':material};passes.append(result);return result

func sync(effects:Array,source_camera:Camera3D)->void:
	if disposed or not is_instance_valid(game) or not is_instance_valid(source_camera):return
	frame_serial+=1;active_components.clear()
	var selected:Array=[]
	for effect in effects:
		var state:Dictionary=effect.get('state',{})
		for registration in registrations:
			var key:String=registration.refs.get('.m_GameObject','')
			var owner:Node3D=state.get('nodes',{}).get(key)
			if not is_instance_valid(owner) or not owner.is_visible_in_tree():continue
			active_components.append(registration.key)
			# The current two original components remain on Default (RenderGlowOnly=false).
			var source:MeshInstance3D=state.get('renderers',{}).get(key)
			if is_instance_valid(source) and source.is_visible_in_tree() and source.layers!=0:selected.append(source)
	enabled=not active_components.is_empty()
	if not enabled:
		if is_instance_valid(graph):clear()
		else:_disable()
		return
	if helper==null:
		_warn('Original screen-pass material factory is unavailable');_disable();return
	var source_view:=source_camera.get_viewport() as SubViewport
	if source_view==null:_warn('Source camera has no SubViewport target');_disable();return
	var source_size:=source_view.size
	var target_size:=Vector2i(maxi(1,roundi(source_size.x*target_scale)),maxi(1,roundi(source_size.y*target_scale)))
	if is_instance_valid(graph) and (dimensions!=target_size or source_dimensions!=source_size):
		var registered:=active_components.duplicate();clear();active_components=registered;enabled=true
	if not is_instance_valid(graph):_make_graph(target_size,source_view)
	for view in views:view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	overlay.visible=true
	for kind in ['color','alpha']:
		var camera:Camera3D=masks[kind].camera
		for property in ['projection','keep_aspect','fov','size','frustum_offset','near','far','h_offset','v_offset','cull_mask']:camera.set(property,source_camera.get(property))
		camera.global_transform=source_camera.global_transform
	var seen:Dictionary={};counters={'depth_surfaces':0,'cardraycast_surfaces':0,'glow_surfaces':0,'hidden_excluded':0}
	var geometry:Array=[];_collect(game.spatial_scene,geometry)
	for source in geometry:
		if not source.is_visible_in_tree() or (source.layers&source_camera.cull_mask)==0:
			counters.hidden_excluded+=1;continue
		if source.mesh==null:continue
		for surface in range(source.mesh.get_surface_count()):
			var material:Material=source.get_active_material(surface)
			var layer:=_source_layer(source)
			if layer==8:
				for kind in ['color','alpha']:_mirror(source,surface,prepass_material,kind,'cardraycast',seen)
				counters.cardraycast_surfaces+=1
			elif _writes_depth(material):
				for kind in ['color','alpha']:
					var depth=_depth_material(material,kind)
					if depth!=null:_mirror(source,surface,depth,kind,'depth',seen)
				counters.depth_surfaces+=1
	for source in selected:
		if (source.layers&source_camera.cull_mask)==0:continue
		var layer:=_source_layer(source)
		if not layer in [0,23]:continue
		for surface in range(source.mesh.get_surface_count()):
			var original:Material=source.get_active_material(surface)
			for kind in ['color','alpha']:
				var material:Material=helper.glow_material(original,'GlowAdditive',kind=='alpha')
				if material!=null:_mirror(source,surface,_glow_depth_override(material),kind,'glow',seen)
			counters.glow_surfaces+=1
	for key in mirrors.keys():
		if not seen.has(key):mirrors[key].queue_free();mirrors.erase(key)

func _source_layer(source:Node)->int:
	var current:Node=source
	while current!=null:
		var key:String=current.get_meta('source_key','')
		if assets.objects.has(key):return int(assets.objects[key].data.get('m_Layer',0))
		if is_instance_valid(game.native_summon) and game.native_summon.assets.objects.has(key):return int(game.native_summon.assets.objects[key].data.get('m_Layer',0))
		current=current.get_parent()
	return -1 # Compatibility geometry is not silently assigned a Unity source layer.

func _collect(node:Node,result:Array)->void:
	if node is SubViewport:return
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():_collect(child,result)

func _mirror(source:MeshInstance3D,surface:int,material:Material,kind:String,role:String,seen:Dictionary)->void:
	var key='%d:%d:%s:%s'%[source.get_instance_id(),surface,kind,role];seen[key]=true
	var target:MeshInstance3D=mirrors.get(key)
	if target==null:
		target=MeshInstance3D.new();target.name='Screen_'+role+'_'+kind;target.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		masks[kind].geometry.add_child(target);mirrors[key]=target
	var mesh_id:=source.mesh.get_instance_id()
	if target.get_meta('mesh_source',0)!=mesh_id:
		# The color/alpha mirrors have independent materials and share the same
		# extracted surface. Compatibility otherwise reads back GPU arrays twice.
		var other_kind:='alpha' if kind=='color' else 'color'
		var paired:MeshInstance3D=mirrors.get('%d:%d:%s:%s'%[source.get_instance_id(),surface,other_kind,role])
		if is_instance_valid(paired) and paired.get_meta('mesh_source',0)==mesh_id:
			target.mesh=paired.mesh
		else:
			var single:=ArrayMesh.new();single.add_surface_from_arrays(source.mesh.surface_get_primitive_type(surface) if source.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES,source.mesh.surface_get_arrays(surface))
			target.mesh=single
		target.set_meta('mesh_source',mesh_id)
	target.global_transform=source.global_transform;target.layers=source.layers;target.visible=source.is_visible_in_tree()
	target.sorting_offset=source.sorting_offset;target.extra_cull_margin=source.extra_cull_margin
	if source.skin!=null:_warn('Skinned depth geometry needs a mirrored skeleton: '+str(source.get_path()))
	if target.material_override!=material:target.material_override=material

func _writes_depth(material:Material)->bool:
	if material is BaseMaterial3D:
		return material.depth_draw_mode!=BaseMaterial3D.DEPTH_DRAW_DISABLED and (material.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] or material.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_ALWAYS)
	if not material is ShaderMaterial:return material==null
	var code:String=material.shader.code
	if code.contains('depth_draw_never'):return false
	if code.contains('depth_prepass_alpha') or code.contains('ALPHA_HASH_SCALE'):
		_warn('Unsupported source depth prepass/hash requires an exact alpha-depth bridge: '+material.shader.resource_path);return false
	return code.contains('depth_draw_always') or not RegEx.create_from_string('\\bALPHA\\s*=').search(code)

func _names(shader:Shader)->Array:
	var id:=shader.get_instance_id()
	if not uniform_names.has(id):
		var names:Array=[];var regex:=RegEx.new();regex.compile('\\buniform\\s+\\w+\\s+([A-Za-z_][A-Za-z_0-9]*)')
		for found in regex.search_all(shader.code):names.append(found.get_string(1))
		uniform_names[id]=names
	return uniform_names[id]

func _copy(source:ShaderMaterial,target:ShaderMaterial)->void:
	for parameter in _names(source.shader):target.set_shader_parameter(parameter,source.get_shader_parameter(parameter))

func _glow_depth_override(source:Material)->Material:
	if not source is ShaderMaterial:return source
	var id:=source.get_instance_id()
	if not glow_materials.has(id):
		var shader:=Shader.new();shader.code=source.shader.code.replace('depth_draw_never','depth_draw_always')
		var material:=ShaderMaterial.new();material.shader=shader;material.render_priority=0;glow_materials[id]=material
	_copy(source,glow_materials[id]);glow_materials[id].render_priority=source.render_priority
	return glow_materials[id]

func _depth_material(source:Material,kind:String)->Material:
	var key='%s:%s'%[str(source.get_instance_id()) if source!=null else 'default',kind]
	if source is ShaderMaterial:
		if not depth_materials.has(key):
			var code:String=source.shader.code
			var shader_key:=str(source.shader.get_instance_id())+kind
			if not depth_shaders.has(shader_key):
				var transparent:=RegEx.create_from_string('\\bALPHA\\s*=').search(code)!=null
				var scissor:=code.contains('ALPHA_SCISSOR_THRESHOLD')
				if scissor:code=code.replace('ALPHA_SCISSOR_THRESHOLD','screen_depth_cutoff')
				var fragment:=code.find('void fragment()')
				if fragment<0:_warn('Depth source lacks a fragment entry');return null
				var begin:=code.find('{',fragment)
				if scissor:code=code.insert(begin+1,'\n float screen_depth_cutoff=0.0;\n')
				var end:=begin+1;var nesting:=1
				while end<code.length() and nesting>0:
					if code[end]=='{':nesting+=1
					elif code[end]=='}':nesting-=1
					end+=1
				var final:='\n ALBEDO=vec3('+('0.0' if kind=='color' else '1.0')+');\n'
				if transparent:
					if scissor:final+='if(ALPHA<screen_depth_cutoff)discard;\n'
					final+='ALBEDO=vec3(0.0); ALPHA=0.0;\n'
				code=code.insert(end-1,final)
				if transparent:
					var blend:=RegEx.new();blend.compile('blend_(mix|add|sub|mul|premul_alpha)')
					code=blend.sub(code,'blend_premul_alpha',true)
					if not code.contains('blend_premul_alpha'):code=code.replace('render_mode','render_mode blend_premul_alpha,')
				var shader:=Shader.new();shader.code=code;depth_shaders[shader_key]=shader
			var material:=ShaderMaterial.new();material.shader=depth_shaders[shader_key];material.render_priority=-128;depth_materials[key]=material
		_copy(source,depth_materials[key]);return depth_materials[key]
	if not depth_materials.has(key):
		var shader:=Shader.new()
		var cull:='cull_back';var no_depth_test:=''
		if source is BaseMaterial3D:
			cull=['cull_back','cull_front','cull_disabled'][source.cull_mode]
			if source.no_depth_test:no_depth_test=', depth_test_disabled'
		shader.code='shader_type spatial; render_mode unshaded,depth_draw_opaque,'+cull+no_depth_test+'; uniform sampler2D source_texture:filter_linear; uniform vec4 depth_source_color=vec4(1); uniform bool use_texture=false; uniform bool clip_alpha=false; uniform bool use_vertex_alpha=false; uniform float clip_threshold=.5; uniform vec4 source_uv=vec4(1,1,0,0); varying float depth_vertex_alpha; void vertex(){depth_vertex_alpha=COLOR.a;} void fragment(){float a=depth_source_color.a*(use_texture?texture(source_texture,UV*source_uv.xy+source_uv.zw).a:1.0)*(use_vertex_alpha?depth_vertex_alpha:1.0);if(clip_alpha&&a<clip_threshold)discard;ALBEDO=vec3('+('0.0' if kind=='color' else '1.0')+');}'
		var material:=ShaderMaterial.new();material.shader=shader;material.render_priority=-128;depth_materials[key]=material
	var material:ShaderMaterial=depth_materials[key]
	if source is BaseMaterial3D:
		material.set_shader_parameter('source_texture',source.albedo_texture);material.set_shader_parameter('use_texture',source.albedo_texture!=null)
		material.set_shader_parameter('depth_source_color',source.albedo_color);material.set_shader_parameter('clip_alpha',source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		material.set_shader_parameter('use_vertex_alpha',source.vertex_color_use_as_albedo);material.set_shader_parameter('clip_threshold',source.alpha_scissor_threshold)
		material.set_shader_parameter('source_uv',Vector4(source.uv1_scale.x,source.uv1_scale.y,source.uv1_offset.x,source.uv1_offset.y))
	return material

func _disable()->void:
	enabled=false
	if is_instance_valid(overlay):overlay.visible=false
	for view in views:
		if is_instance_valid(view):view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func clear()->void:
	_disable();scope_serial+=1;active_components.clear()
	# The overlay outlives its graph; do not keep its last ViewportTexture alive.
	if is_instance_valid(overlay):overlay.material.set_shader_parameter("glow_texture",null)
	if is_instance_valid(graph):graph.queue_free()
	graph=null;views.clear();masks.clear();passes.clear();mirrors.clear();depth_materials.clear();glow_materials.clear();depth_shaders.clear();uniform_names.clear();dimensions=Vector2i.ZERO;source_dimensions=Vector2i.ZERO
	if helper!=null:helper.clear()

func dispose()->void:
	if disposed:return
	clear();disposed=true
	if is_instance_valid(overlay):overlay.queue_free()
	helper=null

func _warn(message:String)->void:
	if not warnings.has(message):warnings.append(message)

func get_audit()->Dictionary:
	return {'enabled':enabled,'disposed':disposed,'scope_serial':scope_serial,'frame_serial':frame_serial,'active_components':active_components.duplicate(),'dimensions':[dimensions.x,dimensions.y],'source_dimensions':[source_dimensions.x,source_dimensions.y],'target_scale':target_scale,'source_format':'ARGB2101010 (raw8)','backend_format':'Godot Compatibility RGBA8, not original 10/10/10/2 precision','source_pass':'ScreenEffectsPass after transparents500, 4tap offsets1/2, base+blur','depth_bridge':'Actual depth-writing production geometry mirrored with source visibility and clipping; no new board geometry','composite_bridge':'Glow RGB added after C+T*background exactly once, opaque final canvas alpha retained','counters':counters.duplicate(),'mirrors':mirrors.size(),'live_viewports':views.size(),'warnings':warnings.duplicate(),'native_pixel_equivalence':false}
