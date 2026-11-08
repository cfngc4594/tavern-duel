extends 'res://scripts/native_rope.gd'
## Standalone source mesh/animation/particle presentation consumer.
## This does not call the legacy begin/update_timer/cancel lifecycle.
const CandidateAssets=preload('native_rope_assets_candidate.gd')
var renderer_snapshots:Dictionary={}
var particle_visibility:Dictionary={}
var emitter_records:Array=[]
var emitting_by_source:Dictionary={}
var scaled_clock:=0.0
var view_epoch:=0
var particle_generation:=0
var compatibility_events:Array=[]
func setup(card_renderer:Node=null):
 assets=CandidateAssets.new();assets.setup(card_renderer,BASE)
 clips=JSON.parse_string(FileAccess.get_file_as_string(BASE+'clips_decoded.json')).clips
 state=assets.instantiate(str(assets.manifest.root),self)
 _make_skin()
 # Source visibility actions affect Renderer.enabled, not this transform.
 state.root.visible=true
 for key in state.particles:
  particle_visibility[key]=bool(state.particles[key].renderer.data.get('m_Enabled',true))
 audit={'source':'37.0.0.255130.254477 TurnTimer prefab','installed_in_game':false,'android_verified':false,'particle_solver':'Explicit existing Godot compatibility solver, not Unity native','restart_boundary':'Stopped source emitters use retained-tail/new-emitter generations; shared source RNG/capacity parity unverified','material_writer_order':'Chosen in presenter; original runtime order unverified'}
func _node(path:String)->Node3D:return state.root if path.is_empty() else state.paths.get(path)
func _matches(node:Node3D,target:Node3D,recursive:bool)->bool:
 return node==target or (recursive and target.is_ancestor_of(node))
func _capture_visibility(target:Node3D,recursive:bool)->Dictionary:
 var snapshot={'mesh':{},'particles':{}}
 for key in state.renderers:
  if _matches(state.nodes[key],target,recursive):snapshot.mesh[key]=state.renderers[key].visible
 for key in state.particles:
  if _matches(state.particles[key].node,target,recursive):snapshot.particles[key]=particle_visibility[key]
 return snapshot
func _set_visibility(target:Node3D,recursive:bool,value:bool):
 assert(target!=null)
 for key in state.renderers:
  if _matches(state.nodes[key],target,recursive):state.renderers[key].visible=value
 for key in state.particles:
  if _matches(state.particles[key].node,target,recursive):particle_visibility[key]=value
 _apply_particle_visibility()
func _apply_particle_visibility():
 for record in emitter_records:
  record.solver.source_renderer['m_Enabled']=bool(particle_visibility[record.key])
  if is_instance_valid(record.solver.mesh_instance):record.solver.mesh_instance.visible=bool(particle_visibility[record.key]) and record.solver.live_count>0
func _restore_visibility(token:String):
 if not renderer_snapshots.has(token):return
 var snapshot:Dictionary=renderer_snapshots[token]
 for key in snapshot.mesh:state.renderers[key].visible=bool(snapshot.mesh[key])
 for key in snapshot.particles:particle_visibility[key]=bool(snapshot.particles[key])
 renderer_snapshots.erase(token);_apply_particle_visibility()
func handle_source_action(action:Dictionary):
 scaled_clock=float(action.scaled_time)
 if action.type=='host_reset':
  view_epoch=int(action.epoch);hard_reset();return
 if int(action.epoch)!=view_epoch:return
 var p:Dictionary=action.params
 match str(action.type):
  'SetVisibility','SetVisibilityRecursiveAction':
   var target=_node(str(p.gameObject.path));var recursive=bool(p.get('includeChildren',false))
   if bool(p.get('resetOnExit',false)):renderer_snapshots[action.token]=_capture_visibility(target,recursive)
   _set_visibility(target,recursive,bool(p.visible))
  'restore_visibility':_restore_visibility(str(p.token))
  'AnimatorPlayAction','AnimatorPlaythroughAction':
   match str(p.m_StateName):
    'Unwrap':_clip('TurnTimer_SpiralUnwrap',0.0)
    'TurnTimer':_clip('TurnTimer_edit',0.0);_skin()
    'TurnTimer_Wick_mat':_clip('TurnTimer_Wick_mat',0.0)
  'ParticlePlayAction':_play_particles(_node(str(p.m_GameObject.path)),bool(p.m_IncludeChildren))
  'ParticleStopAction':_stop_particles(_node(str(p.m_GameObject.path)),bool(p.m_IncludeChildren))
