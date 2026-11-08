extends RefCounted
## Recovered TrailRenderer parameters and live source material/visibility bindings.
## Unity CoreModule only exposes native *_Injected calls, not its tessellator.
## Point sampling, endpoint clipping and camera-facing ribbon joins below are an
## explicit Godot compatibility solver, not recovered Unity native rendering.
const Curves = preload("res://scripts/native_summon_curves.gd")
const EPSILON := 0.000001
var state: Dictionary = {}
var assets
var projection: Node3D
var entries: Array = []
var age := -1.0
var disposed := false
var warnings: Array = []
var _last_audit: Dictionary = {}
var _metric_basis := Basis.IDENTITY
var _metric_inverse := Basis.IDENTITY
var _registration_valid := true

func setup(effect_state: Dictionary, source_assets, source_projection: Node3D) -> void:
	if not entries.is_empty(): dispose()
	var previous = effect_state.get("trail_owner")
	if previous is WeakRef:
		var owner = previous.get_ref()
		if is_instance_valid(owner) and owner != self: owner.dispose()
	state = effect_state; assets = source_assets; projection = source_projection
	state.trail_owner = weakref(self)
	state.trail_renderers = {}
	disposed = false; age = -1.0; warnings.clear(); _last_audit.clear()
	_metric_basis = projection.global_basis
	_registration_valid = absf(_metric_basis.determinant()) > EPSILON
	if not _registration_valid:
		_warn("Singular board registration: emission suspended until the projection is valid")
		_metric_basis = Basis.IDENTITY
	_metric_inverse = _metric_basis.inverse()
	for go_key in state.get("nodes", {}):
		var record: Dictionary = assets.component(go_key, "TrailRenderer")
		if record.is_empty(): continue
		var node: Node3D = state.nodes[go_key]
		# Three Arcane heads have BOTH MeshRenderer and TrailRenderer. Preserve
		# GetComponent<Renderer>'s original first renderer, while retaining this
		# component's independent identity for recursive Renderer operations.
		var storage_key: String = str(record.key) if state.renderers.has(go_key) else str(go_key)
		var data: Dictionary = record.data.duplicate(true)
		var mesh := ArrayMesh.new()
		var mi := MeshInstance3D.new(); mi.name = "OriginalTrailRenderer"
		# Keep hierarchy ownership, visibility and RTT discovery, but never inherit
		# emitter motion twice or invert an animated (possibly zero-scale) emitter.
		node.add_child(mi); mi.top_level = true; mi.global_transform = Transform3D.IDENTITY
		mi.mesh = mesh; mi.visible = bool(data.get("m_Enabled", true))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("source_key", go_key); mi.set_meta("source_component_key", record.key)
		mi.set_meta("source_trail_renderer", true)
		var materials: Array = []
		for index in range(data.get("m_Materials", []).size()):
			materials.append(assets.material(str(record.refs.get(".m_Materials[%d]" % index, ""))))
		if materials.is_empty(): _warn("Original trail has no material: " + str(record.key))
		state.renderers[storage_key] = mi; state.materials[storage_key] = materials; state.trail_renderers[go_key] = mi
		var entry: Dictionary = {"key":record.key, "go_key":go_key, "storage_key":storage_key, "source":node, "data":data, "mesh":mesh, "renderer":mi, "materials":materials, "points":[], "head":{}, "committed_count":0, "vertices":0, "resets":0, "emitting":bool(data.get("m_Emitting",true)), "last_active":false, "last_motion":0.0, "source_destroyed":false, "source_shadow_pass":_source_has_shadow_pass(record)}
		_validate(entry)
		entries.append(entry)

func _source_has_shadow_pass(record: Dictionary) -> bool:
	for field in record.get("refs", {}):
		if not str(field).begins_with(".m_Materials["): continue
		var material: Dictionary = assets.objects.get(record.refs[field], {})
		var shader: Dictionary = assets.objects.get(material.get("refs", {}).get(".m_Shader", ""), {})
		var parsed: Dictionary = shader.get("data", {}).get("m_ParsedForm", {})
		if not str(parsed.get("m_FallbackName", "")).is_empty(): return true
		for sub in parsed.get("m_SubShaders", []):
			for shader_pass in sub.get("m_Passes", []):
				for tag in shader_pass.get("m_State", {}).get("m_Tags", {}).get("tags", []):
					if str(tag[0]).to_lower() == "lightmode" and str(tag[1]).to_lower() == "shadowcaster": return true
	# Two Arcane heads serialize castShadows=On, but the recovered material
	# has no ShadowCaster pass or fallback. shadowBias cannot affect its output.
	return false

