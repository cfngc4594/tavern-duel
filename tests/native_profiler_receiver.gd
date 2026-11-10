extends SceneTree
## Godot's own remote-debug protocol, not a replacement script timer.
## Run headless before the target; use a loopback address only.
var server := TCPServer.new()
var stream: StreamPeerTCP
var packets := PacketPeerStream.new()
var output: FileAccess
var connected := false
var stopped := false
var saw_total := false
var counts: Dictionary = {}
var started_usec := 0
var last_packet_usec := 0
var visual_requested := true
var hard_errors := 0
var malformed_messages := 0

func _initialize() -> void:
 var port := 6019
 var path := "user://native-profiler.jsonl"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
  if arg.begins_with("--output="):path=arg.trim_prefix("--output=")
  if arg=="--cpu-only":visual_requested=false
 output=FileAccess.open(path,FileAccess.WRITE)
 assert(output!=null,"Cannot open profiler capture")
 assert(server.listen(port,"127.0.0.1")==OK,"Cannot bind local profiler port")
 packets.input_buffer_max_size=64*1024*1024
 packets.output_buffer_max_size=4*1024*1024
 started_usec=Time.get_ticks_usec()
 last_packet_usec=started_usec
 print("NATIVE_PROFILER_LISTENING ",port)

func _process(_delta: float) -> bool:
 if not connected and server.is_connection_available():
  stream=server.take_connection()
  packets.stream_peer=stream
  connected=true
  # Main thread ID 1. The options are max_functions and include_native_calls.
  packets.put_var(["profiler:servers",1,[true,[512,true]]])
  if visual_requested:packets.put_var(["profiler:visual",1,[true]])
  print("NATIVE_PROFILER_CONNECTED")
 if connected:
  stream.poll()
  while packets.get_available_packet_count()>0:
   var message=packets.get_var(false)
   assert(packets.get_packet_error()==OK,"Invalid debugger packet")
   output.store_line(JSON.stringify({"received_usec":Time.get_ticks_usec(),"message":message}))
   last_packet_usec=Time.get_ticks_usec()
   if message is Array and message.size()==3:
    var command:=str(message[0])
    counts[command]=int(counts.get(command,0))+1
    if command=="error":
     var payload=message[2]
     if not (payload is Array) or payload.size()<10 or not bool(payload[9]):hard_errors+=1
    if command=="benchmark:done" and not stopped:
     packets.put_var(["profiler:servers",1,[false]])
     if visual_requested:packets.put_var(["profiler:visual",1,[false]])
     stopped=true
    if command=="servers:profile_total":saw_total=true
   else:malformed_messages+=1
  if stream.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
   output.flush()
   var complete:bool=stopped and saw_total and counts.get("benchmark:done",0)==1 and counts.get("servers:profile_frame",0)>0 and (not visual_requested or counts.get("visual:profile_frame",0)>0) and hard_errors==0 and malformed_messages==0
   print("NATIVE_PROFILER_CAPTURE ",JSON.stringify({"counts":counts,"stopped":stopped,"saw_total":saw_total,"visual_requested":visual_requested,"hard_errors":hard_errors,"malformed_messages":malformed_messages,"complete":complete}))
   quit(0 if complete else 1)
 if Time.get_ticks_usec()-started_usec>300000000 or (connected and Time.get_ticks_usec()-last_packet_usec>60000000):
  push_error("Native profiler timeout")
  quit(1)
 return false
