extends SceneTree

const Assets = preload("res://scripts/native_combat_assets.gd")
const Curves = preload("res://scripts/native_summon_curves.gd")
const TRANSFORM_KINDS := ["m_PositionCurves", "m_RotationCurves", "m_ScaleCurves", "m_EulerCurves"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var assets := Assets.new()
	var clip := _test_clip()
	var original := var_to_bytes(clip)
	assets.clips["Clip"] = clip
	var host := Node3D.new()
	root.add_child(host)
	var actual := _state(host, "subject")
	var expected := _state(host, "subject")
	var other_actual := _state(host, "")
	var other_expected := _state(host, "")
	for time in [-1.0, 0.0, 0.13, 0.43, 0.73, 1.0, 1.5, 0.17]:
		_check_pose(assets, clip, actual, expected, time, "subject")
		_check_pose(assets, clip, other_actual, other_expected, time, "")
	assert(var_to_bytes(clip) == original)

	var replacement := clip.duplicate(true)
	replacement.data.m_PositionCurves[0].curve.m_Curve[0].value.x = 17.5
	assets.clips["Clip"] = replacement
	_check_pose(assets, replacement, actual, expected, 0.43, "subject")
	assert(actual.paths.subject.position.x == 17.5)
	host.free()
	print("COMBAT_TRANSFORM_CLIP_CACHE_PASS exact transforms, weighted and stepped keys, empty tracks, multiple targets, clip replacement")
	quit()

func _state(host: Node3D, root_path: String) -> Dictionary:
	var paths: Dictionary = {}
	for path in ["", "animated", "empty", "euler"]:
		var node := Node3D.new()
		node.position = Vector3(7, -1, 2)
		node.rotation = Vector3(0.2, 0.4, 0.8)
		node.scale = Vector3(0.6, 0.8, 1.2)
		node.set_meta("source_key", path)
		host.add_child(node)
		paths[_path(root_path, path)] = node
	return {"paths": paths, "source_rotations": {}}

func _path(root_path: String, relative_path: String) -> String:
	return root_path + ("/" if not root_path.is_empty() and not relative_path.is_empty() else "") + relative_path

func _check_pose(assets: Assets, clip: Dictionary, actual: Dictionary, expected: Dictionary, time: float, root_path: String) -> void:
	assets.sample_clip(actual, "Clip", time, root_path)
	# Preserve the uncached implementation as an independent sampling oracle.
	for kind in TRANSFORM_KINDS:
		for track in clip.data.get(kind, []):
			var node: Node3D = expected.paths.get(_path(root_path, track.path))
			if node == null:
				continue
			var keys: Array = track.curve.m_Curve
			if kind == "m_RotationCurves" or kind == "m_EulerCurves":
				var rotation: Quaternion
				if kind == "m_RotationCurves":
					rotation = Quaternion(_component(keys, "x", time), _component(keys, "y", time), _component(keys, "z", time), _component(keys, "w", time, 1.0))
					rotation = rotation.normalized() if rotation.length_squared() > 0.000001 else Quaternion.IDENTITY
				else:
					rotation = Basis.from_euler(_vector(keys, time) * PI / 180.0).get_rotation_quaternion()
				node.quaternion = rotation
				expected.source_rotations[node.get_meta("source_key")] = rotation
			elif kind == "m_PositionCurves":
				node.position = _vector(keys, time)
			else:
				node.scale = _vector(keys, time, 1.0)
	for path in expected.paths:
		assert(var_to_bytes(actual.paths[path].transform) == var_to_bytes(expected.paths[path].transform))
	assert(var_to_bytes(actual.source_rotations) == var_to_bytes(expected.source_rotations))

func _component(keys: Array, name: String, time: float, fallback: float = 0.0) -> float:
	return Curves.scalar_keys(Curves.component_keys(keys, name), time, fallback)

func _vector(keys: Array, time: float, fallback: float = 0.0) -> Vector3:
	return Vector3(_component(keys, "x", time, fallback), _component(keys, "y", time, fallback), _component(keys, "z", time, fallback))

func _keys(from: Vector4, to: Vector4) -> Array:
	return [
		{"time": 0.0, "value": {"x": from.x, "y": from.y, "z": from.z, "w": from.w},
			"outSlope": {"x": 0.3, "y": -0.2, "z": 0.5, "w": 0.1},
			"outWeight": {"x": 0.15, "y": 0.45, "z": 0.25, "w": 0.6}, "weightedMode": 2},
		{"time": 1.0, "value": {"x": to.x, "y": to.y, "z": to.z, "w": to.w},
			"inSlope": {"x": 0.8, "y": 0.7, "z": -0.2, "w": 0.3},
			"inWeight": {"x": 0.55, "y": 0.15, "z": 0.35, "w": 0.3}, "weightedMode": 1},
	]

func _track(path: String, keys: Array) -> Dictionary:
	return {"path": path, "curve": {"m_Curve": keys}}

func _test_clip() -> Dictionary:
	var stepped := _keys(Vector4(1, 2, 3, 0), Vector4(5, 6, 7, 0))
	stepped[0].outSlope.x = "Infinity"
	stepped[1].inTangentInfinity = 1
	var rotation := _keys(Vector4(0.1, 0.2, 0.3, 0.9), Vector4(0.3, 0.2, 0.1, 0.85))
	return {"data": {
		"m_PositionCurves": [_track("", stepped), _track("missing", stepped), _track("empty", [])],
		"m_RotationCurves": [_track("animated", rotation), _track("euler", rotation), _track("empty", [])],
		"m_ScaleCurves": [_track("animated", _keys(Vector4(1, 2, 1, 0), Vector4(2, 1, 2, 0))), _track("empty", [])],
		"m_EulerCurves": [_track("euler", _keys(Vector4.ZERO, Vector4(10, -70, 85, 0)))],
	}}