func _warn(message: String) -> void:
	if not warnings.has(message): warnings.append(message)

func _validate(entry: Dictionary) -> void:
	var d: Dictionary = entry.data; var p: Dictionary = d.get("m_Parameters", {})
	for name in ["numCornerVertices", "numCapVertices"]:
		if int(p.get(name, 0)) != 0: _warn("Unsupported original trail " + name + ": " + str(entry.key))
	if int(p.get("alignment", 0)) not in [0, 1]: _warn("Unsupported original trail alignment: " + str(entry.key))
	if int(p.get("textureMode", 0)) not in [0, 1, 2, 3]: _warn("Unsupported original trail texture mode: " + str(entry.key))
	if bool(p.get("generateLightingData", false)): _warn("Original lit trail normals/tangents use compatibility ribbon geometry: " + str(entry.key))
	if bool(d.get("m_Autodestruct", false)): _warn("Future AutoDestruct compatibility deactivates the source GO instead of deleting shared source references: " + str(entry.key))
	if bool(d.get("m_ApplyActiveColorSpace", false)): _warn("Original active color space is not recovered for trail: " + str(entry.key))
	if int(d.get("m_CastShadows", 0)) != 0 and bool(entry.source_shadow_pass): _warn("Original trail shadow rasterization unavailable: " + str(entry.key))
	if int(d.get("m_SortingLayerID", 0)) != 0 or int(d.get("m_SortingOrder", 0)) != 0: _warn("Original trail non-default sorting layer/order unavailable: " + str(entry.key))

func set_emitting(go_key: String, value: bool) -> void:
	for entry in entries:
		if entry.go_key == go_key: entry.emitting = value

func clear(go_key: String = "") -> void:
	for entry in entries:
		if go_key != "" and entry.go_key != go_key: continue
		entry.points.clear(); entry.head.clear(); entry.mesh.clear_surfaces(); entry.vertices = 0

func advance(seconds: float) -> void:
	if disposed: return
	var now := maxf(0.0, seconds)
	if now + EPSILON < age:
		clear()
		for entry in entries: entry.resets += 1
	age = now
	_registration_valid = is_instance_valid(projection) and absf(projection.global_basis.determinant()) > EPSILON
	if _registration_valid:
		_metric_basis = projection.global_basis; _metric_inverse = _metric_basis.inverse()
	for entry in entries: _advance_entry(entry, now)

func _distance(a: Vector3, b: Vector3) -> float:
	return (_metric_inverse * (a - b)).length()

func _advance_entry(entry: Dictionary, now: float) -> void:
	if not is_instance_valid(entry.source) or not is_instance_valid(entry.renderer): return
	var lifetime := maxf(0.0, float(entry.data.get("m_Time", 0.0)))
	var active: bool = entry.source.is_visible_in_tree() and _registration_valid and not bool(entry.source_destroyed)
	var point: Vector3 = entry.source.global_position
	if not point.is_finite(): active = false
	# Renderer.enabled controls drawing, not the GameObject's simulation. FSM
	# SetVisibility/clip m_Enabled edit this same MeshInstance.visible directly.
	if active and bool(entry.emitting) and lifetime > EPSILON:
		if entry.head.is_empty() or not bool(entry.last_active):
			entry.head = {"position":point, "time":now}
			entry.points.append(entry.head.duplicate()); entry.committed_count += 1
		elif not entry.points.is_empty() and is_equal_approx(float(entry.points[-1].time), now):
			# Spawn and post-motion sampling can share age zero. Replace, never
			# add a false segment between two initialization poses at one instant.
			entry.head = {"position":point, "time":now}; entry.points[-1] = entry.head.duplicate()
		elif point.distance_squared_to(entry.head.position) > EPSILON * EPSILON:
			entry.head = {"position":point, "time":now}; entry.last_motion = now
			var minimum := maxf(EPSILON, float(entry.data.get("m_MinVertexDistance", 0.1)))
			if entry.points.is_empty() or _distance(point, entry.points[-1].position) + EPSILON >= minimum:
				# At most one committed source sample per observed motion update;
				# no fictitious original random/intermediate trajectory is invented.
				entry.points.append(entry.head.duplicate()); entry.committed_count += 1
	entry.last_active = active
	var cutoff := now - lifetime
	# Retain at most one expired predecessor, solely to clip the oldest segment
	# to its exact lifetime boundary. All stored positions stay world anchored.
	while entry.points.size() >= 2 and float(entry.points[1].time) <= cutoff:
		entry.points.pop_front()
	if not entry.points.is_empty() and float(entry.points[-1].time) <= cutoff and (entry.head.is_empty() or float(entry.head.time) <= cutoff):
		entry.points.clear(); entry.head.clear()
	if bool(entry.data.get("m_Autodestruct", false)) and now - float(entry.last_motion) >= lifetime and entry.points.is_empty():
		# All fifteen restored components have AutoDestruct=false. Future true
		# records deactivate their source GO without deleting shared state refs.
		entry.source_destroyed = true; entry.source.visible = false
	_rebuild(entry, now)

