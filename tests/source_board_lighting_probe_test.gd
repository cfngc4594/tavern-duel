extends SceneTree
const Policy=preload('res://scripts/source_board_camera_policy.gd')
var checks=0
var failures:Array=[]
func _initialize():call_deferred('_run')
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _check_materials(p,ambient:Color,intensity:float):
 var checked=0
 var light=p.data.light.data.m_Color
 for renderer in p.renderer_nodes.values():
  if not renderer is MeshInstance3D or renderer.mesh==null:continue
  for i in range(renderer.mesh.get_surface_count()):
   var m=renderer.get_active_material(i)
   if not m is ShaderMaterial:continue
   var uniforms={}
   for u in m.shader.get_shader_uniform_list():uniforms[str(u.name)]=true
   if uniforms.has('_UnitySHW'):check(m.get_shader_parameter('_UnitySHW').is_equal_approx(Vector3(ambient.r,ambient.g,ambient.b)),'Active board material shared ambient')
   if uniforms.has('_MainLightColor'):check(m.get_shader_parameter('_MainLightColor').is_equal_approx(Vector3(light.r,light.g,light.b)*intensity),'Active board material shared directional')
   checked+=1
 for m in p.water_particles.material_cache.values():
  check(m.get_shader_parameter('_UnitySHW').is_equal_approx(Vector3(ambient.r,ambient.g,ambient.b)),'Actual source particle cache shared ambient')
 return checked
func _run():
 Policy.runtime_layout_verified=true;Policy.qa_phone_platform=true
 ProjectSettings.set_setting('native_mobile/source_camera_enabled',true);ProjectSettings.set_setting('native_mobile/source_consumers_verified',true)
 var p=load('res://original_board/scripts/board_probe.gd').new();p.host_driven=true;p.interaction_audio_enabled=false;root.add_child(p)
 check(p.build_complete and p.phone_variant and p.board_state!=null,'Actual PHONE probe built with controller')
 check(p.source_nodes.size()==128 and p.renderer_nodes.size()==67 and p.meshes.size()==52,'Exact PHONE geometry counts')
 var transforms={}
 for id in p.source_nodes:transforms[id]=p.source_nodes[id].transform
 p.set_mulligan_lighting();p.combined_surface()
 var used=_check_materials(p,p.board_state.ambient,0)
 # Directly exercise the lazy clone hook on a real supported source renderer.
 # This is a unit call, not a claim the PHONE mill FSM animates this material.
 var cloned=false
 for id in p.renderer_nodes:
  var r=p.renderer_nodes[id]
  if r.mesh==null or r.mesh.get_surface_count()==0:continue
  var original=r.get_active_material(0)
  if not original is ShaderMaterial:continue
  var node_id=str(r.get_meta('source_node'))
  p.water_interactions._material_float(node_id,'_LightingBlend',original.get_shader_parameter('_LightingBlend'))
  cloned=p.water_interactions.animated_materials.has(node_id)
  if cloned:break
 check(cloned,'Lazy clone hook registers an actual supported board material')
 p.split_surface();p.raise_lights();p.advance_host(12)
 check(p.board_state.tween_elapsed==0,'Unclamped host/particle clock must not advance lighting')
 p.advance_board_lighting(1.5);p.advance_board_lighting(1.5)
 _check_materials(p,p.board_state.ambient,p.board_state.directional_intensity)
 p.advance_board_lighting(0.1);_check_materials(p,p.board_state.ambient_target,p.board_state.directional_target)
 for id in transforms:check(p.source_nodes[id].transform==transforms[id] or id==p.water_interactions.systems.mill_wheel.rotation_node,'State does not move board transforms; only original wheel animation moves its source target')
 var audit=p.get_audit();check(audit.board_state.split_active and not audit.board_state.combined_active,'Audit current source flags')
 var particle_materials=p.water_particles.material_cache.size()
 p.close_probe();p.close_probe();p.advance_board_lighting(10);p.queue_free()
 print('SOURCE_BOARD_LIGHTING_PROBE_'+('PASS' if failures.is_empty() else 'FAIL')+' checks=',checks,' active_surface_material_slots=',used,' particle_materials=',particle_materials,' exact_counts=128/67/52 failures=',failures)
 quit(0 if failures.is_empty() else 1)
