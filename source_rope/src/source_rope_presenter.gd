extends RefCounted
## Isolated source-FSM compatibility presenter. Not installed in the game.
## Commands preserve recovered action order. Native Unity frame scheduling and
## the overlapping material writers are NOT proven pixel-equivalent.
signal source_action(action:Dictionary)
signal presentation_sample(sample:Dictionary)
signal spell_state_started(spell_state:int,epoch:int)
const SPELL_TO_EVENT={1:'Birth',2:'Idle',5:'Death',4:'Cancel'}
const STATE_TO_SPELL={'State 5':1,'State 2':2,'State 3':5,'State 4':4}
var spec:Dictionary={}
var settings:Dictionary={'PlayMusicStinger':true,'PlayTimeoutFx':true,'RopeFuseVolume':0.4000000059604645,'RopeRolloutVolume':1.0,'EndTurnButtonExplosionVolume':1.0}
var audio_sources:Dictionary={'Sparks/FX_Sparks/Fuse sound loop':true,'Fuse Timer Music Stinger':true}
var scaled_time:=0.0
var realtime:=0.0
var epoch:=0
var generation:=0
var fsm_state:='ready'
var active_spell:=0
var fsm_ready:=false
var wait_until:=-1.0
var wait_realtime:=false
var fade_until:=-1.0
var animation_started:=-1.0
var material_coroutines:Array=[]
var reset_actions:Array=[]
var countdown:Dictionary={}
var trace:Array=[]
# Both candidate orders can be tested. Original Unity last-writer is unverified.
var material_write_order:='countdown_then_birth'
func setup(specification_path:String=''):
 var path=specification_path if not specification_path.is_empty() else get_script().resource_path.get_base_dir().path_join('../data/source_fsm.json')
 spec=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(spec.size()>0)
 _enter_state('ready')
 fsm_ready=true
func configure(values:Dictionary):
 for key in values:
  assert(settings.has(key));settings[key]=values[key]
func reset(new_epoch:int):
 epoch=new_epoch;generation+=1;wait_until=-1;fade_until=-1;animation_started=-1
 material_coroutines.clear();countdown.clear();reset_actions.clear();trace.clear()
 fsm_state='ready'
 active_spell=0
 _emit({'type':'host_reset','params':{}})
 if not spec.is_empty():_enter_state('ready')
func _emit(action:Dictionary)->bool:
 var e=epoch;var g=generation;var item=action.duplicate(true)
 item.epoch=e;item.generation=g;item.scaled_time=scaled_time;item.realtime=realtime;item.state=fsm_state
 trace.append(item);source_action.emit(item)
 return e==epoch and g==generation
func take_trace()->Array:
 var result=trace;trace=[];return result
func _resolve(value):
 if value is Dictionary:
  if value.has('variable'):return settings.get(value.variable,value.get('default'))
  var result={}
  for key in value:result[key]=_resolve(value[key])
  return result
 if value is Array:
  var result=[]
  for item in value:result.append(_resolve(item))
  return result
 return value
func handle_controller_command(command:Dictionary):
 if int(command.epoch)!=epoch:return
 match str(command.kind):
  'activate_spell_state':_activate_spell(int(command.spell_state))
  'birth_material_coroutine':
   material_coroutines.append(scaled_time+float(command.scaled_duration))
   _sample_birth_material()
  'countdown_stop':countdown.clear()
  'countdown_sample':_sample_countdown(float(command.sample_progress),float(command.fuse))
  'countdown_restart':
   countdown={'start':realtime,'duration':float(command.remaining),'progress':float(command.sample_progress),'fuse':float(command.fuse),'ease_type':command.ease_type}
   _sample_countdown(countdown.progress,countdown.fuse)
func _activate_spell(spell:int):
 # Spell.ChangeState notifies logic callbacks BEFORE ChangeFsmState exits the
 # old state. SpellStateAction below is the separate automatic-FSM path.
 assert(fsm_ready)
 var e=epoch;active_spell=spell
 spell_state_started.emit(spell,epoch)
 # Source ChangeFsmState waits for ready and verifies the requested active
 # state still matches. This candidate requires setup/ready before any input.
 if e!=epoch or active_spell!=spell:return
 _enter_state(str(spec.global_transitions[SPELL_TO_EVENT[spell]]))
