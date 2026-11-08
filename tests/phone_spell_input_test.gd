extends SceneTree
const Hits=preload("res://scripts/native_phone_input_hitboxes.gd")
const Spell=preload("res://scripts/native_phone_spell_input.gd")
class Flow:
 func accepts_actions():return true
 func opponent_draw(_key,_burned):pass
class Rules:
 var needs=true
 func needs_target(_key):return needs
 func legal_target(_key,target,_side):return target.type=="hero"
func _initialize():call_deferred("run")
func run():
 var rows=Hits.source_rows()
 var battlefield=rows["BattlefieldHitbox:-2208989807214996501"]
 assert(is_equal_approx(battlefield.phone_world_scale[2],13))
 var hero=Vector3(-7.783791,.054217,-8.8)
 var ray={"origin":hero+Vector3.UP*10,"direction":Vector3.DOWN}
 assert(Hits.hit_ray(ray,12,{},"HeroHitboxForPhone").is_empty())
 assert(not Hits.hit_ray(ray,12,{"HeroHitboxForPhone":true},"HeroHitboxForPhone").is_empty())
 assert(not Spell.next_aim(false,false,true,true)) # Slush preserves, never starts.
 assert(Spell.next_aim(true,false,true,false))
 assert(not Spell.next_aim(true,false,false,true))
 assert(not Spell.next_aim(false,true,false,false))
 for size in [Vector2(1600,900),Vector2(2000,900),Vector2(1350,900)]:
  var view=SubViewport.new();view.size=Vector2i(size);root.add_child(view)
  var rig=Node3D.new();view.add_child(rig);var camera=Camera3D.new();rig.add_child(camera)
  var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
  load("res://scripts/source_board_camera_policy.gd").apply(camera,rig,config,size,true)
  var game=load("res://tests/phone_spell_fixture.gd").new();root.add_child(game)
  game.source_projection=load("res://scripts/source_board_projection.gd").install(game,camera,size,size,Vector2.ZERO,{})
  game.native_phone_hand=load("res://scripts/native_phone_hand.gd").new();game.native_phone_hand.setup(game)
  game.flow=Flow.new();game.player_turn=true;game.rules=Rules.new();game.cards=[{"key":"X","pos":Vector2.ZERO,"scale":1}];game.definitions={"X":{"kind":"spell","cost":1,"name":"X","color":Color.WHITE}};game.drag_index=0;game.tracked_drag=0;game.mana=1
  var context=game.source_projection
  var field=context.source_to_screen(Vector3(-8,.054217,0))
  var slush=context.source_to_screen(Vector3(-15,.054217,-10))
  var outside=context.source_to_screen(Vector3(-30,.054217,-15))
  assert(Spell.over_playfield(context,field));assert(not Spell.over_playfield(context,slush));assert(Spell.keep_targeting(context,slush))
  game.pointer=field;game._update_interaction();assert(game.spell_aim_latched and game.native_phone_hand.targeting_mode)
  game.pointer=slush;game._update_interaction();assert(game.spell_aim_latched)
  game.pointer=outside;game._update_interaction();assert(not game.spell_aim_latched and not game.native_phone_hand.targeting_mode)
  game.mana=0;game.pointer=field;game._update_interaction();assert(not game.spell_aim_latched)
  game.rules.needs=false;game.mana=1
  assert(not game.play_card(0,outside));assert(game.cast_count==0)
  assert(game.play_card(0,field));assert(game.cast_count==1 and game.cards.is_empty())
  assert(game.spatial_scene==null and game.native_card_renderer==null)
  game.enemy_hand=[];game.enemy_deck=["X","X"];game._draw_cards(2,1)
  var logic=game._source_opposing_hand()
  assert(logic.logical_only_mode and logic.pieces.is_empty() and logic.raw.is_empty())
  assert(logic.draw_queue.size()==2 and not logic.source_pose(0,2).is_empty())
  game._ai_action();assert(game.enemy_hand.size()==2) # Source queue blocks AI without a renderer.
  logic.advance_draws();game.elapsed+=1.75;logic.advance_draws();assert(logic.draw_queue.size()==1)
  game.elapsed+=1.75;logic.advance_draws();assert(not logic.draws_pending())
  game.free();view.free()
 print("PHONE_SPELL_AND_HEADLESS_QUEUE_PASS three aspect source ray registration; layer12 start/release, layer16 preserve-only, hero dynamic OBB, no-mana no aim, outside cancel")
 quit()
