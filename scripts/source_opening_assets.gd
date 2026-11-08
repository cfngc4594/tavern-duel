extends "res://scripts/native_state_assets.gd"
## Original opening object hierarchy, assets and authored device transforms.
## Text is explicitly a Godot raster compatibility path, not Unity glyph parity.
const OPENING_BASE: String = "res://assets/original_opening/"
const TEXT_KEYS: Dictionary = {
 "headline": "GAMEPLAY_MULLIGAN_STARTING_HAND",
 "caption": "GAMEPLAY_MULLIGAN_SUBTITLE",
 "replace": "GAMEPLAY_MULLIGAN_REPLACE",
 "confirm": "GLOBAL_CONFIRM"
}
var opening_text: Dictionary = {}
var opening_audit: Array = []
var opening_shader_limits: Array = []
const X_ROOT: String = "cab-69c88b234dfa427e02d1fcee9337ae34:7554812059937896204"
const X_RENDERER: String = "cab-69c88b234dfa427e02d1fcee9337ae34:-7902019769039292660"
var opening_x_mesh: ArrayMesh

func setup(card_renderer: Node = null, source_base: String = OPENING_BASE) -> void:
 # The common loader concatenates filenames, so retain the trailing slash.
 if not source_base.ends_with("/"): source_base += "/"
 super.setup(card_renderer, source_base)
 var path: String = source_base + "data/opening_text_zhcn.json"
 if FileAccess.file_exists(path):
  var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
  if parsed is Dictionary: opening_text = parsed

func instantiate_opening(root_key: String, parent: Node3D, mobile: bool = false) -> Dictionary:
 var key: String = str(manifest.get("root_labels", {}).get(root_key, root_key))
 if not objects.has(key):
  missing.append({"opening_root": root_key, "reason": "Original root absent"})
  return {}
 var state: Dictionary = super.instantiate(key, parent)
 state["labels"] = {}
 state["text_audit"] = []
 state["device_overrides"] = []
 # Unlike generic combat spawn placement, preserve this source root transform.
 var root_transform: Dictionary = component(key, "Transform").get("data", {})
 state.root.position = Curves.vec(root_transform.get("m_LocalPosition", {}))
 apply_device_overrides(state, mobile)
 _adapt_x_winding(state)
 _add_opening_labels(state)
 state.root.set_meta("opening_text_compatibility", "Godot original-font rasterization; no exact Unity glyph atlas")
 return state

func _adapt_x_winding(state: Dictionary) -> void:
 if str(state.get("source_key", "")) != X_ROOT: return
 var renderer: MeshInstance3D = state.get("renderers", {}).get(X_RENDERER)
 if renderer == null: return
 # Original WeldSparkQuad is Unity-front-facing (+Y cross/normal). Godot's
 # native +Y PlaneMesh uses the opposite winding and the GL backend also
 # compensates mirrored instances. Match our original card-mesh adapter,
 # without changing the source CullBack, depth, transform, vertices or UVs.
 # Keep this derived mesh separate from the common original geometry cache.
 if opening_x_mesh == null:
  opening_x_mesh = ArrayMesh.new()
  for surface in range(renderer.mesh.get_surface_count()):
   var arrays: Array = renderer.mesh.surface_get_arrays(surface)
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX].duplicate()
   for i in range(0, indices.size(), 3):
    var swap: int = indices[i + 1]
    indices[i + 1] = indices[i + 2]
    indices[i + 2] = swap
   arrays[Mesh.ARRAY_INDEX] = indices
   opening_x_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  opening_x_mesh.set_meta("source_mesh_key", "cab-66e7137de3b79380e05eb711ae004556:1761313272592801116")
  opening_x_mesh.set_meta("backend_winding_adapter", "Unity_to_Godot_front_face; exact Mulligan_X_Mark only")
 renderer.mesh = opening_x_mesh
 renderer.set_meta("source_cull_mode", "Back")
 renderer.set_meta("backend_winding_adapter", "reversed_triangle_indices")

