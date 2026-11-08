extends RefCounted
## Recovered TurnTimer command/state adapter, deliberately not installed in game.
## Inputs carry authoritative timer timestamps and explicit lifecycle events.
## Outputs are intents, not a substitute for the source Spell/FSM presentation.
## Connect source_command to a SYNCHRONOUS presenter. activate_spell_state must
## synchronously acknowledge on_spell_state_started before another host input.
## take_commands is an audit trace, not an asynchronous delivery queue.
## context.game_over means IsGameOverNowOrPending, including pending game over.
## Source: TurnTimer 0x0600631d..0x06006341, coroutine 0x06006347/0x0600634d.
signal source_command(command:Dictionary)
enum TimerState { NONE=0, START=1, COUNTDOWN=2, TIMEOUT=3, KILL=4 }
const EPSILON=1.401298464324817e-45
const SPELL_STATES={TimerState.START:1,TimerState.COUNTDOWN:2,TimerState.TIMEOUT:5,TimerState.KILL:4}
var state:int=TimerState.NONE
var rope_cap_seconds:=20.0
var countdown_end_timestamp:=0.0
var countdown_timeout_seconds:=0.0
var timer_belongs_to_friendly:=false
var waiting_for_turn_start:=false
var waiting_for_player:int=0
var below_cap_deadline:=-1.0
var now:=0.0
var context:Dictionary={"game_exists":true,"current_player_exists":true,"turn_start_active":false,"game_over":false,"friendly":true,"squelch_emote":false}
var commands:Array=[]
var epoch:=0

func _emit(kind:String,data:Dictionary={})->bool:
 var entry_epoch=epoch
 var item=data.duplicate(true);item.kind=kind;item.epoch=entry_epoch;commands.append(item)
 source_command.emit(item.duplicate(true))
 return epoch==entry_epoch
func take_commands()->Array:
 var result=commands;commands=[];return result
func has_countdown_timeout()->bool:return countdown_timeout_seconds>EPSILON
func remaining()->float:return maxf(0.0,countdown_end_timestamp-now)
func set_context(timestamp:float,values:Dictionary={}):
 now=timestamp
 for key in values:context[key]=values[key]
func reset():
 # Host lifecycle reset is an explicit adapter boundary, not an extra source event.
 # Rejecting old epoch callbacks below is safety hardening for reused local nodes.
 epoch+=1;state=TimerState.NONE;countdown_end_timestamp=0;countdown_timeout_seconds=0;timer_belongs_to_friendly=false
 waiting_for_turn_start=false;waiting_for_player=0;below_cap_deadline=-1;commands.clear()
func _request_state(next:int):
 if not _emit("activate_spell_state",{"timer_state":next,"spell_state":SPELL_STATES.get(next,0)}):return
 if next==TimerState.START:_emit("birth_material_coroutine",{"scaled_duration":1.0})
func on_spell_state_started(spell_state:int,callback_epoch:int=-1):
 if callback_epoch>=0 and callback_epoch!=epoch:return
 var entry_epoch=epoch
 var next:int={1:TimerState.START,2:TimerState.COUNTDOWN,5:TimerState.TIMEOUT,4:TimerState.KILL}.get(spell_state,TimerState.NONE)
 if next==TimerState.NONE:return
 var changed=state!=next;state=next
 match state:
  TimerState.START:
   if context.game_exists and context.current_player_exists:
    if not context.squelch_emote:
     if not _emit("hero_rope_emote",{"emote":9}):return
    timer_belongs_to_friendly=bool(context.friendly)
  TimerState.COUNTDOWN:
   countdown_timeout_seconds=remaining()
   _start_when_below_cap(countdown_timeout_seconds)
  TimerState.TIMEOUT,TimerState.KILL:
   countdown_end_timestamp=0
   if state==TimerState.TIMEOUT:
    if not _emit("timer_ended",{"friendly":timer_belongs_to_friendly,"targets":["EndTurnButton","GameEntity"]}):return
   if not _emit("countdown_stop"):return
   _emit_countdown_sample(0.0,false)
 if epoch!=entry_epoch:return
 if changed:_emit("state_changed",{"state":state})
