class_name NativeCardRenderer
extends Node
signal card_texture_ready(key: String, texture: Texture2D, owner_renderer: Node)
var texture_cache_controller: Node
# Original hierarchy/geometry/UV and locale font mapping. Godot rasterization is
# an explicit compatibility implementation, not an original Unity runtime.
const BASE = 'res://assets/native_cards/'
var data: Dictionary
var meshes = {}
var materials = {}
var textures = {}
var profiles = {}
var geometry_cache = {}
var cards = {}
var missing_glyphs = []
var unresolved_frames = []
var compatibility_fallbacks = []
var summon_source_assets
var font: Font
var title_font: Font
var number_font: Font
var gem_shader: Shader
var pending_freezes = {}
var mask_shader_cache = {}
var race_bounds = {}
var visual_metadata = {}
var visual_assets = {}
var verified_resource_sampling = {}
var rarity_profiles = {}
var rarity_variants = {}
var body_bundle = {}
var number_bundle = {}
var rich_descriptions = {}
var unity_sample = {}
var unity_glyphs = {}
var unity_text_bounds = {}
var unity_atlas: Texture2D
func vec(d): return Vector3(d.x,d.y,d.z)
func col(d): return Color(d.r,d.g,d.b,d.a)
func vec3color(d): return Vector3(d.r,d.g,d.b)
func _ready():
	texture_cache_controller=preload("res://scripts/native_card_texture_cache.gd").new();add_child(texture_cache_controller);texture_cache_controller.setup(self)
	verified_resource_sampling=JSON.parse_string(FileAccess.get_file_as_string(BASE+'source_materials/verified_resource_sampling.json')).textures
	data=JSON.parse_string(FileAccess.get_file_as_string(BASE+'OriginalCards/card_assets.json'))
	font=load(BASE+'OriginalCards/Fonts/BlizzardGlobal__2407746389514081280.ttf')
	title_font=load(BASE+'OriginalCards/Fonts/GLEI00M_t_Outline__4016971574774461928.ttf')
	number_font=load(BASE+'OriginalCards/Fonts/Belwe_Outline__4766376857981636630.ttf')
	gem_shader=load(BASE+'source_gem.gdshader')
	for sample in JSON.parse_string(FileAccess.get_file_as_string(BASE+'evidence/v25_text/race-bounds.json')).texts:race_bounds[sample.text]=sample
	body_bundle=_load_glyph_bundle('res://assets/unity_body_sample/')
	number_bundle=_load_glyph_bundle('res://assets/unity_number_sample/')
	rich_descriptions=JSON.parse_string(FileAccess.get_file_as_string(BASE+'evidence/v25_text/rich_desc_5834.json')).cards
	unity_sample=JSON.parse_string(FileAccess.get_file_as_string('res://assets/unity_middle_sample/glyphs.json'))
	unity_atlas=load('res://assets/unity_middle_sample/atlas_rgba.png')
	for glyph in unity_sample.glyphs:unity_glyphs[glyph.character]=glyph
	for text_sample in unity_sample.texts:unity_text_bounds[text_sample.text]=text_sample.rendererWorldBounds
	for d in data.meshes: meshes[d.key]=d
	for d in data.materials: materials[d.key]=d
	for d in data.textures: textures[d.key]=load(BASE+d.resource+'.png')
	for d in data.profiles: profiles[d.name]=d
	# Modern visual tags are isolated from historical rules and rich text.
	var visual_path=BASE+'evidence/visual_binding/visual_metadata_37.json'
	if FileAccess.file_exists(visual_path):visual_metadata=JSON.parse_string(FileAccess.get_file_as_string(visual_path)).get('cards',{})
	var rarity_path=BASE+'rarity_sources/rarity_material_bindings.json'
	if FileAccess.file_exists(rarity_path):
		visual_assets=JSON.parse_string(FileAccess.get_file_as_string(rarity_path));rarity_variants=visual_assets.runtime_variants
		for md in visual_assets.materials:materials[md.key]=md
		for tx in visual_assets.textures:textures[tx.key]=load(BASE+tx.resource+'.png')
	for kind in ['minion','spell']:
		var path=BASE+'rarity_sources/'+kind+'_geometry.json'
		if FileAccess.file_exists(path):
			var extra=JSON.parse_string(FileAccess.get_file_as_string(path));rarity_profiles[kind]=extra
			for mesh in extra.meshes:meshes[mesh.key]=mesh
func _load_glyph_bundle(path):
	if not FileAccess.file_exists(path+'glyphs.json'):return {}
	var sample=JSON.parse_string(FileAccess.get_file_as_string(path+'glyphs.json'));var glyphs={}
	for glyph in sample.glyphs:
		if glyph.available:glyphs[glyph.character]=glyph
	return {'sample':sample,'glyphs':glyphs,'atlas':load(path+'atlas_rgba.png'),'size':Vector2(sample.atlasWidth,sample.atlasHeight)}
func _audit_text(key,text,f):
	for ch in str(text):
		if ch=='\n' or ch=='\t':continue
		if not f.has_char(ch.unicode_at(0)):
			var missing={'card':key,'character':ch}
			if not missing_glyphs.has(missing):missing_glyphs.append(missing)
func get_audit():
	var info={}
	for key in cards:info[key]={'cost':cards[key].cost,'title_size':cards[key].title_size,'description_size':cards[key].description_size,'frame':cards[key].frame,'race':cards[key].race,'visual_binding':cards[key].get('visual_binding',{}),'whole_card_source_alpha':cards[key].has('card_blend_targets'),'title_equations':cards[key].get('title_equations',{}),'race_equations':cards[key].get('race_equations',{}),'description_equations':cards[key].get('description_equations',{}),'number_equations':cards[key].get('number_equations',{}),'frozen':true if cards[key].viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED else null,'update_mode':cards[key].viewport.render_target_update_mode,'update_mode_name':['DISABLED','ONCE','WHEN_VISIBLE','WHEN_PARENT_VISIBLE','ALWAYS'][int(cards[key].viewport.render_target_update_mode)],'pending_redraw':pending_freezes.has(cards[key].viewport.get_instance_id()),'freeze_observation':'ONCE consumption not proven by property getter; null is unknown, not running'}
	return {'card_count':cards.size(),'cards':info,'missing_glyphs':missing_glyphs.duplicate(),'unresolved_frames':unresolved_frames.duplicate(),'compatibility_fallbacks':compatibility_fallbacks.duplicate(),'native_mesh':true,'native_title_rtt':true,'godot_text_rasterization':true,'texture_cache':texture_cache_controller.get_audit() if is_instance_valid(texture_cache_controller) else {}}.duplicate(true)
func _geometry(d,flipped_surfaces=[]):
	var cache_key=d.key+str(flipped_surfaces)
	if geometry_cache.has(cache_key):return geometry_cache[cache_key]
	var mesh=ArrayMesh.new();var ps=PackedVector3Array();var uv=PackedVector2Array();var uv2=PackedVector2Array();var normals=PackedVector3Array();var colors=PackedColorArray()
	for i in range(0,d.positions.size(),3):ps.append(Vector3(d.positions[i],d.positions[i+1],d.positions[i+2]))
	var uvdata=d.uvs[0]['values']
	for i in range(0,uvdata.size(),2):uv.append(Vector2(uvdata[i],1.0-uvdata[i+1]))
	for channel in d.uvs:
		if int(channel.channel)==1:
			for i in range(0,channel['values'].size(),2):uv2.append(Vector2(channel['values'][i],1.0-channel['values'][i+1]))
	var normal_stride=int(d.normals.size()/ps.size()) if ps.size()>0 else 0
	if normal_stride>=3:
		for i in range(ps.size()):normals.append(Vector3(d.normals[i*normal_stride],d.normals[i*normal_stride+1],d.normals[i*normal_stride+2]))
	for i in range(0,d.colors.size(),4):colors.append(Color(d.colors[i]/255.0,d.colors[i+1]/255.0,d.colors[i+2]/255.0,d.colors[i+3]/255.0))
	if colors.is_empty():
		colors.resize(ps.size());colors.fill(Color.WHITE) # source channel absent, Unity documented white default
	var surface_index=0
	for sub in d.submeshes:
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=ps;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(sub.indices)
		if uv2.size()==ps.size():arrays[Mesh.ARRAY_TEX_UV2]=uv2
		if normals.size()==ps.size():arrays[Mesh.ARRAY_NORMAL]=normals
		if colors.size()==ps.size():arrays[Mesh.ARRAY_COLOR]=colors
		if surface_index in flipped_surfaces:
			var indices=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var hold=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=hold
			arrays[Mesh.ARRAY_INDEX]=indices
		surface_index+=1
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	geometry_cache[cache_key]=mesh;return mesh
func card_raster_scale() -> float:
	# Local high-quality RTT tier; source geometry/glyph metrics stay unchanged.
	# Mirrors the original per-RTT high tier1.5, not a global Unity renderScale.
	return 1.5 if minf(float(get_window().size.x)/1600.0,float(get_window().size.y)/900.0)>1.0 else 1.0

