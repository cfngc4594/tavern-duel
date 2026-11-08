extends SceneTree
const Controller=preload("res://scripts/native_phone_mana_controller.gd")
const Layout=preload("res://scripts/source_phone_board_layout.gd")
class Combat extends Node:
 func supports_spell(_key:String)->bool:return true
class SourceLayout extends RefCounted:
 var mana_events:Array=[]
 var mana_tray={"shown":false,"position":Vector3.ZERO}
class Host extends Node:
 var flow=preload("res://scripts/classic_match_flow.gd").new()
 var native_combat
 var source_phone_layout=SourceLayout.new()
 var max_mana:=10
 var mana:=9
 var enemy_mana:=10
 var enemy_max_mana:=10
 func play_sound(_name:String):pass
 func _event(_name:String):pass
var host
var renderer
var control
var snapshot:Dictionary
var frame:=0
func _initialize():call_deferred("run")
func step(delta:float):
 frame+=1;control.update(snapshot,delta,{},frame)
 assert(control.blockers.is_empty(),str(control.blockers))
 assert(renderer.rendering_ready,str(renderer.blockers))
func run():
 host=Host.new();root.add_child(host);host.flow.game=host
 host.native_combat=Combat.new();host.add_child(host.native_combat)
 var cards=load("res://scripts/native_card_renderer.gd").new();host.add_child(cards)
 renderer=load("res://scripts/native_phone_mana_renderer.gd").new();host.add_child(renderer);renderer.setup(cards)
 control=Controller.new();host.add_child(control);control.setup(host,renderer)
 var items=Layout.recovered_items(0,0,{"aspect":16.0/9.0,"permanent_mana_count":10,"temporary_mana_count":0})
 host.source_phone_layout.mana_tray.position=items.friendly_mana.tray_endpoints.hidden
 snapshot={"ready":true,"canvas_size":Vector2(1600,900),"items":items}
 step(0.0)
 assert(renderer.live_crystals.size()==10 and renderer.text_nodes.friendly_counter.text=="9")
 var used=control.permanent[0].player
 # The Coin at 10 capacity and 9 available grants one TEMP crystal, not capacity.
 host.flow.coin(0);assert(host.mana==10 and host.flow.temporary_mana[0]==1);step(0.0);step(.21)
 assert(control.permanent.size()==10 and control.temporary.size()==1 and renderer.live_crystals.size()==11)
 assert(control.last_snapshot.items.friendly_mana.crystals.size()==10)
 var overflow=control.temporary[0];var player=overflow.player
 assert(overflow.slot==10 and player.birth_played)
 assert(not player.state.root.visible and not player.spawn_state.root.visible)
 var expected_parent:Transform3D=control._source_parent_pose({"mana_tray_position":host.source_phone_layout.mana_tray.position})
 var hidden_pose:Transform3D=control.hidden_crystal_poses[10]
 assert(hidden_pose.origin.is_equal_approx(expected_parent.origin))
 assert(hidden_pose.is_equal_approx(expected_parent*control._source_initial_local_pose()))
 # Hidden means only gem and spawn objects. Destroy still has its original
 # independent FX, at the verified parent/local-zero pose, with no guessed slot11.
 host.flow.temporary_mana[0]=0;host.mana=9
 host.source_phone_layout.mana_events.append({"serial":1,"side":0,"cost":1,"temporary_used":1,"permanent_used":0})
 step(.01)
 assert(control.temporary.is_empty() and renderer.live_crystals.size()==10 and renderer.retiring_crystals.size()==1)
 assert(control.permanent[0].player==used and control.permanent[0].state==1)
 assert(player.desired_state==3 and player.destroy_started<0.0)
 step(2.0)
 assert(player.destroy_started>=0.0 and player.destroy_state.root.visible and player.particle_players.size()==2)
 assert(player.get_parent()==renderer)
 assert(player.transform.is_equal_approx(hidden_pose))
 step(1.0);assert(renderer.retiring_crystals.is_empty())
 # Unused temporary mana removed at the end of the turn is also destroyed.
 host.flow.coin(0);assert(host.mana==10 and host.flow.temporary_mana[0]==1);step(0.0);step(.21)
 var unused=control.temporary[0].player
 host.flow.temporary_mana[0]=0;host.mana=9;step(0.0)
 assert(control.temporary.is_empty() and unused.desired_state==3)
 step(2.0);step(1.0)
 assert(renderer.live_crystals.size()==10 and renderer.retiring_crystals.is_empty())
 assert(control.permanent[0].state==1)
 print("PHONE_MANA_OVERFLOW_PASS 10 permanent + Coin =11 source objects /10 available, only gem+spawn hidden, verified original parent/local-zero pose, temp-first spend, original destroy survives, end-turn cleanup, no index overflow")
 await process_frame;await process_frame;await process_frame
 host.queue_free();root.get_node("SoundManager").stop_all_sfx();await create_timer(.2).timeout;quit()
