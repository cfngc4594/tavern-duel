extends SceneTree
const Layout=preload("res://scripts/source_phone_board_layout.gd")
func _initialize():call_deferred("run")
func verify(controller,game):
 var options={"aspect":game.presentation_size.x/game.presentation_size.y,"permanent_mana_count":game.max_mana,"temporary_mana_count":int(game.flow.temporary_mana[0]),"end_turn_enabled":game.player_turn,"mana_tray_position":controller.mana_tray.position}
 if game.interaction_state==game.Interaction.PLACEMENT_PREVIEW:options.moused_over_slot=game.preview_index+1
 elif not game.pending_battlecry.is_empty():options.moused_over_slot=int(game.pending_battlecry.insertion)+1
 var expected=Layout.recovered_items(game.allies.size(),game.enemies.size(),options)
 assert(controller.source_items==expected,"Cached source layout must equal fresh rule/layout inputs")
 var fresh=Layout.build(controller.source_items,controller.camera,Vector2(controller.viewport.size),game.presentation_size,game.presentation_offset)
 assert(controller.snapshot.items==fresh.items,"Cached projection must equal fresh projection")
func run():
 preload("res://scripts/source_board_camera_policy.gd").qa_phone_platform=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false)
 var c=game.source_phone_layout;c.refresh();game.source_projection=c.context
 verify(c,game)
 var builds=c.layout_builds;var projects=c.projection_builds
 for i in 20:c.refresh();c.reproject()
 assert(c.layout_builds==builds and c.projection_builds==projects)
 game.allies.append(game._new_unit("CS2_189",0,Vector2.ZERO));c.refresh();verify(c,game)
 assert(c.layout_builds==builds+1 and c.snapshot.items.friendly_play.actors.size()==1)
 game.max_mana=7;game.flow.temporary_mana[0]=1;c.refresh();verify(c,game)
 game.pending_battlecry={"insertion":0};c.refresh();verify(c,game)
 game.pending_battlecry.clear();game.player_turn=not game.player_turn;c.refresh();verify(c,game)
 game.native_phone_hand.enlarged=true
 for i in 5:
  await process_frame
  game.source_visual_delta=.1;c.refresh();verify(c,game)
 game.presentation_size=Vector2(2000,900);game.board_render_target_size=Vector2i(2000,900);game.presentation_offset=Vector2(20,0)
 c.refresh();verify(c,game)
 var center=c.snapshot.items.friendly_hero.center
 c.camera.position.x+=.2;c.reproject();verify(c,game)
 assert(not c.snapshot.items.friendly_hero.center.is_equal_approx(center))
 c.refresh();verify(c,game)
 assert(c.snapshot.items.friendly_hero.center.is_equal_approx(center))
 c.camera.h_offset+=.25;c.camera.v_offset-=.1;c.reproject();verify(c,game)
 assert(not c.snapshot.items.friendly_hero.center.is_equal_approx(center))
 print("PHONE_LAYOUT_CACHE_PASS idle reuse, unit/mana/turn/target changes, animated tray, resize, offset and shake match fresh geometry")
 game.queue_free();quit()