func apply_device_overrides(state: Dictionary, mobile: bool) -> void:
 var category: int = 1 if mobile else 4
 for key in state.get("nodes", {}):
  var record: Dictionary = {}
  for target in objects.get(key, {}).get("refs", {}).values():
   var candidate: Dictionary = objects.get(target, {})
   if candidate.get("class_name", "") == "TransformOverride":
    record = candidate
    break
  if record.is_empty(): continue
  var data: Dictionary = record.get("data", {})
  if not bool(data.get("m_Enabled", true)): continue
  var categories: Array = data.get("m_screenCategory", [])
  var index: int = -1
  for i in range(categories.size()):
   if int(categories[i]) == category:
    index = i
    break
  if index < 0: continue
  var node: Node3D = state.nodes[key]
  var positions: Array = data.get("m_localPosition", [])
  var rotations: Array = data.get("m_localRotation", [])
  var scales: Array = data.get("m_localScale", [])
  if index < positions.size(): node.position = Curves.vec(positions[index])
  if index < rotations.size():
   var q: Dictionary = rotations[index]
   node.quaternion = Quaternion(float(q.x), float(q.y), float(q.z), float(q.w))
   state.source_rotations[key] = node.quaternion
  if index < scales.size(): node.scale = Curves.vec(scales[index])
  node.set_meta("source_screen_category", category)
  state.device_overrides.append({"key": key, "component": record.key, "category": category, "index": index})

func _add_opening_labels(state: Dictionary) -> void:
 var strings: Dictionary = opening_text.get("strings", {})
 for role in opening_text.get("text_nodes", {}):
  if not TEXT_KEYS.has(role): continue
  var spec: Dictionary = opening_text.text_nodes[role]
  var go_key: String = str(spec.get("refs", {}).get(".m_GameObject", ""))
  var parent: Node3D = state.nodes.get(go_key)
  if parent == null: continue
  var raw: Dictionary = spec.data
  var font_path: String = str(spec.get("runtime_font_path", OPENING_BASE + "fonts/GLEI00M_t_Outline__4016971574774461928.ttf"))
  var font: Font = load(font_path) as Font
  if font == null:
   missing.append({"role": role, "font": font_path})
   continue
  var label := Label3D.new()
  label.name = "OriginalOpeningZhCN_" + str(role)
  label.font = font
  label.text = str(strings.get(TEXT_KEYS[role], ""))
  label.font_size = int(spec.get("runtime_font_size", int(raw.m_FontSize)))
  # TextMesh uses characterSize / 10 world units per font pixel.
  label.pixel_size = float(spec.get("runtime_character_size_before_resize", float(raw.m_CharacterSize) * 0.01)) * 0.1
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
  label.no_depth_test = false
  label.shaded = false
  label.double_sided = true
  label.modulate = Curves.color(raw.m_TextColor)
  label.outline_modulate = Curves.color(raw.m_OutlineColor)
  label.outline_modulate.a *= label.modulate.a
  label.outline_size = int(round(float(raw.m_OutlineSize))) if bool(raw.m_Outline) else 0
  label.render_priority = clampi(int(raw.get("m_RenderQueue", 0)), -128, 127)
  label.outline_render_priority = label.render_priority
  # Bound fit uses Godot metrics, explicitly not the absent Unity glyph bounds.
  var fit: float = 1.0
  if bool(raw.get("m_ResizeToFit", false)):
   var measure: Vector2 = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
   var width: float = measure.x * label.pixel_size
   var height: float = font.get_height(label.font_size) * label.pixel_size
   if width > 0: fit = minf(fit, float(raw.m_Width) / width)
   if height > 0: fit = minf(fit, float(raw.m_Height) / height)
   label.pixel_size *= fit
  parent.add_child(label)
  label.set_meta("source_ubertext_key", spec.key)
  label.set_meta("source_game_object", go_key)
  label.set_meta("raster_compatibility", "Godot GLEI00M font metrics, fit, outline and rasterization; not Unity glyph parity")
  state.labels[role] = label
  var audit: Dictionary = {"role": role, "source": spec.key, "game_object": go_key, "text": label.text, "font": font_path, "font_size": label.font_size, "pixel_size": label.pixel_size, "fit": fit, "source_color": raw.m_TextColor, "shadow": false, "compatibility": "Godot font raster compatibility, not exact Unity glyphs"}
  state.text_audit.append(audit)
  opening_audit.append(audit)

