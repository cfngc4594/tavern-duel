extends Node3D
## Original modules/textures; Godot compatibility simulation, NOT Unity runtime.
const Solver=preload('res://original_board/scripts/source_particle_solver.gd')
const REFLECTION=Basis(Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,-1))
var owner_probe
var data:Dictionary={}
var objects:Dictionary={}
var entries:Dictionary={}
var material_cache:Dictionary={}
var errors:Array=[]
var generation=0
var closed=false
var elapsed=0.0
var retired_emitted=0
var ambient_particle_density:=1.0
# -1 explicitly means the source GraphicsManager quality is not known.
var render_quality_level=-1
var render_quality_source="Unspecified source quality"
func setup(probe,options:Dictionary={}):
 owner_probe=probe
 var default_density:=float(ProjectSettings.get_setting("render_quality/board_ambient_particle_density",0.4)) if OS.has_feature("android") else 1.0
 ambient_particle_density=clampf(float(options.get("ambient_particle_density",default_density)),0.1,1.0)
 render_quality_level=clampi(int(options.get("render_quality_level",-1)),-1,2)
 render_quality_source=str(options.get("render_quality_source","Explicit caller quality" if render_quality_level>=0 else "Unspecified source quality"))
 data=JSON.parse_string(FileAccess.get_file_as_string(str(options.get('source_file','res://original_board/assets/water_particles/source.json'))))
 for row in data.emitters:
  var key=str(row.node_id)
  if not probe.source_nodes.has(key):errors.append('Missing source emitter '+key);continue
  var proxy=Node3D.new();proxy.name='SourceParticleFrame_'+str(row.name);add_child(proxy);proxy.top_level=true
  proxy.global_transform=probe.source_nodes[key].global_transform*Transform3D(REFLECTION,Vector3.ZERO)
  entries[key]={'row':row,'proxy':proxy,'playing':false,'current':null,'instances':[],'play_calls':0,'stop_calls':0,'source_active':true}
  # Environmental emitters respect both serialized ancestry and REA quality gates.
  if row.has('source_activation'):
   entries[key].source_active=_environment_active(row)
   proxy.visible=entries[key].source_active
  if bool(row.system.data.get('playOnAwake',false)) and bool(entries[key].source_active):set_playing(key,true)
 set_render_quality_level(render_quality_level)
func material(key:String):
 if material_cache.has(key):return material_cache[key]
 if not data.materials.has(key):errors.append('Missing source particle material '+key);return null
 var row=data.materials[key];var mat=ShaderMaterial.new();mat.shader=load(row.shader)
 var saved=row.source.data.m_SavedProperties
 for pair in saved.m_Floats:mat.set_shader_parameter(pair[0],float(pair[1]))
 for pair in saved.m_Colors:
  var c=pair[1];mat.set_shader_parameter(pair[0],Vector4(c.r,c.g,c.b,c.a))
 var image=_load_source_png(str(row.texture))
 if image==null or image.is_empty():
  errors.append('Missing original particle texture '+str(row.texture));return null
 mat.set_shader_parameter('_MainTex',ImageTexture.create_from_image(image))
 var st=saved.m_TexEnvs[0][1];mat.set_shader_parameter('_MainTex_ST',Vector4(st.m_Scale.x,st.m_Scale.y,st.m_Offset.x,1.0-st.m_Scale.y-st.m_Offset.y))
 var amb=owner_probe.config.lighting.ambient_target_raw_rgba
 mat.set_shader_parameter('_UnitySHW',Vector3(amb.r,amb.g,amb.b))
 # Register with the board's exact current world lighting when available.
 var factory=null
 for property in owner_probe.get_property_list():
  if property.name=='material_factory':factory=owner_probe.get('material_factory');break
 if factory!=null and factory.has_method('register_lighting_material'):factory.register_lighting_material(mat)
 material_cache[key]=mat;return mat
func geometry(_key:String):return null
func component(_go:String,_type:String):return {}
func set_playing(key:String,playing:bool):
 if closed:return
 if not entries.has(key):errors.append('Unknown ParticlePlay/Stop node '+key);return
 var e=entries[key]
 if playing and not bool(e.source_active):return
 if playing:e.play_calls+=1
 else:e.stop_calls+=1
 if bool(e.playing)==playing:return
 e.playing=playing
 if not playing:
  if is_instance_valid(e.current):e.current.stop_emitting()
  e.current=null
  return
 generation+=1
 var solver=Solver.new();solver.name='SourceParticleGeneration_'+str(generation)
 var spec={
  'system':e.row.system,'renderer':e.row.renderer,'node':e.proxy,'autoplay':true,
  'compatibility_basis':REFLECTION,'source_scope_root':owner_probe.source_root,
  'fixed_draw_curves':true,'fixed_simulation_modules':true
 }
 for option in e.row.get('solver_options',{}):spec[option]=e.row.solver_options[option]
 if e.row.get('source_category','')=='environment':spec.emission_density=ambient_particle_density
 solver.setup(spec,self,self,97003+generation)
 solver.compatibility_notes.append('Board adapter reflects raw Unity emitter basis once; native random stream and restart clock unavailable.')
 solver.compatibility_notes.append('Renderer sortingFudge retained in source metadata, not reproduced by Godot depth sort.')
 e.current=solver;e.instances.append({'solver':solver,'age':0.0})
