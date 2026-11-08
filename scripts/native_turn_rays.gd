extends Node3D
# Original YourTurn_glow mesh + original shader arithmetic. No procedural replacement texture.
const BASE='res://assets/native_turn_banner/'
var material:ShaderMaterial
var elapsed_seconds:float=0.0
var ready_to_render=false
var audit={}
func setup(viewport:SubViewport, root:Node3D):
 root.add_child(self)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var fx_path=BASE+'6632044137774968281.png'
 audit={'source_mesh':'851487831058885397','source_shader':'3752617471019072207','source_blend':'One OneMinusSrcAlpha','original_transform':'identity, parent TurnIndicator','source_rotation':'angle = elapsed_seconds / 20 * 5','vertex_color':'absent original channel; white default','fragment_evidence':'Original OSX platform14 LZ4 blob re-extracted and formula verified in rays_evidence/platform14_0.txt','texture_missing':not ResourceLoader.exists(fx_path)}
 if not ResourceLoader.exists(fx_path):
  push_warning('Original Rays2 texture missing; rays disabled rather than synthesizing a replacement.')
  return
 var data=JSON.parse_string(FileAccess.get_file_as_string(BASE+'851487831058885397.mesh.json'))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 var ps=PackedVector3Array();var uv=PackedVector2Array();var ix=PackedInt32Array();var colors=PackedColorArray()
 for v in data.positions:ps.append(Vector3(v[0],v[1],v[2]));colors.append(Color.WHITE)
 for v in data.uvs:uv.append(Vector2(v[0],v[1]))
 for sub in data.triangles:
  for t in sub:ix.append_array(PackedInt32Array([int(t[0]),int(t[2]),int(t[1])]))
 arrays[Mesh.ARRAY_VERTEX]=ps;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=ix;arrays[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var mi=MeshInstance3D.new();mi.mesh=mesh;add_child(mi)
 material=ShaderMaterial.new();material.shader=load(BASE+'original_turn_rays.gdshader');material.render_priority=-1
 material.set_shader_parameter('main_tex',load(BASE+'-2774723153666027043.png'))
 material.set_shader_parameter('fx_tex',load(fx_path));mi.material_override=material
 ready_to_render=true
func _process(delta):
 elapsed_seconds+=delta
 if material:material.set_shader_parameter('elapsed_seconds',elapsed_seconds)
func get_audit():return audit.duplicate(true)
