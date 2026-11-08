extends SceneTree
const Timeline=preload("res://scripts/native_hand_burn_timeline.gd")
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame;game.set_process(false);game.sound_enabled=true
 var manager=root.get_node("SoundManager");var router=manager.original_audio
 router.set_process(false);manager.stop_all_sfx();manager.play_history.clear()
 game.flow.reset();game.cards.clear();game.enemy_hand.resize(10)
 for i in 10:game._add_card("CS2_182",false)
 game.deck=["CS2_182","CS2_182","CS2_182"];game.enemy_deck=["CS2_182"]
 var voice=load("res://scripts/native_hand_full_voice.gd").new();voice.setup(game)
 game.flow.active_turn=1
 game._draw_cards(2,0);Timeline.advance(game,.1)
 var first=game.flow.burn_cards[0]
 assert(first.remind_full_hand)
 var before=game.rng.state
 var row=voice.play(first)
 assert(row.status=="dispatched" and row.hero=="HERO_08")
 assert(row.request.first_delay_sec==0.0 and row.request.layers_scheduled==1)
 assert(manager.play_history.back().original=="VO_HERO_08_ERROR06_80")
 assert(game.rng.state==before)
 Timeline.advance(game,1.5)
 assert(not game.flow.burn_cards[1].remind_full_hand)
 # Gate belongs to the global turn, including a draw on the other side.
 game._draw_cards(1,1);Timeline.advance(game,.1)
 assert(not game.flow.burn_cards.back().remind_full_hand)
 # The next half-turn can speak, even when the round-number display is equal.
 game.flow.active_turn=2;game.enemy_deck=["CS2_182"]
 game._draw_cards(1,1);Timeline.advance(game,1.5)
 var next=game.flow.burn_cards.back()
 assert(next.remind_full_hand)
 row=voice.play(next)
 assert(row.status=="dispatched" and row.hero=="HERO_07")
 assert(manager.play_history.back().original=="VO_HERO_07_ERROR06_25")
 var defs=voice.extension.sound_defs
 for definition in defs.values():
  assert(definition.volume==1.0 and definition.pitch==1.0 and definition.category==3)
  assert(definition.source_spatial_blend==0 and definition.main_clip.locale=="zhCN")
  assert(FileAccess.get_sha256(definition.main_clip.path)==definition.main_clip.sha256)
 voice.clear();assert(voice.scopes.is_empty())
 # Reset source default zero. Generated overflow cannot claim a mill source cue.
 game.flow.reset();assert(game.flow.last_full_hand_reminder_turn==0)
 game._add_card("CS2_182");Timeline.advance(game,.01)
 assert(game.flow.burn_cards.back().phase=="blocked")
 assert(not game.flow.burn_cards.back().get("remind_full_hand",false))
 print("HAND_FULL_VOICE_PASS source Emote21, zero delay, two zhCN SHA clips, global per-turn gate, no rules RNG consumption, reset and generated-overflow refusal")
 manager.stop_all_sfx();router.set_process(true)
 game.queue_free();await process_frame
 quit()
