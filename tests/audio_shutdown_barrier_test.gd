extends SceneTree
const Session = preload("res://source_rope/src/source_rope_session_candidate.gd")
const HOST_PATH = "res://source_rope/src/game_rope_host.gd"
const Burn = preload("res://scripts/native_hand_burn.gd")
class Fixture extends Node:
 var sound_enabled = true
 var native_card_renderer: Node
 var flow = {"burn_generation":0}
 var burn: Node
 var rope: Node
 var calls = 0
 func shutdown_presentation_audio():
  calls += 1
  await burn.shutdown()
  await rope.shutdown()
func _initialize(): call_deferred("run")
func run():
 var manager = root.get_node("SoundManager")
 var fixture = Fixture.new()
 root.add_child(fixture)
 fixture.add_to_group("audio_shutdown_participants")
 fixture.burn = Burn.new()
 fixture.add_child(fixture.burn)
 fixture.burn.setup(fixture)
 print("SHUTDOWN_TEST burn ready")
 fixture.rope = load(HOST_PATH).new()
 fixture.add_child(fixture.rope)
 fixture.rope.setup(fixture)
 var session = Session.new()
 fixture.add_child(session)
 fixture.rope.session = session
 session.setup(null, true)
 print("SHUTDOWN_TEST rope ready")
 session.audio_sink.output_bus = &"SFX"
 # Original recovered rope clip output, real session and lifecycle owner.
 session.audio_sink._play_generated("opens",1.0,1.0,1)
 assert(session.audio_sink.players.size() == 1)
 fixture.rope.reset()
 assert(not fixture.rope.releasing and not session.released)
 session.audio_sink._play_generated("opens",1.0,1.0,1)
 fixture.burn.audio.play_burn(0)
 fixture.burn.clear()
 assert(not fixture.burn.audio.get_audit().released)
 var burn_record: Dictionary = fixture.burn.audio.play_burn(1,Vector3(-5.1844520569,8.22980621457,-4.7834343910))
 assert(burn_record.sources[0].status == "playing" and burn_record.sources[1].status == "playing")
 var path = "res://assets/original_hand_burn/audio/global_credits_card_embers_1_f57e5b10.wav"
 var definition = {"path":path,"gain_db":-5.0,"pitch_min":1.0,"pitch_max":1.0,"cooldown_ms":0,"original":"credits_card_embers_1","mapping":"lifecycle_test"}
 # Saturate the pool and exercise retirement during same-frame voice stealing.
 for i in 48: assert(manager._play_definition("shutdown_test_" + str(i),definition,{}) != null)
 var stream = AudioStreamWAV.load_from_file(path)
 manager.music_player.stream = stream
 manager.music_player.play()
 manager.music_player.stream_paused = true
 var extra2d = AudioStreamPlayer2D.new()
 var extra3d = AudioStreamPlayer3D.new()
 fixture.add_child(extra2d);fixture.add_child(extra3d)
 extra2d.stream = stream;extra3d.stream = stream
 extra2d.play();extra3d.play()
 # Collect only WeakRefs: test assertions must not keep retired playback alive.
 var refs: Array = []
 for player in manager.players:
  assert(player.playing)
  refs.append(weakref(player.get_stream_playback()))
 refs.append(weakref(manager.music_player.get_stream_playback()))
 for player in session.audio_sink.players.values(): refs.append(weakref(player.get_stream_playback()))
 for player in fixture.burn.audio._voices: refs.append(weakref(player.get_stream_playback()))
 stream = null
 print("SHUTDOWN_TEST voices ready")
 manager.shutdown_audio() # Begin without awaiting, simulating concurrent close.
 assert(manager.shutdown_pending)
 assert(manager._play_definition("late",definition,{}) == null)
 assert(not manager.start_music())
 assert(manager.play_original_event("@phone_audio","opposing_draw",{}).reason == "shutdown")
 print("SHUTDOWN_TEST started ", manager.pending_disposals())
 if "--request-exit" in OS.get_cmdline_user_args():
  manager.request_shutdown()
  manager.request_shutdown()
 await manager.shutdown_audio() # Same completion barrier, not another release.
 await manager.shutdown_audio() # Already completed is an immediate no-op.
 assert(manager.shutdown_complete and manager.pending_disposals() == 0)
 assert(fixture.calls == 1)
 assert(fixture.rope.release_complete and fixture.rope.session == null)
 for ref in refs: assert(ref.get_ref() == null)
 for player in manager.players: assert(not player.playing and player.stream == null)
 assert(manager.music_player.stream == null)
 assert(not is_instance_valid(extra2d) and not is_instance_valid(extra3d))
 print("AUDIO_SHUTDOWN_BARRIER_PASS ",JSON.stringify(manager.shutdown_audit))
 fixture.queue_free()
 if "--request-exit" in OS.get_cmdline_user_args(): return
 await process_frame
 quit()
