extends RefCounted
## Experimental real-source resident simulation. No runtime CPU state readback.
static var enabled:=false
static var stats:Dictionary={}
static var profile_gpu:=false
static var gpu_stats:Dictionary={}
static var gpu_lock:=Mutex.new()
var profile_frame:=-1
const KEY="cab-69c88b234dfa427e02d1fcee9337ae34:6590410617251757833"
const CAPACITY=512
var owner_node:Node3D
var ready:=false
var failed:=false
var closing:=false
var uploaded:=0
var bound_velocities:Array[Vector3]=[]
var texture:=Texture2DRD.new()
var fixed_mesh:ArrayMesh
var draw_material:ShaderMaterial
var rd:RenderingDevice
var shader:RID
var pipeline:RID
var state_buffer:RID
var render_buffer:RID
var global_buffer:RID
var image_rid:RID
var uniform:RID
static func eligible(o)->bool:
 return enabled and o.source_key==KEY and o._constant_step_valid and RenderingServer.get_current_rendering_method()=="forward_plus" and o.material is ShaderMaterial and not bool(o.raw.RotationModule.enabled) and float(o.raw.ClampVelocityModule.dampen)==1.0 and not bool(o.raw.UVModule.enabled) and float(o.raw.VelocityModule.speedModifier.scalar)==1.0 and int(o.raw.VelocityModule.speedModifier.minMaxState)==0 and bool(o.raw.SizeModule.enabled) and bool(o.raw.ColorModule.enabled) and int(o.raw.moveWithTransform)==0 and int(o.source_renderer.m_RenderMode)==0 and float(o.raw.UVModule.flipU)==0.0 and float(o.raw.UVModule.flipV)==0.0 and o.size_snapshot_enabled and o.color_snapshot_enabled and o.material.shader.resource_path=="res://shaders/native_summon_scroll.gdshader"
static func add_stat(key:String,n:int=1)->void:stats[key]=int(stats.get(key,0))+n
static func get_gpu_stats()->Dictionary:
 gpu_lock.lock();var result=gpu_stats.duplicate();gpu_lock.unlock();return result
func setup(o)->void:
 owner_node=o
 var original:ShaderMaterial=o.material
 var saved:Dictionary={}
 for parameter in original.shader.get_shader_uniform_list():
  var value=original.get_shader_parameter(parameter.name)
  # Avoid ShaderMaterial reflection resetting Color supplied to unhinted vec4.
  if int(parameter.type)==TYPE_VECTOR4 and value is Color:
   var linear=value.srgb_to_linear();value=Vector4(linear.r,linear.g,linear.b,linear.a)
  saved[parameter.name]=value
 draw_material=ShaderMaterial.new();draw_material.render_priority=original.render_priority
 var code=original.shader.code
 if not code.contains("void vertex() {"):failed=true;return
 code=code.replace("void vertex() {", "uniform sampler2D resident_data : filter_nearest, repeat_disable;\nvoid vertex() {\n int slot=int(UV2.x+0.5);\n vec4 p=texelFetch(resident_data,ivec2(0,slot),0);\n vec3 x=texelFetch(resident_data,ivec2(1,slot),0).xyz;\n vec3 y=texelFetch(resident_data,ivec2(2,slot),0).xyz;\n VERTEX=p.xyz+((UV.x*2.0-1.0)*x+(1.0-UV.y*2.0)*y);\n NORMAL=texelFetch(resident_data,ivec2(3,slot),0).xyz;\n COLOR=texelFetch(resident_data,ivec2(4,slot),0);\n")
 var variant=Shader.new();variant.code=code;draw_material.shader=variant
 for key in saved:draw_material.set_shader_parameter(key,saved[key])
 draw_material.set_shader_parameter("resident_data",texture)
 fixed_mesh=ArrayMesh.new()
 var a:Array=[];a.resize(Mesh.ARRAY_MAX)
 var vertices=PackedVector3Array();var uv=PackedVector2Array();var uv2=PackedVector2Array();var colors=PackedColorArray();var normals=PackedVector3Array();var indices=PackedInt32Array()
 for slot in CAPACITY:
  for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
   vertices.append(Vector3.ZERO);uv.append(corner);uv2.append(Vector2(slot,0));colors.append(Color.WHITE);normals.append(Vector3.BACK)
  var start=slot*4;indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
 a[Mesh.ARRAY_VERTEX]=vertices;a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_TEX_UV2]=uv2;a[Mesh.ARRAY_COLOR]=colors;a[Mesh.ARRAY_NORMAL]=normals;a[Mesh.ARRAY_INDEX]=indices
 fixed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 fixed_mesh.custom_aabb=AABB(Vector3(-100,-100,-100),Vector3(200,200,200))
 RenderingServer.call_on_render_thread(_initialize)
