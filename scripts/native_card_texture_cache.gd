extends Node
## A storage optimization after the unchanged source multipass draw completes.
## Keep source geometry for clone_world_hand and cost redraw. Only dormant
## framebuffer attachments shrink; no source texture, camera or shader changes.
var startup_timing=preload("res://scripts/native_startup_timing.gd").new()
var renderer: Node
var enabled:=true
var auto_bake:=true
var pixel_digest_audit:=false
var draw_pending:=false
var history: Array=[]
var errors: Array=[]

func setup(owner_renderer: Node):
	startup_timing.configure()
	pixel_digest_audit=bool(ProjectSettings.get_setting("diagnostics/card_texture_audit",false)) or OS.get_cmdline_user_args().has("--card-texture-audit")
	renderer=owner_renderer
	set_process(false)

func schedule():
	if enabled:set_process(true)

func _process(_delta: float):
	if not enabled or not auto_bake:return
	var dirty:=false
	var ready:=false
	for key in renderer.cards:
		if bool(renderer.cards[key].get("rt_cache_dirty",true)):
			dirty=true
			if can_bake(key):ready=true
	if ready and not draw_pending:
		draw_pending=true
		RenderingServer.frame_post_draw.connect(_after_draw,CONNECT_ONE_SHOT)
	if not dirty:set_process(false)

func _after_draw():
	draw_pending=false
	if enabled and auto_bake:bake_ready()

func _views(state: Dictionary,kind: String) -> Array:
	var result: Array=[]
	for role in ["rgb","mask","merged"]:
		var view=state.get(kind+"_blend_targets",{}).get(role)
		if is_instance_valid(view):result.append(view)
	return result

func can_bake(key: String) -> bool:
	if not enabled or not renderer.cards.has(key):return false
	var state: Dictionary=renderer.cards[key]
	if not bool(state.get("rt_cache_dirty",true)):return false
	var views: Array=_views(state,"card")+_views(state,"title")
	if views.size()!=6:return false
	for view in views:
		if renderer.pending_freezes.has(view.get_instance_id()):return false
	return true

func bake_ready() -> int:
	# QA may set auto_bake=false, await frame_post_draw, then call this to compare
	# actual sampled before/after frames without changing source geometry/camera.
	var count:=0
	for key in renderer.cards:
		if can_bake(key) and bake_card(key):count+=1
	return count

func _digest(image: Image) -> String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	digest.update(image.get_data());return digest.finish().hex_encode()

func _record_pixel_audit(record: Dictionary,image: Image,texture: Texture2D,stage: String,key: String):
	if not pixel_digest_audit:return
	record.source_sha256=_digest(image)
	var uploaded:=_timed_get_image(texture,stage,key)
	if uploaded!=null and not uploaded.is_empty():record.cached_sha256=_digest(uploaded)

func _snapshot(image: Image,previous: Texture2D=null) -> ImageTexture:
	if previous is ImageTexture and previous.get_width()==image.get_width() and previous.get_height()==image.get_height() and previous.get_format()==image.get_format():
		previous.update(image);return previous
	return ImageTexture.create_from_image(image)

func _collect_title_material(material: Material,old_texture: Texture2D,seen: Dictionary,consumers: Array):
	if material==null or seen.has(material.get_instance_id()):return
	seen[material.get_instance_id()]=true
	if material is ShaderMaterial and material.shader!=null and material.shader.code.contains("uniform sampler2D title_rt") and material.get_shader_parameter("title_rt")==old_texture:consumers.append(material)
	if material.next_pass!=null:_collect_title_material(material.next_pass,old_texture,seen,consumers)

func _collect_title_tree(node: Node,old_texture: Texture2D,seen: Dictionary,consumers: Array):
	if node is MeshInstance3D and node.mesh!=null:
		for surface in range(node.mesh.get_surface_count()):_collect_title_material(node.get_active_material(surface),old_texture,seen,consumers)
		_collect_title_material(node.material_overlay,old_texture,seen,consumers)
	for child in node.get_children():_collect_title_tree(child,old_texture,seen,consumers)