static func gradient_sample(gradient: Dictionary, fraction: float) -> Color:
	var t := clampf(fraction, 0.0, 1.0)
	var color := Color.WHITE
	for alpha_only in [false, true]:
		var prefix := "atime" if alpha_only else "ctime"
		var count := int(gradient.get("m_NumAlphaKeys" if alpha_only else "m_NumColorKeys", 0))
		if count <= 0: continue
		var value := Curves.color(gradient.get("key0", {}))
		for index in range(1, count):
			var b := float(gradient.get(prefix + str(index), 65535)) / 65535.0
			var a := float(gradient.get(prefix + str(index - 1), 0)) / 65535.0
			var next := Curves.color(gradient.get("key" + str(index), {}))
			if t <= b:
				var weight := clampf((t - a) / maxf(EPSILON, b - a), 0.0, 1.0)
				if int(gradient.get("m_Mode", 0)) == 1: weight = 0.0 if t < b else 1.0
				value = Curves.color(gradient.get("key" + str(index - 1), {})).lerp(next, weight)
				break
			value = next
		if alpha_only: color.a = value.a
		else: color.r = value.r; color.g = value.g; color.b = value.b
	return color

func _live_points(entry: Dictionary, now: float) -> Array:
	var result: Array = entry.points.duplicate(true)
	if not entry.head.is_empty() and (result.is_empty() or entry.head.position.distance_squared_to(result[-1].position) > EPSILON * EPSILON): result.append(entry.head.duplicate())
	var cutoff := now - maxf(0.0, float(entry.data.get("m_Time", 0.0)))
	while result.size() >= 2 and float(result[1].time) <= cutoff: result.pop_front()
	if result.size() >= 2 and float(result[0].time) < cutoff:
		var a: Dictionary = result[0]; var b: Dictionary = result[1]
		var t := clampf((cutoff - float(a.time)) / maxf(EPSILON, float(b.time) - float(a.time)), 0.0, 1.0)
		result[0] = {"position":a.position.lerp(b.position, t), "time":cutoff}
	if result.size() < 2: return []
	result.reverse() # Unity start width/color is the newest, emitter-facing end.
	return result

