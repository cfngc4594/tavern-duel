extends SceneTree
func _initialize():call_deferred("run")
func run():
 var policy=load("res://scripts/source_board_camera_policy.gd")
 policy.qa_phone_platform=true
 var game=load("res://scripts/game.gd").new()
 root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.sound_enabled=false
 game.headless=false
 game._ensure_card_face_textures()
 # The normal asynchronous card loader is presentation-only. Build the four
 # selected source cards explicitly so the test does not depend on GPU timing.
 var seat:int=0 if OS.get_cmdline_user_args().has("--first") else 1
 game.flow.reset();game.flow.begin_normal(seat,3001)
 for key in game.flow.opening_hand:
  if not game.native_card_renderer.cards.has(key):
   var d:Dictionary=game.definitions[key]
   game.native_card_renderer.build_card(key,d,game.raw_portraits[d.get("portrait",0)])
 game.native_initial_loading=false
 game._setup_spatial_presentation()
 game.native_initial_loading=false
 game.spatial_scene.sync_from_game()
 game.spatial_scene.set_process(false)
 var layer=load("res://scripts/native_opening_presentation.gd").new();game.add_child(layer);layer.setup(game)
 game.flow.visuals.source_opening=layer
 assert(layer.hero_labels.states.size()==2,"Original hero labels failed to attach")
 for name in ["intro","deal","mulligan"]:
  game.flow.phase=name
  for t in [0.0,.1,.5,1.3,2.4,4.8]:
   game.flow.phase_time=t;layer.advance(.016);layer._process(0.0)
 assert(layer.cards.size()==game.flow.first_hand_count)
 for index in range(game.flow.first_hand_count):
  var card:Dictionary=layer.cards[index]
  assert(card.pose.position.is_finite())
  assert(is_instance_valid(card.highlight),"No original 3D highlight for "+str(card.key))
  assert(layer.card_contains(index,layer.project(card.pose.position)),"Source card hit mismatch "+str(index))
 var found=false
 for key in layer.ui.confirm.nodes:
  var collider:Dictionary=layer.assets.component(key,"BoxCollider")
  if collider.is_empty():continue
  var node:Node3D=layer.ui.confirm.nodes[key]
  var center:Vector3=layer.Curves.vec(collider.data.m_Center)
  var world:Vector3=layer.world.global_transform.affine_inverse()*node.global_transform*center
  found=layer.confirm_contains(layer.project(world))
 assert(found,"Original button collider not hittable")
 assert(layer.ui.confirm.root.position.x==layer.anchor("StartingHandZone").x)
 assert(layer.ui.confirm.root.position.y==layer.anchor("Zone_Friendly_Hand").y)
 game.flow.selected.assign([0,2]);game.flow.confirm_mulligan()
 for key in game.flow.opening_hand:
  if not game.native_card_renderer.cards.has(key):
   var d:Dictionary=game.definitions[key]
   game.native_card_renderer.build_card(key,d,game.raw_portraits[d.get("portrait",0)])
 for t in [0.0,.25,.5,1.0,1.5,2.0,3.5,4.5]:
  game.flow.phase_time=t;layer.advance(.016);layer._process(0.0)
 for index in [0,2]:assert(layer.cards[index].key==game.flow.opening_hand[index])
 print("SOURCE_OPENING_LAYER_PASS seat=",seat," cards=",game.flow.first_hand_count," original_hero_labels=2 source_highlights=true collider_hit=true replacement_ids=authoritative")
 print("SOURCE_OPENING_SHADER_LIMITS ",JSON.stringify(layer.assets.opening_shader_limits))
 game.flow.visuals.source_opening=null
 game.headless=true;game.queue_free();await process_frame;quit()
