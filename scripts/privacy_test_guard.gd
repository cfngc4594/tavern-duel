extends Node
## Test-build-only mask. Register FIRST in [autoload], before audio/game code.
## No input, command-line switch, or public setter can disable an active guard.

const FEATURE := "privacy_test"
# Godot reserves layer 1024 for embedded windows; 1025 is above their content.
# Do not use INT_MAX: newer RenderingServer implementations wrap layer ranges.
const MASK_LAYER := 1025
const REPORT_INTERVAL := 5.0

var _active := false
var _surfaces: Dictionary = {}
var _elapsed := 0.0
var _process_ticks := 0
var _post_draws := 0


static func feature_enabled(features: PackedStringArray) -> bool:
	return features.has(FEATURE)


static func coverage_rect(viewport_rect: Rect2) -> Rect2:
	# Round OUTWARD, including fractional viewport edges during resize/stretch.
	var first := viewport_rect.position.floor()
	var last := viewport_rect.end.ceil()
	return Rect2(first, last - first)


func _enter_tree() -> void:
	_active = OS.has_feature(FEATURE)
	# Debug/headless tests can opt in, but this cannot turn protection OFF.
	if (OS.has_feature("debug") or DisplayServer.get_name() == "headless") and OS.get_cmdline_user_args().has("--privacy-guard-test"):
		_active = true
	if not _active:
		set_process(false)
		set_process_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -2147483648
	_mute_master()
	get_tree().root.gui_embed_subwindows = true
	_protect_window(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	RenderingServer.frame_post_draw.connect(_after_draw)
	print("PRIVACY_TEST_ACTIVE ", JSON.stringify(runtime_evidence()))


func _ready() -> void:
	# Godot enables overridden callbacks during ready, after _enter_tree.
	set_process(_active)
	set_process_input(_active)


func _on_node_added(node: Node) -> void:
	if node is Window:
		_protect_window(node as Window)


func _protect_window(window: Window) -> void:
	var id := window.get_instance_id()
	if _surfaces.has(id):
		return
	# Embedded popup windows normally sit at layer 1024; the mask sits above them.
	window.gui_embed_subwindows = true
	window.gui_disable_input = true
	var layer := CanvasLayer.new()
	layer.name = "PrivacyTestOpaqueLayer"
	layer.layer = MASK_LAYER
	var mask := ColorRect.new()
	mask.name = "OpaqueBlack"
	mask.color = Color.BLACK
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.focus_mode = Control.FOCUS_NONE
	layer.add_child(mask)
	_surfaces[id] = {"window": window, "layer": layer, "mask": mask}
	# Root layer belongs to the autoload; popups own their own viewport layers.
	# Avoid custom_viewport: its teardown can outlive a freed popup viewport.
	if window == get_tree().root:
		add_child(layer)
	else:
		window.add_child(layer)
	_fit_surface(_surfaces[id])
	window.size_changed.connect(_fit_surface.bind(_surfaces[id]))
	_block_native_input(window)


func _fit_surface(surface: Dictionary) -> void:
	var window: Window = surface.window
	if not is_instance_valid(window):
		return
	var rect := coverage_rect(window.get_visible_rect())
	var mask: ColorRect = surface.mask
	mask.position = rect.position
	mask.size = rect.size
	mask.color = Color.BLACK
	mask.modulate = Color.WHITE
	mask.self_modulate = Color.WHITE
	mask.show()
	var layer: CanvasLayer = surface.layer
	layer.layer = MASK_LAYER
	layer.transform = Transform2D.IDENTITY
	layer.show()


func _block_native_input(window: Window) -> void:
	# Replace the native Window event forwarder: game _input handlers never see
	# physical events. Embedded windows receive no forwarded root events either.
	# Do not invoke platform-only APIs with the headless display server.
	if DisplayServer.get_name() != "headless" and not window.is_embedded():
		var window_id := window.get_window_id()
		if window_id >= 0:
			DisplayServer.window_set_input_event_callback(_discard_physical_input, window_id)


func _discard_physical_input(_event: InputEvent) -> void:
	pass


func _input(_event: InputEvent) -> void:
	if _active:
		get_viewport().set_input_as_handled()


func _mute_master() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)


func _before_draw() -> void:
	# Repair accidental visibility/size changes before rendering, without hiding,
	# pausing, or replacing the production scene or its SubViewports.
	_mute_master()
	for id in _surfaces.keys():
		var surface: Dictionary = _surfaces[id]
		if not is_instance_valid(surface.window):
			if is_instance_valid(surface.layer):
				surface.layer.queue_free()
			_surfaces.erase(id)
			continue
		_fit_surface(surface)


func _after_draw() -> void:
	_post_draws += 1


func _process(delta: float) -> void:
	if not _active:
		return
	_process_ticks += 1
	_mute_master()
	_elapsed += delta
	if _elapsed >= REPORT_INTERVAL:
		_elapsed = 0.0
		print("PRIVACY_TEST_HEARTBEAT ", JSON.stringify(runtime_evidence()))


func runtime_evidence() -> Dictionary:
	return {
		"active": _active,
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"device": RenderingServer.get_video_adapter_name(),
		"process_ticks": _process_ticks,
		"process_frames": Engine.get_process_frames(),
		"frames_drawn": Engine.get_frames_drawn(),
		"post_draws": _post_draws,
		"protected_windows": _surfaces.size(),
		"master_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
	}
