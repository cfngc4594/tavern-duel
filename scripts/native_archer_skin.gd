extends RefCounted
## Original weights/bind poses; explicit CPU linear blend skinning compatibility.
var assets
var state:Dictionary
var skinned:Array=[]
func setup(a,s:Dictionary):
 assets=a;state=s;_make_skin()
func _matrix(d:Dictionary)->Transform3D:
 return Transform3D(Basis(Vector3(d.e00,d.e10,d.e20),Vector3(d.e01,d.e11,d.e21),Vector3(d.e02,d.e12,d.e22)),Vector3(d.e03,d.e13,d.e23))
func _make_skin():
 for key in state.nodes:
  var r:Dictionary=assets.component(key,'SkinnedMeshRenderer')
  if r.is_empty():continue
  var mesh_key:String=r.refs['.m_Mesh'];var d:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(assets.base_path+assets.objects[mesh_key].files.mesh))
  var source_mesh:ArrayMesh=assets.geometry(mesh_key);var mesh:=ArrayMesh.new();var mi:=MeshInstance3D.new();mi.mesh=mesh;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mi.visible=bool(r.data.get('m_Enabled',true));state.nodes[key].add_child(mi)
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
   for j in range(s.data.bone_weights[i].size()):
    var w:float=s.data.bone_weights[i][j]
    if w==0.0:continue
    var tr:Transform3D=matrices[int(s.data.bone_indices[i][j])];p+=(tr*v)*w;normal+=(tr.basis*n)*w
   verts.append(p);norms.append(normal.normalized())
  s.mesh.clear_surfaces()
  for i in range(s.source.get_surface_count()):
   var arrays:Array=s.source.surface_get_arrays(i);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_NORMAL]=norms;s.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);s.instance.set_surface_override_material(i,s.materials[i])
