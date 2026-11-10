extends SceneTree
## Graphical software-GPU coverage check; NOT Android privacy/performance proof.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var guard = root.get_node_or_null("PrivacyTestGuard")
	assert(guard != null and guard.runtime_evidence().active, "Pass -- --privacy-guard-test to a debug Godot binary")
	assert(DisplayServer.get_name() != "headless", "A real graphical display is required")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(game.visible and game.is_processing() and not paused)
	var first_draws: int = Engine.get_frames_drawn()
	_check_pixels()
	var popup := Window.new()
	popup.size = Vector2i(400, 250)
	var red := ColorRect.new()
	red.color = Color.RED
	red.size = Vector2(400, 250)
	popup.add_child(red)
	root.add_child(popup)
	popup.show()
	await process_frame
	await RenderingServer.frame_post_draw
	_check_pixels()
	root.size = Vector2i(900, 600)
	await process_frame
	await RenderingServer.frame_post_draw
	_check_pixels()
	assert(Engine.get_frames_drawn() > first_draws)
	assert(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME) > 0)
	print("PRIVACY_TEST_GUARD_PIXELS_PASS ", JSON.stringify(guard.runtime_evidence()))
	var manager = root.get_node_or_null("SoundManager")
	if manager != null and manager.has_method("shutdown_audio"):
		await manager.shutdown_audio()
	quit()


func _check_pixels() -> void:
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	image.convert(Image.FORMAT_RGBA8)
	var bytes := image.get_data()
	for offset in range(0, bytes.size(), 4):
		assert(bytes[offset] == 0 and bytes[offset + 1] == 0 and bytes[offset + 2] == 0 and bytes[offset + 3] == 255, "Unmasked pixel at RGBA offset %d" % offset)
	print("PRIVACY_TEST_BLACK_FRAME ", image.get_width(), "x", image.get_height())
