extends SceneTree

const Highlight=preload("res://scripts/native_target_highlight_gpu.gd")

class HighlightProbe extends Highlight:
	var reads:=0
	var updates:=0
	var vertices: PackedVector3Array

	func _read_surface_arrays(mesh: Mesh,surface: int) -> Array:
		reads+=1
		return super._read_surface_arrays(mesh,surface)

	func _project_source(selected: Array,_plane: Transform3D,_plane_mesh: Mesh,_render_size: float,_clip_size: float) -> Dictionary:
		vertices=selected[0].vertices
		return {"audit":{}}

	func _create_pipeline(_id,_shape: Dictionary) -> Dictionary:
		var target:=SubViewport.new()
		add_child(target)
		var passes: Array=[]
		passes.resize(10)
		passes.fill({"viewport":target})
		return {"passes":passes,"audit":[]}

	func _update_pipeline(_pipeline: Dictionary,_shape: Dictionary) -> void:
		updates+=1

class HighlightClipProbe extends Highlight:
	var clip_calls := 0

	func _clip_triangles(sources: Array, render_scale: float) -> PackedVector3Array:
		clip_calls += 1
		return super._clip_triangles(sources, render_scale)

class CardRenderer extends Node:
	signal card_texture_ready(key: String,texture: Texture2D,renderer: Node)
	var cards: Dictionary={}
	var pending_freezes: Dictionary={}

class CardCacheProbe extends "res://scripts/native_card_texture_cache.gd":
	var reads: Array[String]=[]
	var source:=Image.create_empty(8,8,false,Image.FORMAT_RGBA8)

	func _timed_get_image(_texture: Texture2D,stage: String,_key: String) -> Image:
		reads.append(stage)
		return source

func _initialize():
	call_deferred("run")

func _triangle(offset: float) -> Array:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(offset,0,0),Vector3(offset+1,0,0),Vector3(offset,1,0)])
	return arrays

func _test_highlight():
	var probe:=HighlightProbe.new()
	root.add_child(probe)
	assert(not probe.defer_unchanged_surface_arrays)
	probe.defer_unchanged_surface_arrays=true
	var actor:=Node3D.new()
	probe.add_child(actor)
	var body:=MeshInstance3D.new()
	var geometry:=ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_triangle(0.0))
	body.mesh=geometry
	actor.add_child(body)
	var plane:=MeshInstance3D.new()
	plane.mesh=PlaneMesh.new()
	actor.add_child(plane)
	probe.surfaces={"unit":{"body":{"surfaces":[{"verified":true,"eligible":true}]}}}
	probe.bindings={"models":{"unit":{"components":[{"class_name":"HighlightRender","data":{"m_SilouetteRenderSize":1.0,"m_SilouetteClipSize":1.0}}]}}}
	probe.entries[1]={"actor":{"root":actor,"renderers":{"body":body}},"kind":"unit","plane":plane,"mesh":plane,"mask_key":"","material":null,"audit":{}}
	assert(probe.refresh(1) and probe.refresh(1))
	assert(probe.reads==1 and probe.updates==1 and probe.vertices[0].x==0.0)
	body.position.x=2.0
	assert(probe.refresh(1) and probe.refresh(1))
	assert(probe.reads==2 and probe.updates==2)
	var rid:=geometry.get_rid()
	geometry.clear_surfaces()
	assert(not probe.refresh(1))
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_triangle(8.0))
	assert(geometry.get_rid()==rid)
	assert(probe.refresh(1) and probe.refresh(1))
	assert(probe.reads==3 and probe.updates==3 and probe.vertices[0].x==8.0)
	body.visible=false
	assert(not probe.refresh(1) and probe.reads==3)
	body.visible=true
	probe.surfaces.unit.body.surfaces[0].verified=false
	assert(not probe.refresh(1) and probe.reads==3)
	probe.surfaces.unit.body.surfaces[0].verified=true
	body.mesh=BoxMesh.new()
	assert(probe.refresh(1) and probe.refresh(1))
	assert(probe.reads==5 and probe.updates==4)
	probe.free()

