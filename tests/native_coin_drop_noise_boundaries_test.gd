extends SceneTree
func _init():call_deferred("run")
func make_player():
	var p=load("res://scripts/native_coin_player.gd").new();root.add_child(p);p.setup();p.enable_source_ports(true);p.drop_source.inject_source_seeds([1,2]);return p
func run():
	var player=make_player();player.play_drop(true,false)
	player.advance(6.1)
	var audit=player.drop_source_audit()
	assert(audit.requests.size()==4 and audit.particle_audits.size()==2)
	assert(audit.requests[0].source_time==3.866666555404663 and audit.requests[2].source_time==6.0)
	for item in audit.particle_audits:assert(item.original_count>0 and item.source_destroyed)
	player.finish_coin_object();player.queue_free()
	var second=make_player();second.play_drop(false,false);second.advance(4.0)
	assert(second.drop_source_audit().requests.is_empty(),"Do not invent Drop2 particles for Go2Card")
	second.finish_coin_object();second.queue_free()
	var live=make_player();live.play_drop(true,false);live.advance(4.0)
	assert(live.drop_source.runtime_emitters.size()==2)
	live.finish_coin_object();assert(live.drop_source.runtime_emitters.is_empty())
	for item in live.drop_source.completed_audits:assert(item.source_destroyed)
	live.advance(1.0);assert(live.drop_source.runtime_emitters.is_empty())
	live.queue_free()
	var solver=load("res://scripts/native_coin_drop_particles.gd").new()
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_coin/drop_particles.json"))
	var system=data.emitters[0].system.data
	assert(solver._verified_source_configuration(system.NoiseModule,system))
	var unsupported=system.NoiseModule.duplicate(true);unsupported.quality=1
	assert(not solver._verified_source_configuration(unsupported,system))
	var collision_system=system.duplicate(true);collision_system.CollisionModule.enabled=true
	assert(not solver._verified_source_configuration(collision_system.NoiseModule,collision_system))
	var velocity_system=system.duplicate(true);velocity_system.VelocityModule.enabled=true
	assert(not solver._verified_source_configuration(velocity_system.NoiseModule,velocity_system))
	solver.free()
	print("NATIVE_COIN_DROP_BOUNDARIES_PASS one_big_step crosses exactsourcekeys; Go2Card noinventedDrop; liveDestroy noresurrection; unverifiedconfig rejected")
	await process_frame;quit()
