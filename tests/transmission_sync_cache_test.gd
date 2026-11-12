extends SceneTree
const Transmission=preload("res://scripts/native_combat_transmission.gd")
const CODE="shader_type spatial; uniform float amount=0.25; uniform sampler2D tex; void fragment(){ALBEDO=vec3(amount);ALPHA=0.5;}"
func _initialize():call_deferred("run")
func material(code=CODE):
 var m=ShaderMaterial.new();m.shader=Shader.new();m.shader.code=code;return m
func run():
 var view=SubViewport.new();view.size=Vector2i(128,128);root.add_child(view)
 var scene=Node3D.new();view.add_child(scene)
 var source=MeshInstance3D.new();source.mesh=QuadMesh.new();scene.add_child(source)
 var original=material();original.set_shader_parameter("amount",.6)
 var tex=GradientTexture1D.new();original.set_shader_parameter("tex",tex)
 var pass_material=material();pass_material.set_shader_parameter("amount",.8);original.next_pass=pass_material
 source.material_override=original
 var tx=Transmission.new();root.add_child(tx);tx.setup(view,scene)
 var key=source.get_instance_id();var material_key=original.get_instance_id()
 var mirror=tx.mirrors[key];var target=tx.material_cache[material_key]
 assert(target!=original and target.shader!=original.shader)
 assert(target.get_shader_parameter("amount")==.6 and target.get_shader_parameter("tex")==tex)
 assert(target.next_pass!=pass_material and target.next_pass.get_shader_parameter("amount")==.8)
 # A sentinel on the mirror proves idle sync did not repeat the setter.
 target.set_shader_parameter("amount",.77);tx.sync()
 assert(target.get_shader_parameter("amount")==.77)
 original.set_shader_parameter("amount",.2);tx.sync();assert(target.get_shader_parameter("amount")==.2)
 original.set_shader_parameter("amount",null);tx.sync()
 assert(target.get_shader_parameter("amount")==original.get_shader_parameter("amount"))
 var tex2=GradientTexture1D.new();original.set_shader_parameter("tex",tex2);tx.sync()
 assert(target.get_shader_parameter("tex")==tex2 and original.get_shader_parameter("tex")==tex2)
 pass_material.set_shader_parameter("amount",.4);tx.sync();assert(target.next_pass.get_shader_parameter("amount")==.4)
 original.next_pass=null;tx.sync();assert(target.next_pass==null)
 assert(original.shader.code==CODE and original.get_shader_parameter("amount")==target.get_shader_parameter("amount"))
 var replacement=Shader.new();replacement.code=CODE+"\n// distinct shader"
 original.shader=replacement;original.set_shader_parameter("amount",.9);tx.sync()
 var variant=target.shader;assert(target.get_shader_parameter("amount")==.9)
 replacement.code=CODE.replace("uniform float amount=0.25;","uniform float amount=0.25; uniform float extra=0.1;")
 original.set_shader_parameter("extra",.73);tx.sync()
 assert(target.shader!=variant and target.get_shader_parameter("extra")==.73)
 assert(original.shader==replacement and original.shader.code==replacement.code)
 # Hidden mirrors retain old geometry but cannot contribute. Reveal must update all.
 source.visible=false;tx.sync();assert(not mirror.visible)
 var new_mesh=SphereMesh.new();var new_material=material();new_material.set_shader_parameter("amount",.12)
 source.mesh=new_mesh;source.material_override=new_material;source.position=Vector3(3,2,1);source.layers=2
 tx.sync();assert(not mirror.visible and mirror.mesh!=new_mesh)
 source.visible=true;tx.sync()
 assert(mirror.visible and mirror.mesh==new_mesh and mirror.global_transform==source.global_transform and mirror.layers==2)
 assert(mirror.get_surface_override_material(0)==tx.material_cache[new_material.get_instance_id()])
 assert(mirror.get_surface_override_material(0).get_shader_parameter("amount")==.12)
 assert(source.material_override==new_material and new_material.shader.code==CODE and new_material.get_shader_parameter("amount")==.12)
 # Capture-only sources stay active in the scene but outside the T camera.
 source.layers=0;tx.sync();assert(not mirror.visible and source.is_visible_in_tree())
 source.position.x=8.0;new_material.set_shader_parameter("amount",.42)
 tx.sync();assert(mirror.global_transform!=source.global_transform)
 source.layers=2;tx.camera.cull_mask=1;tx.sync();assert(not mirror.visible)
 tx.camera.cull_mask=3;tx.sync()
 assert(mirror.visible and mirror.global_transform==source.global_transform and mirror.layers==2)
 assert(mirror.get_surface_override_material(0).get_shader_parameter("amount")==.42)
 source.free();tx.sync();assert(not tx.mirrors.has(key) and tx.material_cache.is_empty() and tx._uniform_values.is_empty())
 base_material_values(tx)
 await geometry_lifecycle(tx,view,scene)
 identity_additive_geometry(tx,scene)
 print("TRANSMISSION_SYNC_CACHE_PASS uniforms/null/texture/next-pass/shader edits, source immutability, hidden reveal and free cleanup")
 tx.queue_free();view.queue_free();quit()
