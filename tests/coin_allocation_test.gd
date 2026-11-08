extends SceneTree

class Host extends RefCounted:
 var cards:Array=[]
 var enemy_hand:Array=[]
 var turn_side:int=-1
 func _add_card(key,_animate):cards.append({"key":key})
 func _resting_hand_pose(_index,_count):return {"pos":Vector2.ZERO,"scale":1.0,"angle":0.0}
 func _event(_name):pass
 func _begin_normal_turn(side):turn_side=side

func _initialize():
 for first_side in [0,1]:
  var host=Host.new()
  var flow=preload("res://scripts/classic_match_flow.gd").new()
  flow.game=host;flow.first_side=first_side;flow.phase="gather"
  flow.opening_hand=["CS2_029","CS2_023","CS2_024"]
  if first_side==1:flow.opening_hand.append("CS2_182")
  flow.finish_opening()
  var friendly_coins=host.cards.filter(func(c):return c.key=="GAME_005").size()
  assert(friendly_coins==(1 if first_side==1 else 0),"Only second player receives Coin")
  assert(host.enemy_hand.count("GAME_005")== (1 if first_side==0 else 0),"Enemy coin ownership")
  assert(host.turn_side==first_side)
  var count=host.cards.size()
  flow.finish_opening()
  assert(host.cards.size()==count,"Opening cannot award another Coin")
 print("COIN_ALLOCATION_PASS first player no Coin; second player one Coin; idempotent")
 quit()