func advance(dt:float):
 if closed:return
 var step:=maxf(0.0,dt)
 elapsed+=step
 for key in entries:
  var e=entries[key]
  if e.row.has('source_activation'):_refresh_environment_activation(key)
  var pose:Transform3D=owner_probe.source_nodes[key].global_transform*Transform3D(REFLECTION,Vector3.ZERO)
  if e.proxy.global_transform!=pose:e.proxy.global_transform=pose
  var instances:Array=e.instances
  var live_generations:=0
  for index in instances.size():
   var item:Dictionary=instances[index]
   item.age+=step;var solver=item.solver;solver.seek(item.age)
   # Monotonic playback only: discard expired storage, not living stop tails.
   _prune_expired(solver)
   # Non-loop source systems naturally return to stopped once their tails end.
   if solver==e.current and not bool(solver.raw.get('looping',false)) and item.age>=solver.start_delay+solver.duration and solver.live_count==0:
    e.current=null;e.playing=false
   if solver!=e.current and solver.live_count==0:
    retired_emitted+=solver.emitted_count;solver.source_destroy();solver.queue_free()
   else:
    if index!=live_generations:instances[live_generations]=item
    live_generations+=1
  if live_generations!=instances.size():instances.resize(live_generations)

func _prune_expired(solver):
 var particles:Array=solver.particles
 var now:float=solver.simulation_time
 # Retaining the same Array when no entries expire also retains the solver's
 # candidate-index cache. Replacing it after compaction invalidates shifted indices.
 for index in particles.size():
  var particle:Dictionary=particles[index]
  if now-float(particle.birth)<float(particle.life):continue
  var survivors:=particles.slice(0,index)
  for remaining_index in range(index+1,particles.size()):
   var remaining:Dictionary=particles[remaining_index]
   if now-float(remaining.birth)<float(remaining.life):survivors.append(remaining)
  solver.particles=survivors
  return
func get_audit():
 var rows:Array=[]
 for key in entries:
  var e=entries[key];var solvers:Array=[]
  for item in e.instances:solvers.append(item.solver.get_audit())
  rows.append({'node_id':key,'name':e.row.name,'playing':e.playing,'play_calls':e.play_calls,'stop_calls':e.stop_calls,'source_active':e.source_active,'quality_gated':bool(e.row.get('source_activation',{}).get('disable_low_quality',false)),'instances':solvers})
 return {'errors':errors.duplicate(),'elapsed':elapsed,'emitters':rows,'generations':generation,'retired_emitted':retired_emitted,'render_quality_level':render_quality_level,'render_quality_source':render_quality_source,'ambient_particle_density':ambient_particle_density,'quality_status':'unresolved; low-quality-gated dust is deferred' if render_quality_level<0 else ['Low','Medium','High'][render_quality_level],'boundaries':['Source ParticleSystem serialized modules and original textures; compatible fixed-step solver, not recovered Unity native solver.','Stop(false) is StopEmitting: alive particles survive to their source lifetime. Repeated Play while running does not restart.','Play after stop starts a new emission clock while previous live generation survives; native resume clock and RNG equivalence unverified.','Native billboard sort bias, soft-depth keyword variants, exact native light probes/color pipeline not reproduced.','No particle SubViewport, no invented sprite or water mesh. Original scene particles use one source emitter frame reflection.']}
func close_interaction():
 if closed:return
 closed=true
 for e in entries.values():
  for item in e.instances:item.solver.source_destroy();item.solver.queue_free()
  e.instances.clear();e.current=null;e.playing=false
  e.proxy.queue_free()
func close_particles():close_interaction()


func _environment_active(row:Dictionary)->bool:
 if bool(row.get('source_activation',{}).get('disable_low_quality',false)) and render_quality_level<=0:return false
 var node=owner_probe.source_nodes.get(str(row.node_id))
 return is_instance_valid(node) and node.is_visible_in_tree()
func _clear_entry(e:Dictionary):
 # SetActive(false) disables the source GO, not ParticleSystem.StopEmitting.
 # It clears that generation; an explicit Stop still preserves source-lifetime tails.
 for item in e.instances:
  retired_emitted+=item.solver.emitted_count;item.solver.source_destroy();item.solver.queue_free()
 e.instances.clear();e.current=null;e.playing=false
func _refresh_environment_activation(key:String):
 var e=entries[key];var source_active=_environment_active(e.row)
 e.proxy.visible=source_active
 if source_active==bool(e.source_active):return
 e.source_active=source_active
 if not source_active:_clear_entry(e)
 elif bool(e.row.system.data.get('playOnAwake',false)):set_playing(key,true)
func set_render_quality_level(level:int):
 if closed:return
 render_quality_level=clampi(level,-1,2)
 # REA GraphicsManager toggles the registered FX parent, not child emission flags.
 for e in entries.values():
  var gate=str(e.row.get('source_activation',{}).get('quality_gate_node_id',''))
  if render_quality_level>=0 and not gate.is_empty() and owner_probe.source_nodes.has(gate):
   owner_probe.source_nodes[gate].visible=render_quality_level!=0
 for key in entries:
  if entries[key].row.has('source_activation'):_refresh_environment_activation(key)

func supports_source(key:String)->bool:return entries.has(key)

static func _load_source_png(path:String)->Image:
 # Read original PNG bytes from res:// even when packed in an Android PCK.
 # No format conversion, resampling, mip generation or pixel mutation.
 if not FileAccess.file_exists(path):return null
 var image=Image.new()
 if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
 return image
