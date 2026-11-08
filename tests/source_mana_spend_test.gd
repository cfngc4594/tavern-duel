extends SceneTree
class Recorder extends RefCounted:
 var events=[]
 func record_mana_spend(side,cost,temp):events.append([side,cost,temp])
func _initialize():
 var game=load("res://scripts/game.gd").new()
 game.flow={"temporary_mana":[1,2]};game.source_phone_layout=Recorder.new()
 game.mana=1;game.max_mana=4
 game._spend_mana(1)
 assert(game.mana==0 and game.flow.temporary_mana[0]==0)
 assert(game.source_phone_layout.events[0]==[0,1,1])
 game.mana=5;game.flow.temporary_mana[0]=1;game._spend_mana(3)
 assert(game.mana==2 and game.flow.temporary_mana[0]==0)
 assert(game.source_phone_layout.events[1]==[0,3,1])
 game.enemy_mana=5;game._spend_mana(3,1)
 assert(game.enemy_mana==2 and game.flow.temporary_mana[1]==0)
 assert(game.source_phone_layout.events[2]==[1,3,2])
 game.max_mana=5;game.mana=4;game.flow.temporary_mana[0]=1
 game._clear_temporary_mana(0)
 assert(game.mana==3 and game.flow.temporary_mana[0]==0)
 game.free()
 print("SOURCE_MANA_SPEND_PASS")
 quit()