func _test_card_highlight_snapshots() -> void:
	var card_renderer := NativeCardRenderer.new()
	var probe := Highlight.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://assets/native_cards/OriginalCards/card_assets.json"))
	for profile in data.profiles:
		if profile.name != "minion_in_play": continue
		for entry in profile.renderers:
			if entry.enabled and not entry.get("readyHighlight", false):
				card_renderer._highlight_snapshot_meshes[entry.meshKey] = true
	var checked := 0
	var changed_mesh: ArrayMesh
	for descriptor in data.meshes:
		if not card_renderer._highlight_snapshot_meshes.has(descriptor.key): continue
		for flipped in [[], [0]]:
			var mesh: ArrayMesh = card_renderer._geometry(descriptor, flipped)
			assert(mesh.has_meta(NativeCardRenderer.HIGHLIGHT_SURFACE_ARRAYS))
			for surface in mesh.get_surface_count():
				var actual := probe._read_surface_arrays(mesh, surface)
				var reference := mesh.surface_get_arrays(surface)
				assert(var_to_bytes(actual[Mesh.ARRAY_VERTEX]) == var_to_bytes(reference[Mesh.ARRAY_VERTEX]))
				assert(var_to_bytes(actual[Mesh.ARRAY_INDEX]) == var_to_bytes(reference[Mesh.ARRAY_INDEX]))
				checked += 1
			changed_mesh = mesh
	assert(checked > 0)
	changed_mesh.clear_surfaces()
	changed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _triangle(8.0))
	assert(not changed_mesh.has_meta(NativeCardRenderer.HIGHLIGHT_SURFACE_ARRAYS))
	assert(probe._read_surface_arrays(changed_mesh, 0)[Mesh.ARRAY_VERTEX][0].x == 8.0)
	probe.free()
	card_renderer.free()

func _reference_constant_mask(probe: Node, sources: Array, size: Vector2i, ortho: float, render_scale: float) -> ArrayMesh:
	# Previous pipeline clipped and projected the original triangles separately for each pass.
	var vertices := PackedVector2Array()
	for source in sources:
		var points: PackedVector3Array = source.points
		var indices: PackedInt32Array = source.indices
		var count: int = indices.size() if not indices.is_empty() else points.size()
		for index in range(0, count - 2, 3):
			var polygon: Array = []
			for corner in range(3):
				polygon.append(points[indices[index + corner] if not indices.is_empty() else index + corner])
			polygon = probe._clip_depth(polygon, -(1.0 + render_scale), true)
			polygon = probe._clip_depth(polygon, -(1.0 - render_scale), false)
			for corner in range(1, polygon.size() - 1):
				for point in [polygon[0], polygon[corner], polygon[corner + 1]]:
					vertices.append(Vector2((point.x / ortho + 1.0) * 0.5 * size.x, (1.0 - point.y / ortho) * 0.5 * size.y))
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

func _test_highlight_clip() -> void:
	var probe := HighlightClipProbe.new()
	root.add_child(probe)
	probe.setup(null, null)
	# Cross both planes, touch both edges exactly, and cover fully inside,
	# below and above triangles. The unindexed source has a dangling vertex.
	var indexed := {"points": PackedVector3Array([
		Vector3(-0.8, -0.7, -2.0), Vector3(0.9, -0.4, 0.0), Vector3(0.1, 0.8, -1.0),
		Vector3(-0.4, -0.1, -1.5), Vector3(0.4, -0.1, -0.5), Vector3(0.0, 0.6, -1.0),
		Vector3(-0.5, -0.5, -2.0), Vector3(0.5, -0.5, -2.0), Vector3(0.0, 0.5, -2.0),
		Vector3(-0.6, -0.4, -1.25), Vector3(0.5, -0.6, -0.75), Vector3(0.2, 0.5, -1.0),
		Vector3(-0.5, -0.5, -0.4), Vector3(0.5, -0.5, 0.0), Vector3(0.0, 0.5, 0.1),
	]), "indices": PackedInt32Array([2, 0, 1, 3, 4, 5, 6, 7, 8, 11, 10, 9, 12, 13, 14])}
	var unindexed := {"points": PackedVector3Array([
		Vector3(-0.5, -0.7, -0.5), Vector3(0.7, -0.4, -1.8), Vector3(-0.3, 0.7, -0.7),
		Vector3(0.0, 0.0, -1.0),
	]), "indices": PackedInt32Array()}
	var shape := {"projected": [indexed, unindexed], "size": Vector2i(184, 256), "base": 1.4,
		"render_scale": 0.5, "render_size": 0.7, "clip_size": 0.8}
	var candidate := probe._create_pipeline("candidate", shape)
	probe._update_pipeline(candidate, shape)
	assert(probe.clip_calls == 1)
	var rendered := DisplayServer.get_name() != "headless"
	var reference: Dictionary = {}
	if rendered:
		reference = probe._create_pipeline("reference", shape)
		probe._update_pipeline(reference, shape)
	var constant_passes := 0
	for index in candidate.passes.size():
		var pass_state: Dictionary = candidate.passes[index]
		var spec: Dictionary = pass_state.spec
		if spec.type != "constant": continue
		constant_passes += 1
		var mesh: ArrayMesh = pass_state.drawable.mesh
		var expected := _reference_constant_mask(probe, shape.projected, spec.size, spec.ortho, shape.render_scale)
		assert(mesh.get_surface_count() == 1 and expected.get_surface_count() == 1)
		assert(mesh.surface_get_array_len(0) == 21)
		assert(var_to_bytes(mesh.surface_get_arrays(0)) == var_to_bytes(expected.surface_get_arrays(0)))
		if rendered: reference.passes[index].drawable.mesh = expected
	assert(constant_passes == 5)
	if rendered:
		await RenderingServer.frame_post_draw
		var any_mask_pixels := false
		for index in candidate.passes.size():
			var actual: Image = candidate.passes[index].viewport.get_texture().get_image()
			var expected: Image = reference.passes[index].viewport.get_texture().get_image()
			assert(actual != null and expected != null and not actual.is_empty() and not expected.is_empty())
			assert(actual.get_size() == expected.get_size() and actual.get_format() == expected.get_format())
			assert(actual.get_data() == expected.get_data())
			if candidate.passes[index].spec.type == "constant":
				any_mask_pixels = any_mask_pixels or actual.get_used_rect().has_area()
		assert(any_mask_pixels)
	probe.free()