func geometry_lifecycle(tx,view,scene):
 # Begin from a settled cache, then mutate the source hierarchy in place.
 tx.sync();await process_frame;tx.sync();tx.sync()
 var parent=Node3D.new();scene.add_child(parent)
 var mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new();parent.add_child(mesh)
 var id=mesh.get_instance_id();tx.sync();assert(tx.mirrors.has(id))
 tx.sync();await process_frame;tx.sync();tx.sync()
 assert(not tx._geometry_dirty)
 parent.visible=false;tx.sync();assert(not tx.mirrors[id].visible)
 mesh.position=Vector3(2,3,4);parent.position=Vector3(1,0,0)
 parent.visible=true;tx.sync()
 assert(tx.mirrors[id].visible and tx.mirrors[id].global_transform==mesh.global_transform)
 var nested=SubViewport.new();scene.add_child(nested)
 var rtt_mesh=MeshInstance3D.new();rtt_mesh.mesh=QuadMesh.new();nested.add_child(rtt_mesh)
 tx.sync();assert(not tx.mirrors.has(rtt_mesh.get_instance_id()))
 # Reparent a previously mirrored node into an independent RTT and back.
 mesh.reparent(nested);tx.sync();assert(not tx.mirrors.has(id))
 mesh.reparent(parent);tx.sync();assert(tx.mirrors.has(id))
 var geometry_changes={"sorting_offset":2.5,"sorting_use_aabb_center":false,"custom_aabb":AABB(Vector3(-2,-2,-2),Vector3(4,4,4)),"extra_cull_margin":3.0,"transparency":.3,"visibility_range_begin":2.0,"visibility_range_end":50.0,"visibility_range_begin_margin":1.0,"visibility_range_end_margin":4.0,"visibility_range_fade_mode":GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF,"ignore_occlusion_culling":true}
 for prop in geometry_changes:
  mesh.set(prop,geometry_changes[prop]);tx.sync()
  assert(tx.mirrors[id].get(prop)==mesh.get(prop),str(prop))
 var other=Node3D.new();view.add_child(other)
 mesh.reparent(other);tx.sync();assert(not tx.mirrors.has(id))
 tx.setup(view,other);tx.sync();assert(tx.mirrors.has(id) and tx.mirrors.size()==1)
 tx.setup(view,scene);tx.sync();assert(not tx.mirrors.has(id))
 mesh.reparent(parent);tx.sync();assert(tx.mirrors.has(id))
 mesh.free();tx.sync();assert(not tx.mirrors.has(id))
 # Signal subscription belongs to the node's tree lifetime, including re-entry.
 var callback=Callable(tx,"_mark_geometry_dirty")
 assert(tree_changed.is_connected(callback))
 root.remove_child(tx)
 assert(not tree_changed.is_connected(callback) and tx._watched_tree==null)
 root.add_child(tx);tx.sync()
 assert(tree_changed.is_connected(callback))
 var fresh=MeshInstance3D.new();fresh.mesh=QuadMesh.new();parent.add_child(fresh)
 tx.sync();assert(tx.mirrors.has(fresh.get_instance_id()))
 tx.sync();await process_frame;tx.sync();tx.sync()
 root.remove_child(tx);assert(not tree_changed.is_connected(callback))
 root.add_child(tx);tx.sync();assert(tx.mirrors.has(fresh.get_instance_id()),"Re-entering tree must rebuild cleared geometry list")
 fresh.free();tx.sync();assert(tx.mirrors.is_empty())
 print("TRANSMISSION_GEOMETRY_CACHE_PASS add/free/reparent/RTT/ancestor visibility/root replacement/signal lifecycle")
