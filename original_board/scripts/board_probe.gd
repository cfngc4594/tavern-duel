extends Node3D
## Auditable source scene and explicitly ported controllers, not the official runtime or pixel equivalence.
const CameraPolicy=preload("res://scripts/source_board_camera_policy.gd")
const PHONE_DATA_PATH='res://original_board/assets/phone/scene_phone.json'
const PHONE_MESH_BAKE_PATH='res://original_board/assets/phone/board_meshes.res'
const PHONE_MESH_BAKE_VERSION=1
const PHONE_INTERACTIONS_PATH='res://original_board/assets/phone/interaction_profile.json'
const CONFIG_PATH='res://original_board/references/minimum_scene_config.json'
const REFLECTION=Basis(Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,-1))
var host_driven=false
var phone_variant=true
var data:Dictionary={}
var config:Dictionary={}
var source_root:Node3D
var camera_root:Node3D
var camera:Camera3D
var source_light:DirectionalLight3D
var source_nodes:Dictionary={}
var meshes:Dictionary={}
var materials:Dictionary={}
var textures:Dictionary={}
var renderer_nodes:Dictionary={}
var audit:Dictionary={'errors':[],'materials':[],'meshes':[],'renderers':[],'omitted_components':[]}
var closed=false
var build_complete=false
var elapsed_seconds=0.0
var material_factory
var board_state
var interaction_audio_enabled=true
var door_interaction
var arch_interactions
var water_particles
var water_interactions
var bush_interactions
var audit_path=''
var quit_after_frames=0
var process_count=0
static func v3(d):return Vector3(d.x,d.y,d.z)
static func source_vector(d):return REFLECTION*v3(d)
static func color4(d):return Vector4(d.r,d.g,d.b,d.a)
static func source_transform(p,q,s):
 var rotation=REFLECTION*Basis(Quaternion(q.x,q.y,q.z,q.w).normalized())*REFLECTION
 return Transform3D(Basis(rotation.x*s.x,rotation.y*s.y,rotation.z*s.z),source_vector(p))
static func raw_transform(t):return source_transform(t.m_LocalPosition,t.m_LocalRotation,t.m_LocalScale)
func _ready():
 if host_driven:
  build_scene();set_process(false);set_process_unhandled_input(false);set_process_unhandled_key_input(false);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--audit='):audit_path=arg.substr(8)
  if arg.begins_with('--quit-after-frames='):quit_after_frames=int(arg.substr(20))
 build_scene()
 if not audit_path.is_empty():write_audit(audit_path)
func build_scene():
 var scene_json=FileAccess.get_file_as_string(PHONE_DATA_PATH)
 data=JSON.parse_string(scene_json);config=JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
 audit.board_variant={'phone':true,'data_path':PHONE_DATA_PATH,'guid':data.get('guid',''),'selection':'Phone source scene only; layout readiness does not select another board','runtime_state':'Serialized source board; no new X/Y offsets'}
 if data.is_empty() or config.is_empty():audit.errors.append('Missing frozen source scene/config');return
 source_root=Node3D.new();source_root.name='OriginalMOPPhone';add_child(source_root)
 for row in data.nodes:
  var node=Node3D.new();node.name=_safe_name(row.name)+'__'+str(source_nodes.size());node.set_meta('source_id',row.id);node.set_meta('source_transform',row.transform_id);node.set_meta('source_layer',int(row.layer));node.set_meta('source_active_self',row.active)
  source_nodes[row.id]=node
  if row.parent.is_empty():source_root.add_child(node)
  else:source_nodes[row.parent].add_child(node)
  node.transform=source_transform(row.position,row.rotation,row.scale);node.visible=bool(row.active)
  for c in row.components:
   if c.type not in ['GameObject','Transform','MeshFilter','MeshRenderer','Light']:
    audit.omitted_components.append({'id':c.id,'node':row.id,'class':c.class,'status':'Preserved source metadata; not executed in static probe'})
 if data.get('runtime_roles',{}).has('drag_plane'):
  var plane:Dictionary=data.runtime_roles.drag_plane
  set_meta('source_drag_plane_id',str(plane.node_id));set_meta('source_drag_plane_mesh_file',str(plane.mesh_file))
 _setup_camera()
 _setup_light()
 material_factory=load('res://original_board/scripts/board_materials.gd').new();material_factory.setup(self)
 _load_board_meshes(scene_json)
 for key in data.materials:materials[key]=material_factory.build(key)
 for row in data.nodes:
  for r in row.renderers:_build_renderer(row,r)
 board_state=load('res://original_board/scripts/source_board_state.gd').new();board_state.setup(self)
 _setup_phone_interactions()
 build_complete=true
 audit.compatibility=data.limitations.duplicate()
 audit.compatibility.append('Source config earlier proposed reversing triangles after reflection; corrected against native Godot PlaneMesh and exported normal/winding audit: reflect positions/normals but retain a,b,c indices.')
 audit.compatibility.append('Unity layer IDs compactly remapped into Godot 20-bit mask; original camera/light membership preserved.')
 audit.compatibility.append('Phone camera uses source aspect endpoints. No alternate board or camera fallback and no new mana root offset.')
 audit.compatibility.append('Single source door controller added with original legacy curves/audio; no card renderer, SubViewport, particle substitute or screenshot backdrop.')
