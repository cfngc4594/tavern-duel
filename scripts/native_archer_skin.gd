extends RefCounted
static var cache_inputs:bool=true
static var skip_unchanged:bool=true
static var profile_setup:bool=false
static var setup_rows:Array=[]
## Original weights/bind poses; explicit CPU linear blend skinning compatibility.
class CacheInvalidator extends RefCounted:
 var cache:Dictionary
 func invalidate():
  cache.dirty=true;cache.last_matrices=PackedByteArray()
var assets
var state:Dictionary
var skinned:Array=[]
func setup(a,s:Dictionary):
 var started:int=Time.get_ticks_usec() if profile_setup else 0
 assets=a;state=s;_make_skin()
 if profile_setup:_record_setup({"operation":"setup_total","root":str(state.get("source_key","")),"models":skinned.size(),"total_usec":Time.get_ticks_usec()-started})
func _matrix(d:Dictionary)->Transform3D:
 return Transform3D(Basis(Vector3(d.e00,d.e10,d.e20),Vector3(d.e01,d.e11,d.e21),Vector3(d.e02,d.e12,d.e22)),Vector3(d.e03,d.e13,d.e23))
func _make_skin():
 for key in state.nodes:
  var r:Dictionary=assets.component(key,'SkinnedMeshRenderer')
  if r.is_empty():continue
  var started:int=Time.get_ticks_usec() if profile_setup else 0
  var stage:int=started
  var times:Dictionary={}
  var mesh_key:String=r.refs['.m_Mesh']
  var json_text:String=FileAccess.get_file_as_string(assets.base_path+assets.objects[mesh_key].files.mesh)
  if profile_setup:times.read_usec=Time.get_ticks_usec()-stage;stage=Time.get_ticks_usec()
  var d:Dictionary=JSON.parse_string(json_text)
  if profile_setup:times.parse_usec=Time.get_ticks_usec()-stage;stage=Time.get_ticks_usec()
  var source_mesh:ArrayMesh=assets.geometry(mesh_key);var mesh:=ArrayMesh.new();var mi:=MeshInstance3D.new();mi.mesh=mesh;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mi.visible=bool(r.data.get('m_Enabled',true));state.nodes[key].add_child(mi)
  if profile_setup:times.mesh_node_usec=Time.get_ticks_usec()-stage;stage=Time.get_ticks_usec()
  var mats:Array=[]
  for i in range(source_mesh.get_surface_count()):mats.append(assets.material(r.refs['.m_Materials[%d]'%i]))
  state.renderers[key]=mi;state.materials[key]=mats
  if profile_setup:times.materials_usec=Time.get_ticks_usec()-stage;stage=Time.get_ticks_usec()
  var bones:Array=[];var binds:Array=[]
  for i in range(d.bind_pose.size()):
   var t:Dictionary=assets.objects[r.refs['.m_Bones[%d]'%i]]
   bones.append(state.nodes[t.refs['.m_GameObject']]);binds.append(_matrix(d.bind_pose[i]))
  skinned.append({'node':state.nodes[key],'instance':mi,'mesh':mesh,'source':source_mesh,'data':d,'bones':bones,'binds':binds,'materials':mats})
  if profile_setup:
   times.bones_usec=Time.get_ticks_usec()-stage
   times.operation="model_prepare";times.root=str(state.get("source_key",""));times.node=key;times.mesh_key=mesh_key
   times.vertices=d.vertices.size();times.bones=bones.size();times.total_usec=Time.get_ticks_usec()-started
   _record_setup(times)
 var first_started:int=Time.get_ticks_usec() if profile_setup else 0
 _skin()
 if profile_setup:_record_setup({"operation":"first_skin","root":str(state.get("source_key","")),"models":skinned.size(),"total_usec":Time.get_ticks_usec()-first_started})
func _skin_baseline():
 for s in skinned:
  var matrices:Array=[]
  for i in range(s.bones.size()):matrices.append(s.node.global_transform.affine_inverse()*s.bones[i].global_transform*s.binds[i])
  var verts:=PackedVector3Array();var norms:=PackedVector3Array()
  for i in range(s.data.vertices.size()):
   var v:Vector3=Vector3(s.data.vertices[i][0],s.data.vertices[i][1],s.data.vertices[i][2]);var n:Vector3=Vector3(s.data.normals[i][0],s.data.normals[i][1],s.data.normals[i][2]);var p:=Vector3.ZERO;var normal:=Vector3.ZERO
   for j in range(s.data.bone_weights[i].size()):
    var w:float=s.data.bone_weights[i][j]
    if w==0.0:continue
    var tr:Transform3D=matrices[int(s.data.bone_indices[i][j])];p+=(tr*v)*w;normal+=(tr.basis*n)*w
   verts.append(p);norms.append(normal.normalized())
  s.mesh.clear_surfaces()
  for i in range(s.source.get_surface_count()):
   var arrays:Array=s.source.surface_get_arrays(i);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_NORMAL]=norms;s.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);s.instance.set_surface_override_material(i,s.materials[i])

