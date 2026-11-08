extends SceneTree
const Controller=preload("res://scripts/native_phone_mana_controller.gd")
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const Live=preload("res://scripts/native_phone_mana_live.gd")
class Flow extends RefCounted:
 var temporary_mana=[1,0]
class SourceLayout extends RefCounted:
 var mana_events:Array=[]
 var mana_tray={"shown":false,"position":Vector3.ZERO}
class Host extends Node:
 var flow=Flow.new()
 var source_phone_layout=SourceLayout.new()
 var max_mana:=5
 var mana:=2
 var enemy_mana:=3
 var enemy_max_mana:=4
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var cards=load("res://scripts/native_card_renderer.gd").new();host.add_child(cards)
 var renderer=load("res://scripts/native_phone_mana_renderer.gd").new();host.add_child(renderer);renderer.setup(cards)
 var control=Controller.new();host.add_child(control);control.setup(host,renderer)
 var items=Layout.recovered_items(0,0,{"aspect":16.0/9.0,"permanent_mana_count":5,"temporary_mana_count":1})
 host.source_phone_layout.mana_tray.position=items.friendly_mana.tray_endpoints.hidden
 var snapshot={"ready":true,"canvas_size":Vector2(1600,900),"items":items}
 control.update(snapshot,0.0,{},1)
 assert(renderer.rendering_ready,str(renderer.blockers))
 assert(renderer.live_crystals.size()==6 and control.audio_results.is_empty())
 for row in control.permanent+control.temporary:assert(not row.player.birth_played and not row.player.playing)
 var spent=control.permanent[0].player
 assert(spent.visible_state==1)
 assert(spent.state.renderers[Live.GEM].get_surface_override_material(0).get_shader_parameter("fade_rgb").is_equal_approx(Vector3.ONE*0.4627451002597809))
 host.flow.temporary_mana[0]=2;host.mana=3
 control.update(snapshot,0.0,{},2)
 assert(renderer.live_crystals.size()==6)
 control.update(snapshot,.21,{},3)
 assert(renderer.live_crystals.size()==7)
 var born=control.temporary.back().player
 assert(born.birth_played and born.clip=="ManaGemBirth_Temp" and born.clip_time==0.0)
 control.propose("real-card",3)
 assert(control.temporary.back().state==2 and born.clip=="ManaGemBirth_Temp")
 host.flow.temporary_mana[0]=0;host.mana=0
 host.source_phone_layout.mana_events.append({"serial":1,"side":0,"cost":3,"temporary_used":2,"permanent_used":1})
 control.update(snapshot,.01,{},4)
 assert(renderer.live_crystals.size()==5 and renderer.retiring_crystals.size()==2)
 assert(born.desired_state==3 and born.destroy_started<0.0)
 control.update(snapshot,.01,{},5)
 assert(control.permanent[4].state==1)
 control.update(snapshot,2.0,{},6)
 assert(born.destroy_started>=0.0)
 control.update(snapshot,1.0,{},7)
 assert(renderer.retiring_crystals.is_empty())
 assert(control.blockers.is_empty(),str(control.blockers))
 assert(control.audio_results.size()==2,str(control.audio_results))
 assert(control.audio_results[0].event=="mana_add" and control.audio_results[1].event=="mana_spend")
 for result in control.audio_results:assert(result.result.accepted,str(result))
 assert(renderer.rendering_ready,str(renderer.blockers))
 print("PHONE_MANA_CONTROLLER_LIVE_PASS actual original source geometry/material/prime/Birth/queued state/temp destroy-retirement, no GPU parity claim")
 await process_frame;await process_frame;await process_frame
 host.queue_free();root.get_node("SoundManager").stop_all_sfx();await create_timer(.2).timeout;quit()
