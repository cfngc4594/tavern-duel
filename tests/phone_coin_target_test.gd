extends SceneTree
class Flow:
 var first_hand_count=4
class Host extends Node:
 var native_phone_hand
 var cards=[]
 var flow=Flow.new()
class Player extends Node3D:
 func finish_coin_object():pass
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var viewport=SubViewport.new();viewport.size=Vector2i(1600,900);root.add_child(viewport)
 var camera=Camera3D.new();viewport.add_child(camera);camera.set_meta("native_phone_registered",true)
 var context=load("res://scripts/source_board_projection.gd").install(host,camera,Vector2(1600,900),Vector2(1600,900),Vector2.ZERO,{})
 assert(context!=null)
 host.native_phone_hand=load("res://scripts/native_phone_hand.gd").new();host.native_phone_hand.setup(host)
 var coin=load("res://scripts/native_coin_presentation.gd").new();root.add_child(coin);coin.game=host
 coin.player=Player.new();coin.add_child(coin.player)
 var actor=Node3D.new();coin.player.add_child(actor);actor.position=Vector3(1,2,3)
 coin.card_actor={"root":actor}
 coin.begin_hand_transition({"pos":Vector2(-99999,99999),"scale":99,"angle":2})
 var source=host.native_phone_hand.source_pose(4,5)
 assert(coin.gather_to.origin.is_equal_approx(source.position))
 coin.sample_hand_transition(1.0)
 var b=host.native_phone_hand.source_basis(source.rotation)
 var expected=Transform3D(Basis(b.x*source.scale.x,b.y*source.scale.y,b.z*source.scale.z),source.position)
 assert(actor.transform.is_equal_approx(expected))
 print("PHONE_COIN_TARGET_PASS source ZoneHand target, raw nonuniform scale, original1s style2; legacy screen endpoint ignored")
 quit()
