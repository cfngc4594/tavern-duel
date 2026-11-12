extends RefCounted
## Benchmark-only reporting. Do not turn dummy/unsupported counters into timings.
var pipeline_monitors: Dictionary = {}
var pipeline_status: Dictionary = {"available":false,"reason":"not_requested"}

static func stats(values: Array, zero_reason: String = "") -> Dictionary:
 if values.is_empty():return {"count":0,"available":false,"reason":"no_samples"}
 for value in values:
  if not is_finite(float(value)) or float(value)<0.0:
   return {"count":0,"observed_count":values.size(),"available":false,"reason":"invalid_negative_or_nonfinite_samples"}
 var sorted: Array = values.duplicate()
 sorted.sort()
 if not zero_reason.is_empty() and float(sorted[-1])<=0.0:
  return {"count":0,"observed_count":values.size(),"available":false,"reason":zero_reason}
 # Preserve the historical benchmark's floor(n*p), zero-based quantiles.
 return {"count":sorted.size(),"available":true,"mean":sorted.reduce(func(a,b):return a+b,0.0)/sorted.size(),"p50":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*.95)],"p99":sorted[int(sorted.size()*.99)],"max":sorted[-1]}

static func rendering_capabilities(display: String, method: String, adapter: String) -> Dictionary:
 var rendered := display!="headless" and not adapter.is_empty()
 var software := false
 for token in ["llvmpipe","lavapipe","swiftshader","software","softpipe"]:
  if token in adapter.to_lower():software=true
 return {"rendering_active":rendered,"headless":display=="headless","software_renderer":software,"hardware_gpu_candidate":rendered and not software,"rendering_device_counters":rendered and method in ["forward_plus","mobile"],"measurement_scope":"headless_logic_only" if display=="headless" else ("rendered_software" if software else ("rendered_device" if rendered else "renderer_unavailable")),"unavailable_reason":"headless_dummy_renderer" if display=="headless" else "adapter_not_reported"}

static func environment() -> Dictionary:
 var method := RenderingServer.get_current_rendering_method()
 var adapter := RenderingServer.get_video_adapter_name()
 var result := rendering_capabilities(DisplayServer.get_name(),method,adapter)
 result.merge({"schema_version":2,"engine":Engine.get_version_info(),"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor"),"os":OS.get_name(),"os_version":OS.get_version(),"processor":OS.get_processor_name(),"processor_count":OS.get_processor_count(),"display_server":DisplayServer.get_name(),"rendering_method":method,"adapter":adapter,"adapter_vendor":RenderingServer.get_video_adapter_vendor(),"visual_delta_seconds":1.0/60.0,"quantiles":"sorted[floor(n*p)] (zero-based), historical benchmark convention","frame_boundary":"process_frame precedes Node._process; game_process_ms is the last completed game frame, and engine/viewport monitors may lag","cold_scope":"first action in this process, not a cleared driver/disk shader cache"})
 for pair in [["driver","get_current_rendering_driver_name"],["adapter_api_version","get_video_adapter_api_version"]]:
  result[pair[0]]=RenderingServer.call(pair[1]) if RenderingServer.has_method(pair[1]) else null
 return result

func configure_pipelines(requested: bool, capabilities: Dictionary) -> void:
 pipeline_monitors.clear()
 pipeline_status={"available":false,"reason":"not_requested"}
 if not requested:return
 if not capabilities.rendering_active:
  pipeline_status.reason=capabilities.unavailable_reason
  return
 if not capabilities.rendering_device_counters:
  pipeline_status.reason="rendering_device_counters_not_supported_by_renderer"
  return
 # Discover rather than reference version-specific enum members at parse time.
 for name in ClassDB.class_get_integer_constant_list("Performance"):
  if str(name).begins_with("PIPELINE_COMPILATIONS_"):
   pipeline_monitors[str(name).trim_prefix("PIPELINE_COMPILATIONS_").to_lower()]=ClassDB.class_get_integer_constant("Performance",name)
 pipeline_status={"available":not pipeline_monitors.is_empty(),"reason":"" if not pipeline_monitors.is_empty() else "engine_does_not_expose_pipeline_counters","monitor_ids":pipeline_monitors.duplicate(),"units":"cumulative pipeline count, not milliseconds or GPU compilation duration"}

func pipeline_snapshot() -> Dictionary:
 var result: Dictionary = {}
 for name in pipeline_monitors:result[name]=int(Performance.get_monitor(pipeline_monitors[name]))
 return result

static func counter_delta(before: Dictionary, after: Dictionary) -> Dictionary:
 var result: Dictionary = {}
 for name in after:
  # Null is deliberate if a counter was reset or not present in the baseline.
  result[name]=int(after[name])-int(before[name]) if before.has(name) and int(after[name])>=int(before[name]) else null
 return result
