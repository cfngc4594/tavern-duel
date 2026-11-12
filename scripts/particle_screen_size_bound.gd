extends RefCounted

static func fits_perspective(center: Vector3, x: Vector3, y: Vector3, camera_transform: Transform3D, focal_max: float, clamp_max: float) -> bool:
	# Bound X/depth and Y/depth from the center using the nearest possible
	# corner depth. A margin preserves the full projection near the limit.
	var radius := x.length() + y.length()
	var local_center := center * camera_transform
	var depth := -local_center.z
	if depth <= radius:
		return false
	var off_axis := maxf(absf(local_center.x), absf(local_center.y))
	var fraction_bound := focal_max * radius * (1.0 + off_axis / depth) / (depth - radius)
	return fraction_bound < clamp_max * 0.98
