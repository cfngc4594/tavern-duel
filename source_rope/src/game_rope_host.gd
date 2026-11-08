extends Node
## Isolated integration adapter for existing offline ClassicMatchFlow clock.
## The existing rule clock remains authoritative. This bridge never ends a turn.
const Session=preload('source_rope_session_candidate.gd')
const SOURCE_REFLECTION=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
var game
var session
var blockers:Array=[]
var seen_turn:=-1
var seen_side:=-1
var end_timestamp:=0.0
var timeout_sent:=false
var gameover_sent:=false
var setup_msec:=0
var packets:=0
signal release_finished
var releasing:=false
var release_complete:=false
func setup(host):game=host
func enabled()->bool:return bool(ProjectSettings.get_setting('native_rope/enabled',false))
func _ensure_session()->bool:
 if releasing or not enabled():return false
 if is_instance_valid(session):return true
 if not is_instance_valid(game.spatial_scene) or game.source_projection==null or not game.source_projection.is_enabled():
  if blockers.is_empty():blockers.append('Source phone spatial world unavailable; no handmade fallback')
  return false
 var started=Time.get_ticks_msec()
 session=Session.new();session.name='SourceTurnTimer';session.basis=SOURCE_REFLECTION
 game.spatial_scene.add_child(session);session.setup(game.native_card_renderer,false)
 session.camera_shake_requested.connect(_on_camera_shake)
 if 'output_bus' in session.audio_sink:session.audio_sink.output_bus=&'SFX'
 setup_msec=Time.get_ticks_msec()-started;blockers.clear()
 return true
func _on_camera_shake(amount:Vector3,duration:float):
 game.camera_shake.request(amount,duration,'TurnTimer source MainCameraShakerAction')
func _sound_output():
 session.audio_sink.output_enabled=bool(ProjectSettings.get_setting('native_rope/audio_output_enabled',false)) and game.sound_enabled and SoundManager.sfx_enabled
func tick(scaled_delta:float,real_delta:float,turn_active:bool,remaining:float):
 if not _ensure_session():return
 _sound_output()
 # Advance the independent visual clocks first, then timestamp this frame's
 # authoritative local clock value. Never count the same wall delta twice.
 session.advance(maxf(scaled_delta,0),maxf(real_delta,0),{'game_over':game.game_over})
 if game.game_over:
  if not gameover_sent:session.bridge.game_over();gameover_sent=true
  return
 if not turn_active:return
 var side=0 if game.player_turn else 1
 if seen_turn!=game.flow.active_turn or seen_side!=side:
  seen_turn=game.flow.active_turn;seen_side=side;timeout_sent=false;gameover_sent=false
  session.bridge.begin_turn(maxf(remaining,0),game.flow.NORMAL_TURN_SECONDS,side==0,false)
  # The flow's timeout_pending/atomic settlement owns the rule outcome.
  session.bridge.active=false
  end_timestamp=session.bridge.presenter.realtime+maxf(remaining,0);packets+=1
 elif remaining>0:
  var corrected_end=session.bridge.presenter.realtime+remaining
  if absf(corrected_end-end_timestamp)>0.005:
   end_timestamp=corrected_end;session.bridge.receive_update(true,remaining,end_timestamp);packets+=1
 if remaining<=0 and not timeout_sent:
  timeout_sent=true;session.bridge.receive_update(true,0.0,end_timestamp);packets+=1
func end_turn_requested(timed_out:bool):
 if not releasing and is_instance_valid(session) and not timed_out:session.bridge.end_turn_requested()
func reset():
 if releasing:return
 seen_turn=-1;seen_side=-1;end_timestamp=0;timeout_sent=false;gameover_sent=false;packets=0
 if is_instance_valid(session):session.reset()
func release():
 # Non-blocking start; keep the session in its tree while AudioServer retires.
 if releasing:return
 releasing=true
 if is_instance_valid(session):
  if session.camera_shake_requested.is_connected(_on_camera_shake):session.camera_shake_requested.disconnect(_on_camera_shake)
  session.release()
 _finish_release()
func _finish_release():
 if is_instance_valid(session):
  await session.drain_disposals()
  session.queue_free();session=null
 release_complete=true
 release_finished.emit()
func shutdown():
 release()
 if not release_complete:await release_finished
func _exit_tree():
 # Emergency synchronous fallback only: a departing tree cannot await drain.
 # Formal exit must await shutdown() while this host and session are in-tree.
 releasing=true
 if is_instance_valid(session):
  if session.camera_shake_requested.is_connected(_on_camera_shake):session.camera_shake_requested.disconnect(_on_camera_shake)
  session.release()
func get_audit()->Dictionary:
 if not is_instance_valid(session):return {'enabled':enabled(),'ready':false,'blockers':blockers.duplicate(),'android_verified':false}
 var particles=0
 for record in session.view.emitter_records:particles+=record.solver.live_count
 return {'enabled':enabled(),'ready':true,'source_build':'37.0.0.255130.254477','fsm_state':session.bridge.presenter.fsm_state,'timer_state':session.bridge.controller.state,'active_spell':session.bridge.presenter.active_spell,'scaled_time':session.bridge.presenter.scaled_time,'realtime':session.bridge.presenter.realtime,'remaining':session.bridge.controller.remaining(),'denominator':session.bridge.controller.countdown_timeout_seconds,'setup_cpu_msec':setup_msec,'packets':packets,'emitters':session.view.emitter_records.size(),'live_particles':particles,'verified_audio':session.audio_sink.streams.keys(),'missing_audio':['unravels','burns','stinger','tick','final_tick'],'material_order_verified':false,'audio_output_enabled':session.audio_sink.output_enabled,'android_verified':false,'blockers':blockers.duplicate()}