func build_card(key: String,d: Dictionary,portrait: Texture2D)->Texture2D:
	if cards.has(key):return cards[key].get('cached_output',cards[key].get('output_viewport',cards[key].viewport).get_texture())
	var minion=d.kind=='minion';var prof=profiles['minion_in_hand' if minion else 'spell_in_hand']
	var vp=SubViewport.new();vp.name='NativeCard_'+key;vp.size=Vector2i(Vector2(328,484)*card_raster_scale());vp.transparent_bg=true;vp.own_world_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.msaa_3d=Viewport.MSAA_2X;add_child(vp)
	var root=Node3D.new();vp.add_child(root);root.scale.z=-1
	var nodes={}
	for n in prof.nodes:
		var node=Node3D.new();node.name=n.name;nodes[n.id]=node
	for n in prof.nodes:
		var node=nodes[n.id]
		if n.parentId=='':root.add_child(node)
		else:nodes[n.parentId].add_child(node)
		node.position=Vector3.ZERO if n.parentId=='' else vec(n.position)
		node.quaternion=Quaternion(n.rotation.x,n.rotation.y,n.rotation.z,n.rotation.w);node.scale=vec(n.scale)
	var frame=d.get('frame','frame-minion-neutral' if minion else 'frame-spell-mage')
	var atlas_file=BASE+'atlas_'+str(frame).trim_prefix('frame-').replace('-','_')+'.png'
	var atlas: Texture2D
	if ResourceLoader.exists(atlas_file):atlas=load(atlas_file)

	else:unresolved_frames.append({'card':key,'frame':frame})
	for r in prof.renderers:
		if r.get('readyHighlight',false) or r.get('staticShadow',false) or not r.enabled:continue
		if 'Highlight' in str(nodes[r.nodeId].name):continue
		var flipped=[]
		for si in range(r.materialKeys.size()):
			if str(materials[r.materialKeys[si]].sourceShaderKey).get_slice(':',1) in ['-2508996697480494289','-1982294586754922726','9099378368919310605','-5812771937585292081']:flipped.append(si)
		var mi=MeshInstance3D.new();mi.mesh=_geometry(meshes[r.meshKey],flipped);nodes[r.nodeId].add_child(mi)
		for si in range(mi.mesh.get_surface_count()):
			var md=materials[r.materialKeys[mini(si,r.materialKeys.size()-1)]]
			var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
			for tx in md.textures:
				if tx.name=='_MainTex' and textures.has(tx.key):mat.albedo_texture=textures[tx.key];mat.uv1_scale=Vector3(tx.scale.x,tx.scale.y,1);mat.uv1_offset=Vector3(tx.offset.x,tx.offset.y,0)
			if r.nodeId==prof.portraitNodeId and si==int(prof.portraitMaterialIndex):mat.albedo_texture=portrait
			var frame_nodes=['-588361756091118313'] if minion else ['3807802336216085126','467724817657098886']
			if atlas!=null and si==0 and r.nodeId in frame_nodes:mat.albedo_texture=atlas
			if md.sourceShaderKey.ends_with(':3271891197657001233'):
				# Original UnlitTextureDualClass pass is Opaque. Atlas alpha is not coverage.
				mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
			if md.sourceShaderKey.ends_with(':-2508996697480494289'):
				# Original Unlit_Portrait color pass One/Zero, ZWrite1, CullBack.
				mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED;mat.cull_mode=BaseMaterial3D.CULL_BACK;mat.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
			mi.set_surface_override_material(si,_source_material(md,mat,str(d.get('race_name',''))!=''))
	var state={'viewport':vp,'cost':int(d.cost),'base_cost':int(d.cost),'cost_label':null,'title_size':0,'description_size':0,'frame':frame,'race':d.get('race_name','')};cards[key]=state
	state.visual_binding={'status':'pending_verified_binding' if visual_metadata.has(key) else 'no_modern_visual_metadata','modern_metadata':visual_metadata.get(key,{}).duplicate(true),'rule_source':'5834 unchanged'}
	_add_name(nodes,str(d.name),minion,key)
	_add_labels(nodes,prof,d,key)
	if minion and str(d.get('race_name',''))!='':_add_race_plate(nodes)
	_apply_visual_binding(key,nodes,minion)
	var cam=Camera3D.new();vp.add_child(cam);cam.position=Vector3(-0.0553,7,-0.0408) if minion else Vector3(-0.05385,7,-0.04296);cam.rotation_degrees=Vector3(-90,0,0);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3.35 if minion else 3.23;cam.current=true
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0);vp.add_child(env)
	var output=_source_alpha_card(vp,key)
	_freeze_later(vp,9)
	return output.get_texture()
func _freeze_later(vp,frames=3):
	# One pending request per viewport, no suspended coroutine can outlive this node.
	pending_freezes[vp.get_instance_id()]={'viewport':weakref(vp),'frames':frames}
	if is_instance_valid(texture_cache_controller):texture_cache_controller.schedule()
	set_process(true)
func _process(_delta):
	for id in pending_freezes.keys():
		var request=pending_freezes[id]
		var vp=request.viewport.get_ref()
		if not is_instance_valid(vp):
			pending_freezes.erase(id)
			continue
		request.frames-=1
		if request.frames<=0:
			# UPDATE_ONCE disables itself after an actual render, unlike a process-frame freeze.
			vp.render_target_update_mode=SubViewport.UPDATE_ONCE
			pending_freezes.erase(id)
	if pending_freezes.is_empty():set_process(false)
func _exit_tree():
	pending_freezes.clear()
func update_cost(key,cost):
	if not cards.has(key):return
	if is_instance_valid(texture_cache_controller):texture_cache_controller.prepare_cost_redraw(key)
	cards[key].cost=int(cost)
	if cards[key].has('cost_native'):
		var native=cards[key].cost_native
		var tint=Color.GREEN if int(cost)<cards[key].base_cost else (Color.RED if int(cost)>cards[key].base_cost else Color.WHITE)
		var spec=native.spec.duplicate(true);spec.color={'r':tint.r,'g':tint.g,'b':tint.b,'a':tint.a}
		var result=_add_direct_glyphs(native.parent,str(cost),spec,number_bundle.glyphs,number_bundle.atlas,number_bundle.size,74,{'ascent':900.0,'descent':-124.0,'line_gap':6.0,'units':1024.0})
		if result!=null:
			if is_instance_valid(native.node):native.node.get_parent().remove_child(native.node);native.node.queue_free()
			native.node=result.node;cards[key].number_equations.cost.character_size=result.character_size;cards[key].number_equations.cost.color=[tint.r,tint.g,tint.b,tint.a]
	if is_instance_valid(cards[key].cost_label):
		cards[key].cost_label.text=str(cost)
		cards[key].cost_label.modulate=Color.GREEN if int(cost)<cards[key].base_cost else (Color.RED if int(cost)>cards[key].base_cost else Color.WHITE)
	cards[key].viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_freeze_later(cards[key].viewport)
	if cards[key].has('card_blend_targets'):
		_sync_card_mask(key)
		cards[key].card_blend_targets.mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		cards[key].output_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		_freeze_later(cards[key].card_blend_targets.mask,3);_freeze_later(cards[key].output_viewport,6)
