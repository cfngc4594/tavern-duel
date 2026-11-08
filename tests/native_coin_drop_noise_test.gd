extends SceneTree
func _init():call_deferred("run")
func run():
	var player=load("res://scripts/native_coin_player.gd").new();root.add_child(player)
	player.setup();player.place_at_source_bone();player.enable_source_ports(true)
	player.drop_source.inject_source_seeds([37,255])
	player.play_drop(true,false)
	player.advance(3.86)
	assert(player.drop_source.runtime_emitters.is_empty())
	player.advance(0.06)
	var audit=player.drop_source_audit()
	assert(audit.rendered_drop_emitters==2)
	for request in audit.requests:
		assert(request.rendered)
		assert(is_equal_approx(request.source_time,3.866666555404663))
	for item in player.drop_source.runtime_emitters.values():
		var solver=item.solver
		assert(solver.noise_gate)
		assert(solver.material is ShaderMaterial)
		assert(solver.noise_samples>0)
		assert(solver.emitted_count>0)
		assert(solver.source_key in ["7603337248942822606","-3132277453394176818"])
		var p=solver.particles[0]
		var state={"age":0.0,"position":Vector3.ZERO,"velocity":p.velocity,"render_velocity":p.velocity,"rotation":p.rotation}
		var with_noise=solver._integrate(p,state,0.01)
		solver.noise_gate=false
		var without_noise=solver._integrate(p,state,0.01)
		solver.noise_gate=true
		assert(with_noise.velocity.is_equal_approx(without_noise.velocity),"Noise must not accumulate into base velocity")
		assert(not with_noise.position.is_equal_approx(without_noise.position),"Noise must move source particles")
		assert((with_noise.position-without_noise.position).is_equal_approx((with_noise.render_velocity-without_noise.render_velocity)*0.01))
	player.advance(2.08)
	assert(player.drop_source.runtime_emitters.is_empty())
	assert(player.drop_source.completed_audits.size()==2)
	for done in player.drop_source.completed_audits:assert(done.source_destroyed)
	var sibling=Node3D.new();sibling.name="ActualCoinCard";player.add_child(sibling)
	player.finish_coin_object();assert(is_instance_valid(sibling) and not sibling.is_queued_for_deletion())
	print("NATIVE_COIN_DROP_NOISE_PASS original boundary/2renderers/source_seed/noise_motion/not_acceleration/deactivate/finish; explicit solver bridges remain")
	player.queue_free();await process_frame;quit()
