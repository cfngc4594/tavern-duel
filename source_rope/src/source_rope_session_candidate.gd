extends Node3D
## Isolated composition root. Host supplies scaled and monotonic real deltas.
## Attach inside the existing source world exactly once; no extra reflection.
## No automatic production hooks, no old overlay removal, no APK inclusion.
const Bridge=preload('local_turn_timer_bridge.gd')
const View=preload('source_rope_view_candidate.gd')
const Audio=preload('../audio/source_rope_audio_candidate.gd')
signal timer_event(command:Dictionary)
signal camera_shake_requested(amount:Vector3,duration_scaled:float)
var bridge=Bridge.new()
var view
var audio_sink
var pending_shake:Dictionary={}
var initialized:=false
var released:=false
func setup(card_renderer:Node=null,enable_audio_output:bool=false):
 assert(is_inside_tree() and not initialized)
 view=View.new();add_child(view);view.setup(card_renderer)
 audio_sink=Audio.new();add_child(audio_sink);assert(audio_sink.setup('',enable_audio_output))
 bridge.presenter.source_action.connect(view.handle_source_action)
 bridge.presenter.source_action.connect(audio_sink.handle_source_action)
 bridge.presenter.source_action.connect(_observe_source_action)
 bridge.presenter.presentation_sample.connect(view.handle_sample)
 bridge.before_presentation_advance.connect(audio_sink.advance)
 bridge.before_presentation_advance.connect(_before_advance)
 bridge.controller.source_command.connect(_on_timer_event)
 bridge.setup();initialized=true
func _on_timer_event(command:Dictionary):timer_event.emit(command)
func _observe_source_action(action:Dictionary):
 if action.type=='host_reset':pending_shake.clear()
 if action.type=='MainCameraShakerAction':pending_shake=action.duplicate(true)
func _before_advance(_scaled:float,_realtime:float):
 if pending_shake.is_empty():return
 var action=pending_shake;pending_shake={}
 if int(action.epoch)!=bridge.presenter.epoch or int(action.generation)!=bridge.presenter.generation:return
 var p:Dictionary=action.params
 camera_shake_requested.emit(Vector3(p.m_Amount[0],p.m_Amount[1],p.m_Amount[2]),float(p.m_Time))
func advance(scaled_delta:float,real_delta:float,context_values:Dictionary={}):
 assert(initialized and not released);bridge.advance(scaled_delta,real_delta,context_values)
func reset():
 assert(initialized and not released);bridge.reset()
func release():
 if released or not initialized:return
 released=true;pending_shake.clear()
 bridge.presenter.source_action.disconnect(view.handle_source_action)
 bridge.presenter.source_action.disconnect(audio_sink.handle_source_action)
 bridge.presenter.source_action.disconnect(_observe_source_action)
 bridge.presenter.presentation_sample.disconnect(view.handle_sample)
 bridge.before_presentation_advance.disconnect(audio_sink.advance)
 bridge.before_presentation_advance.disconnect(_before_advance)
 bridge.controller.source_command.disconnect(_on_timer_event)
 bridge.disconnect_signals();view.hard_reset();audio_sink.release()
func _exit_tree():release()
func drain_disposals():
 # Explicit graceful-disposal barrier, based on AudioServer ownership rather
 # than sleeping an arbitrary number of frames. Call before queue_free/quit.
 if is_instance_valid(audio_sink):await audio_sink.drain_disposals()
func get_audit()->Dictionary:
 return {'bridge':bridge.get_audit(),'view':view.get_audit(),'audio':audio_sink.get_audit(),'camera_shake':'Source request emitted on first active update; host camera effect not installed','tick':'Source request available on bridge; audible tick not connected (source bytes absent)','installed_in_game':false,'android_verified':false}
