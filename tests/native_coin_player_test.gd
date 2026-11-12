extends SceneTree
func _init():call_deferred("run")
func run():
	var player_script=load("res://scripts/native_coin_player.gd")
	var children_before:=root.get_child_count()
	var prepared:Dictionary=player_script.prepare_assets()
	assert(root.get_child_count()==children_before)
	var player=player_script.new();root.add_child(player);player.setup(prepared)
	assert(player.nodes.size()==20);assert(player.clips.size()==7);assert(player.meshes.size()==9)
	var checked=0
	for clip_name in player.clips:
		var clip:Dictionary=player.clips[clip_name]
		for group in ["m_PositionCurves","m_ScaleCurves","m_RotationCurves","m_FloatCurves"]:
			for track in clip[group]:
				var keys:Array=track.curve.m_Curve
				for key in keys:
					assert(int(key.weightedMode)==0)
					var components=[""] if group=="m_FloatCurves" else ["x","y","z","w"] if group=="m_RotationCurves" else ["x","y","z"]
					for component in components:
						assert(is_equal_approx(player.scalar(keys,key.time,component),player._value(key.value,component)));checked+=1
		player.sample_clip(clip_name,0.0);player.sample_clip(clip_name,0.5);player.sample_clip(clip_name,10.0)
	for instance in player.meshes.values():assert(not instance.visible)
	player.place_at_source_bone()
	assert(player.nodes["-6567163448337853234"].position.is_equal_approx(Vector3(-3.4434101581573486,0.18274974822998047,-4.99461030960083)))
	player.sample_clip("Coin2Card",0.5)
	var cap:ShaderMaterial=player.meshes["9005174219006055630"].material_override
	assert(float(cap.get_shader_parameter("_Dissolve"))>0.0 and float(cap.get_shader_parameter("_Dissolve"))<1.0)
	player.enable_source_ports(true)
	assert(player.meshes["-7538021581227256626"].visible)
	player.bind_source_scene_clock(2.0)
	assert(is_equal_approx(float(player.meshes["-7538021581227256626"].material_override.get_shader_parameter("_UnityTimeX")),0.1))
	player.play_drop(false,false);player.advance(0.5);player.send_birth(false);player.advance(0.1)
	assert(player.source_spawn_bone().has("m_LocalPosition"))
	var next_player=player_script.new();root.add_child(next_player);next_player.setup(prepared)
	assert(next_player.playing.is_empty() and next_player.birth_emitters.is_empty() and next_player.audio_history.is_empty())
	assert(not next_player.drop_source.runtime_enabled and next_player.drop_source.requests.is_empty())
	for key in player.meshes:
		assert(player.meshes[key]!=next_player.meshes[key])
		assert(player.meshes[key].mesh==next_player.meshes[key].mesh)
		assert(player.meshes[key].material_override!=next_player.meshes[key].material_override)
	next_player.queue_free()
	print("NATIVE_COIN_PASS nodes=",player.nodes.size()," clips=",player.clips.size()," meshes=",player.meshes.size()," source_key_components=",checked," default_hidden=true source_port_enable=explicit material_curves=applied")
	player.queue_free();await process_frame;quit()
