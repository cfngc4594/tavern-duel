extends SceneTree
func _init():call_deferred("run")
func run():
	var player=load("res://scripts/native_coin_player.gd").new();root.add_child(player);player.setup();player.place_at_source_bone();player.enable_source_ports(true)
	player.send_birth(false);player.advance(0.2)
	assert(player.birth_emitters.size()==2)
	var counts=[]
	for emitter in player.birth_emitters:
		var audit:Dictionary=emitter.get_audit();print(JSON.stringify(audit))
		assert(audit.unsupported.is_empty());assert(is_equal_approx(audit.stop_seconds,0.1))
		assert(audit.original_count>0);assert(audit.live_count>0)
		counts.append(audit.original_count)
	player.advance(0.2)
	for i in range(2):assert(player.birth_emitters[i].emitted_count==counts[i])
	player.advance(2.0)
	for emitter in player.birth_emitters:assert(emitter.live_count==0)
	print("NATIVE_COIN_PARTICLES_PASS source Cone/Force/rates/curves/materials; StopEmitting .1 preserves particles then expires; no new emissions; Godot compatibility solver not Unity engine")
	player.queue_free();quit()