# Explicit host clock: advance_host intentionally does not advance this tween.
# The opening flow advances on its own clamped/scaled game clock, not loading time.
func advance_board_lighting(dt:float):
 if board_state!=null and not closed:board_state.advance(dt)
func set_mulligan_lighting():
 if board_state!=null and not closed:board_state.set_mulligan_lighting()
func combined_surface()->bool:
 return board_state.combined_surface() if board_state!=null and not closed else false
func split_surface()->bool:
 return board_state.split_surface() if board_state!=null and not closed else false
func raise_lights(speed:float=1.0)->bool:
 return board_state.raise_lights(speed) if board_state!=null and not closed else false
func raise_lights_quickly()->bool:
 return raise_lights(5.0)
func reset_board_state_for_load():
 if board_state!=null and not closed:board_state.reset_for_board_load()
func register_source_lighting_material(mat:ShaderMaterial):
 if material_factory!=null and not closed:material_factory.register_lighting_material(mat)
func get_source_lighting()->Dictionary:
 return material_factory.get_source_lighting() if material_factory!=null else {}
func _setup_phone_interactions():
 var profile=JSON.parse_string(FileAccess.get_file_as_string(PHONE_INTERACTIONS_PATH))
 if not profile is Dictionary:
  audit.errors.append('Missing verified PHONE interaction profile');return
 for field in ['door_interaction','arch_interactions','water_particles','bush_interactions','water_interactions']:
  if not profile.has(field):
   audit.errors.append('Missing verified PHONE interaction '+field);continue
  var entry:Dictionary=profile[field]
  var controller=load(str(entry.script)).new();controller.name=field;add_child(controller);set(field,controller)
  if field!='water_particles':controller.audio_enabled=interaction_audio_enabled
  controller.setup(self,entry.get('options',{}))
 audit.board_variant.interactions='Phone data/IDs/colliders only'
func _safe_name(s):return str(s).replace('/','_').replace(':','_').replace('@','_').replace('.','_')
func _mapped_mask(mask:int)->int:
 var result=0
 for layer in data.layer_map:
  if mask & (1<<int(layer)):result|=int(data.layer_map[layer])
 return result
func refresh_source_camera(canvas:Vector2):
 if is_instance_valid(camera):CameraPolicy.apply(camera,camera_root,canvas)
