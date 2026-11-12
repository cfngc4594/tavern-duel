extends RefCounted
## A viewport updated once retains its last color buffer. Only the main board
## owns this policy. Independent captures still control their own viewports.

var _view: SubViewport
var _changed: Dictionary = {&"initial": true}
var _continuous: Dictionary = {}
var _dependencies: Dictionary = {}
var _seen: Dictionary = {}
var _draws := 0
var _reused := 0
var _continuous_mode := false
var _causes: Dictionary = {}
var _external_inputs := RegEx.create_from_string("\\bTIME\\b|\\bglobal\\s+uniform\\b|#\\s*include\\b|\\bhint_(screen|depth|normal_roughness)_texture\\b")

func setup(view: SubViewport) -> void:
	_view = view
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	RenderingServer.frame_pre_draw.connect(_before_draw)

func begin_sync() -> void:
	_continuous.clear()
	_seen.clear()

func invalidate(cause: StringName) -> void:
	_changed[cause] = true

func require_continuous(cause: StringName) -> void:
	_continuous[cause] = true

func has_external_shader_inputs(shader: Shader) -> bool:
	return _external_inputs.search(shader.code) != null

func observe_value(value: Variant) -> void:
	if value is ImageTexture or value is CompressedTexture2D:
		_watch(value, &"texture")
	elif value is Texture:
		# ViewportTexture and animated textures can change behind the same RID.
		require_continuous(&"live_texture")
	elif value is Array:
		for item in value:
			if item is Texture:observe_value(item)

func observe_mesh(mesh: Mesh, surfaces: int) -> void:
	_watch(mesh, &"mesh", surfaces)

func finish_sync() -> void:
	for id in _dependencies.keys():
		if not _seen.has(id):_unwatch(id)

func audit() -> Dictionary:
	return {"draws":_draws,"reused":_reused,"causes":_causes.duplicate()}

func close() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw):RenderingServer.frame_pre_draw.disconnect(_before_draw)
	for id in _dependencies.keys():_unwatch(id)
	if is_instance_valid(_view):_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view = null

func _watch(resource: Resource, cause: StringName, surfaces: int = -1) -> void:
	var id := resource.get_instance_id()
	if _seen.has(id):return
	_seen[id] = true
	if not _dependencies.has(id):
		var callback := invalidate.bind(cause)
		resource.changed.connect(callback)
		_dependencies[id] = {"source":weakref(resource),"callback":callback,"surfaces":surfaces}
		invalidate(cause)
	elif int(_dependencies[id].surfaces) != surfaces:
		# ArrayMesh.clear_surfaces can clear a same-RID surface without changed.
		_dependencies[id].surfaces = surfaces
		invalidate(cause)

func _unwatch(id: int) -> void:
	var record: Dictionary = _dependencies[id]
	var resource: Resource = record.source.get_ref()
	if is_instance_valid(resource):resource.changed.disconnect(record.callback)
	_dependencies.erase(id)

func _before_draw() -> void:
	if not is_instance_valid(_view) or not _view.is_inside_tree():return
	var continuous := not _continuous.is_empty()
	if continuous:
		if not _continuous_mode:_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif not _changed.is_empty():
		# Godot resets the renderer's UPDATE_ONCE after drawing. Re-arm explicitly.
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif _continuous_mode:
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_continuous_mode = continuous
	if _changed.is_empty() and not continuous:
		_reused += 1
		return
	_draws += 1
	for cause in _changed:_causes[cause] = int(_causes.get(cause, 0)) + 1
	for cause in _continuous:
		if not _changed.has(cause):_causes[cause] = int(_causes.get(cause, 0)) + 1
	_changed.clear()
