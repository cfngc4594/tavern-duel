extends SceneTree
func _init():call_deferred("run")
func run():
	var player=load("res://scripts/native_coin_player.gd").new();root.add_child(player);player.setup();player.place_at_source_bone();player.enable_source_ports(true)
	var actual_card=Node3D.new();actual_card.name="ActualCardSibling";player.add_child(actual_card)
	var card_birth=Node3D.new();card_birth.name="CardBirthSibling";player.add_child(card_birth)
	player.play_drop(false,false);player.send_birth(false);player.advance(0.05)
	var old_root:Node3D=player.nodes["-6567163448337853234"]
	var old_emitters:Array=player.birth_emitters.duplicate()
	assert(not player.playing.is_empty());assert(old_emitters.size()==2)
	player.finish_coin_object()
	assert(player.coin_object_finished);assert(player.playing.is_empty());assert(player.birth_age<0)
	assert(player.birth_emitters.is_empty());assert(player.nodes.is_empty());assert(player.meshes.is_empty())
	assert(old_root.is_queued_for_deletion());assert(not old_root.visible)
	for emitter in old_emitters:
		assert(emitter.source_destroyed);assert(emitter.particles.is_empty());assert(not emitter.visible);assert(emitter.is_queued_for_deletion())
	assert(actual_card.get_parent()==player and not actual_card.is_queued_for_deletion() and actual_card.visible)
	assert(card_birth.get_parent()==player and not card_birth.is_queued_for_deletion() and card_birth.visible)
	# End callbacks can be repeated, and a pending same-frame tick cannot resurrect it.
	player.finish_coin_object();player.advance(10.0);player.play_drop(false,false);player.send_birth(false);player.sample_clip("Coin2Card",0.0);player.bind_source_scene_clock(10.0)
	assert(player.playing.is_empty() and player.birth_emitters.is_empty())
	await process_frame
	assert(not is_instance_valid(old_root))
	for emitter in old_emitters:assert(not is_instance_valid(emitter))
	assert(is_instance_valid(actual_card) and is_instance_valid(card_birth))
	assert(actual_card.get_parent()==player and card_birth.get_parent()==player)
	print("NATIVE_COIN_FINISH_PASS root/playing/top_level particles destroyed; sibling card and cardbirth retained; idempotent; no restart")
	player.queue_free();await process_frame;quit()
