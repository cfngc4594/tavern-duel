extends SceneTree
const Rotation=preload("res://scripts/source_itween_rotation.gd")
const Summon=preload("res://scripts/native_summon_player.gd")
const Opposing=preload("res://scripts/native_phone_opposing_hand.gd")
const SourceProjection=preload("res://scripts/source_board_projection.gd")
class Host extends Node:
	var headless:=true
func _initialize():call_deferred("run")
func run():
	# Direct CIL clerp branch expectations, including the strict 180-degree tie.
	for row in [[350.0,10.0,370.0],[10.0,350.0,-10.0],[0.0,180.0,180.0],[180.0,0.0,0.0],[0.0,-180.0,-180.0],[180.0,360.0,360.0]]:
		assert(is_equal_approx(Rotation.clerp(row[0],row[1],1.0),row[2]))
	assert(is_equal_approx(Rotation.clerp(0.0,180.0,.5),90.0))
	assert(is_equal_approx(Rotation.clerp(0.0,-180.0,.5),-90.0))
	assert(is_equal_approx(Rotation.ease_out_expo_progress(.1,1.0),.5))
	assert(Rotation.ease_out_expo_progress(1.0,1.0)==1.0)
	var player=Summon.new();root.add_child(player)
	var opposing=Opposing.new();root.add_child(opposing)
	opposing.row=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_opposing_hand.json")).rows.Zone_Opposing_Hand
	var projection=SourceProjection.new()
	var target=Vector3(-7.8,.1,-6.0) # Synthetic destination, explicitly a test anchor.
	var end_scale=Vector3(1.058,1.058,1.058)
	for count in [1,4,7,10]:
		for index in count:
			var start=opposing.source_pose(index,count)
			var unit={"source_world_target":target,"source_world_target_scale":end_scale,"source_world_target_rotation":Quaternion.IDENTITY,"source_world_target_euler":Vector3.ZERO}
			var source={"source_world_position":start.position,"source_world_scale":start.scale,"source_world_rotation":Rotation.source_basis(start.rotation).get_rotation_quaternion(),"source_world_euler":start.rotation}
			var entry={"unit":unit,"source":source,"config":{"route":"hand"},"age":0.0}
			var pose=player._source_card_pose(entry,projection)
			assert(not pose.is_empty() and pose.position.is_equal_approx(start.position))
			assert(pose.basis.is_equal_approx(Rotation.source_basis(start.rotation)))
			entry.age=.1;pose=player._source_card_pose(entry,projection)
			# Original fan yaw heads to zero, 352.5 goes forward to 360, not to 0.
			assert(pose.euler.is_equal_approx(Vector3(0,start.rotation.y*.5,356.25)))
			assert(pose.position.is_equal_approx(start.position.lerp(target,.5)))
			assert(pose.scale.is_equal_approx(start.scale.lerp(end_scale,.5)))
			entry.age=1.0;pose=player._source_card_pose(entry,projection)
			assert(pose.position.is_equal_approx(target) and pose.basis.is_equal_approx(Basis.IDENTITY))
			entry.source_transition_delay=.2;entry.age=.2;pose=player._source_card_pose(entry,projection)
			assert(pose.position.is_equal_approx(start.position))
			entry.age=.3;pose=player._source_card_pose(entry,projection)
			assert(pose.euler.is_equal_approx(Vector3(0,start.rotation.y*.5,356.25)))
			source.erase("source_world_euler")
			assert(player._source_card_pose(entry,projection).is_empty())
			source.source_world_euler=Vector3(90,0,0)
			assert(player._source_card_pose(entry,projection).is_empty())
	# The outgoing hidden actor and incoming minion share the same Card tween.
	# Exercise the actual sample method, including an actor swap before 1 second.
	var host=Host.new();root.add_child(host);player.game=host
	var vp=SubViewport.new();vp.size=Vector2i(1600,900);host.add_child(vp)
	var camera=Camera3D.new();vp.add_child(camera)
	camera.position=Vector3(0,20,0);camera.rotation_degrees=Vector3(-90,0,0)
	camera.set_meta("native_phone_registered",true)
	projection=SourceProjection.install(host,camera,Vector2(vp.size),Vector2(vp.size),Vector2.ZERO,{})
	var hand=opposing.source_pose(0,7)
	var source={"source_world_position":hand.position,"source_world_scale":hand.scale,"source_world_rotation":Rotation.source_basis(hand.rotation).get_rotation_quaternion(),"source_world_euler":hand.rotation}
	var unit={"source_world_target":target,"source_world_target_scale":end_scale,"source_world_target_rotation":Quaternion.IDENTITY,"source_world_target_euler":Vector3.ZERO,"pos":Vector2.ZERO,"target":Vector2.ZERO}
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://references/summon_v31/runtime_routes.json")).routes
	var out_duration:float=routes.hand_out_hidden.finished_seconds_nominal
	assert(out_duration<1.0)
	var entry={"unit":unit,"source":source,"config":{"route":"hand","actor_clip":"","out_label":"","in_label":"","out_duration":out_duration},"age":.4,"stage":"out","settled":false,"container":null,"clip_players":{},"particle_players":{},"visual_missing":[]}
	player._sample(entry)
	assert(unit.source_world_position.is_equal_approx(hand.position.lerp(target,Rotation.ease_out_expo_progress(.4,1.0))))
	entry.age=out_duration;entry.stage="in";player._sample(entry)
	assert(not unit.source_world_position.is_equal_approx(target))
	assert(unit.source_world_euler.is_equal_approx(Rotation.interpolate(hand.rotation,Vector3.ZERO,Rotation.ease_out_expo_progress(out_duration,1.0))))
	assert(unit.pos.distance_to(projection.source_to_screen(unit.source_world_position))<.001)
	entry.age=1.0;player._sample(entry)
	assert(unit.source_world_position.is_equal_approx(target))
	assert(unit.source_world_scale.is_equal_approx(end_scale))
	assert(Basis(unit.source_world_rotation).is_equal_approx(Basis.IDENTITY))
	# Completed cosmetic tails must not overwrite later combat movement.
	unit.source_world_position=target+Vector3(2,0,0)
	entry.age=1.5;entry.settled=true;entry.stage="tail";player._sample(entry)
	assert(unit.source_world_position.is_equal_approx(target+Vector3(2,0,0)))
	assert(entry.visual_missing.is_empty())
	host.queue_free()
	# Opposing card back's Y=180 is authored on its Mesh child. It remains
	# separate from the Card parent fan rotation throughout the transition.
	var raw=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_hidden_actor.json"))
	var found_mesh:=false
	for node in raw:
		if node.name!="Mesh":continue
		for component in node.components:
			if component.type!="Transform":continue
			var q=component.data.m_LocalRotation
			assert(Basis(Quaternion(q.x,q.y,q.z,q.w)).is_equal_approx(Rotation.source_basis(Vector3(0,180,0))))
			found_mesh=true
	assert(found_mesh)
	print("PHONE_SUMMON_SOURCE_ROTATION_PASS original Euler/clerp/ease chain, 22 source opposing hand poses, strict +/-180, shared TRS delay, out/in Card continuity, completed tail does not reset motion, missing/mismatched endpoints rejected")
	player.queue_free();opposing.queue_free();quit()
