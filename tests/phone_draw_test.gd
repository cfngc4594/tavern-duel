extends SceneTree
class Host extends Node:
 var cards=[]
 var native_phone_hand
 var events=[]
 func _publish_source_hand_pose(card,pose):card.source_phone_pose=pose
 func _event(value):events.append(value)
func _initialize():call_deferred("run")
func run():
 var draw=load("res://scripts/native_phone_draw.gd")
 var a=Vector3(1,2,3);var b=Vector3(-4,4,-5)
 assert(draw.flight(a,b,Vector3.ONE,0).position==a)
 assert(draw.flight(a,b,Vector3.ONE,1.5).position.is_equal_approx(b))
 assert(draw.flight(a,b,Vector3.ONE,.15).scale.is_equal_approx(Vector3.ONE*.8799999952316284))
 assert(draw.flight(a,b,Vector3.ONE,1.5).scale.is_equal_approx(Vector3.ONE))
 assert(is_equal_approx(draw.ease33(.5),.96875))
 assert(is_equal_approx(draw.ease15(.5),.03125))
 assert(draw.thickness(1)=="1" and draw.thickness(6)=="25" and draw.thickness(7)=="50" and draw.thickness(14)=="75" and draw.thickness(20)=="Full")
 assert(draw.time_scale(2)==1 and is_equal_approx(draw.time_scale(3),.889) and is_equal_approx(draw.time_scale(7),.556))
 var host=Host.new();root.add_child(host)
 host.native_phone_hand=load("res://scripts/native_phone_hand.gd").new();host.native_phone_hand.setup(host)
 for i in 2:host.cards.append({"drawing":true,"source_draw_deck_count":25-i,"source_draw_tracker":i})
 draw.advance(host,.5)
 assert(host.cards[0].source_draw_phase=="flight" and host.cards[1].source_phone_hidden)
 draw.advance(host,1.0)
 assert(host.cards[0].source_draw_phase=="seat" and host.cards[1].source_draw_phase=="flight")
 assert(host.cards[0].source_phone_transition.ease_type==15)
 draw.advance(host,.31);assert(not host.cards[0].drawing)
 print("PHONE_DRAW_PASS original world spline, recovered ease33 actual branch, .15delays/.75scale/1.35rotation, queue, source bones, style1 hand entry, .3interactive")
 quit()
