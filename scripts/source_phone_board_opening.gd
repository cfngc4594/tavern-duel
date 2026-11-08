extends RefCounted
## Visual-only adapter between the existing local opening phases and Board.cs.
## No card rules, RNG, resource balances, or phase transitions are changed.
## Source EndMulligan splits before HandleCoinCard; Raise waits its coroutine,
## not the complete coin-card Birth animation. The host supplies its flow clock.
const OPENING_PHASES=['intro','deal','mulligan','replace','coin','gather']
const COIN_OBJECT_DELAY=0.5+0.10000000149011612
const POST_COIN_WAIT=1.0
var probe
var initialized=false
var end_started=false
var raise_sent=false
var end_age=0.0
var raise_delay=0.0
var last_phase=''
var paused=false
var game_over_seen=false
var events:Array=[]
var blockers:Array=[]
func bind(value):
 probe=value;initialized=false;end_started=false;raise_sent=false;end_age=0.0;raise_delay=0.0;last_phase='';paused=false;game_over_seen=false;events.clear();blockers.clear()
func _available()->bool:
 return is_instance_valid(probe) and probe.get('phone_variant')==true and probe.get('board_state')!=null
func _record(action:String):events.append({'action':action,'phase':last_phase,'end_age':end_age})
func sync(snapshot:Dictionary,dt:float):
 if not _available() or not is_finite(dt) or dt<0.0:return
 var mode=str(snapshot.get('mode',''))
 var phase=str(snapshot.get('phase',''))
 paused=bool(snapshot.get('loading',false));last_phase=phase
 if mode=='normal' and not initialized and phase in OPENING_PHASES:
  probe.set_mulligan_lighting();probe.combined_surface();initialized=true;_record('dim_and_combined')
 if bool(snapshot.get('game_over',false)) and not game_over_seen:game_over()
 if paused:return # Even an advance(0) would resample a running source tween.
 if game_over_seen:
  # HandleGameOverDuringMulligan stops its opening coroutines. Ignore later
  # local flow phases here without changing that rule/state machine itself.
  probe.advance_board_lighting(dt);return
 if mode!='normal' or not initialized:
  return # Practice/settled loads do not invent an opening.
 var step=dt
 if not end_started and phase=='coin':
  probe.split_surface();end_started=true;end_age=maxf(0.0,float(snapshot.get('phase_time',0.0)))
  # Normalized CIL branch IL013f -> IL015c still waits1 sec when the
  # coin card is null. Only the active coin-object branch adds .5+.1.
  var coin_object_wait=COIN_OBJECT_DELAY if bool(snapshot.get('coin_object_active',false)) else 0.0
  raise_delay=0.0 if int(snapshot.get('first_side',0))==0 else coin_object_wait+POST_COIN_WAIT
  _record('end_mulligan_split')
 if end_started:
  if not raise_sent and end_age+step>=raise_delay:
   var before=maxf(0.0,raise_delay-end_age)
   probe.raise_lights();raise_sent=true;_record('raise_lights')
   # A newly scheduled source tween samples its current percentage first.
   # Preserve only the part of this host frame after HandleCoinCard completed.
   probe.advance_board_lighting(maxf(0.0,step-before))
  elif raise_sent:
   probe.advance_board_lighting(step)
  end_age+=step
 elif phase=='playing':
  var message='Opening ended without observed EndMulligan; explicit skip requires skip_mulligan()'
  if not blockers.has(message):blockers.append(message)
func skip_mulligan():
 if not _available():return
 probe.split_surface();probe.raise_lights();initialized=true;end_started=true;raise_sent=true;raise_delay=0.0;end_age=0.0;_record('explicit_skip_normal_raise')
func game_over():
 if not _available():return
 # Source game-over handler quick-raises without changing either surface.
 probe.raise_lights_quickly();game_over_seen=true;raise_sent=true;_record('game_over_quick_raise')
func get_audit()->Dictionary:
 return {'initialized':initialized,'end_started':end_started,'raise_sent':raise_sent,'end_age':end_age,'raise_delay':raise_delay,'phase':last_phase,'paused_loading':paused,'game_over_seen':game_over_seen,'events':events.duplicate(true),'blockers':blockers.duplicate(),'source_timing':'EndMulligan split; first player immediate; second player active coin object adds .5+.1, then fixed1 sec even with null coin card. Explicit skip ordinary speed1; game over quick speed5 without split. Sequential Unity waits are minimums; local summed clock is not native frame-scheduler parity.','clock':'Existing clamped opening clock; loading does not advance lighting. No server/phase mutation.'}
