extends Node3D
## Original TurnTimer prefab/streamed clips/skinned mesh evaluator.
## This module is not self-installed. Host must attach it to the shared source
## world (same Unity->Godot reflection as board), call begin/update/cancel.
const BASE='res://assets/original_rope/'
const Assets=preload('res://scripts/native_rope_assets.gd')
const Particles=preload('res://scripts/native_combat_particles.gd')
var assets
var state:Dictionary={}
var clips:Dictionary={}
var skinned:Array=[]
var solvers:Array=[]
var age:=0.0
var stage:='hidden'
var countdown_duration:=0.0
var countdown_remaining:=0.0
var fuse_animation:=-1.5
var audit:Dictionary={}
func setup(card_renderer:Node=null):
 assets=Assets.new();assets.setup(card_renderer,BASE)
 clips=JSON.parse_string(FileAccess.get_file_as_string(BASE+'clips_decoded.json')).clips
 state=assets.instantiate(str(assets.manifest.root),self)
 _make_skin()
 state.root.visible=false
 audit={'source':'37.0.0.255130.254477 TurnTimer prefab','anchor':'BoardStandardGame/Bones/TurnTimerBone identity','positions':'Original Unity bone endpoints, shared source camera projection','skin':'Original weights/bind poses, CPU linear blend skinning compatibility evaluator','particles':'Original modules/textures with existing explicit Godot compatibility solver; Unity native RNG/rasterization not identical','integration':'Standalone module, host integration and device visual parity not yet verified'}
func _matrix(d:Dictionary)->Transform3D:
 return Transform3D(Basis(Vector3(d.e00,d.e10,d.e20),Vector3(d.e01,d.e11,d.e21),Vector3(d.e02,d.e12,d.e22)),Vector3(d.e03,d.e13,d.e23))
func _make_skin():
 for key in state.nodes:
  var r:Dictionary=assets.component(key,'SkinnedMeshRenderer')
  if r.is_empty():continue
  var mesh_key:String=r.refs['.m_Mesh'];var d:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+assets.objects[mesh_key].files.mesh))
  var source_mesh:ArrayMesh=assets.geometry(mesh_key);var mesh:=ArrayMesh.new();var mi:=MeshInstance3D.new();mi.mesh=mesh;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;state.nodes[key].add_child(mi)
  var mats:Array=[]
  for i in range(source_mesh.get_surface_count()):mats.append(assets.material(r.refs['.m_Materials[%d]'%i]))
  state.renderers[key]=mi;state.materials[key]=mats
  var bones:Array=[];var binds:Array=[]
  for i in range(d.bind_pose.size()):
   var t:Dictionary=assets.objects[r.refs['.m_Bones[%d]'%i]]
   bones.append(state.nodes[t.refs['.m_GameObject']]);binds.append(_matrix(d.bind_pose[i]))
  skinned.append({'node':state.nodes[key],'instance':mi,'mesh':mesh,'source':source_mesh,'data':d,'bones':bones,'binds':binds,'materials':mats})
 _skin()
func _skin():
 for s in skinned:
  var matrices:Array=[]
  for i in range(s.bones.size()):matrices.append(s.node.global_transform.affine_inverse()*s.bones[i].global_transform*s.binds[i])
  var verts:=PackedVector3Array();var norms:=PackedVector3Array()
  for i in range(s.data.vertices.size()):
   var v:Vector3=Vector3(s.data.vertices[i][0],s.data.vertices[i][1],s.data.vertices[i][2]);var n:Vector3=Vector3(s.data.normals[i][0],s.data.normals[i][1],s.data.normals[i][2]);var p:=Vector3.ZERO;var normal:=Vector3.ZERO
   for j in range(4):
    var w:float=s.data.bone_weights[i][j]
    if w==0.0:continue
    var tr:Transform3D=matrices[int(s.data.bone_indices[i][j])];p+=(tr*v)*w;normal+=(tr.basis*n)*w
   verts.append(p);norms.append(normal.normalized())
  s.mesh.clear_surfaces()
  for i in range(s.source.get_surface_count()):
   var arrays:Array=s.source.surface_get_arrays(i);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_NORMAL]=norms;s.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);s.instance.set_surface_override_material(i,s.materials[i])
