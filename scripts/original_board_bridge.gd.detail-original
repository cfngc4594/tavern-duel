extends Node
## Stage A: original perspective board rendered once behind 2.5D game actors.
## All visible content is moved by the host WorldPresentation, not this camera.
var game
var source_opening=preload("res://scripts/source_phone_board_opening.gd").new()
const RenderResolution = preload("res://scripts/render_resolution_policy.gd")
var render_size := Vector2i(1600,900)

func set_render_size(value:Vector2i):
 render_size=value
 if is_instance_valid(viewport) and is_instance_valid(probe):
  viewport.size=render_size
  _sync_camera_extent()
 if is_instance_valid(game) and is_instance_valid(game.board_sprite):game.board_sprite.scale=game.presentation_size/Vector2(render_size)
var viewport:SubViewport
var probe
var closed=false
var match_count=0
var advance_count=0
var accepted_clicks=0
var audio_enabled=true
var generation=0
var reset_pending=false
var waiting_for_cache=false
var ready_cache_frames=0
var build_wait_frames=0
var last_cache_gate={}
func setup(host):
 game=host
 render_size=host.board_render_target_size
 viewport=SubViewport.new();viewport.name="OriginalBoardViewport";viewport.size=Vector2i(2,2)
 viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 viewport.audio_listener_enable_3d=true;viewport.handle_input_locally=true;viewport.gui_disable_input=true;add_child(viewport)
 audio_enabled=host.sound_enabled and DisplayServer.get_name()!="headless"
 _request_build()
func _request_build():
 if DisplayServer.get_name()=="headless":
  _build_probe();return
 waiting_for_cache=true;ready_cache_frames=0
func _build_probe():
 waiting_for_cache=false;ready_cache_frames=0
 viewport.size=render_size;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 probe=load("res://original_board/scripts/board_probe.gd").new()
 probe.host_driven=true;probe.interaction_audio_enabled=audio_enabled;viewport.add_child(probe)
 generation+=1
 _sync_camera_extent()
 source_opening.bind(probe)
 _sync_opening_board(0.0)
func _sync_camera_extent():
 if not is_instance_valid(probe) or not is_instance_valid(probe.camera):return
 probe.refresh_source_camera(game.presentation_size)
 sync_source_camera()
func get_texture():return viewport.get_texture() if is_instance_valid(viewport) else null
static func card_cache_ready(cards:Dictionary,pending_freezes:Dictionary,draw_pending:bool,retired_count:int)->bool:
 if cards.is_empty() or not pending_freezes.is_empty() or draw_pending or retired_count>0:return false
 for state in cards.values():
  if not state.get("rt_cache_baked",false) or state.get("rt_cache_dirty",true):return false
 return true
func _cache_gate()->Dictionary:
 if is_instance_valid(game) and game.native_card_loader.has_pending():return {"ready":false,"reason":"waiting_for_serial_card_queue"}
 if not is_instance_valid(game) or not is_instance_valid(game.native_card_renderer):return {"ready":false,"reason":"waiting_for_card_renderer"}
 var renderer=game.native_card_renderer
 var controller=renderer.texture_cache_controller
 if not is_instance_valid(controller) or not controller.enabled or not controller.auto_bake:return {"ready":false,"reason":"card_cache_disabled"}
 var ready=card_cache_ready(renderer.cards,renderer.pending_freezes,controller.draw_pending,game.retired_native_renderers.size())
 return {"ready":ready,"cards":renderer.cards.size(),"pending_freezes":renderer.pending_freezes.size(),"retired_renderers":game.retired_native_renderers.size(),"draw_pending":controller.draw_pending,"reason":"ready" if ready else "waiting_for_completed_card_cache"}
