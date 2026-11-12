extends SceneTree
const Placement=preload("res://scripts/native_phone_placement.gd")
const Layout=preload("res://scripts/source_phone_board_layout.gd")
class Visuals:
 func release_button():return false
class Flow:
 var visuals=Visuals.new()
 func accepts_actions():return true
class Rules:
 func needs_target(_key):return false
class Probe extends Node3D:
 var camera:Camera3D
class Bridge extends Node:
 var probe
 var viewport:SubViewport
class Shake:
 func present_source_camera(_projection):pass
class Rows:
 var source_items:Dictionary
 var snapshot:Dictionary
 var context
 func contains(key,point):return Layout.contains(snapshot,key,point)
 func refresh():pass
 func reproject():pass
 func update_units():pass
func _initialize():call_deferred("run")
func run():
 for size in [Vector2(1600,900),Vector2(2000,900),Vector2(1350,900)]:
  var game=load("res://tests/phone_battlecry_fixture.gd").new();root.add_child(game)
  game.presentation_size=size;game.board_render_target_size=Vector2i(size)
  game.flow=Flow.new();game.rules=Rules.new();game.player_turn=true;game.mana=10;game.camera_shake=Shake.new()
  game.definitions={"CS2_189":{"kind":"minion","cost":1,"battlecry":"damage1","atk":1,"hp":1,"name":"Archer","color":Color.WHITE}}
  game.cards=[{"key":"CS2_189","pos":Vector2.ZERO,"scale":.7,"angle":0,"spring":Vector2.ZERO}]
  var bridge=Bridge.new();game.add_child(bridge);game.original_board_bridge=bridge
  bridge.viewport=SubViewport.new();bridge.viewport.size=Vector2i(size);bridge.add_child(bridge.viewport)
  bridge.probe=Probe.new();bridge.viewport.add_child(bridge.probe)
  var rig=Node3D.new();bridge.probe.add_child(rig);bridge.probe.camera=Camera3D.new();rig.add_child(bridge.probe.camera)
  var camera=bridge.probe.camera
  load("res://scripts/source_board_camera_policy.gd").apply(camera,rig,{},size,true)
  var context=load("res://scripts/source_board_projection.gd").install(game,camera,size,size,Vector2.ZERO,{})
  game.source_projection=context
  var rows=Rows.new();rows.context=context;rows.source_items=Layout.recovered_items(0,0,{"aspect":size.x/size.y})
  rows.snapshot=Layout.build(rows.source_items,camera,size,size,Vector2.ZERO)
  game.source_phone_layout=rows
  game.native_phone_hand=load("res://scripts/native_phone_hand.gd").new();game.native_phone_hand.setup(game)
  game.native_phone_hand.mini_hand_play_enabled=true
  game._update_hand(.01)
  var hand_pose=game.cards[0].source_phone_pose.duplicate(true)
  var f=rows.source_items.friendly_play.source_row
  var o=rows.source_items.opposing_play.source_row
  # Closer to the hand than the narrow row, but inside the friendly battlefield.
  var drop=context.source_to_screen(Vector3(float(f.collider_bounds.center[0]),.054217,-7.15))
  assert(not rows.contains("friendly_play",drop))
  assert(game._source_play_contains(drop))
  assert(not game._source_play_contains(rows.snapshot.items.opposing_hero.center))
  assert(not game._source_play_contains(context.source_to_screen(Vector3(-8,.054217,3))))
  assert(not game._source_play_contains(context.source_to_screen(Vector3(6,.054217,-7.15))))
  assert(not game._source_play_contains(Vector2(-10000,-10000)))
  game.drag_index=0;game.tracked_drag=0;game.pointer=drop
  game._update_interaction();assert(game.preview_index==0)
  # An archer is placed provisionally before selecting a target; no mana or
  # hand/board mutation is committed yet, and phone target origin is resolvable.
  game._pointer_release()
  assert(game.interaction_state==game.Interaction.BATTLECRY_AIM)
  assert(game.cards.size()==1 and game.allies.is_empty() and game.mana==10)
  var placed=game.pending_battlecry.source_world_position
  assert(not context.resolve_anchor(game.pending_battlecry).is_empty())
  assert(placed.is_equal_approx(Layout.normal_slots(f,1)[0]))
  game._update_hand(.25);assert(game.cards[0].source_world_position.is_equal_approx(placed))
  game._resolve_target(Vector2(-10000,-10000));assert(not game.pending_battlecry.is_empty())
  # Touching the hand cancels with a real in-between pose, then seats the card.
  game._resolve_target(game.native_phone_hand.project(hand_pose.position))
  assert(game.pending_battlecry.is_empty() and game.cards[0].returning)
  assert(game.mana==10 and game.allies.is_empty())
  game._update_hand(.1)
  assert(not game.cards[0].source_world_position.is_equal_approx(placed))
  assert(not game.cards[0].source_world_position.is_equal_approx(hand_pose.position))
  game._update_hand(.5);assert(not game.cards[0].returning)
  assert(game.cards[0].source_world_position.is_equal_approx(hand_pose.position))
  # Replay and commit consumes exactly once, preserving the chosen slot.
  assert(game.play_card(0,drop,0))
  game._resolve_target(rows.snapshot.items.opposing_hero.center)
  assert(game.pending_battlecry.is_empty() and game.cards.is_empty())
  assert(game.mana==9 and game.allies.size()==1 and game.summons==1)
  assert(game.resolved_target.type=="hero" and game.resolved_target.side==1)
  game.free()
 print("PHONE_BATTLECRY_PLACEMENT_PASS friendly-field drops, stable placed target origin, cancel-return animation, and one-time commit across 3 aspects")
 quit()