func _skin():
 if not cache_inputs and not skip_unchanged:
  # A baseline rebuild can replace geometry while an older cached pose remains.
  for s in skinned:
   if s.has("cache"):s.cache.last_matrices=PackedByteArray()
  _skin_baseline();return
 for s in skinned:
  if not s.has("cache"):
   var cache:Dictionary={"dirty":true,"last_matrices":PackedByteArray(),"vertices":[],"normals":[],"weights":[],"indices":[],"surfaces":[]}
   s.cache=cache
   var observer=CacheInvalidator.new();observer.cache=cache;s.cache_observer=observer
   var callback:Callable=observer.invalidate
   s.cache_callback=callback
   s.source.changed.connect(callback)
   s.cache_source=s.source
  elif s.cache_source!=s.source:
   if is_instance_valid(s.cache_source) and s.cache_source.changed.is_connected(s.cache_callback):
    s.cache_source.changed.disconnect(s.cache_callback)
   s.cache_source=s.source
   s.source.changed.connect(s.cache_callback)
   s.cache.dirty=true;s.cache.last_matrices=PackedByteArray()
  var cache:Dictionary=s.cache
  if cache.dirty:
   cache.vertices.clear();cache.normals.clear();cache.weights.clear();cache.indices.clear();cache.surfaces.clear()
   for i in range(s.data.vertices.size()):
    cache.vertices.append(Vector3(s.data.vertices[i][0],s.data.vertices[i][1],s.data.vertices[i][2]))
    cache.normals.append(Vector3(s.data.normals[i][0],s.data.normals[i][1],s.data.normals[i][2]))
    var weights:Array=[];var indices:Array=[]
    for j in range(s.data.bone_weights[i].size()):
     weights.append(float(s.data.bone_weights[i][j]));indices.append(int(s.data.bone_indices[i][j]))
    cache.weights.append(weights);cache.indices.append(indices)
   for surface in range(s.source.get_surface_count()):cache.surfaces.append(s.source.surface_get_arrays(surface))
   cache.dirty=false;cache.last_matrices=PackedByteArray()
  var inverse:Transform3D=s.node.global_transform.affine_inverse()
  var matrices:Array=[]
  for i in range(s.bones.size()):matrices.append(inverse*s.bones[i].global_transform*s.binds[i])
  var matrix_bytes:PackedByteArray=var_to_bytes(matrices) if skip_unchanged else PackedByteArray()
  if skip_unchanged and cache.last_matrices==matrix_bytes and s.mesh.get_surface_count()==cache.surfaces.size():
   # Visibility lives on the instance. Reapply material bindings even when
   # identical geometry is retained, so runtime material replacement is observed.
   for surface in range(s.mesh.get_surface_count()):s.instance.set_surface_override_material(surface,s.materials[surface])
   continue
  var verts:=PackedVector3Array();var norms:=PackedVector3Array()
  for i in range(s.data.vertices.size()):
   var v:Vector3=cache.vertices[i] if cache_inputs else Vector3(s.data.vertices[i][0],s.data.vertices[i][1],s.data.vertices[i][2])
   var n:Vector3=cache.normals[i] if cache_inputs else Vector3(s.data.normals[i][0],s.data.normals[i][1],s.data.normals[i][2])
   var p:=Vector3.ZERO;var normal:=Vector3.ZERO
   for j in range(s.data.bone_weights[i].size()):
    var w:float=cache.weights[i][j] if cache_inputs else s.data.bone_weights[i][j]
    if w==0.0:continue
    var index:int=cache.indices[i][j] if cache_inputs else int(s.data.bone_indices[i][j])
    var tr:Transform3D=matrices[index];p+=(tr*v)*w;normal+=(tr.basis*n)*w
   verts.append(p);norms.append(normal.normalized())
  s.mesh.clear_surfaces()
  for i in range(s.source.get_surface_count()):
   var arrays:Array=cache.surfaces[i].duplicate(false) if cache_inputs else s.source.surface_get_arrays(i)
   arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_NORMAL]=norms
   s.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   s.instance.set_surface_override_material(i,s.materials[i])
  cache.last_matrices=matrix_bytes

## Parsed skin data is immutable after setup unless the owner edits it and calls
## this method. No per-frame deep hashing of vertices/weights/bind data is done.
func invalidate_inputs():
 for s in skinned:
  if s.has("cache"):
   s.cache.dirty=true;s.cache.last_matrices=PackedByteArray()

func _notification(what:int):
 if what!=NOTIFICATION_PREDELETE:return
 for s in skinned:
  if s.has("cache_callback") and is_instance_valid(s.cache_source) and s.cache_source.changed.is_connected(s.cache_callback):
   s.cache_source.changed.disconnect(s.cache_callback)
func _record_setup(row:Dictionary):
 row.frame=Engine.get_process_frames()
 if setup_rows.size()>=512:setup_rows.pop_front()
 setup_rows.append(row)