func advance(dt):
 if closed:return
 if waiting_for_cache:
  build_wait_frames+=1;last_cache_gate=_cache_gate()
  ready_cache_frames=ready_cache_frames+1 if last_cache_gate.ready else 0
  # Cache signals precede RT shrink inside frame_post_draw. Two host frames
  # avoid overlapping the first board allocation with the attachment release.
  if ready_cache_frames>=2:_build_probe()
 if not is_instance_valid(probe):return
 _sync_opening_board(minf(maxf(dt,0.0),0.05))
 advance_count+=1;probe.advance_host(maxf(dt,0.0))
 sync_source_camera()
func try_pointer_press(board_position:Vector2)->bool:
 if closed or not is_instance_valid(probe) or not Rect2(Vector2.ZERO,Vector2(1600,900)).has_point(board_position):return false
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=(board_position+game.presentation_offset)*Vector2(viewport.size)/game.presentation_size
 var accepted=probe.handle_host_input(event)
 if accepted:accepted_clicks+=1
 return accepted
func set_audio(enabled:bool):
 audio_enabled=enabled
 if not is_instance_valid(probe):return
 probe.interaction_audio_enabled=enabled
 for controller in [probe.door_interaction,probe.window_lamp_interaction,probe.arch_interactions,probe.kite_interactions,probe.pumpkin_interaction,probe.bush_interactions,probe.water_interactions]:
  if is_instance_valid(controller):controller.audio_enabled=enabled
 # Existing and new players are routed through host SFX bus. Host owns mute/gain.
func reset_for_match():
 match_count+=1
 if match_count==1 or closed:return
 if reset_pending:return
 reset_pending=true
 if is_instance_valid(probe):
  if is_instance_valid(probe.camera):probe.camera.current=false
  probe.close_probe();probe.queue_free()
 probe=null;source_opening.bind(null)
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.size=Vector2i(2,2)
 waiting_for_cache=false;ready_cache_frames=0
 call_deferred("_finish_reset")
func _finish_reset():
 if closed or not reset_pending:return
 reset_pending=false
 _request_build()
func get_audit():
 return {"closed":closed,"waiting_for_cache":waiting_for_cache,"build_wait_frames":build_wait_frames,"last_cache_gate":last_cache_gate,"generation":generation,"advance_count":advance_count,"accepted_clicks":accepted_clicks,"viewports":1 if is_instance_valid(viewport) else 0,"host_driven":is_instance_valid(probe) and probe.host_driven,"camera_offset_applied":false,"stage":"A: original board perspective; actors remain existing 2.5D","source":probe.get_audit() if is_instance_valid(probe) and not closed else {},"opening_board":source_opening.get_audit()}
func close():
 if closed:return
 closed=true;waiting_for_cache=false
 if is_instance_valid(game) and is_instance_valid(game.board_sprite):game.board_sprite.texture=null
 if is_instance_valid(probe):probe.close_probe();probe.queue_free()
 probe=null;source_opening.bind(null)
 if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.queue_free()
 viewport=null
func _exit_tree():close()

func sync_source_camera()->bool:
 # Host calls after its one shake sample. The board is a camera follower when
 # the phone controller owns registration; never shake board geometry itself.
 if not is_instance_valid(probe) or not is_instance_valid(probe.camera):return false
 var context=preload("res://scripts/source_board_projection.gd").from_game(game)
 return context!=null and context.copy_camera(probe.camera)

func _sync_opening_board(delta:float):
 if not is_instance_valid(game):return
 var flow=game.get("flow")
 if flow==null:return
 var coin_active=false
 var visuals=flow.get("visuals")
 var coin=visuals.get("source_coin") if visuals!=null else null
 var player=coin.get("player") if is_instance_valid(coin) else null
 if is_instance_valid(player) and player.has_method("is_coin_object_active"):
  coin_active=player.is_coin_object_active()
 source_opening.sync({"mode":flow.get("mode"),"phase":flow.get("phase"),"phase_time":flow.get("phase_time"),"first_side":flow.get("first_side"),"coin_object_active":coin_active,"loading":game.get("native_initial_loading")==true,"game_over":game.get("game_over")==true},delta)
func skip_source_mulligan_board():
 # Explicit source SkipMulligan presentation hook. It does not skip local rules.
 source_opening.skip_mulligan()