func _add_name(nodes,title,minion,key):
	var meshid='8694985930566816389' if minion else '8902536718298385945'
	var nodeid='-3331166760336192233' if minion else '1668453833425154694'
	var d=JSON.parse_string(FileAccess.get_file_as_string(BASE+meshid+'.mesh.json'))
	# Source CalcTextureSize and TextMesh character sizing. Native glyph metrics are
	# unavailable; Godot metrics below are explicitly a compatibility measurement.
	var width=1.9;var height=0.3 if minion else 0.28;var resolution=300.0*card_raster_scale()
	var rt=SubViewport.new();rt.size=Vector2i(int(resolution),int(resolution*height/width));rt.transparent_bg=true;rt.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(rt)
	# Source SetTargetClearColor retains outline RGB at alpha zero. An explicit
	# non-blended canvas clear preserves these channels rather than transparent black.
	var clear_rect=ColorRect.new();clear_rect.size=rt.size
	var clear_material=ShaderMaterial.new();clear_material.shader=load(BASE+'source_title_clear.gdshader');clear_rect.material=clear_material;rt.add_child(clear_rect)
	var fs=int(PackedFloat32Array([40.0*1.149999976158142])[0]) # Unity float32 multiply then trunc
	var character_size=5.0*0.01
	var sampled=true
	for ch in title:
		if not unity_glyphs.has(ch):sampled=false
	var measured=title_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,fs)
	if sampled:
		var advance_width=0.0
		for ch in title:advance_width+=unity_glyphs[ch].advance
		# Same font46 line metrics measured from both native MiddleCenter samples.
		measured=Vector2(advance_width,4.626953125*10.0)
	var measured_height=measured.y if sampled else title_font.get_height(fs)
	var bounds=Vector2(measured.x,measured_height)*character_size*0.1
	var steps=0
	while (bounds.x>width or bounds.y>height) and steps<40:
		character_size=maxf(1.0*0.01,character_size*0.95);steps+=1
		bounds=Vector2(measured.x,measured_height)*character_size*0.1
	cards[key].title_size=fs;_audit_text(key,title,title_font)
	cards[key].title_equations={'rt_size':[rt.size.x,rt.size.y],'font_size':fs,'character_size':character_size,'resize_steps':steps,'source_width':width,'source_height':height,'bounds_provider':'Godot Font compatibility, not Unity TextMesh','missing_native_glyph_atlas':true}
	if sampled:
		cards[key].title_equations.bounds_provider='Unity CharacterInfo summed advances and measured same-font single-line height'
		cards[key].title_equations.missing_native_glyph_atlas=false
		cards[key].title_equations.glyph_provider='Unity 6000.3.10f1 Mac font46 alpha atlas + CharacterInfo; not original-client atlas'
		cards[key].title_equations.anchor_provider='MiddleCenter baseline from TTF hhea (ascent900 descent-124 lineGap6 units1024), independently registered to Unity screenshots; no native vertex export'
		_add_unity_title(rt,title,width,height,character_size)
	else:
		compatibility_fallbacks.append({'card':key,'component':'title','used':'Godot glyph atlas','reason':'Unity sampled glyph coverage unavailable'})
		var label=Label.new();label.text=title;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override('font',title_font);label.add_theme_font_size_override('font_size',fs);label.add_theme_color_override('font_color',Color.WHITE);label.add_theme_constant_override('outline_size',0)
		# Orthographic [-W/2,W/2] x [-H/2,H/2] to pixels; this is a 2D equivalent
		# mapping, not a claim that the Unity native TextMesh camera was executed.
		var glyph_scale=Vector2(float(rt.size.x)/width,float(rt.size.y)/height)*character_size*0.1
		label.scale=glyph_scale;label.size=Vector2(rt.size)/glyph_scale;rt.add_child(label)
		var outline=ShaderMaterial.new();outline.shader=load(BASE+'source_title_outline.gdshader');outline.set_shader_parameter('outline_texels',3.0);outline.set_shader_parameter('outline_color',Color(0.03921568766236305,0.0303975660353899,0.021530181169509888,1));label.material=outline
	var title_output=_source_alpha_title(rt,key)
	var arr=[];arr.resize(Mesh.ARRAY_MAX);var ps=PackedVector3Array();var uv=PackedVector2Array();var ix=PackedInt32Array()
	for p in d.positions:ps.append(Vector3(p[0],p[1],p[2]))
	for u in d.uvs:uv.append(Vector2(u[0],1-u[1]))
	for sub in d.triangles:
		for tri in sub:
			for i in [tri[0],tri[2],tri[1]]:ix.append(i) # mirror-converted name mesh winding, verified cull probe
	arr[Mesh.ARRAY_VERTEX]=ps;arr[Mesh.ARRAY_TEX_UV]=uv;arr[Mesh.ARRAY_INDEX]=ix
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var mat=ShaderMaterial.new();mat.shader=load(BASE+'source_title_antialias.gdshader');mat.set_shader_parameter('title_rt',title_output.get_texture());mat.set_shader_parameter('aa_offset',Vector2(0.5/rt.size.x,0.5/rt.size.y));mat.render_priority=10
	cards[key].title_equations.cull_state='original CullBack, name triangle winding adapted for Godot mirrored root; front/back GUI verified'
	cards[key].title_equations.final_antialias='source Hidden/TextAntialiasing center RGB + half sum of four half-texel diagonal alpha samples'
	mesh.surface_set_material(0,mat);var mi=MeshInstance3D.new();mi.mesh=mesh;nodes[nodeid].add_child(mi)
	_freeze_later(rt)
func _card_mask_material(original):
	if not original is ShaderMaterial:return original
	var mat=original.duplicate()
	if 'uniform bool alpha_mask_pass' in original.shader.code:
		mat.set_shader_parameter('alpha_mask_pass',true);return mat
	if not ('glyph_atlas' in original.shader.code or 'Hidden/TextAntialiasing' in original.shader.code):return original
	var shader_key=original.shader.get_instance_id()
	if not mask_shader_cache.has(shader_key):
		var code=original.shader.code
		var source=FileAccess.get_file_as_string(BASE+'source_materials/original_opaque_double.gdshader')
		var begin=source.find('vec3 mask_backend_inverse(');var end=source.find('void vertex()',begin)
		var inverse=source.substr(begin,end-begin)
		if not code.contains('vec3 mask_backend_inverse('):
			var fragment_at=code.find('void fragment()');code=code.insert(fragment_at,inverse)
		code=code.replace('ALBEDO=mask_backend_inverse(clamp(ALBEDO,vec3(0.0),vec3(1.0)));','')
		var last=code.rfind('}');code=code.insert(last,'\n ALBEDO=mask_backend_inverse(vec3(clamp(ALPHA,0.0,1.0)));\n')
		var shader=Shader.new();shader.code=code;mask_shader_cache[shader_key]=shader
	mat.shader=mask_shader_cache[shader_key];return mat
func _convert_card_mask(node):
	if node is MeshInstance3D and node.mesh!=null:
		for surface in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(surface,_card_mask_material(node.get_active_material(surface)))
	for child in node.get_children():_convert_card_mask(child)
func _sync_card_mask(key):
	var source=cards[key].viewport;var mask=cards[key].card_blend_targets.mask
	for child in mask.get_children():mask.remove_child(child);child.queue_free()
	for child in source.get_children():
		var copy=child.duplicate();mask.add_child(copy);_convert_card_mask(copy)
func _source_alpha_card(color_rt,key):
	var mask=SubViewport.new();mask.size=color_rt.size;mask.transparent_bg=true;mask.own_world_3d=true;mask.msaa_3d=color_rt.msaa_3d;mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(mask)
	var merged=SubViewport.new();merged.size=color_rt.size;merged.transparent_bg=true;merged.disable_3d=true;merged.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(merged)
	var rect=ColorRect.new();rect.size=merged.size;var mat=ShaderMaterial.new();mat.shader=load(BASE+'source_alpha_merge.gdshader');mat.set_shader_parameter('rgb_rt',color_rt.get_texture());mat.set_shader_parameter('mask_rt',mask.get_texture());rect.material=mat;merged.add_child(rect)
	cards[key].card_blend_targets={'rgb':color_rt,'mask':mask,'merged':merged};cards[key].output_viewport=merged
	_sync_card_mask(key);_freeze_later(mask,9);_freeze_later(merged,12)
	return merged
func _source_alpha_title(color_rt,key):
	# RGB blend matches original. Independent red mask realizes a*a+dstR*(1-a).
	var mask=SubViewport.new();mask.size=color_rt.size;mask.transparent_bg=true;mask.disable_3d=true;mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(mask)
	var mask_shader=load(BASE+'source_title_outline_mask.gdshader')
	for child in color_rt.get_children():
		var copy=child.duplicate();mask.add_child(copy)
		if child is ColorRect:
			var clear=ShaderMaterial.new();clear.shader=load(BASE+'source_title_mask_clear.gdshader');copy.material=clear
		elif child is CanvasItem and child.material is ShaderMaterial:
			var mat=child.material.duplicate();mat.shader=mask_shader;copy.material=mat
	var merged=SubViewport.new();merged.size=color_rt.size;merged.transparent_bg=true;merged.disable_3d=true;merged.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(merged)
	var rect=ColorRect.new();rect.size=merged.size;var material=ShaderMaterial.new();material.shader=load(BASE+'source_alpha_merge.gdshader');material.set_shader_parameter('rgb_rt',color_rt.get_texture());material.set_shader_parameter('mask_rt',mask.get_texture());rect.material=material;merged.add_child(rect)
	cards[key].title_blend_targets={'rgb':color_rt,'mask':mask,'merged':merged}
	cards[key].title_equations.source_blend='dual RT exact source-alpha recurrence, RGB from color and alpha from mask red; blend_disabled merge'
	_freeze_later(mask,3);_freeze_later(merged,6)
	return merged