func _scalar(keys:Array,t:float)->float:
 var key:Dictionary=keys[0]
 for candidate in keys:
  if float(candidate.time)>t:break
  key=candidate
 var dt:float=maxf(0,t-float(key.time));var c:Array=key.coefficients
 return ((float(c[0])*dt+float(c[1]))*dt+float(c[2]))*dt+float(c[3])
func _clip(name:String,t:float):
 var clip:Dictionary=clips[name];t=clampf(t,0,float(clip.duration))
 for binding in clip.bindings:
  var values:Array=[]
  for channel in binding.channels:values.append(_scalar(channel,t))
  var node:Node3D=state.paths.get(binding.path)
  match str(binding.kind):
   'position':node.position=Vector3(values[0],values[1],values[2])
   'rotation':node.quaternion=Quaternion(values[0],values[1],values[2],values[3]).normalized()
   'scale':node.scale=Vector3(values[0],values[1],values[2])
   'm_Enabled':
    for key in state.renderers:
     if state.nodes[key]==node:state.renderers[key].visible=values[0]>=0.5
   'material._Xamount':
    for key in state.materials:
     if state.nodes[key]==node:
      for mat in state.materials[key]:mat.set_shader_parameter('_Xamount',values[0])
   'm_FuseXamountAnimation':fuse_animation=values[0]
func _fuse(value:float):
 for key in state.materials:
  if assets.objects[key].name in ['joint1','TurnTimer_ShadowQuad']:
   for mat in state.materials[key]:mat.set_shader_parameter('_Xamount',value)
func begin(remaining:float):
 cancel();age=0.0;stage='birth';countdown_remaining=remaining;state.root.visible=false
 for key in state.renderers:state.renderers[key].visible=true
 state.paths['TurnTimer_Wick'].visible=true;state.paths['TurnTimer_Spiral'].visible=true;state.paths['TurnTimer_ShadowQuad'].visible=true
 sample_birth(0.0)
func sample_birth(seconds:float):
 _clip('TurnTimer_edit',seconds*2.0);_clip('TurnTimer_SpiralUnwrap',seconds);_clip('TurnTimer_Wick_mat',seconds*2.0);_fuse(fuse_animation);_skin()
func update_timer(delta:float,remaining:float):
 if stage=='hidden':return
 age+=maxf(delta,0);countdown_remaining=maxf(remaining,0)
 if stage=='birth':
  state.root.visible=age>=0.01
  sample_birth(maxf(age-0.01,0.0))
  # Source Birth enters State5 Wait(0.01 scaled), then State1 Wait(0.87 realtime).
  if age>=0.88:
   stage='countdown';countdown_duration=maxf(remaining,0.000001);_start_particles()
 if stage=='countdown':
  var progress:float=clampf(remaining/countdown_duration,0.0,1.0)
  state.paths['Sparks'].position=state.paths['Bones/SparksFinishBone'].position.lerp(state.paths['Bones/SparksStartBone'].position,progress)
  _fuse(lerpf(-1.5,0.41999998688697815,progress))
  # Original 1-second Birth coroutine writes animated material concurrently;
  # host scheduling parity of last-writer during 0.88..1s is not established.
  for solver in solvers:solver.seek(maxf(age-0.88,0.0))
  if remaining<=0.0:cancel()
func _start_particles():
 for key in state.particles:
  var spec:Dictionary=state.particles[key]
  if not spec.node.is_ancestor_of(state.paths['Sparks/FX_Sparks']) and not state.paths['Sparks/FX_Sparks'].is_ancestor_of(spec.node) and spec.node!=state.paths['Sparks/FX_Sparks']:continue
  var solver=Particles.new();spec=spec.duplicate();spec.autoplay=true;spec.source_scope_root=self;spec.compatibility_basis=global_basis;solver.setup(spec,assets,self,12345+solvers.size());solvers.append(solver)
func cancel():
 for solver in solvers:
  if is_instance_valid(solver):solver.source_destroy();solver.queue_free()
 solvers.clear();stage='hidden'
 if not state.is_empty():state.root.visible=false
func get_audit()->Dictionary:return audit.merged({'stage':stage,'age':age,'countdown_duration':countdown_duration,'source_objects':assets.objects.size() if assets!=null else 0,'particle_count':solvers.size()})
