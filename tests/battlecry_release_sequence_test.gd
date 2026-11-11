extends SceneTree
const Layout=preload("res://scripts/source_phone_board_layout.gd")
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false);game.headless=true;game.allies.clear();game.enemies.clear();game.cards.clear()
 game.player_turn=true;game.mana=10;game.busy=false;game.game_over=false;game.flow.phase="playing"
 var camera=Camera3D.new();var rig=Node3D.new();game.add_child(rig);rig.add_child(camera)
 var size=Vector2(1600,900)
 load("res://scripts/source_board_camera_policy.gd").apply(camera,rig,size)
 game.source_projection=load("res://scripts/source_board_projection.gd").install(game,camera,size,size,Vector2.ZERO,{})
 game.native_phone_hand=load("res://scripts/native_phone_hand.gd").new();game.native_phone_hand.setup(game)
 var row=Layout.recovered_items(0,0,{"aspect":size.x/size.y}).friendly_play.source_row
 var destination=Layout.normal_slots(row,1)[0]
 var scale=Layout.vector(row.phone_card_target_scale)
 var origin=Vector3(-7.83,-.04,-8)
 var source={"key":"CS2_189","pos":game.source_projection.source_to_screen(origin),"source_world_position":origin,"source_world_scale":Vector3.ONE,"source_world_rotation":Quaternion.IDENTITY,"source_world_euler":Vector3.ZERO}
 game.cards=[source.duplicate(true)]
 var pose={"position":destination,"scale":Vector3.ONE,"rotation":Vector3.ZERO}
 game.pending_battlecry={"index":0,"pos":game.source_projection.source_to_screen(destination),"insertion":0,"source":source,"source_phone_pose":pose,"source_world_position":destination,"source_world_scale":scale}
 # Exercise actual visual actor construction even under the headless renderer.
 game.source_phone_layout.source_items=Layout.recovered_items(0,0,{"aspect":size.x/size.y})
 game.source_phone_layout.snapshot=Layout.build(game.source_phone_layout.source_items,camera,size,size,Vector2.ZERO)
 game.native_card_renderer=load("res://scripts/native_card_renderer.gd").new();game.add_child(game.native_card_renderer)
 game.native_card_renderer.build_card("CS2_189",game.definitions.CS2_189,game.raw_portraits[game.definitions.CS2_189.art])
 game.spatial_scene=load("res://scripts/classic_spatial.gd").new();game.add_child(game.spatial_scene);game.spatial_scene.setup(game,Vector2i(size))
 game.headless=false
 game._start_battlecry_release()
 var serial=game.native_summon.serial
 assert(game.pending_battlecry.releasing and game.busy)
 assert(game.allies.is_empty() and game.cards.size()==1 and game.mana==10)
 assert(game._presentation_boards()[0].size()==1)
 var entry=game.native_summon.instances.back()
 assert(entry.stage=="out" and entry.unit.hidden)
 assert(entry.unit.provisional)
 game.interaction_state=game.Interaction.BATTLECRY_AIM
 assert(not game._target_is_legal({"type":"unit","unit":entry.unit,"pos":entry.unit.pos}))
 assert(game.spatial_scene.pieces.has(entry.unit.id))
 assert(not entry.hand.is_empty() and not entry["in"].is_empty())
 game._resolve_target(Vector2.ZERO)
 assert(game.pending_battlecry.releasing and game.mana==10)
 game.native_summon.advance(.05)
 assert(game.pending_battlecry.releasing)
 assert(not entry.unit.source_world_position.is_equal_approx(destination))
 game.native_summon.advance(float(entry.config.out_duration)+float(entry.config.in_duration))
 assert(not game.pending_battlecry.releasing and not game.busy)
 assert(entry.settled and not entry.unit.hidden and entry.visual_missing.is_empty())
 var pending=game.pending_battlecry.duplicate();game.pending_battlecry.clear()
 var hp=game.health[1]
 var target={"type":"hero","side":1,"pos":game.ENEMY_HERO,"source_world_position":Vector3(-8,0,5)}
 game._commit_battlecry_release(pending,target)
 assert(game.native_summon.serial==serial) # target confirmation MUST NOT summon twice.
 assert(game.allies.size()==1 and game.cards.is_empty() and game.mana==9)
 assert(not game.allies[0].get("provisional",false))
 assert(game.health[1]==hp and game.busy)
 var fx=game.native_combat.effect_player
 var shot=fx.archer_shots.back()
 fx.advance(float(shot.route.impact_time))
 assert(game.health[1]==hp-1 and not game.busy)
 game.native_summon.cancel_unit(int(pending.unit.id))
 assert(game.native_summon.instances.is_empty())
 game.cards=[source.duplicate(true)];game._publish_source_hand_pose(game.cards[0],pose)
 game.pending_battlecry={"index":0,"pos":game.source_projection.source_to_screen(destination),"insertion":1,"source":source,"source_phone_pose":pose,"source_world_position":destination,"source_world_scale":scale}
 game._start_battlecry_release();assert(game.busy)
 var mana_before=game.mana
 game.cancel_interaction()
 assert(game.pending_battlecry.is_empty() and not game.busy)
 assert(game.cards.size()==1 and game.cards[0].returning and game.mana==mana_before)
 assert(game.native_summon.instances.is_empty())
 game.native_summon.advance(10)
 assert(not game.busy and game.allies.size()==1)
 print("BATTLECRY_RELEASE_SEQUENCE_PASS original Out/In before targeting, no early damage/payment, no replay on target commit")
 game.queue_free();quit()