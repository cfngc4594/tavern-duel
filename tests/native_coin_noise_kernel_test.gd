extends SceneTree
func _init():
	var source_rng=load("res://scripts/native_coin_source_random.gd")
	assert(source_rng.next_state([1,2,3,4])==[2,3,4,2061])
	var kernel_type = load("res://scripts/native_coin_noise_kernel.gd")
	var kernel = kernel_type.new()
	if "--require-native-coin-noise" in OS.get_cmdline_user_args():
		assert(kernel_type._native_curl != null, "Mac coin Noise extension was not loaded and configured")
	var vectors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/noise_kernel_vectors.json"))
	var maximum=0.0
	for row in vectors.vectors:
		var got=kernel.derivative(Vector3(row.p[0],row.p[1],row.p[2]),row.frequency)
		var expected=Vector2(row.reference_dx_dy[0],row.reference_dx_dy[1])
		maximum=maxf(maximum,maxf(absf(got.x-expected.x),absf(got.y-expected.y)))
	assert(maximum<0.00002,"Derivative exceeds independent instruction-reference tolerance: %s"%maximum)
	for p in [Vector3(.1,.2,.3),Vector3(-2.1,3.4,.2)]:
		assert(kernel.octave_derivative(p,.85,2,1.0,1.0).is_equal_approx(kernel.derivative(p,.85)))
	var curl_vectors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/noise_curl_vectors.json"))
	for row in curl_vectors:
		var got=kernel.curl_at_source_position(Vector3(row.p[0],row.p[1],row.p[2]),Vector3(row.offset[0],row.offset[1],row.offset[2]),row.scroll,row.frequency,2,1.0,1.0)
		var want=Vector3(row.curl[0],row.curl[1],row.curl[2])
		assert((got-want).length()<0.00003,"Curl exceeds original arithmetic reference tolerance")
		if kernel_type._native_curl != null:
			_check_native_curl(kernel_type, kernel, Vector3(row.p[0], row.p[1], row.p[2]), Vector3(row.offset[0], row.offset[1], row.offset[2]), row.scroll, row.frequency)
	var seed_vectors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/noise_seed_vectors.json"))
	for row in seed_vectors:
		var got=kernel.source_seed_offset(int(row.seed))
		assert(got.is_equal_approx(Vector3(row.offset[0],row.offset[1],row.offset[2])))
	var exact_count := 0
	if kernel_type._native_curl != null:
		var random := RandomNumberGenerator.new()
		random.seed = 5834
		for index in 2048:
			var span := 4.0 if index < 1024 else 512.0
			var point := Vector3(random.randf_range(-span, span), random.randf_range(-span, span), random.randf_range(-span, span))
			var offset: Vector3 = kernel_type.source_seed_offset(random.randi())
			var frequency: float = [0.8500000238418579, 1.0, 1.2, 0.0][index % 4]
			_check_native_curl(kernel_type, kernel, point, offset, random.randf_range(-2.0, 8.0), frequency)
			exact_count += 1
		exact_count += curl_vectors.size()
	print("NATIVE_COIN_NOISE_KERNEL_PASS vectors=", vectors.count, " max_error=", maximum, " native_exact=", exact_count)
	quit()

func _check_native_curl(kernel_type: GDScript, kernel: RefCounted, point: Vector3, offset: Vector3, scroll: float, frequency: float) -> void:
	var native: Variant = kernel_type._native_curl.curl(point, offset, scroll, frequency)
	assert(native is Vector3, "Source-range inputs must use the native kernel")
	kernel_type.native_curl_enabled = false
	var reference: Vector3 = kernel.curl_at_source_position(point, offset, scroll, frequency, 2, 1.0, 1.0)
	kernel_type.native_curl_enabled = true
	assert(var_to_bytes(native) == var_to_bytes(reference), "Native curl diverged for %s offset %s scroll %s frequency %s: %s / %s" % [point, offset, scroll, frequency, native, reference])