func _enter_state(next:String):
 var entering_epoch=epoch
 # Only the Cancel spiral visibility action requests reset-on-exit.
 var restore=reset_actions.duplicate(true);reset_actions.clear()
 for action in restore:
  if not _emit({'type':'restore_visibility','params':{'token':action.token}}):return
 if epoch!=entering_epoch:return
 generation+=1;fsm_state=next;wait_until=-1;fade_until=-1
 var expected_generation=generation
 for original in spec.states[next].actions:
  if not original.enabled:continue
  var action:Dictionary=original.duplicate(true);action.params=_resolve(action.params)
  action.token='%d:%d:%d'%[epoch,generation,int(action.index)]
  if not _emit(action):return
  var p:Dictionary=action.params
  match str(action.type):
   'SpellStateAction':
    var spell=int(STATE_TO_SPELL[next])
    if active_spell!=spell:
     active_spell=spell;spell_state_started.emit(spell,epoch)
   'AnimatorPlayAction','AnimatorPlaythroughAction':animation_started=scaled_time
   'SetVisibility','SetVisibilityRecursiveAction':
    if bool(p.get('resetOnExit',false)):reset_actions.append(action)
   'Wait':
    wait_realtime=bool(p.realTime);wait_until=(realtime if wait_realtime else scaled_time)+float(p.time)
   'AudioVolumeFadeAction':
    var source_path:String=p.m_GameObject.get('path','')
    var duration=float(p.m_FadeTime) if bool(audio_sources.get(source_path,true)) else 0.0
    fade_until=scaled_time+duration
   'BoolAllTrue':
    if p.boolVariables.all(func(value):return bool(value)):
     _send_event(str(p.sendEvent));return
  if epoch!=entering_epoch or generation!=expected_generation:return
 _finish_audio_state_if_ready()
func _send_event(event:String):
 var transitions:Dictionary=spec.states[fsm_state].transitions
 if transitions.has(event):_enter_state(str(transitions[event]))
func _finish_audio_state_if_ready():
 # In these source states all other enabled actions finish synchronously.
 # Fade is the only blocking action. Missing AudioSource finishes immediately.
 if fsm_state in ['State 2','State 3'] and fade_until>=0 and scaled_time>=fade_until:
  fade_until=-1;_send_event('FINISHED')
func advance(scaled_delta:float,real_delta:float):
 assert(scaled_delta>=0 and real_delta>=0)
 scaled_time+=scaled_delta;realtime+=real_delta
 var e=epoch
 if wait_until>=0 and (realtime if wait_realtime else scaled_time)>=wait_until:
  wait_until=-1;_send_event('FINISHED')
 if e!=epoch:return
 _finish_audio_state_if_ready()
 if e!=epoch:return
 if animation_started>=0:
  presentation_sample.emit({'kind':'animation','seconds':maxf(0.0,scaled_time-animation_started),'epoch':epoch})
 if e!=epoch:return
 if material_write_order=='birth_then_countdown':
  _sample_birth_material();_sample_tween()
 else:
  _sample_tween();_sample_birth_material()
 if e!=epoch:return
 presentation_sample.emit({'kind':'particle_clock','scaled_time':scaled_time,'scaled_delta':scaled_delta,'epoch':epoch})
func _sample_birth_material():
 material_coroutines=material_coroutines.filter(func(deadline):return scaled_time<float(deadline))
 for _deadline in material_coroutines:
  var e=epoch
  presentation_sample.emit({'kind':'birth_material','epoch':epoch})
  if e!=epoch:return
func _sample_tween():
 if countdown.is_empty():return
 # Source Blizzard.T5.iTween EaseType field 0x0400008c linear has Constant 21.
 # Unity frame scheduling remains unverified despite the exact linear formula.
 var fraction=clampf((realtime-float(countdown.start))/maxf(float(countdown.duration),0.00000001),0.0,1.0)
 _sample_countdown(lerpf(float(countdown.progress),0.0,fraction),lerpf(float(countdown.fuse),-1.5,fraction))
 # Reaching zero never sends Death. Explicit timer update owns that event.
func _sample_countdown(progress:float,fuse:float):
 presentation_sample.emit({'kind':'countdown','progress':progress,'fuse':fuse,'epoch':epoch})
func get_audit()->Dictionary:
 return {'fsm_state':fsm_state,'active_spell':active_spell,'fsm_ready_required':true,'epoch':epoch,'generation':generation,'scaled_time':scaled_time,'realtime':realtime,'wait_until':wait_until,'wait_realtime':wait_realtime,'birth_material_writers':material_coroutines.size(),'material_write_order':material_write_order,'material_order_verified':false,'installed_in_game':false,'android_verified':false}