func bake_card(key: String) -> bool:
	if not can_bake(key):return false
	var state: Dictionary=renderer.cards[key]
	var image: Image=_timed_get_image(state.output_viewport.get_texture(),"card_source_readback",key)
	if image==null or image.is_empty():errors.append("Empty completed card target "+key);return false
	var title_binds:=0
	var title_record: Dictionary=state.get("rt_cache_title_record",{})
	if not state.has("cached_title"):
		var title_view: SubViewport=state.title_blend_targets.merged
		var old_title: Texture2D=title_view.get_texture()
		var title_image: Image=_timed_get_image(old_title,"title_source_readback",key)
		if title_image==null or title_image.is_empty():errors.append("Empty completed title target "+key);return false
		var seen: Dictionary={};var consumers: Array=[]
		for view in _views(state,"card"):_collect_title_tree(view,old_title,seen,consumers)
		title_binds=consumers.size()
		# Validate the entire binding transaction before mutating any consumer.
		# A failed audit can be retried after fixing its source binding.
		if title_binds<2:errors.append("Missing source color/alpha title consumers "+key);return false
		var title: ImageTexture=_snapshot(title_image)
		for consumer in consumers:consumer.set_shader_parameter("title_rt",title)
		state.cached_title=title
		title_record={"width":title_image.get_width(),"height":title_image.get_height(),"format":title_image.get_format(),"bindings":title_binds}
		_record_pixel_audit(title_record,title_image,title,"title_cached_audit_readback",key)
		state.rt_cache_title_record=title_record
	var output: ImageTexture=_snapshot(image,state.get("cached_output"))
	state.cached_output=output
	state.rt_cache_generation=int(state.get("rt_cache_generation",0))+1
	state.rt_cache_dirty=false;state.rt_cache_baked=true
	var record: Dictionary={"card":key,"generation":state.rt_cache_generation,"cost":state.cost,"draw_frame":Engine.get_frames_drawn(),"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"mipmaps":image.has_mipmaps(),"title":title_record.duplicate(true),"geometry_preserved":true,"dormant_viewport_size":[2,2]}
	_record_pixel_audit(record,image,output,"card_cached_audit_readback",key)
	state.rt_cache_record=record
	# Rebind game/spatial consumers before discarding any viewport attachment.
	# World-hand clones share the original title materials changed above; the
	# transmission mirror copies those source parameters on the next scene sync.
	renderer.card_texture_ready.emit(key,output,renderer)
	for view in _views(state,"card")+_views(state,"title"):
		if not view.has_meta("rt_cache_original_size"):view.set_meta("rt_cache_original_size",view.size)
		view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		view.size=Vector2i(2,2)
	history.append(record.duplicate(true))
	while history.size()>96:history.pop_front()
	return true

func prepare_cost_redraw(key: String):
	if not renderer.cards.has(key):return
	var state: Dictionary=renderer.cards[key]
	for view in _views(state,"card"):
		if view.has_meta("rt_cache_original_size"):view.size=view.get_meta("rt_cache_original_size")
	state.rt_cache_dirty=enabled;state.rt_cache_baked=false
	if not enabled and state.has("cached_output"):
		# Disabling after a bake must not leave future redraw at 2x2 or keep an
		# obsolete public image. Restore the live original-size card output.
		state.erase("cached_output")
		renderer.card_texture_ready.emit(key,state.output_viewport.get_texture(),renderer)
	# Keep the last valid full-resolution image visible while the original
	# multipass redraw completes, instead of exposing freshly resized blank RTs.
	schedule()

func get_audit() -> Dictionary:
	var rows: Array=[]
	var pixels:=0
	for key in renderer.cards:
		var state: Dictionary=renderer.cards[key]
		for view in _views(state,"card")+_views(state,"title"):pixels+=view.size.x*view.size.y
		rows.append({"card":key,"baked":state.get("rt_cache_baked",false),"dirty":state.get("rt_cache_dirty",true),"generation":state.get("rt_cache_generation",0),"last":state.get("rt_cache_record",{})})
	return {"enabled":enabled,"auto_bake":auto_bake,"pixel_digest_audit":pixel_digest_audit,"cards":rows,"current_viewport_pixels":pixels,"history":history.duplicate(true),"errors":errors.duplicate(),"policy":"Actual completed source draw copied at identical dimensions and format; original source geometry retained; final sampled GPU parity requires QA"}

## Wall time includes a possible GPU synchronization; it is not GPU timer data.
func _timed_get_image(texture:Texture2D,stage:String,key:String)->Image:
	startup_timing.begin(stage,key)
	var image:Image=texture.get_image()
	startup_timing.end(stage,key)
	return image
