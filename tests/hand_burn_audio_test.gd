extends SceneTree
class FakeGame extends Node:
 var sound_enabled = true
func _initialize(): call_deferred("run")
func run():
 var game = FakeGame.new()
 root.add_child(game)
 var sink = load("res://scripts/native_hand_burn_audio.gd").new()
 root.add_child(sink)
 sink.setup(game)
 assert(sink.get_audit().errors.is_empty(), str(sink.get_audit().errors))
 assert(sink.get_audit().loaded_sources.size() == 4)
 for endpoint in [Vector3(-5.1844520569, 8.0 + 0.22980621457, -4.7834343910), Vector3(-5.1799998283, 6.5 + 0.22980621457, -3.5999999046)]:
  var spatial: Dictionary = sink.source_spatial_diagnostic(endpoint)
  assert(spatial.inside_min_distance and spatial.distance_attenuation_gain == 1.0)
  var positioned: Dictionary = sink.play_burn(-1, endpoint)
  assert(positioned.source_spatial.distance_attenuation_gain == 1.0)
  assert(positioned.sources[0].source_spatial_blend == 0.0)
  assert(positioned.sources[1].source_spatial_blend == 1.0)
  sink.stop_all()
 var boundary: Dictionary = sink.source_spatial_diagnostic(sink.SOURCE_LISTENER + Vector3(300,0,0))
 assert(is_equal_approx(boundary.distance_attenuation_gain, 0.5))
 assert(sink.source_spatial_diagnostic(sink.SOURCE_LISTENER + Vector3(500,0,0)).distance_attenuation_gain == 0.0)
 sink.cosmetic_rng.seed = 8821
 seed(9823)
 var expected_global = randi()
 seed(9823)
 var variants: Dictionary = {}
 var stream_refs: Array = []
 for stream in sink._streams.values(): stream_refs.append(weakref(stream))
 for batch in range(8):
  for index in range(64):
   var record: Dictionary = sink.play_burn(batch * 64 + index)
   assert(record.sources.size() == 2)
   assert(record.sources[0].gain == 1.0)
   assert(record.sources[1].gain == 0.800000011920929)
   assert(record.sources[1].source == "Fatigue_LastCard_02")
   variants[record.sources[0].source] = true
   for source in record.sources:
    assert(source.status == "playing", str(source))
    assert(source.pitch == 1.0)
   sink.stop_all()
   assert(sink.get_audit().active_voices == 0)
   sink.advance(0.0)
  await sink.drain_disposals()
  assert(sink.pending_disposals() == 0)
 assert(randi() == expected_global, "Cosmetic choice consumed global RNG")
 assert(variants.size() == 3)
 game.sound_enabled = false
 var muted: Dictionary = sink.play_burn(1000)
 for source in muted.sources: assert(source.status == "muted")
 game.sound_enabled = true
 sink.play_burn(1001)
 game.sound_enabled = false
 sink.advance(0.016)
 assert(sink.get_audit().active_voices == 0)
 game.sound_enabled = true
 # Natural completion, not elapsed-time pretend completion or a fixed sleep.
 sink.play_burn(1002)
 while sink.get_audit().active_voices > 0:
  await process_frame
  sink.advance(0.016)
 await sink.drain_disposals()
 assert(sink.pending_disposals() == 0)
 # Setup while active must retire the previous playback before replacing cache.
 sink.play_burn(1003)
 sink.setup(game)
 sink.play_burn(1004)
 await sink.shutdown()
 await process_frame
 assert(not is_instance_valid(sink))
 for ref in stream_refs: assert(ref.get_ref() == null, "WAV retained after shutdown")
 game.queue_free()
 print("HAND_BURN_AUDIO_PASS: 512 same-frame resets, source gains/pitch, three variants, global RNG isolation, mute, natural finish, setup replacement, awaited shutdown")
 quit()
