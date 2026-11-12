extends SceneTree
## Bake only the static phone board geometry using the runtime source converter.
const BoardProbe := preload("res://original_board/scripts/board_probe.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := BoardProbe.new()
	var scene_json := FileAccess.get_file_as_string(BoardProbe.PHONE_DATA_PATH)
	var scene: Variant = JSON.parse_string(scene_json)
	if not scene is Dictionary or not scene.get("meshes") is Dictionary or scene.meshes.is_empty():
		_fail(probe, "Missing phone board mesh descriptors")
		return
	probe.data = scene
	var entries := {}
	for key in scene.meshes:
		var source_file: String = scene.meshes[key].file
		if not FileAccess.file_exists(source_file):
			_fail(probe, "Missing mesh source " + source_file)
			return
		var mesh: ArrayMesh = probe._build_mesh(key)
		if mesh == null or mesh.get_surface_count() == 0:
			_fail(probe, "No surfaces built from " + source_file)
			return
		entries[key] = {"mesh": mesh, "audit": probe.audit.meshes.back(), "sha256": FileAccess.get_sha256(source_file)}
	var pack := Resource.new()
	pack.set_meta("bake_version", BoardProbe.PHONE_MESH_BAKE_VERSION)
	pack.set_meta("scene_sha256", scene_json.sha256_text())
	pack.set_meta("meshes", entries)
	var path := BoardProbe.PHONE_MESH_BAKE_PATH
	var status := ResourceSaver.save(pack, path, ResourceSaver.FLAG_COMPRESS)
	if status != OK:
		_fail(probe, "Could not save phone board mesh pack: " + error_string(status))
		return
	var serialized := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	if serialized == null or not _same_meshes(entries, serialized.get_meta("meshes", {})):
		DirAccess.remove_absolute(path)
		_fail(probe, "Phone board mesh pack failed round-trip validation")
		return
	probe.free()
	print("PHONE_BOARD_MESH_BAKE_PASS meshes=", entries.size(), " bytes=", FileAccess.get_size(path))
	quit()

func _same_meshes(source: Dictionary, packed: Dictionary) -> bool:
	if packed.size() != source.size():
		return false
	for key in source:
		if not packed.has(key) or source[key].audit != packed[key].audit or source[key].sha256 != packed[key].sha256:
			return false
		var original: ArrayMesh = source[key].mesh
		var baked: ArrayMesh = packed[key].mesh
		if original.get_aabb() != baked.get_aabb() or original.get_surface_count() != baked.get_surface_count():
			return false
		for surface in original.get_surface_count():
			if original.surface_get_format(surface) != baked.surface_get_format(surface) or original.surface_get_arrays(surface) != baked.surface_get_arrays(surface):
				return false
	return true

func _fail(probe: Node, message: String) -> void:
	probe.free()
	printerr(message)
	quit(1)