func identity_additive_geometry(tx,scene):
 var source=MeshInstance3D.new();source.mesh=QuadMesh.new();scene.add_child(source)
 var additive=ShaderMaterial.new();additive.shader=preload("res://shaders/native_combat_r2t_additive.gdshader")
 var key=source.get_instance_id();source.material_override=additive
 tx.prune_identity_additive=true
 tx.sync()
 assert(not tx.mirrors.has(key) and tx.audit().identity_additive_skipped==1)
 assert(source.is_visible_in_tree() and source.material_override==additive)
 var normal=material()
 source.material_overlay=normal;tx.sync();assert(tx.mirrors[key].visible and tx.audit().identity_additive_skipped==0)
 source.material_overlay=null;tx.sync();assert(not tx.mirrors[key].visible)
 additive.next_pass=normal;source.position.x=2.0;tx.sync()
 assert(tx.mirrors[key].visible and tx.mirrors[key].global_transform==source.global_transform)
 additive.next_pass=null
 var arrays=source.mesh.surface_get_arrays(0)
 var mixed=ArrayMesh.new();mixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 source.mesh=mixed;source.material_override=null
 source.set_surface_override_material(0,additive);source.set_surface_override_material(1,normal)
 tx.sync();assert(tx.mirrors[key].visible and tx.audit().identity_additive_skipped==0)
 source.set_surface_override_material(1,additive);tx.sync();assert(tx.mirrors[key].visible)
 var changed=material(additive.shader.code)
 source.material_override=changed;tx.sync();assert(not tx.mirrors[key].visible)
 changed.shader.code=additive.shader.code.replace("ALPHA = 0.0", "ALPHA = 0.5")
 tx.sync();assert(tx.mirrors[key].visible)
 changed.shader.code=additive.shader.code
 tx.sync();assert(not tx.mirrors[key].visible)
 tx.prune_identity_additive=false;tx.sync()
 assert(tx.mirrors[key].visible and tx.audit().identity_additive_skipped==0 and tx.audit().identity_additive_skipped_total>=3)
 source.free();tx.sync();assert(tx.mirrors.is_empty())
 print("TRANSMISSION_IDENTITY_ADDITIVE_PASS exact whole-mesh override, surface/overlay/next-pass fallback, shader edit invalidation and opt-out")
func base_material_values(tx):
 var source=StandardMaterial3D.new()
 var texture=GradientTexture1D.new()
 for i in 8:
  source.transparency=i%4
  source.blend_mode=i%5
  source.albedo_color=Color(.2+i*.05,.7,.4,.25+i*.07)
  source.albedo_texture=texture if i%2 else null
  source.emission_enabled=i%2==1
  source.emission=Color(.2,.3,.7)
  source.normal_enabled=i%2==0
  source.normal_scale=i*.1
  source.roughness=i*.1
  source.metallic=i*.1
  source.cull_mode=i%3
  source.uv1_scale=Vector3.ONE*(i+1)
  tx._material_seen.clear()
  var mirrored=tx.transmission_material(source)
  assert(mirrored!=source)
  assert(mirrored.albedo_texture==source.albedo_texture)
  assert(mirrored.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and not mirrored.emission_enabled)
  var color=source.albedo_color if source.blend_mode==BaseMaterial3D.BLEND_MODE_MUL else Color(0,0,0,source.albedo_color.a)
  assert(mirrored.albedo_color==color)
  for property in source.get_property_list():
   if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or property.name in ["next_pass","resource_path","resource_name","script","shading_mode","emission_enabled","albedo_color"]:continue
   assert(mirrored.get(property.name)==source.get(property.name),str(property.name))
  assert(source.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL)
  assert(source.emission_enabled==(i%2==1))
 # Explicit invalidation must rebuild names without losing values.
 source.notify_property_list_changed();tx._material_seen.clear()
 assert(tx.transmission_material(source).roughness==source.roughness)
 print("TRANSMISSION_BASE_MATERIAL_PASS dynamic storage properties, flags, textures and source immutability")
