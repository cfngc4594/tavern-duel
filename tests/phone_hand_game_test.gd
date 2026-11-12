extends SceneTree
class Probe extends Node3D:
 var camera:Camera3D
class Bridge extends Node:
 var probe
 var viewport:SubViewport
class Visuals:
 func release_button():return false
 func press_button():return false
class Flow:
 var visuals=Visuals.new()
 func accepts_actions():return true
 func pointer_press():return false
class PhoneLayout:
 var overlap_power:=true
 var power_checks:=0
 func contains(key,_point):
  if key=="friendly_power":power_checks+=1;return overlap_power
  return false
class Motion:
 var game
 var point=Vector3(-7,4,-3)
 func hit(_p):return {"source_world":point}
 func source_scale_at(start,age):return preload("res://scripts/native_held_motion.gd").source_scale_at(start,age)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,900);await process_frame
 var game=load("res://tests/phone_hand_game_fixture.gd").new();root.add_child(game)
 game.touch_input_active=true # This fixture exercises touch, not desktop mouse gestures.
 game.flow=Flow.new();game.player_turn=true;game.cards=[];game.definitions={"X":{"kind":"minion","cost":1}}
 var bridge=Bridge.new();game.add_child(bridge);game.original_board_bridge=bridge
 bridge.viewport=SubViewport.new();bridge.viewport.size=Vector2i(1600,900);bridge.add_child(bridge.viewport)
 bridge.probe=Probe.new();bridge.viewport.add_child(bridge.probe)
 var rig=Node3D.new();bridge.probe.add_child(rig);bridge.probe.camera=Camera3D.new();rig.add_child(bridge.probe.camera)
 var policy=load("res://scripts/source_board_camera_policy.gd")
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 policy.apply(bridge.probe.camera,rig,Vector2(1600,900))
 game.source_projection=load("res://scripts/source_board_projection.gd").install(game,bridge.probe.camera,Vector2(1600,900),Vector2(1600,900),Vector2.ZERO,{})
 game.native_phone_hand=load("res://scripts/native_phone_hand.gd").new();game.native_phone_hand.setup(game);game.native_phone_hand.mini_hand_play_enabled=true
 game.cards=[{"key":"X","pos":Vector2.ZERO,"scale":.75,"angle":0,"spring":Vector2.ZERO}]
 game._update_hand(.01)
 assert(game.cards[0].source_world_position.is_equal_approx(game.native_phone_hand.source_pose(0,1).position))
 var point=game.native_phone_hand.project(game.cards[0].source_world_position)
 game.pointer=point;game.screen_pointer=point;game.mouse_down=true;game.active_touch_index=0
 game.source_phone_layout=PhoneLayout.new();game.mana=10;game.busy=false
 game.hover_card=game.native_phone_hand.hit_card(point);assert(game.hover_card==0)
 game._pointer_press()
 assert(game.pressed_card==0 and game.native_phone_hand.touched_slot==0)
 assert(not game.targeting_power and game.source_phone_layout.power_checks==0)
 game._update_hand(.05);assert(game.native_phone_hand.focus==-1)
 game._update_hand(.06);assert(game.native_phone_hand.focus==0)
 game.native_phone_hand.mini_hand_play_enabled=false
 game.touch_input_active=true;game._pointer_release();assert(not game.native_phone_hand.enlarged)
 game.native_phone_hand.mini_hand_play_enabled=true
 game.native_phone_hand.begin_touch(0,game._touch_window_position(point));game.pressed_card=0
 game._pointer_release();assert(game.native_phone_hand.enlarged and game.native_phone_hand.focus==-1)
 game.source_phone_layout.overlap_power=false
 game.hover_card=-1;game.pointer=Vector2(800,300);game.screen_pointer=game.pointer
 game._pointer_press();assert(game.native_phone_hand.enlarged) # Do not interrupt enlargement.
 game.native_phone_hand.enlarging_remaining=0
 game.hover_card=0;game.pointer=point;game.screen_pointer=point
 game._pointer_press();assert(game.native_phone_hand.enlarged) # Hand touch keeps it open.
 game.native_phone_hand.release_touch();game.pressed_card=-1
 game.hover_card=-1;game.pointer=Vector2(800,300);game.screen_pointer=game.pointer
 game._pointer_press();assert(not game.native_phone_hand.enlarged)
 # Opponent turn permits browsing, but neither card dragging nor hero power.
 game.player_turn=false;game.native_phone_hand.enlarging_remaining=0
 game.pointer=point;game.screen_pointer=point;game._update_hover(false)
 assert(game.hover_card==0)
 game.source_phone_layout.overlap_power=true
 var power_checks=game.source_phone_layout.power_checks
 game._pointer_press();assert(game.native_phone_hand.touched_slot==0)
 game._begin_card_drag(0);assert(game.drag_index==-1)
 game._pointer_release();assert(game.native_phone_hand.enlarged)
 assert(not game.targeting_power and game.source_phone_layout.power_checks==power_checks)
 game.native_phone_hand.enlarging_remaining=0
 game.pointer=Vector2(800,300);game.screen_pointer=game.pointer;game._update_hover(false)
 assert(game.hover_card==-1)
 game._pointer_press();assert(not game.native_phone_hand.enlarged)
 assert(not game.targeting_power and game.source_phone_layout.power_checks==power_checks)
 # Busy state still rejects hand gestures; target/drag guards remain earlier.
 game.busy=true;game.pointer=point;game.screen_pointer=point;game._update_hover(false)
 game._pointer_press();assert(game.native_phone_hand.touched_slot==-1)
 game._begin_card_drag(0);assert(game.drag_index==-1)
 game.busy=false;game.player_turn=true;game.source_phone_layout.overlap_power=false
 game.native_phone_hand.set_enlarged(false);game.native_phone_hand.enlarging_remaining=0
 game._begin_card_drag(0);assert(game.drag_index==0)
 var motion=Motion.new();motion.game=game;game.source_held_motion=motion
 game._update_hand(.21)
 assert(game.cards[0].source_world_position.is_equal_approx(motion.point))
 assert(game.cards[0].source_world_scale.is_equal_approx(Vector3.ONE*.699999988079071))
 assert(game.cards[0].source_world_rotation is Quaternion)
 game._return_card(0);game.drag_index=-1;game.mouse_down=false
 game._update_hand(.5)
 assert(not game.cards[0].returning and game.native_phone_hand.focus==-1)
 assert(game.cards[0].source_world_position.is_equal_approx(game.native_phone_hand.source_pose(0,1).position))
 game.cards[0].drawing=true;game._update_hand(.1);assert(game.cards[0].source_phone_hidden)
 game.cards[0].source_draw_deck_count=20;game.cards[0].source_draw_tracker=0
 game._update_hand(.5);assert(game.cards[0].source_draw_phase=="flight" and not game.cards[0].source_phone_hidden)
 game._update_hand(1.0);assert(game.cards[0].source_draw_phase=="seat")
 var end_bone=load("res://scripts/native_phone_draw.gd").endpoints.FriendlyDrawCard.phone_world_position
 assert(game.cards[0].source_world_position.is_equal_approx(Vector3(end_bone[0],end_bone[1],end_bone[2])))
 game._update_hand(.31);assert(not game.cards[0].drawing)
 game._update_hand(.2);assert(game.cards[0].source_world_position.is_equal_approx(game.native_phone_hand.source_pose(0,1).position))
 print("PHONE_HAND_GAME_PASS hand claims overlapping power touch; opponent-turn browsing without card/power actions; busy guard; tap expands, outside press collapses, transition guarded; source layout, held hit, draw and return")
 quit()
