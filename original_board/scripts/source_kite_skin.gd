extends Node
## Original mesh, weights, bind poses and 13 source bone transforms; no hand-authored sway.
var probe
var source:Dictionary
var skeleton:Skeleton3D
var renderer:MeshInstance3D
var mesh:ArrayMesh
var bind:Skin
var skin_root:Node3D
var closed=false
var errors=[]
var max_basis_decomposition_error=0.0
static func matrix(d)->Transform3D:
 var b=Basis(Vector3(d.e00,d.e10,-d.e20),Vector3(d.e01,d.e11,-d.e21),Vector3(-d.e02,-d.e12,d.e22))
 return Transform3D(b,Vector3(d.e03,d.e13,-d.e23))
func setup(p):
 probe=p;source=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/assets/kite/kite.json'))
 var d=JSON.parse_string(FileAccess.get_file_as_string(source.mesh_file))
 skin_root=probe.source_nodes[source.game_object]
 skeleton=Skeleton3D.new();skeleton.name='OriginalKiteBones';skin_root.add_child(skeleton)
 bind=Skin.new()
 for i in range(source.bones.size()):
  skeleton.add_bone(source.bones[i].name);skeleton.set_bone_rest(i,Transform3D.IDENTITY)
  bind.add_bind(i,matrix(d.bind_pose[i]))
 mesh=ArrayMesh.new()
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var bones=PackedInt32Array();var weights=PackedFloat32Array();var tangents=PackedFloat32Array()
 for v in d.vertices:vertices.append(Vector3(v[0],v[1],-v[2]))
 for v in d.normals:normals.append(Vector3(v[0],v[1],-v[2]))
 for v in d.uv0:uv.append(Vector2(v[0],v[1]))
 for v in d.tangents:tangents.append_array(PackedFloat32Array([v[0],v[1],-v[2],-v[3]]))
 for v in d.bone_indices:
  for value in v:bones.append(int(value))
 for v in d.bone_weights:
  for value in v:weights.append(float(value))
 for tris in d.triangles:
  var indices=PackedInt32Array()
  for tri in tris:indices.append_array(PackedInt32Array([tri[0],tri[1],tri[2]]))
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;arrays[Mesh.ARRAY_INDEX]=indices
  if tangents.size()==vertices.size()*4:arrays[Mesh.ARRAY_TANGENT]=tangents
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 probe.data.materials.merge(source.materials);probe.data.textures.merge(source.textures)
 var material=probe.material_factory.build(source.material_id)
 renderer=MeshInstance3D.new();renderer.name='OriginalKiteSkinnedRenderer';skin_root.add_child(renderer);renderer.mesh=mesh;renderer.skin=bind;renderer.skeleton=renderer.get_path_to(skeleton);renderer.layers=int(probe.data.layer_map[str(skin_root.get_meta('source_layer'))]);renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 renderer.set_meta('source_renderer',source.skin_id);renderer.set_meta('source_node',source.game_object);renderer.set_meta('source_mesh',source.mesh_id)
 probe.renderer_nodes[source.skin_id]=renderer
 for i in range(mesh.get_surface_count()):renderer.set_surface_override_material(i,material)
 renderer.visible=source.renderer.m_Enabled;advance(0)
func advance(_dt):
 if closed:return
 var inv=skin_root.global_transform.affine_inverse()
 for i in range(source.bones.size()):
  var t=inv*probe.source_nodes[source.bones[i].node].global_transform
  var q=t.basis.get_rotation_quaternion();var scale=t.basis.get_scale();var b=Basis(q).scaled(scale)
  max_basis_decomposition_error=maxf(max_basis_decomposition_error,maxf((b.x-t.basis.x).length(),maxf((b.y-t.basis.y).length(),(b.z-t.basis.z).length())))
  skeleton.set_bone_pose_position(i,t.origin);skeleton.set_bone_pose_rotation(i,q);skeleton.set_bone_pose_scale(i,scale)
func get_audit():
 var reference=renderer.get_skin_reference() if is_instance_valid(renderer) else null
 return {'source_skin':source.skin_id,'bones':skeleton.get_bone_count() if is_instance_valid(skeleton) else 0,'max_basis_decomposition_error':max_basis_decomposition_error,'skin_reference_valid':reference!=null,'rendering_skeleton_rid_valid':reference.get_skeleton().is_valid() if reference!=null else false,'renderer_visible':renderer.visible if is_instance_valid(renderer) else false,'errors':errors,'method':'Original vertex weights and bind pose through Godot Skeleton3D; 13 flat bones driven by original source hierarchy global transforms. No procedural sway.','boundary':'Dummy headless RenderingServer intentionally returns RID(0) for skeletons, so renderer baking is only tested on a real graphics backend. Source animation blending and original shadows are separate compatibility boundaries.'}
func close_interaction():
 if closed:return
 closed=true
 if probe!=null:probe.renderer_nodes.erase(source.skin_id)
 if is_instance_valid(renderer):renderer.queue_free()
 if is_instance_valid(skeleton):skeleton.queue_free()
 mesh=null;bind=null