func handle_sample(sample:Dictionary):
 if int(sample.epoch)!=view_epoch:return
 match str(sample.kind):
  'animation':_sample_animation(float(sample.seconds))
  'birth_material':_fuse(fuse_animation)
  'countdown':
   state.paths['Sparks'].position=state.paths['Bones/SparksFinishBone'].position.lerp(state.paths['Bones/SparksStartBone'].position,float(sample.progress))
   _fuse(float(sample.fuse))
  'particle_clock':
   scaled_clock=float(sample.scaled_time);_advance_particles()
func _sample_animation(seconds:float):
 # The three source Animators continue after FSM state exit. The material
 # property writer is separate; do not call base.sample_birth (which couples it).
 _clip('TurnTimer_edit',seconds*2.0);_clip('TurnTimer_SpiralUnwrap',seconds);_clip('TurnTimer_Wick_mat',seconds*2.0);_skin()
func _play_particles(target:Node3D,recursive:bool):
 assert(target!=null)
 for key in state.particles:
  var spec:Dictionary=state.particles[key]
  if not _matches(spec.node,target,recursive):continue
  if emitting_by_source.has(key):
   var current:Dictionary=emitting_by_source[key]
   if not current.stopped and (current.solver.active or current.solver.elapsed_seconds==0):continue
  var tail_count=emitter_records.filter(func(record):return record.key==key).size()
  if tail_count>0:compatibility_events.append({'kind':'restart_with_residual_tail','source':key,'scaled_time':scaled_clock,'source_identity_parity_verified':false})
  particle_generation+=1
  spec=spec.duplicate();spec.autoplay=true;spec.source_scope_root=self;spec.compatibility_basis=global_basis
  var solver=Particles.new();solver.setup(spec,assets,self,12345+particle_generation)
  solver.source_renderer=solver.source_renderer.duplicate(true)
  solver.source_renderer['m_Enabled']=bool(particle_visibility[key])
  var record={'key':key,'solver':solver,'started':scaled_clock,'stopped':false,'generation':particle_generation}
  emitter_records.append(record);emitting_by_source[key]=record;solver.seek(0.0)
func _stop_particles(target:Node3D,recursive:bool):
 assert(target!=null)
 for record in emitter_records:
  if _matches(state.particles[record.key].node,target,recursive):
   record.solver.stop_emitting(maxf(0,scaled_clock-float(record.started)));record.stopped=true
func _advance_particles():
 for i in range(emitter_records.size()-1,-1,-1):
  var record:Dictionary=emitter_records[i]
  record.solver.seek(maxf(0,scaled_clock-float(record.started)))
  if not record.solver.active and (record.stopped or not bool(record.solver.raw.get('looping',false))):
   if emitting_by_source.get(record.key,{}).get('generation',-1)==record.generation:emitting_by_source.erase(record.key)
   record.solver.source_destroy();record.solver.queue_free();emitter_records.remove_at(i)
func hard_reset():
 for record in emitter_records:record.solver.source_destroy();record.solver.queue_free()
 emitter_records.clear();emitting_by_source.clear();renderer_snapshots.clear();compatibility_events.clear()
 _set_visibility(state.root,true,false)
func particle_audit()->Array:
 var result=[]
 for record in emitter_records:
  result.append({'key':record.key,'stopped':record.stopped,'generation':record.generation,'renderer_enabled':particle_visibility[record.key],'audit':record.solver.get_audit()})
 return result
func get_audit()->Dictionary:
 return audit.merged({'particles':particle_audit(),'compatibility_events':compatibility_events.duplicate(true),'epoch':view_epoch,'scaled_clock':scaled_clock})
