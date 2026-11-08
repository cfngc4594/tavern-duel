extends SceneTree
func _init():
	var source_rng=load("res://scripts/native_coin_source_random.gd")
	assert(source_rng.next_state([1,2,3,4])==[2,3,4,2061])
	var kernel=load("res://scripts/native_coin_noise_kernel.gd").new()
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
	var seed_vectors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/noise_seed_vectors.json"))
	for row in seed_vectors:
		var got=kernel.source_seed_offset(int(row.seed))
		assert(got.is_equal_approx(Vector3(row.offset[0],row.offset[1],row.offset[2])))
	print("NATIVE_COIN_NOISE_KERNEL_PASS vectors=%s max_error=%s; source kernel verified; runtime requires explicit source ports"%[vectors.count,maximum]);quit()
