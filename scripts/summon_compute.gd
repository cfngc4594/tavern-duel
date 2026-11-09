extends RefCounted
## Opt-in experiment. CPU keeps RNG/emission, fractional steps and all rendering.
## A failed/unsupported batch never changes source particle checkpoints.
static var enabled:=false
static var _instance:RefCounted
static var _stats:Dictionary={}
const STEP=1.0/120.0
const EPSILON=0.00000001
const STRIDE=80
var rd:RenderingDevice
var shader:RID
var pipeline:RID
var buffer:RID
var uniforms:RID
var capacity:=0
var attempted:=false
var reason:="not initialized"
static func add_stat(key:String,value:int=1)->void:_stats[key]=int(_stats.get(key,0))+value
static func get_stats()->Dictionary:
 var result=_stats.duplicate(true)
 result.enabled=enabled
 result.timing_domain="CPU timers are microseconds; GPU dispatch timestamps are nanoseconds, exclude upload/readback"
 result.reason=_instance.reason if _instance!=null else "not initialized"
 return result
static func reset_stats()->void:_stats.clear()
static func shutdown()->void:
 if _instance!=null:_instance.dispose();_instance=null
static func apply(particles:Array,raw:Dictionary,now:float,stop_time:float)->bool:
 add_stat("calls")
 var start=Time.get_ticks_usec()
 if not enabled:add_stat("disabled");return false
 # The owner additionally requires the unchanged base-only constant signature.
 if bool(raw.get("VelocityModule",{}).get("enabled",false)):
  add_stat("ineligible_velocity");return false
 add_stat("eligible_calls")
 if _instance==null:_instance=load("res://scripts/summon_compute.gd").new()
 var ok:bool=_instance.run_batch(particles,raw,now,stop_time)
 add_stat("end_to_end_usec",Time.get_ticks_usec()-start)
 if not ok:add_stat("fallback_calls")
 return ok
func initialize()->bool:
 if attempted:return rd!=null and pipeline.is_valid()
 attempted=true
 if RenderingServer.get_current_rendering_method()!="gl_compatibility":
  rd=RenderingServer.create_local_rendering_device()
 if rd==null:reason="RenderingDevice unavailable";return false
 var source=RDShaderSource.new()
 source.source_compute=FileAccess.get_file_as_string("res://shaders/summon_compute.glsl").replace("#[compute]","")
 var spirv=rd.shader_compile_spirv_from_source(source)
 var error=spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
 if not error.is_empty():reason="FP64 shader compilation: "+error;return false
 shader=rd.shader_create_from_spirv(spirv)
 if not shader.is_valid():reason="FP64 shader creation failed";return false
 pipeline=rd.compute_pipeline_create(shader)
 if not pipeline.is_valid():reason="FP64 compute pipeline unavailable";return false
 reason="FP64 pipeline ready; parity must be verified on this device"
 return true
func ensure_capacity(count:int)->bool:
 if count<=capacity and buffer.is_valid() and uniforms.is_valid():return true
 if uniforms.is_valid():rd.free_rid(uniforms);uniforms=RID()
 if buffer.is_valid():rd.free_rid(buffer);buffer=RID()
 capacity=maxi(64,capacity)
 while capacity<count:capacity*=2
 buffer=rd.storage_buffer_create(capacity*STRIDE)
 if not buffer.is_valid():reason="storage buffer allocation failed";capacity=0;return false
 var uniform=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;uniform.binding=0;uniform.add_id(buffer)
 uniforms=rd.uniform_set_create([uniform],shader,0)
 if not uniforms.is_valid():reason="uniform set allocation failed";capacity=0;return false
 return true
