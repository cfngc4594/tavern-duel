extends SceneTree
## Rendered production-main regression. No phone/platform override or replacement
## game component. Synthetic mouse/key events enter the production input handler;
## physical input stays blocked by PrivacyTestGuard on the isolated test desktop.
const Policy=preload("res://scripts/source_board_camera_policy.gd")
var game
var capture:SubViewport
var failures:Array[String]=[]
var checks:Array[String]=[]
var output="res://build/desktop-ui"
var mouse=Vector2.ZERO
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:checks.append(label)
 else:failures.append(label);print("DESKTOP_UI_FAIL ",label)
func pause(seconds:float):await create_timer(seconds,true,false,true).timeout
func until(label:String,predicate:Callable,seconds:float=12.0)->bool:
 var started=Time.get_ticks_msec()
 while not predicate.call() and Time.get_ticks_msec()-started<seconds*1000:
  await process_frame
 var ok=predicate.call();check(ok,label);return ok
func move(point:Vector2):
 var screen=game.board_to_screen(point)
 game._update_screen_pointer(screen)
 var event=InputEventMouseMotion.new();event.position=screen;event.relative=screen-mouse;mouse=screen
 game._unhandled_input(event);game._update_hover(false)
func button(point:Vector2,pressed:bool,which:int=MOUSE_BUTTON_LEFT):
 move(point)
 var event=InputEventMouseButton.new();event.position=mouse;event.button_index=which;event.pressed=pressed
 game._unhandled_input(event)
