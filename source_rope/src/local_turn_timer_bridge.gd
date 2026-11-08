extends RefCounted
## Explicit OFFLINE event producer, not the original server/network source.
## Call instead of old rope hooks only after separate host/GPU integration QA.
const Controller=preload('source_turn_timer_controller.gd')
const Presenter=preload('source_rope_presenter.gd')
signal source_tick_requested(final_tick:bool,seconds_remaining:int)
signal before_presentation_advance(scaled_timestamp:float,realtime_timestamp:float)
var controller=Controller.new()
var presenter=Presenter.new()
var active:=false
var local_end_timestamp:=0.0
var timeout_sent:=false
var shared_countdown_end_timestamp:=0.0
var play_tick_sound:=false
var game_entity_exists:=true
var game_is_over:=false # Source tick checks IsGameOver, not NowOrPending.
var last_tick_second:=0
func setup():
 controller.source_command.connect(_on_controller_command)
 presenter.spell_state_started.connect(controller.on_spell_state_started)
 presenter.setup()
func _on_controller_command(command:Dictionary):
 if command.kind=='countdown_restart':last_tick_second=int(ceil(controller.rope_cap_seconds))
 presenter.handle_controller_command(command)
func begin_turn(duration:float,timeout_tag:float,friendly:bool=true,turn_start_active:bool=false):
 assert(duration>=0)
 controller.set_context(presenter.realtime,{'game_exists':true,'current_player_exists':true,'friendly':friendly,'turn_start_active':turn_start_active,'game_over':false})
 game_is_over=false;active=true;timeout_sent=false;local_end_timestamp=presenter.realtime+duration
 controller.on_current_player_changed(timeout_tag)
 receive_update(true,duration,local_end_timestamp)
func receive_update(should_show:bool,remaining:float,end_timestamp:float):
 # This mirrors the source shared AssembleUIManager assignment without claiming
 # the current project has that manager or an authoritative networking stack.
 shared_countdown_end_timestamp=end_timestamp
 # A correction must replace this OFFLINE producer's deadline too; otherwise
 # its previous scheduled timeout would overwrite the corrected source input.
 if not should_show:active=false
 elif active and is_finite(end_timestamp):
  local_end_timestamp=end_timestamp;timeout_sent=remaining<=Controller.EPSILON
 controller.set_context(presenter.realtime)
 controller.on_timer_update(should_show,remaining,end_timestamp)
func advance(scaled_delta:float,realtime_delta:float,context_values:Dictionary={}):
 assert(scaled_delta>=0 and realtime_delta>=0)
 # Align controller endpoint computations before synchronous FSM callbacks.
 controller.set_context(presenter.realtime+realtime_delta,context_values)
 # Audio fade must reach this frame's value before FINISHED can leave its
 # source FSM state. A new state cancels the old action without snapping it.
 before_presentation_advance.emit(presenter.scaled_time+scaled_delta,presenter.realtime+realtime_delta)
 presenter.advance(scaled_delta,realtime_delta)
 controller.advance(presenter.realtime)
 if active and not timeout_sent and presenter.realtime>=local_end_timestamp:
  timeout_sent=true;receive_update(true,0.0,local_end_timestamp)
 _update_tick()
func notify_friendly_turn_started():controller.on_friendly_turn_started()
func end_turn_requested(is_2v2:bool=false):
 controller.on_end_turn_requested(is_2v2)
 if not is_2v2:active=false
func hide_for_reconnect():
 active=false;receive_update(false,INF,INF)
func game_over(pending:bool=false):
 active=false;game_is_over=not pending
 controller.set_context(presenter.realtime,{'game_over':true})
 controller.on_game_over()
func reset():
 active=false;timeout_sent=false;local_end_timestamp=0;shared_countdown_end_timestamp=0;last_tick_second=0;game_is_over=false
 controller.reset();presenter.reset(controller.epoch)
func _update_tick():
 if not play_tick_sound or not controller.context.game_exists or not game_entity_exists or game_is_over:return
 var remaining=controller.remaining()
 if not is_finite(remaining):return # Local safety boundary for reconnect INF.
 var second=int(ceil(remaining))
 if second<last_tick_second:
  last_tick_second=second;source_tick_requested.emit(second==0,second)
func disconnect_signals():
 controller.source_command.disconnect(_on_controller_command)
 presenter.spell_state_started.disconnect(controller.on_spell_state_started)
func get_audit()->Dictionary:
 return {'producer':'Explicit offline authoritative-timer substitute; not original server','active':active,'timeout_sent':timeout_sent,'shared_countdown_end_timestamp':shared_countdown_end_timestamp,'controller':controller.get_audit(),'presenter':presenter.get_audit(),'installed_in_game':false,'android_verified':false}
