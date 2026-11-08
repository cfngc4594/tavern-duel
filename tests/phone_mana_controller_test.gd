extends SceneTree
const Controller=preload("res://scripts/native_phone_mana_controller.gd")
const Layout=preload("res://scripts/source_phone_board_layout.gd")
class Flow extends RefCounted:
 var temporary_mana=[2,0]
class SourceLayout extends RefCounted:
 var mana_events:Array=[]
 var mana_tray={"shown":false,"position":Vector3.ZERO}
class Host extends Node:
 var flow=Flow.new()
 var source_phone_layout=SourceLayout.new()
 var max_mana:=5
 var mana:=5
 var enemy_mana:=3
 var enemy_max_mana:=4
class FakeAssets extends RefCounted:
 func clip_length(_name:String)->float:return 0.1666666716337204
class Player extends RefCounted:
 var source_sound_events:Array=[]
 var elapsed:=0.0
 var desired_state:=0
 var birth:=false
 var primed:=false
 var hidden:=false
 var pose:=Transform3D.IDENTITY
class Renderer extends Node:
 var assets=FakeAssets.new()
 var live_crystals:Dictionary={}
 var retired:Array=[]
 var samples:Array=[]
 var values:Dictionary={}
 var advance_count:=0
 func begin_live(index:int,temp:bool,already_present:bool=false,initial_state:int=0,_pose=null,_hidden:bool=false):
  var player=Player.new();player.birth=not already_present;player.primed=already_present;player.desired_state=initial_state
  live_crystals[index]=player;samples.append(["begin",index,temp,already_present,initial_state]);return player
 func set_live_state(index:int,state:int):
  var player=live_crystals[index];player.desired_state=state;samples.append(["state",index,state])
  if state==3:retired.append(player);live_crystals.erase(index)
 func remap_live(mapping:Dictionary)->bool:
  var next={}
  for old in live_crystals:
   var at=int(mapping.get(old,old))
   if next.has(at):return false
   next[at]=live_crystals[old]
  live_crystals=next;return true
 func set_live_pose(index:int,pose:Transform3D):live_crystals[index].pose=pose
 func set_live_hidden(index:int,value:bool):live_crystals[index].hidden=value
 func clear_live(_index:int=-1):live_crystals.clear();retired.clear()
 func advance_live(delta:float):
  advance_count+=1
  for player in live_crystals.values()+retired:player.elapsed+=delta
 func sync(snapshot:Dictionary,data:Dictionary):
  values=data;assert(snapshot.items.friendly_mana.crystals.size()==mini(10,live_crystals.size()))
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var renderer=Renderer.new();host.add_child(renderer)
 var control=Controller.new();host.add_child(control);control.setup(host,renderer)
 var items=Layout.recovered_items(0,0,{"aspect":16.0/9.0,"permanent_mana_count":5,"temporary_mana_count":2})
 var snapshot={"ready":true,"canvas_size":Vector2(1600,900),"items":items}
 control.update(snapshot,0.0,{},1)
 assert(control.permanent.size()==5 and control.temporary.size()==2)
 assert(control.permanent[0].state==1 and control.permanent[1].state==1 and control.permanent[2].state==0)
 assert(control.permanent[0].slot==4 and control.permanent[4].slot==0)
 for player in renderer.live_crystals.values():assert(player.primed and not player.birth)
 assert(renderer.values.friendly_counter=="5/5" and renderer.values.opposing_counter=="3/4")
 var original=control.permanent[0].player
 control.propose("card-17",4)
 assert(control.temporary[1].state==2 and control.temporary[0].state==2)
 assert(control.permanent[2].state==2 and control.permanent[3].state==2 and control.permanent[4].state==0)
 control.cancel_proposal("different-card");assert(control.temporary[0].state==2)
 control.cancel_proposal("card-17");assert(control.temporary[0].state==0 and control.permanent[2].state==0)
 host.flow.temporary_mana[0]=0;host.mana=2
 host.source_phone_layout.mana_events.append({"serial":1,"side":0,"cost":3,"temporary_used":2,"permanent_used":1})
 control.update(snapshot,.01,{},2)
 assert(control.temporary.is_empty() and renderer.retired.size()==2)
 assert(control.permanent[2].state==0) # WaitForSeconds(0) still yields the source coroutine.
 control.update(snapshot,.01,{},3);assert(control.permanent[2].state==1)
 var advance_count=renderer.advance_count;var clock=control.elapsed
 control.update(snapshot,5.0,{},3)
 assert(control.elapsed==clock and renderer.advance_count==advance_count)
 host.max_mana=6;host.mana=3
 control.update(snapshot,0.0,{},4)
 assert(control.permanent.size()==6 and not control.permanent.back().loaded and renderer.live_crystals.size()==5)
 control.update(snapshot,.19,{},5);assert(not control.permanent.back().loaded)
 control.update(snapshot,.02,{},6)
 assert(control.permanent.back().loaded and control.permanent.back().player.birth)
 assert(control.permanent.back().player.elapsed==0.0)
 assert(control.permanent[0].player==original and control.permanent[0].slot==5)
 host.mana=6;control.update(snapshot,0.0,{},7)
 control.update(snapshot,.21,{},8)
 assert(control.permanent[2].state==0 and control.permanent[1].state==1)
 control.update(snapshot,.2,{},9);assert(control.permanent[1].state==0 and control.permanent[0].state==1)
 control.update(snapshot,.2,{},10);assert(control.permanent[0].state==0)
 host.source_phone_layout.mana_tray.shown=true
 control.update(snapshot,0.0,{},11)
 assert(renderer.values.friendly_counter_alpha==1.0)
 control.update(snapshot,.05,{},12)
 assert(is_equal_approx(float(renderer.values.friendly_counter_alpha),.03125))
 assert(is_equal_approx(float(renderer.values.counter_flip_times.friendly),.05))
 host.source_phone_layout.mana_tray.shown=false;control.update(snapshot,0.0,{},13)
 control.update(snapshot,.05,{},14)
 assert(renderer.values.counter_flip_times.friendly==0.0)
 host.max_mana=10;host.mana=10;control.update(snapshot,0.0,{},15)
 assert(renderer.values.friendly_counter=="10")
 assert(control.blockers.is_empty(),str(control.blockers))
 control.reset();assert(control.pending.is_empty() and renderer.live_crystals.is_empty())
 host.max_mana=5;host.mana=2;host.flow.temporary_mana[0]=0
 control.update(snapshot,0.0,{},30)
 var survivor=control.permanent[1].player
 host.max_mana=4;host.mana=1;control.update(snapshot,0.0,{},31)
 assert(control.permanent.size()==4 and control.permanent[0].player==survivor)
 assert(control.permanent[0].state==1 and control.permanent[1].state==1 and control.permanent[2].state==1 and control.permanent[3].state==0)
 assert(control.blockers.is_empty(),str(control.blockers))
 print("PHONE_MANA_CONTROLLER_PASS source prime/no Birth, stable reverse-list identities, temp-first destroy, deferred ordinary spend, queued Birth/restore, proposal lifecycle, source Flip/text alpha, localized counter, once-per-frame clock")
 await process_frame;await process_frame;await process_frame
 host.queue_free();root.get_node("SoundManager").stop_all_sfx();await create_timer(.2).timeout;quit()
