extends SceneTree
const Draw=preload("res://scripts/native_phone_opponent_draw.gd")
func _initialize():
 var start=Vector3(1,2,3);var bone=Vector3(3,4,5)
 var target={"position":Vector3(8,9,10),"rotation":Vector3(0,-20,352.5),"scale":Vector3(.682,.125,.682)}
 var zero=Draw.flight(start,bone,target,0)
 assert(zero.position.is_equal_approx(start));assert(zero.rotation.is_equal_approx(Vector3(275,90,0)))
 assert(zero.scale.is_equal_approx(Vector3.ONE*.88))
 var waiting=Draw.flight(start,bone,target,.8)
 assert(waiting.rotation.is_equal_approx(zero.rotation));assert(waiting.scale.is_equal_approx(zero.scale))
 var end=Draw.flight(start,bone,target,1.75)
 assert(end.position.is_equal_approx(target.position));assert(end.scale.is_equal_approx(target.scale))
 assert(preload("res://scripts/native_phone_hand.gd").source_basis(end.rotation).is_equal_approx(preload("res://scripts/native_phone_hand.gd").source_basis(target.rotation)))
 for power in [3,4,5]:
  assert(is_equal_approx(Draw.ease_in_out(.5,power),.5));assert(Draw.ease_in_out(0,power)==0);assert(Draw.ease_in_out(1,power)==1)
 var scaled=Draw.flight(start,bone,target,.875,.5)
 assert(scaled.position.is_equal_approx(target.position))
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_deck_runtime.json"))
 assert(data.rows.has("OpponentDrawCard"))
 print("PASS original hidden-opponent 4-point path/ease8, rotation5/scale11, delays/endpoints/time scale")
 quit()