func _initialize()->void:
 if closing:return
 rd=RenderingServer.get_rendering_device()
 if rd==null:failed=true;return
 var file:RDShaderFile=load("res://shaders/summon_resident.glsl")
 if file==null:failed=true;return
 var spirv=file.get_spirv()
 if not spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE).is_empty():failed=true;return
 shader=rd.shader_create_from_spirv(spirv)
 if not shader.is_valid():failed=true;return
 pipeline=rd.compute_pipeline_create(shader)
 state_buffer=rd.storage_buffer_create(CAPACITY*96)
 render_buffer=rd.storage_buffer_create(CAPACITY*80)
 global_buffer=rd.storage_buffer_create(80)
 if not state_buffer.is_valid() or not render_buffer.is_valid() or not global_buffer.is_valid():failed=true;return
 var f=RDTextureFormat.new();f.format=RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT;f.width=5;f.height=CAPACITY
 f.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
 image_rid=rd.texture_create(f,RDTextureView.new(),[])
 if not pipeline.is_valid() or not image_rid.is_valid():failed=true;return
 rd.texture_clear(image_rid,Color(0,0,0,0),0,1,0,1)
 var us:Array[RDUniform]=[]
 for binding in 4:
  var u=RDUniform.new();u.binding=binding
  u.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE if binding==2 else RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
  u.add_id([state_buffer,render_buffer,image_rid,global_buffer][binding]);us.append(u)
 uniform=rd.uniform_set_create(us,shader,0)
 if not uniform.is_valid():failed=true;return
 texture.texture_rd_rid=image_rid
 ready=true
func encode_vec(data:PackedByteArray,offset:int,v:Vector3,w:float=0)->void:
 data.encode_float(offset,v.x);data.encode_float(offset+4,v.y);data.encode_float(offset+8,v.z);data.encode_float(offset+12,w)
func update(now:float,frame:Transform3D,local_scale:Vector3)->bool:
 if not ready or failed or closing:return false
 var o=owner_node
 if o.particles.size()>CAPACITY:failed=true;return false
 var started=Time.get_ticks_usec()
 var spawn=PackedByteArray();spawn.resize((o.particles.size()-uploaded)*96)
 var curves=preload("res://scripts/native_summon_curves.gd")
 for i in range(uploaded,o.particles.size()):
  var p:Dictionary=o.particles[i];var at=(i-uploaded)*96
  if p.life>10.0 or not is_finite(p.life):failed=true;return false
  spawn.encode_double(at,p.sim_age);spawn.encode_double(at+8,p.birth);spawn.encode_double(at+16,p.life)
  var cap:float=curves.minmax(o.raw.ClampVelocityModule.magnitude,0,p.limit_mix)
  spawn.encode_double(at+24,cap)
  var bound_v:Vector3=p.velocity+o._velocity_over_life(p,0.0)
  var speed=bound_v.length()
  if speed>cap:bound_v*=lerpf(speed,cap,1.0)/speed
  bound_velocities.append(bound_v)
  encode_vec(spawn,at+32,p.displacement);encode_vec(spawn,at+48,p.sim_velocity)
  encode_vec(spawn,at+64,p.velocity+o._velocity_over_life(p,0.0));encode_vec(spawn,at+80,p.shape_point)
 var display=PackedByteArray();display.resize(o.particles.size()*80)
 var camera:Camera3D=o.get_viewport().get_camera_3d() if o.is_inside_tree() else null
 var view_right:Vector3=camera.global_basis.x.normalized() if camera!=null else o.compatibility_basis.x.normalized()
 var view_up:Vector3=camera.global_basis.y.normalized() if camera!=null else o.compatibility_basis.y.normalized()
 var normal=view_right.cross(view_up).normalized()
 var motion:Basis=o._motion_basis(frame,local_scale)
 var sx=motion.x.length();var sy=motion.y.length()
 var cs=o._frame_color_sampler();var ss=o._frame_size_sampler()
 o.live_count=0
 var bounds_min=Vector3(INF,INF,INF);var bounds_max=Vector3(-INF,-INF,-INF)
 for i in o.particles.size():
  var p:Dictionary=o.particles[i];var age:float=now-float(p.birth);var at=i*80
  if age<0 or age>=float(p.life) or float(p.birth)>o.stop_time:continue
  o.live_count+=1
  var normalized=age/float(p.life)
  var size:float=p.size*ss.sample(normalized,p.size_mix)
  var color:Color=p.color*cs.sample(normalized,p.color_mix)
  # Original ArrayMesh stores COLOR as RGBA8 UNORM (truncate, then normalize).
  for channel in 4:color[channel]=float(int(clampf(color[channel],0.0,1.0)*255.0))/255.0
  var right=view_right.rotated(normal,p.rotation);var up=view_up.rotated(normal,p.rotation)
  var base:Vector3=frame*p.shape_point
  var extent=(right*size*sx*0.5).abs()+(up*size*sy*0.5).abs()
  var bound_center:Vector3=base+motion*(bound_velocities[i]*age)
  bounds_min=bounds_min.min(bound_center-extent);bounds_max=bounds_max.max(bound_center+extent)
  encode_vec(display,at,base,1)
  encode_vec(display,at+16,right*size*sx*0.5);encode_vec(display,at+32,up*size*sy*0.5)
  encode_vec(display,at+48,normal);encode_vec(display,at+64,Vector3(color.r,color.g,color.b),color.a)
 var global=PackedByteArray();global.resize(80);global.encode_double(0,now)
 encode_vec(global,16,motion.x);encode_vec(global,32,motion.y);encode_vec(global,48,motion.z);global.encode_u32(64,o.particles.size())
 var offset=uploaded*96;uploaded=o.particles.size()
 if o.live_count>0:fixed_mesh.custom_aabb=AABB(bounds_min,bounds_max-bounds_min).grow(0.001)
 o.mesh_instance.mesh=fixed_mesh;o.mesh_instance.material_override=draw_material
 o.mesh_instance.visible=bool(o.source_renderer.get("m_Enabled",true)) and o.source_node.is_visible_in_tree()
 var can_emit=bool(o.raw.get("EmissionModule",{}).get("enabled",false)) and not o.period_events.is_empty() and now<o.stop_time and (bool(o.raw.get("looping",false)) or now<=o.start_delay+o.duration)
 o.active=o.live_count>0 or can_emit
 RenderingServer.call_on_render_thread(_dispatch.bind(spawn,offset,display,global,o.particles.size()))
 add_stat("frames");add_stat("live_particle_frames",o.live_count);add_stat("pack_usec",Time.get_ticks_usec()-started);add_stat("spawn_upload_bytes",spawn.size());add_stat("display_upload_bytes",display.size())
 return true
