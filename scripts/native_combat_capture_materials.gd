extends RefCounted
# Captures source framebuffer alpha into RGB. This avoids Godot's coverage-alpha blend.
# Original RenderCommandLists selects the first SRPDefaultUnlit, UniversalForward,
# and LightweightForward pass. Empty tags mean SRPDefaultUnlit. Glow/Alpha are excluded.
# Same-version-family Unity ShaderTagId probe confirms case-insensitive equality.
# Preserve original strings in metadata; normalize only comparison.
# Generated shaders keep source uniforms/defaults and source vertex/fragment formulas.
var _alpha_cache: Dictionary = {}
var _color_cache: Dictionary = {}
var _uniform_cache: Dictionary = {}
var unsupported: Dictionary = {}
var _samplers = preload("res://scripts/native_combat_samplers.gd").new()

func _matches_light_mode(source: Material, light_mode: String) -> bool:
 if source == null: return false
 var route: Dictionary = source.get_meta("source_shader_route", {})
 var mode: String = str(source.get_meta("source_light_mode", route.get("source_light_mode", "")))
 if mode.is_empty(): mode = "SRPDefaultUnlit"
 if not light_mode.is_empty(): return mode.to_lower() == light_mode.to_lower()
 var passes: Array = source.get_meta("source_rtt_selected_passes", route.get("rtt_selected_passes", []))
 if passes.size() > 1:
  unsupported[str(source.get_meta("source_key", "unknown")) + "|" + str(source.get_instance_id())] = "Original RTT selects multiple passes; a single translated material cannot represent their separate commands."
  return false
 return mode.to_lower() in ["srpdefaultunlit", "universalforward", "lightweightforward"]

func color_material(source: Material, light_mode: String = "", target_unorm: bool = true) -> Material:
 if not _matches_light_mode(source, light_mode): return null
 if not target_unorm: return source
 return _capture_material(source, light_mode, "color", true)

func alpha_material(source: Material, light_mode: String = "", target_unorm: bool = true) -> Material:
 if not _matches_light_mode(source, light_mode): return null
 return _capture_material(source, light_mode, "alpha", target_unorm)

func _capture_material(source: Material, light_mode: String, kind: String, target_unorm: bool) -> Material:
 if not source is ShaderMaterial:
  unsupported[str(source.get_meta("source_key", "unknown")) + "|" + str(source.get_instance_id())] = "No recovered source shader; capture not approximated."
  return null
 var material := source as ShaderMaterial
 if material.shader == null: return null
 var path: String = str(source.get_meta("source_base_shader_path", material.shader.resource_path))
 var suffix: String = path.get_file().trim_prefix("native_combat_").trim_suffix(".gdshader")
 var capture_path := "res://shaders/native_combat_capture_" + kind + ("_unorm_" if target_unorm else "_") + suffix + ".gdshader"
 if not ResourceLoader.exists(capture_path):
  unsupported[str(source.get_meta("source_key", "unknown")) + "|" + str(source.get_instance_id())] = "No recovered " + kind + " capture formula for " + path
  return null
 var key := str(source.get_instance_id()) + ":" + str(target_unorm)
 var cache: Dictionary = _color_cache if kind == "color" else _alpha_cache
 if not cache.has(key) or str(cache[key].get_meta("source_capture_shader_path", "")) != capture_path:
  var capture := ShaderMaterial.new()
  capture.shader = preload("res://scripts/immutable_shader_cache.gd").load_shader(capture_path)
  for meta in source.get_meta_list(): capture.set_meta(meta,source.get_meta(meta))
  capture.set_meta("source_light_mode", source.get_meta("source_light_mode",light_mode))
  capture.set_meta("original_framebuffer_alpha_in_rgb", kind == "alpha")
  capture.set_meta("source_target_unorm_preblend", target_unorm)
  capture.set_meta("source_capture_shader_path", capture_path)
  cache[key] = capture
 var result: ShaderMaterial = cache[key]
 var variant: Shader = _samplers.variant(preload("res://scripts/immutable_shader_cache.gd").load_shader(capture_path), source.get_meta("source_sampler_bindings", {}))
 if result.shader != variant: result.shader = variant
 sync(material, result)
 return result

func sync(source: Material, target: Material = null) -> void:
 if not source is ShaderMaterial: return
 var material := source as ShaderMaterial
 if material.shader == null: return
 if target == null:
  for cache in [_alpha_cache, _color_cache]:
   for unorm in [false, true]:
    var key := str(source.get_instance_id()) + ":" + str(unorm)
    if cache.has(key): sync(source,cache[key])
  return
 if not target is ShaderMaterial: return
 var result := target as ShaderMaterial
 var shader_id: int = material.shader.get_instance_id()
 if not _uniform_cache.has(shader_id):
  # get_shader_uniform_list() may be empty before the first real render compiles
  # this shader. Do not cache that empty result and drop initial texture/fade inputs.
  var names: Array = []
  var expression := RegEx.new()
  expression.compile("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)")
  for found in expression.search_all(material.shader.code):
   names.append({"name":found.get_string(1)})
  _uniform_cache[shader_id] = names
 for info in _uniform_cache[shader_id]:
  var value = material.get_shader_parameter(info.name)
  result.set_shader_parameter(info.name, value) # null resets an old override back to the recovered default.
 result.render_priority = source.render_priority

func clear() -> void:
 _alpha_cache.clear()
 _color_cache.clear()
 _uniform_cache.clear()
 unsupported.clear()
 _samplers.cache.clear()
