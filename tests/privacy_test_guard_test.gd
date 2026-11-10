extends SceneTree

const Guard = preload("res://scripts/privacy_test_guard.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(not Guard.feature_enabled(PackedStringArray()))
	assert(not Guard.feature_enabled(PackedStringArray(["production", "privacy_test_off"])))
	assert(Guard.feature_enabled(PackedStringArray(["privacy_test"])))
	for rect in [Rect2(0, 0, 1600, 900), Rect2(-0.5, 0.5, 900.7, 1600.1), Rect2(0, 0, 1, 1)]:
		assert(Guard.coverage_rect(rect).encloses(rect))
	var guard = root.get_node_or_null("PrivacyTestGuard")
	assert(guard != null, "PrivacyTestGuard must be the first project autoload")
	var expected := OS.has_feature("privacy_test") or OS.get_cmdline_user_args().has("--privacy-guard-test")
	assert(guard.runtime_evidence().active == expected)
	if not expected:
		assert(guard.get_child_count() == 0)
		assert(not guard.is_processing())
		assert(not guard.runtime_evidence().master_muted)
		print("PRIVACY_TEST_GUARD_PRODUCTION_PASS")
		quit()
		return
	assert(root.gui_embed_subwindows)
	assert(root.gui_disable_input)
	assert(not paused)
	guard._input(InputEventScreenTouch.new())
	assert(root.is_input_handled())
	var popup := Window.new()
	popup.size = Vector2i(320, 240)
	root.add_child(popup)
	await process_frame
	guard._before_draw()
	assert(guard.runtime_evidence().protected_windows == 2)
	for surface in guard._surfaces.values():
		assert(surface.layer.layer == Guard.MASK_LAYER)
		assert(surface.layer.visible)
		assert(surface.mask.visible and surface.mask.color == Color.BLACK)
		assert(Rect2(surface.mask.position, surface.mask.size).encloses(surface.window.get_visible_rect()))
		surface.mask.hide()
		surface.mask.color = Color.TRANSPARENT
	guard._before_draw()
	for surface in guard._surfaces.values():
		assert(surface.mask.visible and surface.mask.color == Color.BLACK)
	popup.size = Vector2i(641, 479)
	guard._before_draw()
	assert(guard._surfaces[popup.get_instance_id()].mask.size == Guard.coverage_rect(popup.get_visible_rect()).size)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	guard._before_draw()
	assert(guard.runtime_evidence().master_muted)
	var start := int(guard.runtime_evidence().process_ticks)
	await process_frame
	await process_frame
	assert(int(guard.runtime_evidence().process_ticks) > start)
	assert(not paused)
	popup.queue_free()
	await process_frame
	guard._before_draw()
	assert(guard.runtime_evidence().protected_windows == 1)
	print("PRIVACY_TEST_GUARD_STRUCTURE_PASS ", JSON.stringify(guard.runtime_evidence()))
	quit()