func _rebuild(entry: Dictionary, now: float) -> void:
	var mesh: ArrayMesh = entry.mesh; mesh.clear_surfaces(); entry.vertices = 0
	var points := _live_points(entry, now)
	if points.size() < 2: return
	var p: Dictionary = entry.data.get("m_Parameters", {})
	var lengths: Array[float] = [0.0]
	for index in range(1, points.size()): lengths.append(lengths[-1] + _distance(points[index].position, points[index - 1].position))
	var total: float = lengths[-1]
	if total <= EPSILON: return
	var camera: Camera3D = entry.renderer.get_viewport().get_camera_3d()
	var view_normal := Vector3.BACK
	if is_instance_valid(camera): view_normal = camera.global_basis.z.normalized()
	var positions := PackedVector3Array(); var colors := PackedColorArray(); var uv := PackedVector2Array(); var normals := PackedVector3Array(); var indices := PackedInt32Array()
	var texture_scale: Dictionary = p.get("textureScale", {"x":1.0,"y":1.0})
	for index in range(points.size()):
		var center: Vector3 = points[index].position
		var before: Vector3 = points[maxi(0, index - 1)].position
		var after: Vector3 = points[mini(points.size() - 1, index + 1)].position
		var tangent := (before - after).normalized()
		var normal := view_normal
		if int(p.get("alignment", 0)) == 1:
			var forward: Vector3 = entry.source.global_basis.z
			if forward.length_squared() > EPSILON: normal = forward.normalized()
		elif is_instance_valid(camera) and camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
			normal = (camera.global_position - center).normalized()
		var side := tangent.cross(normal)
		if side.length_squared() <= EPSILON: side = tangent.cross(Vector3.UP)
		if side.length_squared() <= EPSILON: side = Vector3.RIGHT
		side = side.normalized()
		var fraction := lengths[index] / total
		var width := maxf(0.0, float(p.get("widthMultiplier", 1.0)) * Curves.scalar_keys(p.get("widthCurve", {}).get("m_Curve", []), fraction, 1.0))
		var half_side := side * (width * 0.5 / maxf(EPSILON, (_metric_inverse * side).length()))
		var tint := gradient_sample(p.get("colorGradient", {}), fraction)
		var u := fraction
		match int(p.get("textureMode", 0)):
			1: u = lengths[index]
			2: u = float(index) / float(points.size() - 1)
			3: u = float(index)
		u *= float(texture_scale.get("x", 1.0))
		positions.append(center - half_side); positions.append(center + half_side)
		colors.append(tint); colors.append(tint); normals.append(normal); normals.append(normal)
		# Original v=[0,scaleY] converted once to upper-left Godot UV.
		uv.append(Vector2(u, 1.0)); uv.append(Vector2(u, 1.0 - float(texture_scale.get("y", 1.0))))
		if index > 0:
			var k := index * 2
			indices.append_array(PackedInt32Array([k-2,k-1,k,k,k-1,k+1]))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
	# Unity renders the same ribbon once per material. Reuse the exact source
	# translated shaders/samplers, with material instances shared with FSM actions.
	for index in range(entry.materials.size()):
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		entry.renderer.set_surface_override_material(index, entry.materials[index])
	entry.vertices = positions.size()

func get_audit() -> Dictionary:
	if disposed: return _last_audit.duplicate(true)
	var rows: Array = []
	for entry in entries:
		var mats: Array = []
		for mat in entry.materials:
			if mat != null: mats.append({"source_key":mat.get_meta("source_key", ""), "intensity":mat.get_shader_parameter("_Intensity") if mat is ShaderMaterial else null})
		rows.append({"source_key":entry.key, "go_key":entry.go_key, "source_parameters":entry.data.duplicate(true), "points":entry.points.size(), "committed_count":entry.committed_count, "vertices":entry.vertices, "renderer_enabled":entry.renderer.visible if is_instance_valid(entry.renderer) else false, "go_active":entry.source.is_visible_in_tree() if is_instance_valid(entry.source) else false, "emitting":entry.emitting, "materials":mats, "rewind_resets":entry.resets})
	return {"renderer_count":entries.size(), "age":age, "disposed":false, "trails":rows, "warnings":warnings.duplicate(), "compatibility":"Original serialized renderer, width/gradient, materials, UV and lifetime retained. Unity native trajectory sampling, endpoint clipping, joins and camera rasterization are replaced by explicit Godot ribbon geometry; no original native kernel or game RNG claimed."}

func dispose() -> void:
	if disposed: return
	_last_audit = get_audit(); _last_audit.disposed = true
	for entry in entries:
		if state.get("renderers", {}).get(entry.storage_key) == entry.renderer:
			state.renderers.erase(entry.storage_key); state.materials.erase(entry.storage_key)
		if state.get("trail_renderers", {}).get(entry.go_key) == entry.renderer: state.trail_renderers.erase(entry.go_key)
		if is_instance_valid(entry.renderer): entry.renderer.free()
		entry.points.clear(); entry.head.clear(); entry.materials.clear()
	entries.clear(); state.erase("trail_owner"); state = {}; assets = null; projection = null; disposed = true