func _setup_camera():
 camera_root=Node3D.new();camera_root.name='OriginalBoardCameras';add_child(camera_root)
 camera=Camera3D.new();camera.name='OriginalMainCamera';camera_root.add_child(camera)
 CameraPolicy.apply(camera,camera_root,get_viewport().get_visible_rect().size)
 var c=CameraPolicy.settings()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL if c.orthographic else Camera3D.PROJECTION_PERSPECTIVE
 camera.cull_mask=_mapped_mask(int(c.m_CullingMask.m_Bits));camera.current=true
 var camera_source='phone-prefab:1e862adebb4fd4fca8b24249d32f8d86'
 camera.set_meta('source_id',camera_source)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0,0,0,0);environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 camera.environment=environment
 audit.camera={'source_id':camera_source,'source_trs':CameraPolicy.phone_data().camera_transform,'fov':camera.fov,'near':camera.near,'far':camera.far,'keep_aspect':'KEEP_HEIGHT; source vertical FOV','source_mask':c.m_CullingMask.m_Bits,'mapped_mask':camera.cull_mask,'layer_map':data.layer_map,'projection':'source perspective','source_settings':c,'runtime_status':'Phone source prefab and aspect position. Narrow-window horizontal framing is a Godot adapter. Mercenaries zoom not simulated','extra_camera_or_texture_target':false}
func _setup_light():
 var l=data.light;var d=l.data
 source_light=DirectionalLight3D.new();source_light.name='OriginalDirectionalLight';source_nodes[l.game_object].add_child(source_light);source_light.set_meta('source_id',l.id)
 source_light.light_color=Color(d.m_Color.r,d.m_Color.g,d.m_Color.b);source_light.light_energy=float(config.lighting.directional_intensity_normal_play_target);source_light.light_cull_mask=_mapped_mask(int(d.m_CullingMask.m_Bits));source_light.shadow_enabled=false
 audit.light={'source_id':l.id,'source_settings':d,'source_transform':config.unity_light_transform,'normal_play_energy':source_light.light_energy,'serialized_energy':d.m_Intensity,'source_ambient':config.lighting.ambient_target_raw_rgba,'shadow_status':'Original shadow settings preserved; shadowmap/URP variant not implemented in unshadowed source-formula routes','shader_global_status':'MainLight direction/color translated; ambient SH projection and UnityLightData/keyword selection explicitly compatible, not recovered exact globals'}
func _load_board_meshes(scene_json: String) -> void:
 var baked := {}
 if ResourceLoader.exists(PHONE_MESH_BAKE_PATH):
  var pack := ResourceLoader.load(PHONE_MESH_BAKE_PATH)
  if pack != null and pack.get_meta('bake_version', -1) == PHONE_MESH_BAKE_VERSION and pack.get_meta('scene_sha256', '') == scene_json.sha256_text():
   var entries: Variant = pack.get_meta('meshes', {})
   if entries is Dictionary:
    baked = entries
 var baked_count := 0
 for key in data.meshes:
  var entry: Variant = baked.get(key)
  if entry is Dictionary and _use_baked_mesh(key, entry):
   meshes[key] = entry.mesh
   audit.meshes.append(entry.audit.duplicate(true))
   baked_count += 1
  else:
   meshes[key] = _build_mesh(key)
 audit.board_variant['baked_meshes'] = baked_count

func _use_baked_mesh(key: String, entry: Dictionary) -> bool:
 if not entry.get('mesh') is ArrayMesh or not entry.get('audit') is Dictionary:
  return false
 var descriptor: Dictionary = data.meshes[key]
 if entry.audit.get('source_file') != descriptor.file or entry.audit.get('name') != descriptor.name:
  return false
 # Exported source files are baked together by the build. Editor previews can
 # use changed mesh JSON immediately, before another bake is generated.
 return not OS.has_feature('editor') or entry.get('sha256', '') == FileAccess.get_sha256(descriptor.file)