func _add_unity_title(rt,title,width,height,character_size):
	var total_advance=0.0
	# Font hhea equation verified against both MiddleCenter native screenshots.
	var baseline_pixels=-46.0*900.0/1024.0+46.0*(900.0+124.0+6.0)/1024.0*0.5
	for ch in title:
		var glyph=unity_glyphs[ch];total_advance+=glyph.advance
	var advance=0.0
	var pixel_scale=Vector2(float(rt.size.x)/width,float(rt.size.y)/height)*character_size*0.1
	for ch in title:
		var g=unity_glyphs[ch]
		var quad=Polygon2D.new();var vertices=PackedVector2Array();var uvs=PackedVector2Array()
		# Four named CharacterInfo corners preserve atlas rotations; never infer a rectangle.
		var points=[Vector2(g.minX,g.minY),Vector2(g.maxX,g.minY),Vector2(g.maxX,g.maxY),Vector2(g.minX,g.maxY)]
		var corners=[g.uvBottomLeft,g.uvBottomRight,g.uvTopRight,g.uvTopLeft]
		for i in range(4):
			var point=points[i];var uv=corners[i]
			vertices.append(Vector2(rt.size)*0.5+Vector2(advance+point.x-total_advance*0.5,-point.y-baseline_pixels)*pixel_scale)
			uvs.append(Vector2(uv.x*unity_sample.atlasWidth,(1.0-uv.y)*unity_sample.atlasHeight))
		quad.polygon=vertices;quad.uv=uvs;quad.texture=unity_atlas;quad.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		var outline=ShaderMaterial.new();outline.shader=load(BASE+'source_title_outline.gdshader');outline.set_shader_parameter('outline_texels',3.0);outline.set_shader_parameter('outline_color',Color(0.03921568766236305,0.0303975660353899,0.021530181169509888,1));quad.material=outline
		rt.add_child(quad);advance+=g.advance
func _rich_glyph_tokens(rich):
	# Restricted source-equivalent break rules for the verified 5834 zhCN alphabet.
	var visible=[];var bold=false;var i=0
	while i<rich.length():
		if rich.substr(i,3)=='<b>':bold=true;i+=3;continue
		if rich.substr(i,4)=='</b>':bold=false;i+=4;continue
		visible.append({'ch':rich[i],'bold':bold});i+=1
	var words=[];var word=[]
	for entry in visible:
		if not word.is_empty():
			var left=word[-1].ch;var right=entry.ch;var code=right.unicode_at(0)
			var can_break=not right in ['。','，','：'] and (left in ['。','，'] or (code>=0x3000 and code<=0xD7AF))
			if can_break:words.append(word);word=[]
		word.append(entry)
	if not word.is_empty():words.append(word)
	return words
func _glyph_entries_width(entries,glyph_map):
	var width=0.0
	for entry in entries:width+=glyph_map[entry.ch].advance
	return width
func _wrap_native_body(words,glyph_map,character_size,spec,minion,line_height):
	# Formula-based TextMesh bounds proxy; actual per-iteration native bounds absent.
	var W=float(spec.width);var H=float(spec.height);var uW=0.25 if minion else 0.25999999046325684;var uH=0.17000000178813934 if minion else 0.1599999964237213
	var scale=character_size*0.1;var total=0.0
	for word in words:total+=_glyph_entries_width(word,glyph_map)*scale
	var needed=minion or total>=W
	var lines=[[]]
	for word in words:
		var container=W
		if needed:
			var has_text=false
			for line in lines:
				if not line.is_empty():has_text=true
			var measured_height=(line_height+(lines.size()-1)*line_height*0.9375)*scale # native empty string retains one linebox
			if not minion:
				if measured_height-(H-measured_height)*0.2<H*uH:container=W*(1.0-uW)
			else:
				# Temporary UpperCenter at y=H*.25; measured linebox is a proxy.
				var ymax=H*0.25;var ymin=ymax-measured_height
				var cy=-H*0.5+H*uH*0.5;var half_y=H*uH*0.25
				var max_width=0.0
				for line in lines:max_width=maxf(max_width,_glyph_entries_width(line,glyph_map)*scale)
				var inner_edge=W*0.5-W*uW*0.5 # center.x - half size.x, i.e. NarrowW/2
				if has_text and ymin<=cy+half_y and ymax>=cy-half_y and max_width*0.5>=inner_edge:container=W*(1.0-uW)
		var candidate=_glyph_entries_width(lines[-1],glyph_map)*scale+_glyph_entries_width(word,glyph_map)*scale
		if candidate>=container and not lines[-1].is_empty():lines.append([])
		lines[-1].append_array(word)
	return lines
func _add_body_glyphs(parent,rich,spec,glyph_map,atlas,atlas_size,minion):
	var words=_rich_glyph_tokens(rich)
	for word in words:
		for entry in word:
			if not glyph_map.has(entry.ch):return null
	var font_size=40.0;var line_height=font_size*(502.0+113.0)/512.0
	var character_size=0.05;var steps=0;var lines=[];var measured_height=0.0
	while true:
		lines=_wrap_native_body(words,glyph_map,character_size,spec,minion,line_height)
		var spacing=0.9375 if lines.size()>1 else 0.75
		measured_height=(line_height+(lines.size()-1)*line_height*spacing)*character_size*0.1
		var checked_height=measured_height
		# Original first fit subtracts intra-line delta; subsequent attempts do not.
		if steps==0:checked_height-=(line_height*0.9375-line_height)*character_size*0.1
		var max_width=0.0
		for line in lines:max_width=maxf(max_width,_glyph_entries_width(line,glyph_map)*character_size*0.1)
		if (checked_height<=float(spec.height) and max_width<=float(spec.width)) or steps>=40 or character_size<=0.01:break
		character_size=maxf(0.01,character_size*0.95);steps+=1
	var mesh=ArrayMesh.new();var baseline=-font_size*502.0/512.0+line_height*0.5
	var line_advance=line_height*0.9375
	var plain_lines=[];var bold_count=0
	for line in lines:
		var text=''
		for entry in line:text+=entry.ch
		plain_lines.append(text)
	for mode in [0,2]:
		var ps=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
		for li in range(lines.size()):
			var line=lines[li];var advance=_glyph_entries_width(line,glyph_map);var cursor=0.0
			for entry in line:
				var g=glyph_map[entry.ch]
				if (entry.bold and mode==2) or (not entry.bold and mode==0):
					if entry.bold:bold_count+=1
					var start=ps.size()
					var points=[Vector2(g.minX,g.minY),Vector2(g.maxX,g.minY),Vector2(g.maxX,g.maxY),Vector2(g.minX,g.maxY)]
					var corners=[g.uvBottomLeft,g.uvBottomRight,g.uvTopRight,g.uvTopLeft]
					for i in range(4):
						ps.append(Vector3(cursor+points[i].x-advance*0.5,points[i].y+baseline+(lines.size()-1)*line_advance*0.5-li*line_advance,0)*character_size*0.1)
						uv.append(Vector2(corners[i].x,1.0-corners[i].y))
					for index in [0,1,2,0,2,3]:indices.append(start+index)
				cursor+=g.advance
		if ps.is_empty():continue
		var arr=[];arr.resize(Mesh.ARRAY_MAX);arr[Mesh.ARRAY_VERTEX]=ps;arr[Mesh.ARRAY_TEX_UV]=uv;arr[Mesh.ARRAY_INDEX]=indices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		var mat=ShaderMaterial.new();mat.shader=load(BASE+'source_glyph_spatial.gdshader');mat.set_shader_parameter('glyph_atlas',atlas);mat.set_shader_parameter('atlas_texel',Vector2(1.0/atlas_size.x,1.0/atlas_size.y));mat.set_shader_parameter('text_mode',mode);mat.set_shader_parameter('bold_texels',1.25);mat.set_shader_parameter('text_tint',col(spec.color));mat.render_priority=20;mesh.surface_set_material(mesh.get_surface_count()-1,mat)
	var node=MeshInstance3D.new();node.mesh=mesh;parent.add_child(node)
	return {'node':node,'character_size':character_size,'font_size':40,'resize_steps':steps,'lines':plain_lines,'bold_glyph_count':bold_count,'line_spacing':0.9375 if lines.size()>1 else 0.75,'bounds_provider':'font hhea/advance model verified by 197 native bounds samples; not a native call on every wrap iteration','underwear':'source forbidden-area and temporary UpperCenter equations with native-verified bounds model','renderer':'direct sampled glyph mesh, material0 normal/material1 source eight-tap bold; no RTT'}
