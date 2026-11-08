extends RefCounted
# Explicit original secondary pass factory, separate from ordinary camera/RTT passes.
# Current supported source: FX_AreaEffect_Render pass 1, exact LightMode GlowAdditive.
# Graph registration/visibility/layers/opaque prepass are the caller's responsibility.
var _cache: Dictionary = {}
var _uniform_cache: Dictionary = {}
var unsupported: Dictionary = {}
var _samplers = preload("res://scripts/native_combat_samplers.gd").new()

func glow_material(source: Material, light_mode: String = "GlowAdditive", scalar_alpha: bool = false) -> Material:
 if source == null or light_mode.to_lower() != "glowadditive": return null
 if not source is ShaderMaterial: return null
 var material := source as ShaderMaterial
 if material.shader == null: return null
 var route: Dictionary = source.get_meta("source_shader_route", {})
 var source_shader: String = str(route.get("source_key", ""))
 var area_source := source_shader == "cab-c394926ba464822396a05cbfae08a8b3:-1499608994728766255" or str(source.get_meta("source_base_shader_path", material.shader.resource_path)) == "res://shaders/native_combat_area_render.gdshader"
 if not area_source: return null
 var path := "res://shaders/native_combat_screen_area_glow_alpha.gdshader" if scalar_alpha else "res://shaders/native_combat_area_render_glow.gdshader"
 var cache_key := str(source.get_instance_id()) + ":" + str(scalar_alpha)
 if not _cache.has(cache_key):
  var target := ShaderMaterial.new()
  target.shader = load(path)
  target.set_meta("source_key", source.get_meta("source_key", ""))
  target.set_meta("source_light_mode", "GlowAdditive")
  target.set_meta("source_pass_index", 1)
  target.set_meta("original_framebuffer_alpha_in_rgb", scalar_alpha)
  _cache[cache_key] = target
 var result: ShaderMaterial = _cache[cache_key]
 var variant: Shader = _samplers.variant(load(path), source.get_meta("source_sampler_bindings", {}))
 if result.shader != variant: result.shader = variant
 sync(material, result)
 return result

func sync(source: Material, target: Material = null) -> void:
 if not source is ShaderMaterial: return
 if target == null:
  for scalar in [false, true]:
   var key := str(source.get_instance_id()) + ":" + str(scalar)
   if _cache.has(key): sync(source, _cache[key])
  return
 if not target is ShaderMaterial: return
 var material := source as ShaderMaterial
 var result := target as ShaderMaterial
 if result.shader == null: return
 var shader_id: int = result.shader.get_instance_id()
 if not _uniform_cache.has(shader_id):
  var names: Array = []
  var expression := RegEx.new()
  expression.compile("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)")
  for found in expression.search_all(result.shader.code): names.append(found.get_string(1))
  _uniform_cache[shader_id] = names
 var floats: Dictionary = source.get_meta("source_floats", {})
 var colors: Dictionary = source.get_meta("source_colors", {})
 for name in _uniform_cache[shader_id]:
  # The primary shader does not declare secondary-only Glow properties. The loader
  # still retains their current overrides and original source metadata.
  var value = material.get_shader_parameter(name)
  if value == null: value = floats.get(name, colors.get(name))
  result.set_shader_parameter(name, value)
 result.render_priority = source.render_priority

func clear() -> void:
 _cache.clear()
 _uniform_cache.clear()
 unsupported.clear()
 _samplers.cache.clear()
