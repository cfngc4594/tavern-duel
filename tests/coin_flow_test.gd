extends SceneTree
class Flow extends RefCounted:
 var phase="coin"
 var phase_time=0.0
 var first_side=1
 var first_hand_count=4
class Host extends Node:
 var headless=false
 var flow=Flow.new()
 var elapsed=10.0
 var sound_enabled=false
 func _resting_hand_pose(_i,_n):return {"pos":Vector2(800,850),"scale":0.8,"angle":0.0}
class Mock extends Node:
 var events=[]
 var gather_started=false
 var advanced=0.0
 var card_advanced=0.0
 var card_started=false
 func advance_source(dt,_time):advanced+=dt;events.append(["advance",dt])
 func advance_card(dt):
  if card_started:card_advanced+=dt
 func begin_source_birth(_sound):events.append(["birth",advanced])
 func begin_source_card():card_started=true;events.append(["card",advanced])
 func begin_hand_transition(_pose):gather_started=true;events.append(["gather",0])
 func sample_hand_transition(t):events.append(["gather_sample",t])
 func set_active(value):events.append(["active",value])
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var visuals=load("res://scripts/classic_flow_visuals.gd").new();visuals.game=host
 var source=Mock.new();host.add_child(source);visuals.source_coin=source
 host.flow.phase_time=0.0;visuals._tick_source_coin(0.8)
 assert(visuals.source_birth_sent and visuals.source_card_started)
 assert(source.events[1][0]=="birth" and is_equal_approx(source.events[1][1],0.5))
 assert(source.events[3][0]=="card" and is_equal_approx(source.events[3][1],0.6))
 assert(is_equal_approx(source.advanced,0.8));assert(is_equal_approx(source.card_advanced,0.2))
 host.flow.phase_time=0.8;visuals._tick_source_coin(0.2)
 var births=0
 for e in source.events:
  if e[0]=="birth":births+=1
 assert(births==1)
 host.flow.phase="gather";host.flow.phase_time=0;visuals._tick_source_coin(0.2);assert(source.gather_started)
 assert(is_equal_approx(visuals.COIN_PHASE_SECONDS,2.11666668057442));assert(visuals.COIN_FLY_SECONDS==1.0)
 visuals._clear_source_coin();assert(not visuals.source_birth_sent and not visuals.source_card_started)
 print("COIN_FLOW_PASS exact0.5 Birth/0.6 card boundaries across coarse frame; one-shot events;1s gather; lifecycle")
 host.queue_free();quit()