func run_batch(particles:Array,raw:Dictionary,now:float,stop_time:float)->bool:
 if attempted and (rd==null or not pipeline.is_valid()):return false
 var start=Time.get_ticks_usec()
 var indices:Array[int]=[]
 var data=PackedByteArray();data.resize(particles.size()*STRIDE)
 var limit:Dictionary=raw.get("ClampVelocityModule",{})
 var rotation:Dictionary=raw.get("RotationModule",{})
 var limited=bool(limit.get("enabled",false));var rotates=bool(rotation.get("enabled",false))
 var curves=preload("res://scripts/native_summon_curves.gd")
 var amount=1.0-pow(1.0-clampf(float(limit.get("dampen",0.0)),0.0,1.0),STEP/STEP)
 for i in particles.size():
  var p:Dictionary=particles[i]
  var until=now-float(p.birth)
  if until<0.0 or until>=float(p.life) or float(p.birth)>stop_time:continue
  # Rewind follows original CPU reset (including original initial velocity).
  var age:float=p.sim_age;var position:Vector3=p.displacement;var velocity:Vector3=p.sim_velocity;var angle:float=p.sim_rotation
  if until+EPSILON<age:age=0.0;position=Vector3.ZERO;velocity=p.velocity+Vector3.ZERO;angle=p.rotation
  if age+STEP>until+EPSILON:continue
  if not is_finite(age) or not is_finite(until) or not is_finite(angle) or not position.is_finite() or not velocity.is_finite():
   reason="non-finite state remains on CPU";return false
  # Bound shader work; an extraordinary long seek retains the CPU reference.
  if until-age>10.0:reason="large seek remains on CPU";return false
  if age+STEP<=age:reason="integration clock cannot advance; remains on CPU";return false
  var offset=indices.size()*STRIDE
  var cap=maxf(0.0,curves.minmax(limit.get("magnitude",{}),0.0,p.limit_mix)) if limited else -1.0
  var rotation_step=curves.minmax(rotation.get("curve",{}),0.0,p.rotation_mix)*STEP if rotates else 0.0
  data.encode_double(offset,age);data.encode_double(offset+8,until);data.encode_double(offset+16,angle);data.encode_double(offset+24,rotation_step)
  data.encode_double(offset+32,cap);data.encode_double(offset+40,amount)
  for axis in 3:data.encode_float(offset+48+axis*4,position[axis]);data.encode_float(offset+64+axis*4,velocity[axis])
  data.encode_float(offset+60,1.0 if rotates else 0.0)
  indices.append(i)
 data.resize(indices.size()*STRIDE)
 add_stat("pack_usec",Time.get_ticks_usec()-start)
 if indices.is_empty():add_stat("empty_batches");return false
 var init_start=Time.get_ticks_usec()
 var first_attempt=not attempted
 var ready=initialize()
 if first_attempt:add_stat("initialize_usec",Time.get_ticks_usec()-init_start)
 if not ready:return false
 start=Time.get_ticks_usec()
 if not ensure_capacity(indices.size()):return false
 if rd.buffer_update(buffer,0,data.size(),data)!=OK:reason="buffer upload failed";return false
 add_stat("upload_usec",Time.get_ticks_usec()-start)
 start=Time.get_ticks_usec()
 var push=PackedByteArray();push.resize(16);push.encode_u32(0,indices.size())
 rd.capture_timestamp("summon_begin")
 var list=rd.compute_list_begin()
 rd.compute_list_bind_compute_pipeline(list,pipeline);rd.compute_list_bind_uniform_set(list,uniforms,0);rd.compute_list_set_push_constant(list,push,16)
 rd.compute_list_dispatch(list,(indices.size()+63)/64,1,1);rd.compute_list_end()
 rd.capture_timestamp("summon_end")
 rd.submit();rd.sync()
 add_stat("dispatch_submit_sync_usec",Time.get_ticks_usec()-start)
 var gpu_begin:int=-1;var gpu_end:int=-1
 for query in rd.get_captured_timestamps_count():
  var label=rd.get_captured_timestamp_name(query)
  if label=="summon_begin":gpu_begin=rd.get_captured_timestamp_gpu_time(query)
  elif label=="summon_end":gpu_end=rd.get_captured_timestamp_gpu_time(query)
 if gpu_begin>=0 and gpu_end>=gpu_begin:
  add_stat("gpu_dispatch_nanoseconds",gpu_end-gpu_begin);add_stat("gpu_timestamp_samples")
 else:add_stat("gpu_timestamp_missing")
 start=Time.get_ticks_usec()
 var output=rd.buffer_get_data(buffer,0,data.size())
 add_stat("readback_usec",Time.get_ticks_usec()-start)
 if output.size()!=data.size():reason="incomplete readback";return false
 start=Time.get_ticks_usec()
 var checkpoints:Array=[]
 # Validate the entire batch before changing even one source particle.
 for slot in indices.size():
  var offset=slot*STRIDE
  var age=output.decode_double(offset);var angle=output.decode_double(offset+16)
  var position=Vector3(output.decode_float(offset+48),output.decode_float(offset+52),output.decode_float(offset+56))
  var velocity=Vector3(output.decode_float(offset+64),output.decode_float(offset+68),output.decode_float(offset+72))
  var until=data.decode_double(offset+8)
  if not is_finite(age) or not is_finite(angle) or not position.is_finite() or not velocity.is_finite() or age>until+EPSILON or age+STEP<=until+EPSILON:
   reason="invalid GPU checkpoint; full batch discarded";return false
  checkpoints.append([age,position,velocity,angle])
 for slot in indices.size():
  var p:Dictionary=particles[indices[slot]];var c:Array=checkpoints[slot]
  p.sim_age=c[0];p.displacement=c[1];p.sim_velocity=c[2];p.sim_rotation=c[3]
 add_stat("unpack_usec",Time.get_ticks_usec()-start);add_stat("dispatches");add_stat("particles",indices.size())
 return true
func dispose()->void:
 if rd!=null:
  for rid in [uniforms,buffer,pipeline,shader]:
   if rid.is_valid():rd.free_rid(rid)
  rd.free();rd=null
 uniforms=RID();buffer=RID();pipeline=RID();shader=RID();capacity=0
func _notification(what:int)->void:
 if what==NOTIFICATION_PREDELETE and rd!=null:
  for rid in [uniforms,buffer,pipeline,shader]:
   if rid.is_valid():rd.free_rid(rid)
  rd.free();rd=null
