extends Node
## Isolated audio sink, not installed in production. Source-only compatibility.
## Observe EVERY source_action so non-audio state changes cancel old fades.
## Per frame, advance audio to next absolute clock BEFORE presenter.advance.
## Missing original bytes remain silent, with explicit missing_clip audit.
signal audio_event(event:Dictionary)
const EPSILON=1.401298464324817e-45
const ROOT_GO='-7775139079732154233'
var manifest:Dictionary={}
var sources:Dictionary={}
var sounddef_roles:Dictionary={}
var go_roles:Dictionary={}
var streams:Dictionary={}
var players:Dictionary={}
var fades:Array=[]
var trace:Array=[]
var scaled_time:=0.0
var realtime:=0.0
var epoch:=-1
var generation:=-1
var serial:=0
var output_enabled:=false
var output_bus:StringName=&'Master':
 set(value):
  output_bus=value
  for player in players.values():player.bus=output_bus
var settings:Dictionary={}
var base_directory:=''
## Weak references never keep a playback alive. AudioServer may own it after
## stop() until its mix thread retires the node and main-thread cleanup runs.
var retirement_refs:Dictionary={}

func setup(directory:String='',enable_output:bool=false)->bool:
 base_directory=directory if not directory.is_empty() else get_script().resource_path.get_base_dir()
 manifest=JSON.parse_string(FileAccess.get_file_as_string(base_directory.path_join('manifest.json')))
 if manifest.is_empty():return false
 output_enabled=enable_output;settings=manifest.default_game_mode_settings.duplicate(true)
 for role in manifest.clips:
  var clip:Dictionary=manifest.clips[role]
  sounddef_roles[str(clip.sounddef_key).get_slice(':',1)]=role
  go_roles[str(clip.game_object_path_id)]=role
  if not clip.audio_sources.is_empty():
   var data:Dictionary=clip.audio_sources[0].data
   sources[str(clip.game_object_path_id)]={'role':role,'source_volume':float(data.m_Volume),'code_volume':1.0,'pitch':float(data.m_Pitch),'loop':bool(data.Loop),'category':int(clip.sounddef.m_Category),'requested_playing':false,'audible_playing':false,'bytes_available':false,'generated':false}
  if clip.status=='verified_export':
   var path=base_directory.path_join(str(clip.runtime_path))
   if FileAccess.get_sha256(path)!=str(clip.wav_sha256):
    _record('invalid_clip_hash',{'role':role});continue
   var stream=AudioStreamWAV.load_from_file(path)
   if stream==null:
    _record('invalid_wav',{'role':role});continue
   streams[role]=stream
   sources[str(clip.game_object_path_id)].bytes_available=true
 return streams.size()==3

func configure(values:Dictionary):
 for key in values:settings[key]=values[key]

func _record(kind:String,data:Dictionary={}):
 var item=data.duplicate(true);item.kind=kind;item.epoch=epoch;item.generation=generation;item.scaled_time=scaled_time;item.realtime=realtime
 trace.append(item);audio_event.emit(item.duplicate(true))

func take_trace()->Array:
 var result=trace;trace=[];return result

func _value(value):
 if value is Dictionary and value.has('variable'):return settings.get(value.variable,value.get('default'))
 return value

func _go(reference:Dictionary)->String:
 return str(reference.get('path_id',ROOT_GO))

func _sound_role(reference:Dictionary)->String:
 return str(sounddef_roles.get(str(reference.get('path_id','0')),''))