func _dispatch(spawn:PackedByteArray,offset:int,display:PackedByteArray,global:PackedByteArray,count:int)->void:
 if closing or failed or not ready:return
 if not spawn.is_empty() and rd.buffer_update(state_buffer,offset,spawn.size(),spawn)!=OK:_dispatch_failed();return
 if not display.is_empty() and rd.buffer_update(render_buffer,0,display.size(),display)!=OK:_dispatch_failed();return
 if rd.buffer_update(global_buffer,0,80,global)!=OK:_dispatch_failed();return
 if count==0:return
 if profile_gpu:
  var frame_id=rd.get_captured_timestamps_frame()
  if frame_id!=profile_frame:
   profile_frame=frame_id
   var begin:int=-1;var end:int=-1
   for q in rd.get_captured_timestamps_count():
    var label=rd.get_captured_timestamp_name(q)
    if label=="resident_begin_"+str(get_instance_id()):begin=rd.get_captured_timestamp_gpu_time(q)
    if label=="resident_end_"+str(get_instance_id()):end=rd.get_captured_timestamp_gpu_time(q)
   if begin>=0 and end>=begin:
    gpu_lock.lock();gpu_stats.nanoseconds=int(gpu_stats.get("nanoseconds",0))+end-begin;gpu_stats.samples=int(gpu_stats.get("samples",0))+1;gpu_lock.unlock()
  rd.capture_timestamp("resident_begin_"+str(get_instance_id()))
 var list=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,pipeline);rd.compute_list_bind_uniform_set(list,uniform,0);rd.compute_list_dispatch(list,(count+63)/64,1,1);rd.compute_list_end()
 if profile_gpu:rd.capture_timestamp("resident_end_"+str(get_instance_id()))
func _dispatch_failed()->void:
 failed=true
 if image_rid.is_valid():rd.texture_clear(image_rid,Color(0,0,0,0),0,1,0,1)
func close()->void:
 if closing:return
 closing=true;texture.texture_rd_rid=RID()
 RenderingServer.call_on_render_thread(_release)
func _release()->void:
 texture.texture_rd_rid=RID()
 if rd==null:return
 for id in [uniform,pipeline,shader,state_buffer,render_buffer,global_buffer,image_rid]:
  if id.is_valid():rd.free_rid(id)
 uniform=RID();pipeline=RID();shader=RID();state_buffer=RID();render_buffer=RID();global_buffer=RID();image_rid=RID()
 ready=false
# Validation only: synchronous readback is deliberately excluded from runtime path.
func inspect(callback:Callable)->void:
 RenderingServer.call_on_render_thread(_inspect.bind(callback))
func _inspect(callback:Callable)->void:
 if not ready or failed:callback.call_deferred({});return
 var state=rd.buffer_get_data(state_buffer,0,uploaded*96)
 var pixels=rd.texture_get_data(image_rid,0)
 callback.call_deferred({"state":state,"pixels":pixels})