func click(point:Vector2):button(point,true);button(point,false)
func key(code:int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;game._unhandled_input(event)
func card_index(id:String)->int:
 for i in game.cards.size():
  if game.cards[i].key==id:return i
 return -1
func card_point(index:int)->Vector2:
 var hand=game.native_phone_hand
 var pose=hand.source_pose(index,hand.layout_count())
 var center:Vector3=pose.position+hand.source_basis(pose.rotation)*(pose.scale*(hand.standin_child*hand.standin_box.get_center()))
 var point:Vector2=hand.project(center)
 if hand.hit_card(point)==index:return point
 # Overlapping fan cards are selected by visible stand-ins, not their raw
 # transform origins (which can land on a neighbor). Find an exposed hit.
 for radius in range(5,151,5):
  for offset in [Vector2(radius,0),Vector2(-radius,0),Vector2(0,-radius),Vector2(0,radius)]:
   if hand.hit_card(point+offset)==index:return point+offset
 check(false,"exposed hand hit for index "+str(index));return point
func play_point()->Vector2:
 return game.source_phone_layout.snapshot.items.friendly_play.center
func outside_hand_point()->Vector2:
 var hand=game.native_phone_hand
 for pixel in [Vector2(20,20),Vector2(game.presentation_size.x-20,20),Vector2(20,game.presentation_size.y*.5)]:
  var point:Vector2=pixel-game.presentation_offset
  if hand.hit_card(point)>=0:continue
  if hand.focus>=0 and hand.focus<game.cards.size():
   var card:Dictionary=game.cards[hand.focus]
   if card.has("source_phone_pose") and Geometry2D.is_point_in_polygon(point,hand.card_polygon(card.source_phone_pose,game.definitions[card.key].kind)):continue
  return point
 check(false,"outside hand point available");return Vector2(-1000,-1000)
func drag(index:int,destination:Vector2):
 button(card_point(index),true)
 check(game.pressed_card==index,"mouse press selects requested card "+str(index))
 move(destination)
 check(game.drag_index==index,"mouse drag holds requested card "+str(index))
 await pause(.12)
 button(destination,false)
func screenshot(label:String):
 capture.size=Vector2i(game.presentation_size)
 await process_frame;await RenderingServer.frame_post_draw
 var img=capture.get_texture().get_image()
 check(img!=null and not img.is_empty(),label+" capture available")
 if img!=null:check(img.save_png(output+"/"+label+".png")==OK,label+" capture saved")
 var guard=root.get_node("PrivacyTestGuard")
 check(guard.runtime_evidence().active and guard.runtime_evidence().master_muted,label+" guard stays active")
 var screen=root.get_texture().get_image()
 check(screen.get_pixel(screen.get_width()/2,screen.get_height()/2).is_equal_approx(Color.BLACK),label+" visible root stays black")
func refresh_practice():
 game.start_match("practice");game.flow.test_clock_delta=0;game.mana=10;game.max_mana=10;game.tutorial_hint=false
 await until("practice assets ready",func():return not game.native_initial_loading)
 await pause(1.2)
func health_tint(state:Dictionary)->Color:
 return state.stat_nodes.health.mesh.surface_get_material(0).get_shader_parameter("text_tint")
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--ui-output="):output=arg.trim_prefix("--ui-output=")
 DirAccess.make_dir_recursive_absolute(output)
 if DisplayServer.get_name()=="headless":
  push_error("Rendered desktop integration requires Windows Forward+; headless is not UI verification.");quit(2);return
 check(OS.has_feature("windows"),"real Windows platform")
 check(not Policy.qa_phone_platform and not Policy.phone_platform_requested(),"no emulated phone platform")
 check(Policy.source_ui_requested(),"production shared UI default")
 check(RenderingServer.get_current_rendering_method()=="forward_plus","real Forward+ renderer")
 check(root.get_node("PrivacyTestGuard").runtime_evidence().active,"privacy guard required")
 if not failures.is_empty():quit(2);return
 Engine.max_fps=60
 check(change_scene_to_file("res://main.tscn")==OK,"load production main.tscn")
 await scene_changed;game=current_scene;game.scripted_pointer=true
 if not await until("production loading complete",func():return not game.native_initial_loading,60):await finish();return
 game.flow.test_clock_delta=0
 await pause(.5)
 check(game.source_projection!=null and game.source_projection.is_enabled(),"default main owns source projection")
 check(game._phone_hand_enabled() and not game.touch_input_active,"shared hand with real mouse input")
 check(game.original_board_bridge.probe.phone_variant,"board variant matches shared camera")
 check(game.spatial_scene.phone_board_actors.actors.size()==4,"native heroes and powers instantiated by main")
 check(game.spatial_scene.phone_board_actors.blockers.is_empty(),"native hero/power materials ready")
 check(game.spatial_scene.phone_blockers.is_empty(),"source minion geometry ready")
 check(is_instance_valid(game.spatial_scene.phone_mana_renderer),"native mana renderer")
 check(is_instance_valid(game.spatial_scene.phone_deck_renderer),"native deck renderer")
 check(game.flow.mode=="normal","unmodified normal opening default")
 capture=SubViewport.new();capture.name="ProductionWorldCapture";capture.world_2d=root.world_2d
 capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS;capture.disable_3d=true;root.add_child(capture)
 await screenshot("normal-opening")
 # Keep the production normal lifecycle. Only its random seat/seed is fixed.
 game.start_match("normal",1,318);game.flow.test_clock_delta=0
 if not await until("normal second-player assets ready",func():return not game.native_initial_loading,60):await finish();return
 if not await until("normal opening reaches mulligan",func():return game.flow.phase=="mulligan",30):await finish();return
 await pause(.6)
 var opening=game.flow.visuals.source_opening
 check(is_instance_valid(opening) and opening.mobile,"normal opening uses shared source presentation")
 var first:Vector2=opening.opening_position(0)
 click(first);check(game.flow.selected.has(0),"mouse selects mulligan card")
 click(first);check(not game.flow.selected.has(0),"mouse deselects mulligan card")
 var collider:Dictionary=opening.assets.component(opening.roots.confirm,"BoxCollider")
 var c=collider.data.m_Center
 var world:Vector3=opening.ui.confirm.root.global_transform*Vector3(c.x,c.y,c.z)
 var confirm:Vector2=opening.camera.unproject_position(world)*game.presentation_size/Vector2(opening.viewport.size)-game.presentation_offset
 check(opening.confirm_contains(confirm),"projected mulligan confirm hit")
 await screenshot("normal-mulligan")
 click(confirm);check(game.flow.phase=="replace","mouse confirms normal mulligan")
 if await until("normal coin enters gather",func():return game.flow.phase=="gather",15):
  await pause(.15)
  var coin=game.flow.visuals.source_coin
  check(is_instance_valid(coin) and coin.gather_started and coin.gather_source_rotation,"normal coin flies to shared native hand")
  await screenshot("normal-coin-gather")
 await until("normal opening completes",func():return game.flow.phase=="playing")
 check(card_index("GAME_005")>=0 and not game.enemy_hand.has("GAME_005"),"only second player receives coin in normal main")
 await screenshot("normal-playing")
 await until("normal AI yields player's turn",func():return game.player_turn and not game.busy,25)
 await pause(.6)
 var normal_mana=game.mana
 await drag(card_index("GAME_005"),play_point())
 await until("normal coin spell completes",func():return not game.busy)
 check(game.mana==normal_mana+1 and game.flow.temporary_mana[0]==1 and card_index("GAME_005")<0,"mouse normal coin play adds one temporary mana")
 await screenshot("coin-temporary-mana")
 await refresh_practice()
 var initial_cards=game.cards.size()
 var point=card_point(0)
 click(point);await pause(.35)
 check(game.native_phone_hand.enlarged and game.drag_index<0,"mouse click expands collapsed hand without pickup")
 point=card_point(0);move(point);await pause(.55)
 check(game.native_phone_hand.focus==0,"mouse hover previews expanded hand")
 await screenshot("expanded-hand")
 click(Vector2(800,340));await pause(.35)
 check(not game.native_phone_hand.enlarged,"outside mouse click collapses hand")
 click(card_point(0));await pause(.35)
 click(card_point(0))
 check(game.drag_index==0,"second click picks up expanded card")
 key(KEY_ESCAPE);await pause(.6)
 check(game.drag_index<0 and game.pressed_card<0 and game.native_phone_hand.touched_slot<0,"Escape clears held card and touch state")
 check(game.cards.size()==initial_cards and not game.cards[0].returning,"Escape returns card without consumption")
 button(card_point(0),true);button(game.pointer,true,MOUSE_BUTTON_RIGHT);button(game.pointer,false)
 check(game.drag_index<0 and game.native_phone_hand.touched_slot<0,"right cancel before drag cannot pick up on release")
 await pause(.35)
 var before=game.cards.size()
 var start=card_point(0)
 button(start,true);move(start+Vector2(12,-12));await pause(.1)
 check(game.drag_index==0,"mouse movement starts drag with desktop threshold")
 button(card_point(0),false);await pause(.6)
 check(game.drag_index<0 and game.cards.size()==before,"drop back onto hand cancels")
 game.native_phone_hand.set_enlarged(false);await pause(.35)
 game.player_turn=false;game.ai_timer=999
 click(card_point(0));await pause(.35)
 check(game.native_phone_hand.enlarged,"opponent turn hand browsing")
 button(card_point(0),true);move(play_point());button(play_point(),false)
 check(game.drag_index<0 and game.cards.size()==before,"opponent turn cannot play cards")
 game.player_turn=true
 click(Vector2(800,340));await pause(.35)
 game.busy=true;click(card_point(0));check(not game.native_phone_hand.enlarged and game.drag_index<0,"busy rejects hand gestures");game.busy=false
 var hero=game.spatial_scene.phone_board_actors.actors["hero:1"].actor
 check(not hero.paths["RootObject/DecorationRoot/AttackObject"].visible,"actual zero-attack hero gem hidden")
 var index=card_index("CS2_189")
 check(index>=0,"archer fixture card exists")
 var old_mana=game.mana
 await drag(index,play_point())
 check(not game.pending_battlecry.is_empty() and game.pending_battlecry.has("unit"),"mouse drop starts provisional archer summon")
 check(game.health[1]==30 and game.mana==old_mana,"uncommitted archer preserves health and mana")
 if not game.pending_battlecry.is_empty():
  await until("archer enters before target",func():return not game.busy)
  check(game.spatial_scene.pieces.has(game.pending_battlecry.unit.id),"provisional archer rendered in actual desktop scene")
  await screenshot("archer-before-target")
  button(game.pointer,true,MOUSE_BUTTON_RIGHT);await pause(.6)
  check(game.pending_battlecry.is_empty() and game.mana==old_mana and game.health[1]==30,"archer right cancel restores hand without costs")
  await until("cancelled archer finishes returning",func():return not game.cards[card_index("CS2_189")].get("returning",false))
 index=card_index("CS2_189")
 await drag(index,play_point())
 if not game.pending_battlecry.is_empty():
  await until("repeated archer enters",func():return not game.busy)
  click(game.ENEMY_HERO)
  check(game.health[1]==30,"archer target commit does not apply damage before projectile impact")
  await until("archer projectile resolves",func():return not game.busy)
  check(game.health[1]==29 and game.mana==old_mana-1,"archer one impact and one mana charge")
  await pause(.25)
  check(health_tint(hero).is_equal_approx(Color(1,50.0/255.0,50.0/255.0)),"actual desktop hero damage uses shared red text")
 await screenshot("archer-damaged-hero")
 game.mana=10;game.power_used=false;await pause(.4)
 click(game.POWER_POS);check(game.targeting_power,"native hero power mouse hit")
 key(KEY_ESCAPE);check(not game.targeting_power and not game.power_used,"power Escape cancels without use")
 click(game.POWER_POS);click(game.ENEMY_HERO)
 await until("hero power impact resolves",func():return not game.busy)
 await pause(.8)
 check(game.power_used and game.health[1]==28,"hero power commits through mouse target")
 var power=game.spatial_scene.phone_board_actors.actors["power:0"].actor
 check(power.get("power_exhausted",false),"native power used state")
 await screenshot("power-used")
 game.power_used=false;await pause(.8)
 check(not power.get("power_exhausted",true),"native power restore state")
 # Targeted spell cancellation must retain the card and clear native aim state.
 var spell=card_index("CS2_024")
 button(card_point(spell),true);move(game.ENEMY_HERO);await pause(.15)
 check(game.interaction_state==game.Interaction.SPELL_AIM,"mouse spell enters native aim")
 key(KEY_ESCAPE)
 check(game.drag_index<0 and not game.native_phone_hand.targeting_mode and card_index("CS2_024")>=0,"spell Escape restores card and clears target mode")
 await until("cancelled spell returns",func():return not game.cards[card_index("CS2_024")].get("returning",false))
 # Real minion selection and target, through the same mouse route as hero power.
 var attacker=game.allies[0];var victim=game.enemies[0]
 var victim_health=int(victim.hp);var attacker_health=int(attacker.hp)
 click(attacker.pos);check(game.selected_unit==attacker.id,"mouse selects native minion")
 button(game.pointer,true,MOUSE_BUTTON_RIGHT);check(game.selected_unit<0,"right-click cancels minion attack")
 click(attacker.pos);click(victim.pos)
 await until("native minion attack completes",func():return not game.busy)
 check(victim.hp==victim_health-int(attacker.atk) and attacker.hp==attacker_health-int(victim.atk),"native minion attack resolves both health values")
 await screenshot("minion-attack")
 for size in [Vector2i(1920,1080),Vector2i(1200,900),Vector2i(2100,900),Vector2i(1280,720)]:
  root.size=size;await pause(.4)
  check(game.source_projection.is_enabled() and not Policy.qa_phone_platform,"native UI remains default after resize "+str(size))
  for anchor in ["friendly_hero","opposing_hero","friendly_power","end_turn"]:
   var p:Vector2=game.source_phone_layout.snapshot.items[anchor].center
   check(game.source_phone_layout.contains(anchor,p),anchor+" projected hit after resize "+str(size))
   check(game.screen_to_board(game.board_to_screen(p)).distance_to(p)<.01,anchor+" screen inverse after resize "+str(size))
  var bounds=Rect2(Vector2.ZERO,game.presentation_size)
  for corner in game.source_phone_layout.snapshot.items.end_turn.hit_polygon:
   check(bounds.grow(1).has_point(corner+game.presentation_offset),"end-turn hit geometry stays onscreen "+str(size))
  check(game.original_board_bridge.probe.camera.global_transform.is_equal_approx(game.source_projection.camera.global_transform),"board camera matches gameplay after resize "+str(size))
  click(game.POWER_POS)
  check(game.targeting_power,"real mouse power hit after resize "+str(size))
  key(KEY_ESCAPE)
  click(card_point(0));await until("hand expansion settles after resize "+str(size),func():return game.native_phone_hand.enlarging_remaining<=0)
  check(game.native_phone_hand.enlarged,"real mouse hand hit after resize "+str(size))
  click(outside_hand_point());await until("hand collapse settles after resize "+str(size),func():return game.native_phone_hand.enlarging_remaining<=0)
  check(not game.native_phone_hand.enlarged,"real mouse outside collapse after resize "+str(size))
  await screenshot("size-"+str(size.x)+"x"+str(size.y))
 await refresh_practice()
 check(not game.power_used and game.health==[30,30] and game.pending_battlecry.is_empty(),"restart clears prior battle state")
 check(not game.native_phone_hand.enlarged and game.native_phone_hand.focus<0 and game.native_phone_hand.touched_slot<0,"restart resets native hand gesture state")
 check(game.spatial_scene.phone_board_actors.blockers.is_empty(),"restart keeps native actors healthy")
 click(game.source_phone_layout.snapshot.items.end_turn.center)
 check(not game.player_turn,"native end-turn mouse click changes turn")
 await finish()
func finish():
 var report={"ok":failures.is_empty(),"checks":checks,"failures":failures,"platform":OS.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"main_scene":game.scene_file_path if game!=null else "","qa_phone_platform":Policy.qa_phone_platform,"scope":"Production main, default Windows source UI, rendered Forward+, synthetic mouse/key events at production handler. Root remains privacy masked. Captures share the live world canvas; fixed overlay/cursor are excluded. No physical touch, gamepad, APK or performance claim."}
 var file=FileAccess.open(output+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("DESKTOP_UI_RESULT ",JSON.stringify(report))
 if failures.is_empty():print("DESKTOP_UI_INTEGRATION_PASS")
 await root.get_node("SoundManager").shutdown_audio()
 if is_instance_valid(capture):capture.queue_free()
 if is_instance_valid(game):game.queue_free()
 await process_frame;quit(0 if failures.is_empty() else 1)
