extends SceneTree
func _initialize():call_deferred("run")
func run():
 var sound=root.get_node("SoundManager");sound.set_sfx_enabled(true);sound.sfx_volume=0.5
 assert(sound.reload_original_audio_manifest())
 var router=sound.original_audio;var catalog=router.catalog
 for event in ["temporary_mana_birth","temporary_mana_destroy","opposing_draw","mana_add","mana_spend","mana_refresh"]:
  assert(sound.has_original_event("@phone_audio",event))
  var route=catalog.systems.phone_audio.events[event];assert(route.layers.size()==1)
  assert(route.layers[0].delay_sec==0.0)
  var definition=catalog.sound_defs[route.layers[0].sound_def]
  var clip=definition.main_clip;assert(router._clip_problem(clip)=="")
  var stream=AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(clip.path))
  assert(stream!=null and absf(stream.get_length()-float(clip.duration_sec))<0.001)
  var result=sound.play_phone_source_audio(event,{"scope_id":"audio-test:"+event,"source_side":1 if event=="opposing_draw" else 0})
  assert(result.accepted,str(result))
 var draw=catalog.systems.phone_audio.events.opposing_draw.layers[0]
 assert(is_equal_approx(draw.source_volume,0.3499999940395355))
 assert(catalog.sound_defs[draw.sound_def].random_clips.size()==3)
 for alt in catalog.sound_defs[draw.sound_def].random_clips:
  assert(alt.weight==1.0 and router._clip_problem(alt.clip)=="")
 assert(is_equal_approx(catalog.systems.mana.events.destroy.layers[0].delay_sec,0.5))
 await process_frame;await process_frame;await process_frame
 var played={}
 for row in sound.play_history:
  if str(row.get("event","")).begins_with("original:@phone_audio:"):played[str(row.event).get_slice(":",2)]=true
 assert(played.size()==6,str(sound.play_history))
 sound.stop_all_sfx();await create_timer(0.2).timeout
 print("PHONE_SOURCE_AUDIO_PASS eight SHA verified original WAVs, source random weights/gain, precise zero-delay events, normal destroy original .5 delay retained");quit()