func on_timer_update(should_show:bool,seconds_remaining:float,end_timestamp:float):
 # Source writes the absolute timestamp before branching. Hide/INF is valid
 # during GameState reconnect waiting; do not reject it with a finite precheck.
 countdown_end_timestamp=end_timestamp
 if not should_show:
  if state in [TimerState.START,TimerState.COUNTDOWN]:_request_state(TimerState.KILL)
  return
 if seconds_remaining<=EPSILON:
  on_turn_timed_out();return
 if seconds_remaining>rope_cap_seconds:
  _start_when_below_cap(seconds_remaining);return
 _handle_update(seconds_remaining)
func _start_when_below_cap(seconds_remaining:float):
 # Starting a new source cap coroutine replaces the prior cap wait.
 below_cap_deadline=-1
 if seconds_remaining>rope_cap_seconds:below_cap_deadline=now+seconds_remaining-rope_cap_seconds
 else:_handle_update(seconds_remaining)
func _handle_update(seconds_remaining:float):
 if context.game_exists and context.game_over:return
 if state==TimerState.COUNTDOWN:
  if not _emit("countdown_stop"):return
  _emit_countdown_sample(seconds_remaining,true);return
 if remaining()==0:return
 if context.turn_start_active:waiting_for_turn_start=true;return
 waiting_for_player+=1
 _pump_player_wait()
func _pump_player_wait():
 if waiting_for_player and context.game_exists and context.current_player_exists:
  var entry_epoch=epoch
  var pending=waiting_for_player;waiting_for_player=0
  for _i in range(pending):
   _request_state(TimerState.START)
   if epoch!=entry_epoch:return
func advance(timestamp:float,values:Dictionary={}):
 var entry_epoch=epoch
 set_context(timestamp,values)
 if below_cap_deadline>=0 and now>=below_cap_deadline:
  below_cap_deadline=-1;_handle_update(rope_cap_seconds)
 if epoch!=entry_epoch:return
 _pump_player_wait()
 # No timeout inferred here: source iTween has no oncomplete Death callback.
func _emit_countdown_sample(seconds_remaining:float,restart:bool):
 var raw_progress=0.0
 if seconds_remaining>EPSILON:raw_progress=INF if countdown_timeout_seconds==0 else seconds_remaining/countdown_timeout_seconds
 var sample_progress=clampf(raw_progress,0.0,1.0)
 _emit("countdown_restart" if restart else "countdown_sample",{
  "remaining":seconds_remaining,"denominator":countdown_timeout_seconds,
  "raw_progress":raw_progress,"sample_progress":sample_progress,
  "fuse":lerpf(-1.5,0.41999998688697815,sample_progress),
  "ignore_time_scale":true,"ease_type":21})
func on_current_player_changed(timeout_tag_seconds:float,has_timeout_tag:bool=true):
 var entry_epoch=epoch
 if state in [TimerState.START,TimerState.COUNTDOWN]:_request_state(TimerState.KILL)
 if epoch!=entry_epoch:return
 countdown_timeout_seconds=0.0
 if context.game_exists and context.current_player_exists and has_timeout_tag:countdown_timeout_seconds=timeout_tag_seconds
func on_friendly_turn_started():
 var entry_epoch=epoch
 if not has_countdown_timeout() and not waiting_for_turn_start:return
 if waiting_for_turn_start:_request_state(TimerState.START)
 if epoch!=entry_epoch:return
 waiting_for_turn_start=false
func on_end_turn_requested(is_2v2:bool=false):
 if has_countdown_timeout() and not is_2v2:_request_state(TimerState.KILL)
func on_turn_timed_out():
 if has_countdown_timeout():_request_state(TimerState.TIMEOUT)
func on_game_over():
 if state in [TimerState.START,TimerState.COUNTDOWN]:_request_state(TimerState.KILL)
func get_audit()->Dictionary:
 return {"state":state,"epoch":epoch,"remaining":remaining(),"denominator":countdown_timeout_seconds,"waiting_for_player":waiting_for_player,"waiting_for_turn_start":waiting_for_turn_start,"below_cap_deadline":below_cap_deadline,"native_runtime":false,"installed_in_game":false,"boundaries":["Explicit authoritative update required; local turn-clock is not a server source","Spell/FSM consumer must synchronously acknowledge actual state starts; audit queue is not delivery","Reset epoch protection is adapter hardening, not source coroutine parity","Death/Cancel visuals, audio and particle stop semantics remain presenter requirements"]}