func handle_source_action(action:Dictionary):
 var next_epoch=int(action.get('epoch',0));var next_generation=int(action.get('generation',0))
 if next_epoch<epoch or (next_epoch==epoch and next_generation<generation):
  _record('stale_action_ignored',{'action_type':action.get('type','')});return
 if next_epoch!=epoch or next_generation!=generation:
  # Cancellation does not advance old fades or force their endpoint/Stop.
  var count=fades.size();fades.clear();epoch=next_epoch;generation=next_generation
  if count>0:_record('fades_cancelled_on_state_exit',{'count':count})
 scaled_time=float(action.get('scaled_time',scaled_time));realtime=float(action.get('realtime',realtime))
 if not bool(action.get('enabled',true)):return
 var p:Dictionary=action.get('params',{})
 match str(action.get('type','')):
  'host_reset':_host_reset()
  'AudioPlaythroughAction':
   if float(p.get('m_Delay',0))!=0:
    _record('unsupported_action',{'reason':'Recovered TurnTimer actions have zero delay; delayed coroutine semantics are not implemented.'});return
   var role=_sound_role(p.get('m_OneShotSound',{}))
   var volume=float(_value(p.get('m_VolumeScale',1.0)))
   if not role.is_empty():_play_generated(role,volume,1.0,-1)
   else:
    var key=_go(p.get('m_GameObject',{}))
    if not sources.has(key):_record('missing_audio_source',{'key':key});return
    sources[key].code_volume=volume
    _play_existing(key)
  'AudioPlayClipAction':
   if float(p.get('m_Delay',0))!=0:
    _record('unsupported_action',{'reason':'Nonzero audio delay is outside this recovered TurnTimer scope.'});return
   var role=_sound_role(p.get('m_Sound',{}))
   if role.is_empty():_record('missing_sounddef',{'reference':p.get('m_Sound',{})});return
   _play_generated(role,float(_value(p.get('m_Volume',1))),float(_value(p.get('m_Pitch',1))),int(p.get('m_Category',0)))
  'AudioStopAction':_stop(_go(p.get('m_GameObject',{})))
  'AudioVolumeFadeAction':
   var key=_go(p.get('m_GameObject',{}))
   if not sources.has(key):_record('missing_audio_source',{'key':key});return
   var duration=float(_value(p.m_FadeTime))
   if duration<=EPSILON:
    _record('zero_duration_fade_finished',{'key':key});return
   if bool(_value(p.get('m_RealTime',false))):
    _record('unsupported_action',{'reason':'Recovered rope fades all use scaled time. The original real-time branch has different clock arithmetic and is not generalized here.'});return
   fades.append({'key':key,'start':scaled_time,'duration':duration,'from':float(sources[key].code_volume),'target':float(_value(p.m_TargetVolume)),'stop':bool(_value(p.m_StopWhenDone)),'generation':generation,'epoch':epoch})
   _record('fade_started',fades[-1])

func _play_generated(role:String,volume:float,pitch:float,category:int):
 serial+=1;var key='generated:%d'%serial;var original:Dictionary=sources[str(manifest.clips[role].game_object_path_id)]
 sources[key]=original.duplicate(true)
 sources[key].source_volume=volume;sources[key].code_volume=1.0;sources[key].pitch=pitch;sources[key].generated=true
 if category>0:sources[key].category=category
 _play_existing(key)

func _play_existing(key:String):
 var source:Dictionary=sources[key];var role=str(source.role)
 source.requested_playing=true;source.audible_playing=false;source.started_realtime=realtime
 if not streams.has(role):
  _record('missing_clip',{'key':key,'role':role,'guid':manifest.clips[role].guid,'bundle':manifest.clips[role].source_bundle})
  if bool(source.generated):sources.erase(key)
  return
 if output_enabled and is_inside_tree():
  var player:AudioStreamPlayer=players.get(key)
  if player==null:
   player=AudioStreamPlayer.new();player.bus=output_bus;add_child(player);players[key]=player
  var stream:AudioStreamWAV=streams[role]
  if bool(source.loop):
   stream=stream.duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
   stream.loop_begin=0;stream.loop_end=int(manifest.clips[role].audio.frames)
  _track_player_playback(player)
  player.stream=stream;player.pitch_scale=float(source.pitch);_update_volume(key);player.play();source.audible_playing=true
 _record('play_requested',{'key':key,'role':role,'bytes_available':true,'output_started':source.audible_playing,'gain_before_category_and_ducking':gain(key),'category':source.category,'loop':source.loop})

func _stop(key:String):
 if not sources.has(key):_record('missing_audio_source',{'key':key});return
 sources[key].requested_playing=false;sources[key].audible_playing=false
 if players.has(key):
  _track_player_playback(players[key]);players[key].stop()
 _record('stop',{'key':key,'role':sources[key].role})

func gain(key:String)->float:
 if not sources.has(key):return 0.0
 return float(sources[key].code_volume)*float(sources[key].source_volume)

