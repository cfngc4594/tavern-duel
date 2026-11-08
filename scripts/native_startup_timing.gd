extends RefCounted
## Opt-in CPU/observed-frame diagnostics. No render synchronization or gameplay clock writes.
## Enable project setting diagnostics/startup_timing or user argument --startup-timing.
var enabled:bool=false
var origin_us:int=0
var spans:Dictionary={}
var observed:Dictionary={}
var records:Array=[]
func configure():
 enabled=bool(ProjectSettings.get_setting("diagnostics/startup_timing",false)) or OS.get_cmdline_user_args().has("--startup-timing")
 origin_us=Time.get_ticks_usec()
 if enabled:mark("timing_enabled",{"display_server":DisplayServer.get_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method","")})
func mark(event:String,fields:Dictionary={}):
 if not enabled:return
 var now=Time.get_ticks_usec()
 var row={"event":event,"engine_ms":now/1000.0,"since_ready_ms":(now-origin_us)/1000.0,"frame":Engine.get_process_frames()}
 row.merge(fields,false)
 records.append(row)
 print("NATIVE_STARTUP_TIMING "+JSON.stringify(row))
func once(event:String,identity:String="",fields:Dictionary={}):
 if not enabled:return
 var key=event+":"+identity
 if observed.has(key):return
 observed[key]=true
 var data=fields.duplicate();if not identity.is_empty():data["key"]=identity
 mark(event,data)
func begin(stage:String,identity:String=""):
 if not enabled:return
 spans[stage+":"+identity]=Time.get_ticks_usec()
 mark(stage+"_begin",{"key":identity})
func end(stage:String,identity:String=""):
 if not enabled:return
 var key=stage+":"+identity
 var data={"key":identity}
 if spans.has(key):data["cpu_or_wall_ms"]=(Time.get_ticks_usec()-int(spans[key]))/1000.0;spans.erase(key)
 mark(stage+"_end",data)
var watched_game:WeakRef
var watched_tree:SceneTree
var last_phase:String=""
func watch_game(game:Node):
 if not enabled:return
 watched_game=weakref(game);watched_tree=game.get_tree()
 watched_tree.process_frame.connect(_observe_game)
func _observe_game():
 var game=watched_game.get_ref() if watched_game!=null else null
 if not is_instance_valid(game):
  stop_watching();return
 if game.flow==null:return
 var phase=str(game.flow.phase)
 if phase!=last_phase:
  mark("flow_phase_observed",{"phase":phase,"loading":game.native_initial_loading});last_phase=phase
 if not game.native_initial_loading:
  if phase=="deal" and not observed.has("deal_window_armed:"):
   once("deal_window_armed","",{"note":"Phase observation only; not the later coin construction CPU"})
   arm_frame_window("deal_phase_observed",game)
  once("input_loading_gate_open_observed","",{"phase":phase})
  if phase=="mulligan" or phase=="playing":
   mark("opening_input_phase_ready_observed",{"phase":phase,"help_visible":game.help_visible,"settings_visible":game.settings_visible,"note":"Read-only next process-frame observation, not an injected touch or displayed-frame guarantee"})
   if phase=="mulligan":arm_frame_window("mulligan_phase_observed",game)
   _stop_phase_observer()
func _stop_phase_observer():
 if is_instance_valid(watched_tree) and watched_tree.process_frame.is_connected(_observe_game):watched_tree.process_frame.disconnect(_observe_game)
 watched_game=null;watched_tree=null

## Short passive observation window. No draw requests, waits or GPU queries.
var window_tree:SceneTree
var window_game:WeakRef
var window_label:String=""
var window_arm_frame:int=-1
var window_pre_count:int=0
var window_post_count:int=0
func arm_frame_window(label:String,game:Node):
 if not enabled or not is_instance_valid(game) or not game.is_inside_tree():return
 if not window_label.is_empty():_close_frame_window("superseded")
 window_tree=game.get_tree();window_game=weakref(game);window_label=label
 window_arm_frame=Engine.get_process_frames();window_pre_count=0;window_post_count=0
 RenderingServer.frame_pre_draw.connect(_window_pre_draw)
 RenderingServer.frame_post_draw.connect(_window_post_draw)
 window_tree.process_frame.connect(_window_process_frame)
 _window_mark("frame_window_armed")
func _window_mark(event:String):
 var data={"window":window_label,"armed_frame":window_arm_frame,
  "process_seconds":Performance.get_monitor(Performance.TIME_PROCESS),
  "fps":Performance.get_monitor(Performance.TIME_FPS),
  "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
  "counter_note":"Published counters may lag; no GPU completion guarantee"}
 var game=window_game.get_ref() if window_game!=null else null
 if is_instance_valid(game):
  data["raw_process_delta"]=game.get_process_delta_time()
  data["capped_flow_delta"]=clampf(game.get_process_delta_time(),0.0,0.05)
  data["loading"]=game.native_initial_loading
  if game.flow!=null:data["phase"]=str(game.flow.phase);data["phase_time"]=game.flow.get("phase_time")
 mark(event,data)
func _window_pre_draw():
 if window_pre_count>=2:return
 window_pre_count+=1;_window_mark("frame_window_pre_draw")
func _window_post_draw():
 if window_post_count>=2:return
 window_post_count+=1;_window_mark("frame_window_post_draw")
func _window_process_frame():
 if Engine.get_process_frames()<=window_arm_frame:return
 _window_mark("frame_window_next_process")
 if Engine.get_process_frames()>=window_arm_frame+2:_close_frame_window("two_process_frames")
func _close_frame_window(reason:String):
 if window_label.is_empty():return
 mark("frame_window_closed",{"window":window_label,"reason":reason,"pre_samples":window_pre_count,"post_samples":window_post_count})
 if RenderingServer.frame_pre_draw.is_connected(_window_pre_draw):RenderingServer.frame_pre_draw.disconnect(_window_pre_draw)
 if RenderingServer.frame_post_draw.is_connected(_window_post_draw):RenderingServer.frame_post_draw.disconnect(_window_post_draw)
 if is_instance_valid(window_tree) and window_tree.process_frame.is_connected(_window_process_frame):window_tree.process_frame.disconnect(_window_process_frame)
 window_tree=null;window_game=null;window_label=""
func stop_watching():
 _stop_phase_observer()
 _close_frame_window("game_exit_or_stop")
