extends Node
## Opt-in render-thread CPU timings for the named effect targets. The Android
## GLES backend does not supply GPU timestamps for these Godot measurements.
const EFFECT_TARGETS := ["Main_", "BloomSource_", "Bloom_", "SourceBlur", "SE_", "LiveBoardCanvasOnly",
	"OriginalResultColor", "SourceDesat", "SourceVignetting", "SourceCoinViewport",
	"RGBTransmissionTarget", "ClassicBoardSpatialObjects", "OriginalBoardViewport"]

var game: Node
var views: Dictionary = {}
var peaks: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_register_target)
	RenderingServer.frame_post_draw.connect(_sample_targets)
	_register_view(get_window(), "RootWindow")

func _register_target(node: Node) -> void:
	if node is SubViewport:
		var label := str(node.name)
		for prefix in EFFECT_TARGETS:
			if label.begins_with(prefix):
				_register_view(node, label)
				return

func _register_view(view: Viewport, label: String) -> void:
	var id := view.get_instance_id()
	views[id] = {"view": weakref(view), "label": label}
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)

func _sample_targets() -> void:
	var benchmark = game.android_match_benchmark
	if not is_instance_valid(benchmark):return
	if benchmark.phase in ["loading", "fixture_setup", "fixture_settle"]:return
	var phase_name: String = benchmark.phase
	var read_frame: int = benchmark.frame
	_record_peak("FrameSetup", RenderingServer.get_frame_setup_time_cpu(), read_frame, phase_name, "")
	for id in views.keys():
		var record: Dictionary = views[id]
		var view: Viewport = record.view.get_ref()
		if not is_instance_valid(view):
			views.erase(id)
			continue
		if view is SubViewport and view.render_target_update_mode == SubViewport.UPDATE_DISABLED:continue
		var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
		_record_peak(record.label, cpu_ms, read_frame, phase_name, str(view.get_visible_rect().size))
	if not benchmark.result.is_empty():
		for phase_peaks in peaks.values():
			var rows: Array = phase_peaks.values()
			rows.sort_custom(func(a, b):return a.cpu_ms > b.cpu_ms)
			for row in rows.slice(0, 3):benchmark.emit_record("FX_VIEWPORT_PEAK " + JSON.stringify(row))
		queue_free()

func _record_peak(label: String, cpu_ms: float, read_frame: int, phase_name: String, size: String) -> void:
	if cpu_ms <= 0.0:return
	if not peaks.has(phase_name):peaks[phase_name] = {}
	var phase_peaks: Dictionary = peaks[phase_name]
	if cpu_ms > float(phase_peaks.get(label, {}).get("cpu_ms", 0.0)):
		phase_peaks[label] = {"target": label, "cpu_ms": cpu_ms, "read_frame": read_frame,
			"phase_at_read": phase_name, "size": size}

func _exit_tree() -> void:
	for record in views.values():
		var view: Viewport = record.view.get_ref()
		if is_instance_valid(view):RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), false)
