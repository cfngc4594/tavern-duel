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
	_test_card_cache(false)
	_test_card_cache(true)
	print("RENDER_READBACK_PASS")
	quit()