func _build_mesh(key):
 var descriptor=data.meshes[key];var d=JSON.parse_string(FileAccess.get_file_as_string(descriptor.file));var mesh=ArrayMesh.new()
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var uv2=PackedVector2Array();var colors=PackedColorArray();var tangents=PackedFloat32Array()
 for v in d.vertices:vertices.append(Vector3(v[0],v[1],-v[2]))
 for v in d.get('normals',[]) if d.get('normals') is Array else []:normals.append(Vector3(v[0],v[1],-v[2]))
 for v in d.get('uv0',[]) if d.get('uv0') is Array else []:uv.append(Vector2(v[0],v[1]))
 for v in d.get('uv1',[]) if d.get('uv1') is Array else []:uv2.append(Vector2(v[0],v[1]))
 var color_divisor=255.0 if d.get('vertex_channels',[]).size()>3 and int(d.vertex_channels[3].format)==2 else 1.0
 for v in d.get('colors',[]) if d.get('colors') is Array else []:colors.append(Color(v[0]/color_divisor,v[1]/color_divisor,v[2]/color_divisor,v[3]/color_divisor))
 for v in d.get('tangents',[]) if d.get('tangents') is Array else []:tangents.append_array(PackedFloat32Array([v[0],v[1],-v[2],-v[3]]))
 var tris=0
 for sub in d.triangles:
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
  if normals.size()==vertices.size():arrays[Mesh.ARRAY_NORMAL]=normals
  if uv.size()==vertices.size():arrays[Mesh.ARRAY_TEX_UV]=uv
  if uv2.size()==vertices.size():arrays[Mesh.ARRAY_TEX_UV2]=uv2
  if colors.size()==vertices.size():arrays[Mesh.ARRAY_COLOR]=colors
  if tangents.size()==vertices.size()*4:arrays[Mesh.ARRAY_TANGENT]=tangents
  var indices=PackedInt32Array()
  for tri in sub:indices.append_array(PackedInt32Array([int(tri[0]),int(tri[1]),int(tri[2])]))
  arrays[Mesh.ARRAY_INDEX]=indices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);tris+=sub.size()
 audit.meshes.append({'source_id':key,'name':descriptor.name,'vertices':vertices.size(),'surfaces':mesh.get_surface_count(),'triangles':tris,'uv0_count':uv.size(),'uv1_count':uv2.size(),'normals_count':normals.size(),'colors_count':colors.size(),'source_color_divisor':color_divisor,'source_file':descriptor.file,'coordinates':'S reflection; source winding retained (a,b,c) because native Godot front-face convention has negative geometric-normal dot; raw UV, sample V flipped after ST','unsupported_channels':'UV2..7/bone channels retained in raw source file but not used by static MeshRenderer routes'})
 return mesh
func _build_renderer(row,r):
 if not meshes.has(r.mesh):audit.errors.append('Missing mesh for renderer '+r.id);return
 var mi=MeshInstance3D.new();mi.name='SourceMeshRenderer';mi.mesh=meshes[r.mesh];source_nodes[row.id].add_child(mi);mi.layers=int(data.layer_map[str(int(row.layer))]);mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mi.set_meta('source_renderer',r.id);mi.set_meta('source_mesh',r.mesh);mi.set_meta('source_node',row.id);mi.set_meta('source_materials',r.materials)
 var slots=[];var unsupported=false
 for i in range(mi.mesh.get_surface_count()):
  if i>=r.materials.size():audit.errors.append('Unbound source submesh '+r.id+':'+str(i));unsupported=true;continue
  var key=r.materials[i];var mat=materials.get(key)
  if mat==null:unsupported=true
  else:mi.set_surface_override_material(i,mat)
  slots.append({'surface':i,'material':key,'route':material_factory.routes.get(key,{})})
 mi.visible=bool(r.enabled) and not unsupported;renderer_nodes[r.id]=mi
 audit.renderers.append({'source_id':r.id,'node':row.id,'node_path':str(mi.get_path()),'mesh':r.mesh,'source_enabled':r.enabled,'rendered':mi.visible,'visibility_in_tree':mi.is_visible_in_tree(),'reason':'unsupported shader/material omitted explicitly' if unsupported else 'static source MeshRenderer','source_layer':row.layer,'mapped_layer':mi.layers,'slots':slots,'source_settings':r.source_settings})