func _update_volume(key:String):
 if players.has(key):players[key].volume_linear=maxf(0.0,gain(key))

func advance(next_scaled_time:float,next_realtime:float):
 assert(next_scaled_time>=scaled_time and next_realtime>=realtime)
 scaled_time=next_scaled_time;realtime=next_realtime
 _collect_retirements()
 var remaining:Array=[]
 for fade in fades:
  if int(fade.epoch)!=epoch or int(fade.generation)!=generation:continue
  var progress=clampf((scaled_time-float(fade.start))/float(fade.duration),0.0,1.0)
  var key=str(fade.key)
  sources[key].code_volume=lerpf(float(fade.from),float(fade.target),progress);_update_volume(key)
  if progress>=1.0:
   _record('fade_finished',{'key':key,'code_volume':sources[key].code_volume})
   if fade.stop:_stop(key)
  else:remaining.append(fade)
 fades=remaining
 # Keep real-player state honest without making missing-byte virtual playback
 # look like proof that an audible clip ran.
 for key in players:
  sources[key].audible_playing=players[key].playing
 # Generated one-shots own their players and must not accumulate across turns.
 # Virtual known-byte auditions expire at their verified full clip duration.
 var finished:Array=[]
 for key in sources:
  var source:Dictionary=sources[key]
  if not bool(source.get('generated',false)):continue
  var role=str(source.role)
  var age=realtime-float(source.started_realtime)
  var duration=float(manifest.clips[role].audio.duration_seconds)/maxf(float(source.pitch),0.000001)
  var real_finished=players.has(key) and age>0.0 and not players[key].playing
  if real_finished or age>=duration:finished.append(key)
 for key in finished:
  _record('generated_source_finished',{'key':key,'role':sources[key].role})
  _dispose_player(str(key));sources.erase(key)

func _dispose_player(key:String):
 if not players.has(key):return
 var player:AudioStreamPlayer=players[key]
 _track_player_playback(player)
 player.stop();player.stream=null;player.queue_free();players.erase(key)

func _track_player_playback(player:AudioStreamPlayer):
 if not player.has_stream_playback():return
 var playback=player.get_stream_playback()
 retirement_refs[playback.get_instance_id()]=weakref(playback)

func _collect_retirements()->int:
 for id in retirement_refs.keys():
  if retirement_refs[id].get_ref()==null:retirement_refs.erase(id)
 return retirement_refs.size()

func pending_disposals()->int:
 return _collect_retirements()

func drain_disposals():
 ## Must be awaited after release()/host reset and before freeing this Node
 ## or exiting the tree. Never substitutes a fixed sleep for engine completion.
 assert(is_inside_tree(),'Keep the audio sink in the tree until drain_disposals completes.')
 while _collect_retirements()>0:await get_tree().process_frame

func _host_reset():
 # Explicit adapter boundary, not an invented source Spell/FSM transition.
 fades.clear()
 for key in players.keys():_dispose_player(str(key))
 for key in sources.keys():
  if bool(sources[key].get('generated',false)):sources.erase(key)
  else:
   sources[key].requested_playing=false;sources[key].audible_playing=false;sources[key].code_volume=1.0
 _record('host_reset_cleanup',{'scope':'Host-owned candidate audio and generated resources only; not source FSM parity.'})

func release():
 # Explicit host disposal, not a synthetic source FSM stop.
 fades.clear()
 for key in players.keys():_dispose_player(str(key))
 players.clear();sources.clear();streams.clear()

func get_audit()->Dictionary:
 return {'verified_streams':streams.keys(),'active_fades':fades.duplicate(true),'sources':sources.duplicate(true),'epoch':epoch,'generation':generation,'scaled_time':scaled_time,'realtime':realtime,'output_enabled':output_enabled,'output_bus':output_bus,'pending_disposals':pending_disposals(),'installed_in_game':false,'auditory_verified':false,'limitations':['Five clips missing original bytes; no substitute played.','Player output is a 2D audition: Unity spatial attenuation/category ducking is not reproduced.','Observe all source actions; advance audio before presenter each frame.','Host release is explicit lifecycle disposal; await drain_disposals before freeing the sink or exiting.']}