func _targets(renderer: CardRenderer) -> Dictionary:
	var targets: Dictionary={}
	for role in ["rgb","mask","merged"]:
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(8,8)
		renderer.add_child(viewport)
		targets[role]=viewport
	return targets

func _test_card_cache(audit: bool):
	var renderer:=CardRenderer.new()
	root.add_child(renderer)
	var cache:=CardCacheProbe.new()
	renderer.add_child(cache)
	cache.setup(renderer)
	cache.pixel_digest_audit=audit
	var card:=_targets(renderer)
	var title:=_targets(renderer)
	var shader:=Shader.new()
	shader.code="shader_type spatial; uniform sampler2D title_rt; void fragment() { ALBEDO = texture(title_rt, UV).rgb; }"
	for viewport in [card.rgb,card.mask]:
		var consumer:=MeshInstance3D.new()
		consumer.mesh=PlaneMesh.new()
		var material:=ShaderMaterial.new()
		material.shader=shader
		material.set_shader_parameter("title_rt",title.merged.get_texture())
		consumer.set_surface_override_material(0,material)
		viewport.add_child(consumer)
	var state: Dictionary={"card_blend_targets":card,"title_blend_targets":title,"output_viewport":card.merged,"cost":3}
	renderer.cards["fixture"]=state
	assert(cache.bake_card("fixture"))
	assert(state.rt_cache_baked and not state.rt_cache_dirty)
	assert(state.rt_cache_title_record.bindings==2 and card.rgb.size==Vector2i(2,2) and title.rgb.size==Vector2i(2,2))
	assert(cache.reads.size()==(4 if audit else 2))
	assert(state.rt_cache_record.has("source_sha256")==audit and state.rt_cache_record.has("cached_sha256")==audit)
	if audit:
		assert(state.rt_cache_record.source_sha256==state.rt_cache_record.cached_sha256)
		assert(state.rt_cache_title_record.source_sha256==state.rt_cache_title_record.cached_sha256)
	cache.reads.clear()
	cache.prepare_cost_redraw("fixture")
	assert(state.rt_cache_dirty and card.rgb.size==Vector2i(8,8) and title.rgb.size==Vector2i(2,2))
	assert(cache.bake_card("fixture") and cache.reads.size()==(2 if audit else 1))
	assert(state.rt_cache_generation==2 and cache.errors.is_empty())
	renderer.free()

func run():
	_test_highlight()
	_test_card_highlight_snapshots()
	await _test_highlight_clip()
	_test_card_cache(false)
	_test_card_cache(true)
	var sound := root.get_node_or_null("SoundManager")
	if is_instance_valid(sound):await sound.shutdown_audio()
	print("RENDER_READBACK_PASS")
	quit()