func _process(dt):
 if host_driven:return
 advance_host(dt)
func advance_host(dt):
 if closed:return
 elapsed_seconds+=dt;process_count+=1
 if material_factory!=null:material_factory.advance(elapsed_seconds)
 if is_instance_valid(door_interaction):door_interaction.advance(dt)
 if is_instance_valid(arch_interactions):arch_interactions.advance(dt)
 if is_instance_valid(bush_interactions):bush_interactions.advance(dt)
 if is_instance_valid(water_interactions):water_interactions.advance(dt)
 if is_instance_valid(water_particles):water_particles.advance(dt)
 if quit_after_frames>0 and process_count>=quit_after_frames:
  if not audit_path.is_empty():write_audit(audit_path)
  close_probe();await get_tree().process_frame;get_tree().quit()
func _unhandled_input(event):
 if host_driven:return
 if handle_host_input(event):get_viewport().set_input_as_handled()
func handle_host_input(event)->bool:
 for controller in [arch_interactions,door_interaction,bush_interactions,water_interactions]:
  if is_instance_valid(controller) and controller.handle_input(event):
   return true
 return false
func _unhandled_key_input(event):
 if host_driven:return
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  close_probe();get_tree().quit()
func get_audit():
 var result=audit.duplicate(true);result.build_complete=build_complete;result.closed=closed;result.elapsed_seconds=elapsed_seconds;result.source_manifest_sha256=data.get('source_manifest_sha256','');result.source_nodes=source_nodes.size();result.renderer_count=renderer_nodes.size();result.static_renderer_count=audit.renderers.size();result.skinned_renderer_count=renderer_nodes.size()-audit.renderers.size();result.texture_count=textures.size();result.material_count=materials.size();result.mesh_count=meshes.size();result.extra_subviewports=0
 if is_instance_valid(camera):result.camera.global_transform=str(camera.global_transform);result.camera.viewport_size=get_viewport().get_visible_rect().size
 if is_instance_valid(door_interaction):result.door=door_interaction.get_audit()
 if is_instance_valid(arch_interactions):result.arch=arch_interactions.get_audit()
 if is_instance_valid(bush_interactions):result.bushes=bush_interactions.get_audit()
 if is_instance_valid(water_interactions):result.water=water_interactions.get_audit()
 if is_instance_valid(water_particles):result.water_particles=water_particles.get_audit()
 if board_state!=null:result.board_state=board_state.get_audit()
 if material_factory!=null:
  var live=material_factory.get_source_lighting()
  var a:Color=live.ambient
  result.light.current_ambient_rgba=[a.r,a.g,a.b,a.a];result.light.current_directional_intensity=live.directional_intensity
  result.light.registered_lighting_materials=live.registered_materials
 for row in result.renderers:
  var renderer=renderer_nodes.get(row.source_id)
  if is_instance_valid(renderer):row.visibility_in_tree=renderer.is_visible_in_tree();row.rendered=renderer.visible
 return result
func write_audit(path):
 DirAccess.make_dir_recursive_absolute(path.get_base_dir());var f=FileAccess.open(path,FileAccess.WRITE)
 if f:f.store_string(JSON.stringify(get_audit(),'  '))
func close_probe():
 if closed:return
 closed=true;set_process(false)
 if board_state!=null:board_state.close();board_state=null
 if material_factory!=null:material_factory.close()
 for controller in [water_interactions,bush_interactions,water_particles,arch_interactions,door_interaction]:
  if is_instance_valid(controller):controller.close_interaction();controller.queue_free()
 if is_instance_valid(source_root):source_root.queue_free()
 if is_instance_valid(camera_root):camera_root.queue_free()
 renderer_nodes.clear();source_nodes.clear();materials.clear();meshes.clear();textures.clear();material_factory=null