func _add_direct_glyphs(parent,text,spec,glyph_map,atlas,atlas_size,font_size,metrics):
	# Native glyph XY plane uses the source label transform. No billboard/RTT.
	var character_size=float(spec.characterSize)*0.01
	var advance=0.0
	for ch in text:
		if not glyph_map.has(ch):return null
		advance+=glyph_map[ch].advance
	var line_height=font_size*(metrics.ascent-metrics.descent+metrics.line_gap)/metrics.units
	var baseline=-font_size*metrics.ascent/metrics.units+line_height*0.5
	var steps=0
	if spec.role=='race' and advance>0.0 and line_height>0.0:
		# Source ResizeToFitAndGrow for non-wrapped text: direct min(H/y,W/x).
		var width=advance*character_size*0.1;var height=line_height*character_size*0.1
		if race_bounds.has(text):
			var sample=race_bounds[text];var extent=sample.rendererLocalBounds.m_Extent
			width=2.0*extent.x*character_size/sample.characterSize;height=2.0*extent.y*character_size/sample.characterSize
		var factor=minf(float(spec.height)/height,float(spec.width)/width)
		character_size=maxf(0.01,character_size*factor)
	while not spec.role in ['cost','attack','health','race'] and (advance*character_size*0.1>float(spec.width) or line_height*character_size*0.1>float(spec.height)) and steps<40:
		character_size=maxf(0.01,character_size*0.95);steps+=1
	var ps=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array();var cursor=0.0
	for ch in text:
		var g=glyph_map[ch];var start=ps.size()
		var points=[Vector2(g.minX,g.minY),Vector2(g.maxX,g.minY),Vector2(g.maxX,g.maxY),Vector2(g.minX,g.maxY)]
		var corners=[g.uvBottomLeft,g.uvBottomRight,g.uvTopRight,g.uvTopLeft]
		for i in range(4):
			ps.append(Vector3(cursor+points[i].x-advance*0.5,points[i].y+baseline,0)*character_size*0.1)
			uv.append(Vector2(corners[i].x,1.0-corners[i].y))
		for index in [0,1,2,0,2,3]:indices.append(start+index)
		cursor+=g.advance
	var arr=[];arr.resize(Mesh.ARRAY_MAX);arr[Mesh.ARRAY_VERTEX]=ps;arr[Mesh.ARRAY_TEX_UV]=uv;arr[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var mat=ShaderMaterial.new();mat.shader=load(BASE+'source_glyph_spatial.gdshader');mat.set_shader_parameter('glyph_atlas',atlas);mat.set_shader_parameter('atlas_texel',Vector2(1.0/atlas_size.x,1.0/atlas_size.y));mat.set_shader_parameter('outline_texels',float(spec.outlineSize) if spec.outline else 0.0);mat.set_shader_parameter('text_mode',1 if spec.outline else 0);mat.set_shader_parameter('text_tint',col(spec.color));mat.set_shader_parameter('outline_color',col(spec.outlineColor));mat.render_priority=20
	mesh.surface_set_material(0,mat);var node=MeshInstance3D.new();node.mesh=mesh;parent.add_child(node)
	return {'node':node,'character_size':character_size,'font_size':font_size,'resize_steps':steps,'renderer':'direct sampled glyph mesh with source transform; no RTT'}
func _add_labels(nodes,prof,d,key):
	for spec in prof.labels:
		if not spec.normal or spec.role=='name':continue
		var text=''
		if spec.role=='cost':text=str(d.cost)
		if spec.role=='attack':text=str(d.get('atk',0))
		if spec.role=='health':text=str(d.get('hp',0))
		if spec.role=='description':text='\n'.join(PackedStringArray(d.get('desc',[])))
		if spec.role=='race':text=str(d.get('race_name',''))
		if text=='':continue
		if spec.role=='description' and not body_bundle.is_empty() and rich_descriptions.has(key):
			var result=_add_body_glyphs(nodes[spec.nodeId],rich_descriptions[key].rich_desc_base,spec,body_bundle.glyphs,body_bundle.atlas,body_bundle.size,d.kind=='minion')
			if result!=null:
				result.erase('node');cards[key].description_equations=result;cards[key].description_size=40
				continue
			compatibility_fallbacks.append({'card':key,'component':'description','used':'Godot Label3D','reason':'sampled body glyph unavailable'})
		if spec.role in ['cost','attack','health'] and not number_bundle.is_empty():
			var result=_add_direct_glyphs(nodes[spec.nodeId],text,spec,number_bundle.glyphs,number_bundle.atlas,number_bundle.size,74,{'ascent':900.0,'descent':-124.0,'line_gap':6.0,'units':1024.0})
			if result!=null:
				if not cards[key].has('number_equations'):cards[key].number_equations={}
				cards[key].number_equations[spec.role]={'character_size':result.character_size,'font_size':74,'renderer':result.renderer}
				if spec.role=='cost':cards[key].cost_native={'node':result.node,'parent':nodes[spec.nodeId],'spec':spec.duplicate(true)}
				continue
			compatibility_fallbacks.append({'card':key,'component':spec.role,'used':'Godot Label3D','reason':'sampled numeric glyph unavailable'})
		if spec.role=='race':
			var result=_add_direct_glyphs(nodes[spec.nodeId],text,spec,unity_glyphs,unity_atlas,Vector2(unity_sample.atlasWidth,unity_sample.atlasHeight),46,{'ascent':900.0,'descent':-124.0,'line_gap':6.0,'units':1024.0})
			if result!=null:
				cards[key].race_equations={'character_size':result.character_size,'font_size':result.font_size,'resize_steps':result.resize_steps,'renderer':result.renderer,'grow_bounds_provider':'actual native race-string MiddleCenter lineSpacing0 bounds; source hhea baseline retained'}
				continue
			compatibility_fallbacks.append({'card':key,'component':'race','used':'Godot Label3D','reason':'sampled glyph unavailable'})
		var label=Label3D.new();label.text=text;label.font=title_font if spec.role=='race' else (font if spec.role=='description' else number_font);label.font_size=int(round(spec.fontSize*1.15)) if spec.role=='race' else spec.fontSize;label.pixel_size=0.005 if spec.role=='description' else spec.characterSize*0.001
		if spec.role=='description':
			# Explicit Godot fit-to-source width/height compatibility. Source anchors preserved.
			var fs=int(spec.fontSize);var lines=text.split('\n');var width=0.0
			for line in lines:width=maxf(width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x)
			while (width*label.pixel_size>float(spec.width) or (font.get_height(fs)*lines.size()*label.pixel_size)>float(spec.height)) and fs>18:
				fs-=1;width=0.0
				for line in lines:width=maxf(width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x)
			label.font_size=fs;cards[key].description_size=fs
		label.outline_size=0 if not spec.outline else 5;label.modulate=col(spec.color);label.outline_modulate=col(spec.outlineColor);label.no_depth_test=true;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.render_priority=20;nodes[spec.nodeId].add_child(label)
		_audit_text(key,text,label.font)
		if spec.role=='cost':cards[key].cost_label=label
func _bind_verified_texture(material: ShaderMaterial, parameter: String, texture: Texture2D):
	material.set_shader_parameter(parameter,texture)
	if parameter in ['main_tex','second_tex']:
		material.set_shader_parameter(parameter+'_repeat',texture)
		var source=verified_resource_sampling.get(texture.resource_path,{}) if texture!=null else {}
		material.set_shader_parameter('main_repeat' if parameter=='main_tex' else 'second_repeat',source.get('sampler_hint','repeat_disable')=='repeat_enable')
		material.set_meta(parameter+'_sampling',source.get('name','unknown source; compatibility clamp retained'))
	elif parameter=='scrolling_tex':
		material.set_shader_parameter('scrolling_tex_clamp',texture)
		# Actual original gem compiled code shares sampler_MainTex; main_repeat chooses its state.
func _source_material(md,fallback,has_race=false):
	var id=str(md.sourceShaderKey).get_slice(':',1)
	var kind_map={'-4440234706065032223':0,'3271891197657001233':1,'-2508996697480494289':2,'-1982294586754922726':3,'9099378368919310605':4,'-5812771937585292081':5}
	if not kind_map.has(id):return fallback
	var kind=int(kind_map[id]);var m=ShaderMaterial.new();m.shader=load(BASE+'source_materials/original_opaque_double.gdshader' if kind in [0,1] else BASE+'source_materials/original_opaque_back.gdshader');m.set_shader_parameter('original_shader_kind',kind)
	var fl={};var co={}
	for f in md.floats:fl[f.name]=f.value
	for c in md.colors:co[c.name]=c.value
	var float_names={'_BlendIntensity':'blend_intensity','_LightingBlend':'lighting_blend','_EnableDualClass':'enable_dual_class','_MiddleValue':'middle_value','_Intensity':'intensity'}
	for source in float_names:
		if fl.has(source):m.set_shader_parameter(float_names[source],fl[source])
	var color_names={'_Color':'original_color','_SecondTint':'second_tint','_TintColor':'tint_color'}
	for source in color_names:
		if co.has(source):m.set_shader_parameter(color_names[source],col(co[source]))
	if co.has('_tint'):m.set_shader_parameter('scroll_tint',vec3color(co['_tint']))
	if co.has('_Fade'):m.set_shader_parameter('fade_rgb',vec3color(co['_Fade']))
	m.set_shader_parameter('scroll_scale',Vector2(fl.get('_ScaleX',1),fl.get('_ScaleY',1)));m.set_shader_parameter('scroll_speed',Vector2(fl.get('_XSpeed',0),fl.get('_YSpeed',0)))
	for tx in md.textures:
		var texture_name={'_MainTex':'main_tex','_SecondTex':'second_tex','_ScrollingTex':'scrolling_tex'}.get(tx.name,'')
		if texture_name!='' and textures.has(tx.key):_bind_verified_texture(m,texture_name,textures[tx.key])
		if tx.name in ['_MainTex','_SecondTex']:
			var offset_y=float(tx.offset.y)
			if kind==3 and tx.name=='_SecondTex' and not has_race:offset_y+=0.07
			# Source UV and image Y are both inverted; ST offset must be conjugated too.
			var st=Vector4(tx.scale.x,tx.scale.y,tx.offset.x,1.0-tx.scale.y-offset_y)
			m.set_shader_parameter('main_st' if tx.name=='_MainTex' else 'second_st',st)
	if fallback.albedo_texture!=null:_bind_verified_texture(m,'main_tex',fallback.albedo_texture)
	m.set_meta('original_shader_id',id);m.set_meta('source_blend','One Zero');m.set_meta('source_alpha_mask',true)
	return m

func _add_race_plate(nodes):
	# Exact single-race mesh from original bundle, enabled iff Actor has one race.
	var d=JSON.parse_string(FileAccess.get_file_as_string(BASE+'2605485296766705561.mesh.json'))
	var arr=[];arr.resize(Mesh.ARRAY_MAX);var ps=PackedVector3Array();var uv=PackedVector2Array();var ix=PackedInt32Array()
	for p in d.positions:ps.append(Vector3(p[0],p[1],p[2]))
	for u in d.uvs:uv.append(Vector2(u[0],1-u[1]))
	for sub in d.triangles:
		for tri in sub:
			for i in tri:ix.append(i)
	arr[Mesh.ARRAY_VERTEX]=ps;arr[Mesh.ARRAY_TEX_UV]=uv;arr[Mesh.ARRAY_INDEX]=ix
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var md=materials['CAB-3563ba8b89db13ca6eb196aa111591f1:-3969520693805149181']
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for tx in md.textures:
		if tx.name=='_MainTex':mat.albedo_texture=textures[tx.key]
	mesh.surface_set_material(0,_source_material(md,mat,true));var mi=MeshInstance3D.new();mi.mesh=mesh;nodes['5081530617887690007'].add_child(mi)

func _apply_visual_binding(key,nodes,minion):
	if not visual_metadata.has(key):return
	var meta=visual_metadata[key];var audit=cards[key].visual_binding
	var rarity=str(meta.get('rarity_name',''));var kind='minion' if minion else 'spell'
	var asset=meta.get('watermark_asset',null)
	var alpha=99.0/128.0 if asset!=null and not meta.get('hide_watermark',false) else 0.0
	var description_id='5226516710514330903' if minion else '-4160781473786695034'
	for child in nodes[description_id].get_children():
		if child is MeshInstance3D:
			for surface in range(child.mesh.get_surface_count()):
				var material=child.get_surface_override_material(surface)
				if material is ShaderMaterial and material.get_shader_parameter('original_shader_kind')==3:
					if asset!=null:_bind_verified_texture(material,'second_tex',load(BASE+'rarity_sources/HallOfFameIcon.png'))
					var tint=material.get_shader_parameter('second_tint');tint.a=alpha;material.set_shader_parameter('second_tint',tint)
	audit.watermark_asset=asset;audit.watermark_alpha=alpha
	audit.watermark_selection_basis=meta.get('selection_basis','')

	audit.rarity_name=rarity
	if rarity in ['FREE','INVALID']:
		audit.rarity_enabled=false
	elif rarity_variants.has(rarity) and rarity_profiles.has(kind):
		for renderer in rarity_profiles[kind].renderers:
			var is_gem=str(nodes[renderer.nodeId].name)=='RarityGem'
			var md=rarity_variants[rarity] if is_gem else materials[renderer.materialKeys[0]]
			var fallback=StandardMaterial3D.new()
			var instance=MeshInstance3D.new();instance.name='SourceRarityGem' if is_gem else 'SourceRarityFrame'
			instance.mesh=_geometry(meshes[renderer.meshKey],[0] if is_gem else [])
			instance.set_surface_override_material(0,_source_material(md,fallback))
			nodes[renderer.nodeId].add_child(instance)
		audit.rarity_enabled=true
	else:audit.rarity_enabled=null
	audit.status='partial_verified_visual_binding'

func build_world_minion(key: String, definition: Dictionary, portrait: Texture2D) -> Dictionary:
	# The same original in-play profile already shipped in OriginalCards/card_assets.
	# Unlike the legacy board oval this preserves the original mesh, submeshes, UV,
	# local hierarchy and gem geometry. Unknown source portrait lighting stays unlit.
	var prof: Dictionary=profiles.minion_in_play
	if summon_source_assets==null:
		summon_source_assets=load("res://scripts/native_summon_assets.gd").new();summon_source_assets.setup(self)
	if key=="CS2_182":
		var original_portrait=summon_source_assets.load_texture(summon_source_assets.manifest.root_labels.get("yeti_portrait",""))
		if original_portrait!=null:portrait=original_portrait
	var nodes: Dictionary={};var paths: Dictionary={};var render_nodes: Dictionary={};var material_nodes: Dictionary={}
	var actor: Node3D
	for n in prof.nodes:
		var node:=Node3D.new();node.name=n.name;nodes[n.id]=node
		var source_key: String="cab-69c88b234dfa427e02d1fcee9337ae34:"+str(n.id)
		node.set_meta("source_key",source_key)
		paths[str(n.path).trim_prefix("/Card_Play_Ally").trim_prefix("/")]=node
		if n.parentId=="":actor=node
	for n in prof.nodes:
		var node: Node3D=nodes[n.id]
		if n.parentId!="":nodes[n.parentId].add_child(node)
		node.position=Vector3.ZERO if n.parentId=="" else vec(n.position)
		node.quaternion=Quaternion(n.rotation.x,n.rotation.y,n.rotation.z,n.rotation.w);node.scale=vec(n.scale);node.visible=bool(n.active)
	for r in prof.renderers:
		if r.get("readyHighlight",false) or not r.enabled:continue
		var flipped: Array=[]
		for surface in range(r.materialKeys.size()):
			if str(materials[r.materialKeys[surface]].sourceShaderKey).get_slice(":",1) in ["9099378368919310605","6322982158558142423"]:flipped.append(surface)
		var mi:=MeshInstance3D.new();mi.mesh=_geometry(meshes[r.meshKey],flipped);nodes[r.nodeId].add_child(mi)
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source_key: String=nodes[r.nodeId].get_meta("source_key")
		render_nodes[source_key]=mi;material_nodes[source_key]=[]
		for surface in range(mi.mesh.get_surface_count()):
			var md: Dictionary=materials[r.materialKeys[surface]]
			var fallback:=StandardMaterial3D.new();fallback.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fallback.cull_mode=BaseMaterial3D.CULL_DISABLED
			for tx in md.textures:
				if tx.name=="_MainTex" and textures.has(tx.key):fallback.albedo_texture=textures[tx.key]
			if str(r.nodeId)==str(prof.portraitNodeId) and surface==int(prof.portraitMaterialIndex):fallback.albedo_texture=portrait
			var mat: Material=summon_source_assets.material(str(md.key).to_lower(),fallback.albedo_texture)
			mi.set_surface_override_material(surface,mat);material_nodes[source_key].append(mat)
	var state: Dictionary={"root":actor,"nodes":{},"paths":paths,"renderers":render_nodes,"materials":material_nodes,"particles":{},"source_key":"cab-69c88b234dfa427e02d1fcee9337ae34:"+str(prof.rootId),"stats":{},"stat_nodes":{},"card":key,"native_board_actor":true,"portrait_lighting":"Recovered 6322982158558142423 formula; scene SH/light compatibility inputs"}
	for id in nodes:state.nodes[nodes[id].get_meta("source_key")]=nodes[id]
	state.base_health=int(definition.hp)
	update_world_minion_stats(state,int(definition.atk),int(definition.hp))
	return state

func update_world_minion_card(state: Dictionary,key: String,definition: Dictionary,portrait: Texture2D) -> bool:
	# Entity.OnChangeEntity ordinary->Sheep keeps Card_Play_Ally Actor alive.
	# Replace only its original portrait material binding and stats, not meshes,
	# hierarchy, attached status spells, highlight plane or animation identity.
	var prof: Dictionary=profiles.minion_in_play
	if state.get("source_key","")!="cab-69c88b234dfa427e02d1fcee9337ae34:"+str(prof.rootId):return false
	for r in prof.renderers:
		if str(r.nodeId)!=str(prof.portraitNodeId):continue
		var source_key: String="cab-69c88b234dfa427e02d1fcee9337ae34:"+str(r.nodeId)
		var mi: MeshInstance3D=state.renderers.get(source_key)
		if not is_instance_valid(mi):return false
		var surface: int=int(prof.portraitMaterialIndex)
		var md: Dictionary=materials[r.materialKeys[surface]]
		var material: Material=summon_source_assets.material(str(md.key).to_lower(),portrait)
		if material==null:return false
		mi.set_surface_override_material(surface,material);state.materials[source_key][surface]=material
	state.card=key
	state.base_health=int(definition.hp)
	update_world_minion_stats(state,int(definition.atk),int(definition.hp))
	return true

func update_world_minion_stats(state: Dictionary, attack: int, health: int, max_health: int=-1, base_health: int=-1):
	var prof: Dictionary=profiles.minion_in_play
	for spec in prof.labels:
		if spec.role not in ["attack","health"]:continue
		var value: int=attack if spec.role=="attack" else health
		if state.stats.get(spec.role,-999)==value:continue
		state.stats[spec.role]=value
		if state.stat_nodes.has(spec.role) and is_instance_valid(state.stat_nodes[spec.role]):
			var previous: Node=state.stat_nodes[spec.role];previous.get_parent().remove_child(previous);previous.queue_free()
		var parent: Node=state.nodes["cab-69c88b234dfa427e02d1fcee9337ae34:"+str(spec.nodeId)]
		var result=_add_direct_glyphs(parent,str(value),spec,number_bundle.glyphs,number_bundle.atlas,number_bundle.size,74,{"ascent":900.0,"descent":-124.0,"line_gap":6.0,"units":1024.0})
		if result!=null:state.stat_nodes[spec.role]=result.node
	var base: int=base_health if base_health>=0 else int(state.get("base_health",health))
	_update_health_stat_tint(state,health,max_health if max_health>=0 else base,base)

static func health_stat_color(health: int, max_health: int, base_health: int, phone: bool) -> Color:
	# Actor.UpdateHealthTextMesh 0x060128c9 gives damage priority over buffs.
	# UpdateTextColor 0x060128e3 uses a lighter red for UsePhoneUI.
	if health<max_health:return Color(1.0,50.0/255.0,50.0/255.0) if phone else Color.RED
	if max_health>base_health:return Color.GREEN
	return Color.WHITE

func _update_health_stat_tint(state: Dictionary, health: int, max_health: int, base_health: int):
	var node=state.stat_nodes.get("health")
	if not is_instance_valid(node) or not node is MeshInstance3D:return
	var material=node.mesh.surface_get_material(0)
	if material is ShaderMaterial:
		material.set_shader_parameter("text_tint",health_stat_color(health,max_health,base_health,preload("res://scripts/source_board_camera_policy.gd").source_ui_requested()))

func clone_world_hand(key: String) -> Dictionary:
	# Duplicate real source geometry/glyphs, not a new card-face quad.
	var source: Node3D=cards[key].viewport.get_child(0)
	var outer: Node3D=source.duplicate()
	outer.scale=Vector3.ONE
	var actor: Node3D=outer.get_child(0)
	outer.remove_child(actor);outer.free()
	var state: Dictionary={"root":actor,"nodes":{},"paths":{},"renderers":{},"materials":{},"particles":{},"source_key":"cab-69c88b234dfa427e02d1fcee9337ae34:-2189759849338270441"}
	_index_world_clone(actor,actor,state)
	return state

func _index_world_clone(node: Node,root: Node3D,state: Dictionary):
	if node is MeshInstance3D:
		state.renderers[str(root.get_path_to(node))]=node
	if node is Node3D:
		state.paths[str(root.get_path_to(node)).trim_prefix(".")]=node
	for child in node.get_children():_index_world_clone(child,root,state)

func build_world_hero(key: String, definition: Dictionary, portrait: Texture2D) -> Dictionary:
	return _build_world_source_character("hero_in_play",key,definition,portrait)

func build_world_hero_power(key: String, definition: Dictionary, portrait: Texture2D) -> Dictionary:
	return _build_world_source_character("hero_power",key,definition,portrait)

func _build_world_source_character(profile_name: String, key: String, definition: Dictionary, portrait: Texture2D) -> Dictionary:
	# Actor.SetCard 0x060127f5: parent Actor to Card, Identity Actor and m_rootObject.
	# Caller supplies Card world pose. Never retain the serialized hero root 1.11.
	var prof: Dictionary=profiles[profile_name]
	if summon_source_assets==null:
		summon_source_assets=load("res://scripts/native_summon_assets.gd").new();summon_source_assets.setup(self)
	var prefix: String="cab-69c88b234dfa427e02d1fcee9337ae34:"
	var state: Dictionary={"root":null,"nodes":{},"paths":{},"renderers":{},"materials":{},"particles":{},"stats":{},"stat_nodes":{},"card":key,"source_key":prefix+str(prof.rootId),"source_profile":profile_name,"source_asset":prof.sourceAsset,"native_board_actor":true,"materials_ready":true,"unresolved_materials":[],"portrait_binding":{"node_id":str(prof.portraitNodeId),"material_index":int(prof.portraitMaterialIndex),"runtime_override":portrait!=null},"pose_contract":"Card parent world pose; Actor and RootObject identity (Actor.SetCard 0x060127f5)"}
	var nodes: Dictionary={}
	var root_path: String=""
	for n in prof.nodes:
		var node:=Node3D.new();node.name=n.name;nodes[str(n.id)]=node
		node.set_meta("source_key",prefix+str(n.id));state.nodes[prefix+str(n.id)]=node
		if n.parentId=="":state.root=node;root_path=str(n.path)
	for n in prof.nodes:
		var node: Node3D=nodes[str(n.id)]
		if n.parentId!="":nodes[str(n.parentId)].add_child(node)
		node.position=vec(n.position);node.quaternion=Quaternion(n.rotation.x,n.rotation.y,n.rotation.z,n.rotation.w);node.scale=vec(n.scale);node.visible=bool(n.active)
		var path: String=str(n.path).trim_prefix(root_path).trim_prefix("/")
		state.paths[path]=node
		if n.parentId=="" or path=="RootObject":node.transform=Transform3D.IDENTITY
	for r in prof.renderers:
		if r.get("readyHighlight",false) or not r.enabled:continue
		var flipped: Array=[]
		for surface in range(r.materialKeys.size()):
			# The power mesh has front/portrait/back surfaces, all back-face culled.
			# Reflecting Unity source space requires reversing their winding, otherwise
			# Restore shows the cover and Used shows the portrait (without its cost).
			if (profile_name=="hero_power" and str(r.nodeId)==str(prof.portraitNodeId)) or str(materials[r.materialKeys[surface]].sourceShaderKey).get_slice(":",1) in ["9099378368919310605","6322982158558142423"]:flipped.append(surface)
		if str(r.meshKey)=="unity default resources:10210":
			meshes[r.meshKey]=_source_builtin_power_quad()
		if meshes[r.meshKey].positions.is_empty() or meshes[r.meshKey].uvs.is_empty():
			state.materials_ready=false
			state.unresolved_materials.append({"mesh":r.meshKey,"reason":"Source built-in mesh geometry was not exported"})
			continue
		var mi:=MeshInstance3D.new();mi.mesh=_geometry(meshes[r.meshKey],flipped);nodes[str(r.nodeId)].add_child(mi)
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source_key: String=prefix+str(r.nodeId)
		state.renderers[source_key]=mi;state.materials[source_key]=[]
		for surface in range(mi.mesh.get_surface_count()):
			var md: Dictionary=materials[r.materialKeys[surface]]
			var main_texture: Texture2D
			for tx in md.textures:
				if tx.name=="_MainTex":main_texture=textures.get(tx.key)
			if str(r.nodeId)==str(prof.portraitNodeId) and surface==int(prof.portraitMaterialIndex) and portrait!=null:main_texture=portrait
			var mat: Material=_world_character_material(md,main_texture)
			# Explicit fail-closed audit: an unported shader is not a recovered shader.
			if mat==null or not mat is ShaderMaterial or mat.has_meta("compatibility"):
				state.materials_ready=false
				state.unresolved_materials.append({"material":md.key,"shader":md.sourceShaderKey,"node":source_key,"surface":surface})
			mi.set_surface_override_material(surface,mat);state.materials[source_key].append(mat)
	update_world_character_stats(state,definition)
	# Unsupported power materials must not accidentally become a visible fallback.
	state.root.visible=state.materials_ready
	return state

func update_world_character_stats(state: Dictionary, definition: Dictionary) -> void:
	var prof: Dictionary=profiles[state.source_profile]
	# Source Actor.UpdateAttackTextMesh 0x060128a9 hides the entire hero gem
	# at zero attack, not just its text. Minion zero-attack gems stay visible.
	if state.source_profile=="hero_in_play" and definition.has("atk"):
		var attack_object=state.paths.get("RootObject/DecorationRoot/AttackObject")
		if is_instance_valid(attack_object):attack_object.visible=int(definition.atk)!=0
	for spec in prof.labels:
		var field: String={"attack":"atk","health":"hp","cost":"cost"}.get(spec.role,spec.role)
		if not definition.has(field):continue
		var value: int=int(definition[field])
		if state.stats.get(spec.role,-999)==value:continue
		state.stats[spec.role]=value
		if state.stat_nodes.has(spec.role) and is_instance_valid(state.stat_nodes[spec.role]):
			var previous: Node=state.stat_nodes[spec.role];previous.get_parent().remove_child(previous);previous.queue_free()
		var parent: Node=state.nodes["cab-69c88b234dfa427e02d1fcee9337ae34:"+str(spec.nodeId)]
		var result=_add_direct_glyphs(parent,str(value),spec,number_bundle.glyphs,number_bundle.atlas,number_bundle.size,int(spec.fontSize),{"ascent":900.0,"descent":-124.0,"line_gap":6.0,"units":1024.0})
		if result!=null:state.stat_nodes[spec.role]=result.node
	if state.source_profile=="hero_in_play" and definition.has("hp"):
		_update_health_stat_tint(state,int(definition.hp),int(definition.get("max_hp",30)),int(definition.get("base_hp",30)))

func _world_character_material(md: Dictionary, main_texture: Texture2D) -> Material:
	var shader_id: String=str(md.sourceShaderKey).get_slice(":",1)
	var base:=StandardMaterial3D.new();base.albedo_texture=main_texture
	if shader_id in ["-4440234706065032223","3271891197657001233","-2508996697480494289","-1982294586754922726","9099378368919310605","-5812771937585292081"]:
		return _source_material(md,base)
	var file: String={"6322982158558142423":"portrait","-2557555604182605517":"shadow"}.get(shader_id,"")
	if file=="":
		if shader_id in ["-7567517821626992556","-870869104636564592"]:return _power_source_surface_material(md,main_texture)
		return null
	var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/native_summon_"+file+".gdshader")
	for f in md.floats:mat.set_shader_parameter(f.name,f.value)
	for c in md.colors:mat.set_shader_parameter(c.name,col(c.value))
	for tx in md.textures:
		var texture: Texture2D=main_texture if tx.name=="_MainTex" else textures.get(tx.key)
		if texture!=null:mat.set_shader_parameter(tx.name,texture)
		mat.set_shader_parameter(str(tx.name)+"_ST",Vector4(tx.scale.x,tx.scale.y,tx.offset.x,1.0-tx.scale.y-tx.offset.y))
	mat.set_meta("source_key",md.key);mat.set_meta("original_shader_id",shader_id)
	mat.set_meta("lighting_compatibility","Scene SH/light inputs not recovered")
	return mat

func _source_builtin_power_quad() -> Dictionary:
	# Decoded with UnityPy MeshHandler, without OBJ coordinate inversion, from
	# source CASC unity default resources pathID10210. Evidence power_builtin_mesh_decoded.json.
	return {"key":"unity default resources:10210","positions":[-.5,-.5,-3.0616168005906746e-17,.5,-.5,-3.0616168005906746e-17,-.5,.5,3.0616168005906746e-17,.5,.5,3.0616168005906746e-17],"normals":[0,0,-1,0,0,-1,0,0,-1,0,0,-1],"uvs":[{"channel":0,"values":[0,0,1,0,0,1,1,1]}],"colors":[],"submeshes":[{"indices":[0,3,1,3,0,2]}]}

func _power_source_surface_material(md: Dictionary, main_texture: Texture2D) -> ShaderMaterial:
	var multiply: bool=str(md.sourceShaderKey).ends_with(":-870869104636564592")
	var shader:=Shader.new()
	# Source DXBC: Custom_Card_Diffuse blob15 (texture * lerp(1,SH+lights,LightingBlend));
	# Hero_Multiply_Multiply blob1/blob3 (texture + lit vertexColor*Color, DstColor Zero).
	# Godot light inputs remain an explicit scene-light compatibility bridge, not Unity globals.
	shader.code="""shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST=vec4(1.0,1.0,0.0,0.0);
uniform float _LightingBlend=1.0;
uniform vec4 _Color=vec4(1.0);
uniform vec3 _UnitySHW=vec3(1.0);
uniform vec3 _MainLightColor=vec3(0.0);
uniform vec3 _MainLightDirection=vec3(0.0,1.0,0.0);
uniform vec3 _AdditionalLightContribution=vec3(0.0);
varying vec3 source_world_normal;
vec3 bridge(vec3 c){
 vec3 target=pow((c+vec3(0.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0);vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++){vec3 m=(lo+hi)*0.5;vec3 y=m*(m*(m*0.305306011+0.682171111)+0.012522878);vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);}
 return mix((lo+hi)*0.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}
void vertex(){source_world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 vec4 texel=texture(_MainTex,UV*_MainTex_ST.xy+_MainTex_ST.zw);
 vec3 sh=clamp(pow(abs(_UnitySHW),vec3(0.416666657))*1.05499995-vec3(0.0549999997),vec3(0.0),vec3(1.0));
 vec3 lighting=sh+_MainLightColor*max(0.0,dot(normalize(source_world_normal),_MainLightDirection))+_AdditionalLightContribution;
 ALBEDO=bridge(clamp(texel.rgb*mix(vec3(1.0),lighting,_LightingBlend),vec3(0.0),vec3(1.0)));
}
"""
	if multiply:
		shader.code=shader.code.replace("unshaded, fog_disabled, cull_back","unshaded, fog_disabled, cull_back, blend_mul, depth_draw_never")
		shader.code=shader.code.replace("texel.rgb*mix(vec3(1.0),lighting,_LightingBlend)","texel.rgb+COLOR.rgb*_Color.rgb*mix(vec3(1.0),sh+_MainLightColor,_LightingBlend)")
		# Godot transparent pipeline: ALPHA1 enables RGB multiplier, not coverage.
		shader.code=shader.code.replace("ALBEDO=bridge(","ALPHA=1.0; ALBEDO=bridge(")
	var mat:=ShaderMaterial.new();mat.shader=shader
	for f in md.floats:mat.set_shader_parameter(f.name,f.value)
	for c in md.colors:mat.set_shader_parameter(c.name,col(c.value))
	mat.set_shader_parameter("_MainTex",main_texture)
	for tx in md.textures:
		if tx.name=="_MainTex":mat.set_shader_parameter("_MainTex_ST",Vector4(tx.scale.x,tx.scale.y,tx.offset.x,1.0-tx.scale.y-tx.offset.y))
	mat.set_meta("source_key",md.key);mat.set_meta("lighting_compatibility","Recovered shader arithmetic; scene Unity light globals not recovered")
	return mat

func set_world_power_exhausted(state: Dictionary, exhausted: bool, animate: bool = true) -> bool:
	# Card.ShowExhaustedChange -> PlayHeroPowerAnimation. Caller must preserve a
	# separate Card parent for Zone pose: these source tracks animate Actor itself.
	if state.get("source_profile","")!="hero_power":return false
	if state.get("power_exhausted",null)==exhausted:return true
	var path: String=BASE+"power_source_clips.json"
	if not FileAccess.file_exists(path):return false
	if not state.has("power_source_clips"):state.power_source_clips=JSON.parse_string(FileAccess.get_file_as_string(path))
	var name: String="HeroPower_Used_phone" if exhausted else "HeroPower_Restore_phone"
	if not state.power_source_clips.has(name):return false
	var record: Dictionary=state.power_source_clips[name]
	var length: float=0.0
	for kind in ["m_PositionCurves","m_RotationCurves","m_ScaleCurves"]:
		for track in record.data.get(kind,[]):
			for point in track.curve.get("m_Curve",[]):length=maxf(length,float(point.time))
	state.power_exhausted=exhausted
	state.power_animation={"name":name,"source_key":record.source_key,"length":length,"time":0.0 if animate else length,"playing":animate}
	_sample_world_power_animation(state)
	return true

func advance_world_power_animation(state: Dictionary, delta: float) -> void:
	if not state.has("power_animation") or not state.power_animation.playing:return
	state.power_animation.time=minf(float(state.power_animation.length),float(state.power_animation.time)+maxf(delta,0.0))
	_sample_world_power_animation(state)
	if state.power_animation.time>=state.power_animation.length:state.power_animation.playing=false

func _sample_world_power_animation(state: Dictionary) -> void:
	var curves=preload("res://scripts/native_summon_curves.gd")
	var clip: Dictionary=state.power_source_clips[state.power_animation.name].data
	var time: float=float(state.power_animation.time)
	for kind in ["m_PositionCurves","m_RotationCurves","m_ScaleCurves"]:
		for track in clip.get(kind,[]):
			var node: Node3D=state.paths.get(str(track.path))
			if not is_instance_valid(node):continue
			match kind:
				"m_PositionCurves":node.position=curves.vector_curve(track.curve,time)
				"m_RotationCurves":node.quaternion=curves.quaternion_curve(track.curve,time)
				"m_ScaleCurves":node.scale=curves.vector_curve(track.curve,time,Vector3.ONE)