func set_label_alpha(state: Dictionary, role: String, alpha: float) -> void:
 var label: Label3D = state.get("labels", {}).get(role)
 if not is_instance_valid(label): return
 label.modulate.a = clampf(alpha, 0.0, 1.0)
 var spec: Dictionary = opening_text.get("text_nodes", {}).get(role, {})
 label.outline_modulate.a = label.modulate.a * float(spec.get("data", {}).get("m_OutlineColor", {}).get("a", 1.0))

func set_labels_alpha(state: Dictionary, alpha: float) -> void:
 for role in state.get("labels", {}): set_label_alpha(state, str(role), alpha)

func material(key: String, texture_override: Texture2D = null) -> Material:
 var source: Dictionary = objects.get(key, {})
 var shader_key: String = str(source.get("refs", {}).get(".m_Shader", ""))
 var shader_id: String = shader_key.get_slice(":", 1)
 var routes: Dictionary = {"4516190081797324900": "desaturate", "-870869104636564592": "multiply", "45632884066622321":"weldline"}
 if routes.has(shader_id):
  var mat := ShaderMaterial.new()
  mat.shader = load("res://shaders/source_opening_" + str(routes[shader_id]) + ".gdshader")
  _bind_render_order(mat, source)
  _apply_source_samplers(mat, source)
  var props: Dictionary = source.data.get("m_SavedProperties", {})
  var colors: Dictionary = {}; var floats: Dictionary = {}
  for entry in props.get("m_Floats", []):
   floats[entry[0]] = entry[1]; mat.set_shader_parameter(entry[0], entry[1])
  for entry in props.get("m_Colors", []):
   colors[entry[0]] = Curves.color(entry[1]); mat.set_shader_parameter(entry[0], colors[entry[0]])
  for i in range(props.get("m_TexEnvs", []).size()):
   var entry: Array = props.m_TexEnvs[i]
   var tex: Texture2D = texture_override if texture_override != null and entry[0] == "_MainTex" else load_texture(str(source.refs.get(".m_SavedProperties.m_TexEnvs[%d][1].m_Texture" % i, "")))
   if tex != null: mat.set_shader_parameter(entry[0], tex)
   mat.set_shader_parameter(str(entry[0])+"_ST", Vector4(entry[1].m_Scale.x, entry[1].m_Scale.y, entry[1].m_Offset.x, 1.0-float(entry[1].m_Scale.y)-float(entry[1].m_Offset.y)))
  mat.set_meta("source_key", key); mat.set_meta("source_shader_key", shader_key)
  mat.set_meta("source_colors", colors); mat.set_meta("source_floats", floats)
  mat.set_meta("source_base_shader_path", "res://shaders/source_opening_" + str(routes[shader_id]) + ".gdshader")
  mat.set_meta("source_blend", "DstColor Zero" if shader_id == "-870869104636564592" else "SrcAlpha OneMinusSrcAlpha" if shader_id == "45632884066622321" else "One Zero")
  mat.set_meta("compatibility", "Original DXBC RGB equations and source render state; Godot GL color bridge. C+RGB_T compositor preserves destination RGB multiply; source alpha-zero is not coverage alpha." if shader_id == "-870869104636564592" else "Original DXBC equations and opaque source render state; Godot GL color bridge. Original scene light globals not recovered, bound LightingBlend=0.")
  return mat
 var result: Material = super.material(key, texture_override)
 if result != null and str(result.get_meta("compatibility", "")).begins_with("Untranslated"):
  var record: Dictionary = objects.get(key, {})
  var fallback_shader_key: String = str(record.get("refs", {}).get(".m_Shader", ""))
  var limitation: Dictionary = {"material": key, "shader": fallback_shader_key, "name": objects.get(fallback_shader_key, {}).get("data", {}).get("m_ParsedForm", {}).get("m_Name", ""), "status": "Original shader not translated; inherited compatibility fallback"}
  if not opening_shader_limits.has(limitation): opening_shader_limits.append(limitation)
 return result
