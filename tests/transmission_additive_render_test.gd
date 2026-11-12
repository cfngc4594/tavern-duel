extends SceneTree
## Fixed-pose framebuffer comparison. Run in a graphical Compatibility window.

const Transmission = preload("res://scripts/native_combat_transmission.gd")
const ADDITIVE = preload("res://shaders/native_combat_r2t_additive.gdshader")
const MULTIPLY = preload("res://shaders/native_combat_multiply_rgb.gdshader")
const SIZE := Vector2i(128, 128)

func _initialize():
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility":
		push_error("Run the transmission render comparison in a Compatibility window")
		quit(1)
		return
	var color := _new_view()
	color.transparent_bg = true
	color.own_world_3d = true
	color.msaa_3d = Viewport.MSAA_4X
	var scene := Node3D.new()
	color.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position.z = 6.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.current = true
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(white)
	var opaque := StandardMaterial3D.new()
	opaque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	opaque.albedo_color = Color(0.2, 0.35, 0.55)
	_quad(scene, opaque, Vector3(0.4, 0.1, -0.3), Vector2(1.2, 1.3))
	_quad(scene, _material(MULTIPLY, texture, Vector4(0.65, 0.30, 0.90, 0.7)), Vector3(0.0, 0.0, 0.2), Vector2(1.7, 1.6))
	var glow := _quad(scene, _material(ADDITIVE, texture, Vector4(0.40, 0.12, 0.28, 0.7)), Vector3(-0.5, 0.2, 0.4), Vector2(1.9, 1.4))
	var transmission := Transmission.new()
	transmission.prune_identity_additive = false
	root.add_child(transmission)
	transmission.setup(color, scene)
	var composite := _make_composite(color, transmission)
	var display := TextureRect.new()
	display.texture = composite.get_texture()
	display.size = Vector2(SIZE) * 3.0
	display.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(display)

	var before := await _read_targets(color, transmission.transmission_view, composite)
	var before_draws := transmission.transmission_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	transmission.prune_identity_additive = true
	transmission.sync()
	var after := await _read_targets(color, transmission.transmission_view, composite)
	var after_draws := transmission.transmission_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var failed: bool = transmission.identity_additive_skipped != 1 or before_draws <= after_draws
	for label in before:
		var a: Image = before[label]
		var b: Image = after[label]
		var equal := not a.is_empty() and a.get_size() == b.get_size() and a.get_format() == b.get_format() and a.get_data() == b.get_data()
		print("TRANSMISSION_ADDITIVE_RENDER ", label, " equal=", equal)
		failed = failed or not equal
	_save_requested(before, after)
	# Verify that the additive mesh was visible in C and multiply still affects T.
	glow.hide()
	transmission.sync()
	var no_glow := await _read_targets(color, transmission.transmission_view, composite)
	failed = failed or before.color.get_data() == no_glow.color.get_data()
	failed = failed or before.composite.get_data() == no_glow.composite.get_data()
	var colored_transmission: Color = before.transmission.get_pixel(40, 64)
	failed = failed or is_equal_approx(colored_transmission.r, colored_transmission.g)
	print("TRANSMISSION_ADDITIVE_RENDER draws=", before_draws, "→", after_draws)
	display.queue_free()
	composite.queue_free()
	transmission.queue_free()
	color.queue_free()
	await process_frame
	await process_frame
	var sound := root.get_node_or_null("SoundManager")
	if is_instance_valid(sound):await sound.shutdown_audio()
	if failed:push_error("TRANSMISSION_ADDITIVE_RENDER_FAIL")
	else:print("TRANSMISSION_ADDITIVE_RENDER_PASS")
	quit(1 if failed else 0)

func _new_view() -> SubViewport:
	var view := SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func _quad(parent: Node3D, material: Material, position: Vector3, size: Vector2) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	parent.add_child(node)
	return node

func _material(shader: Shader, texture: Texture2D, color: Vector4) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("_MainTex", texture)
	material.set_shader_parameter("_Color", color)
	material.set_shader_parameter("_Intensity", 1.0)
	return material

func _make_composite(color: SubViewport, transmission: Node) -> SubViewport:
	var view := _new_view()
	view.disable_3d = true
	var background := ColorRect.new()
	background.color = Color(0.30, 0.55, 0.25)
	background.size = Vector2(SIZE)
	view.add_child(background)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	view.add_child(copy)
	var canvas := Node2D.new()
	canvas.material = transmission.make_composite_material()
	canvas.draw.connect(func(): canvas.draw_texture_rect(color.get_texture(), Rect2(Vector2.ZERO, Vector2(SIZE)), false, Color(1, 1, 1, 2)))
	view.add_child(canvas)
	return view

func _read_targets(color: SubViewport, transmission: SubViewport, composite: SubViewport) -> Dictionary:
	for frame in 3:await RenderingServer.frame_post_draw
	return {"color":color.get_texture().get_image(), "transmission":transmission.get_texture().get_image(), "composite":composite.get_texture().get_image()}

func _save_requested(before: Dictionary, after: Dictionary) -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--transmission-capture-dir="):continue
		var directory := arg.trim_prefix("--transmission-capture-dir=")
		DirAccess.make_dir_recursive_absolute(directory)
		for label in before:
			before[label].save_png(directory.path_join(label + "-reference.png"))
			after[label].save_png(directory.path_join(label + "-pruned.png"))
