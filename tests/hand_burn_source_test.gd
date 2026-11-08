extends SceneTree
const Timeline=preload("res://scripts/native_hand_burn_timeline.gd")
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame;game.set_process(false);game.sound_enabled=false
 game.flow.reset();game.cards.clear();game.deck=["CS2_182","GAME_005","CS2_182"]
 for i in 10:game._add_card("CS2_182",false)
 var before_particles=game.particles.size()
 game.rng.seed=102938
 var expected=RandomNumberGenerator.new();expected.seed=102938
 for i in 24:
  expected.randf();expected.randf_range(35,260);expected.randf_range(.3,.85);expected.randf_range(2,6)
 game._draw_cards(1,0)
 assert(game.rng.state==expected.state,"Removed burst changed rule RNG state")
 assert(game.particles.size()==before_particles and game.cards.size()==10 and game.deck.size()==2)
 assert(game.flow.burn_cards.size()==1)
 var entry=game.flow.burn_cards[0]
 Timeline.advance(game,1.49);assert(entry.phase=="flight")
 Timeline.advance(game,.01);assert(entry.phase=="burning")
 assert(entry.deck_count==3)
 # The mill releases the side draw slot at Birth, not at ash completion.
 game._draw_cards(1,0);Timeline.advance(game,.1)
 assert(game.flow.burn_cards.size()==2 and game.flow.burn_cards[1].phase=="flight")
 var renderer=load("res://scripts/native_card_renderer.gd").new();game.add_child(renderer);game.native_card_renderer=renderer
 for key in ["CS2_182","GAME_005"]:
  var definition=game.definitions[key].duplicate()
  if key=="GAME_005":definition.frame="frame-spell-neutral"
  renderer.build_card(key,definition,load("res://assets/original_classic_v13/art/"+key+".png"))
 var burn=load("res://scripts/native_hand_burn.gd").new();game.add_child(burn);burn.setup(game);burn.sync()
 assert(burn.pieces.size()==2)
 var piece=burn.pieces[entry.ticket]
 assert(piece.actor.root.visible)
 assert(piece.effect.particles.size()==4 and piece.particles.size()==4)
 assert(piece.effect_holder.basis.is_equal_approx(Basis.IDENTITY))
 assert(piece.effect_holder.position.is_equal_approx(piece.finish))
 assert(piece.effect.renderers.size()==1)
 Timeline.advance(game,.06);burn.sync();assert(not piece.actor.root.visible)
 assert(burn.assets.material_audit.is_empty() and burn.assets.missing.is_empty())
 # Sampling must reach real original burn mesh, clip and all emitters.
 assert(piece.particles[0].emitted_count>0)
 print("BURN_SOURCE_AUDIT ",JSON.stringify(burn.get_audit()))
 Timeline.advance(game,6);burn.sync();assert(game.flow.burn_cards.is_empty() and burn.pieces.is_empty())
 # Unknown generated overflow receives no fabricated deck trajectory.
 game._add_card("CS2_182");Timeline.advance(game,.01);burn.sync()
 assert(game.flow.burn_cards.back().phase=="blocked" and burn.pieces.is_empty())
 game.flow.reset();burn.sync();assert(burn.pieces.is_empty())
 # Nine-card hand: source ordinary draw is ahead of the burned tenth+one card.
 game.cards.resize(9);game.deck=["CS2_182","CS2_182"]
 game._draw_cards(2,0);Timeline.advance(game,.5)
 assert(game.flow.burn_cards[0].phase=="queued")
 game.cards.back().source_draw_phase="seat"
 Timeline.advance(game,.1);assert(game.flow.burn_cards[0].phase=="flight")
 # A later ordinary draw cannot pass an earlier burn flight.
 var ticket=game.flow.next_draw_ticket()
 assert(Timeline.blocks_draw(game,0,ticket))
 assert(not Timeline.blocks_draw(game,1,ticket))
 # Repeat both sides, reset, and verify cleanup with no rule mutation.
 game.flow.reset();game.enemy_hand.resize(10);game.enemy_deck=["CS2_182"]
 game._draw_cards(1,1);Timeline.advance(game,1.5);burn.sync()
 assert(game.enemy_hand.size()==10 and game.enemy_deck.is_empty())
 assert(burn.pieces.size()==1)
 piece=burn.pieces.values()[0]
 assert(piece.finish.is_equal_approx(Vector3(-5.179999828338623,6.5,-3.5999999046325684)))
 game.flow.reset();burn.sync();assert(burn.pieces.is_empty())
 await burn.shutdown();await process_frame
 game.queue_free();await process_frame
 print("HAND_BURN_SOURCE_PASS source hierarchy/materials/particles, timing, both sides, draw queue, reset, rule RNG preservation")
 quit()
