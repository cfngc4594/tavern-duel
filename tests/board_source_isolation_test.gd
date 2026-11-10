extends SceneTree
const Store=preload('res://original_board/scripts/board_source_store.gd')
const Compiler=preload('res://original_board/scripts/board_source_compiler.gd')
const Probe=preload('res://original_board/scripts/board_probe.gd')
const OUT='res://build/board_source/desktop_source.bin'
var checks=0
var failures=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func _initialize():call_deferred('run')
func make_probe(candidate:bool):
 Store.enabled=candidate
 var p=Probe.new();p.host_driven=true;p.interaction_audio_enabled=false;root.add_child(p)
 check(p.build_complete and not p.phone_variant,'desktop probe complete')
 for controller in [p.door_interaction,p.window_lamp_interaction,p.arch_interactions,p.kite_interactions,p.pumpkin_interaction,p.bush_interactions,p.water_interactions]:
  controller.rng.seed=654321
  if controller.get('systems') is Dictionary:
   for system in controller.systems.values():
    for gate in system.get('gates',{}).values():gate.threshold=3
 return p
func image_value(tex):
 if tex==null:return null
 var image=tex.get_image()
 if image==null:return null
 return [image.get_width(),image.get_height(),image.get_format(),image.has_mipmaps(),Compiler.digest(image.get_data())]
func material_value(mat):
 if mat==null:return null
 var params={}
 for u in mat.shader.get_shader_uniform_list():
  var v=mat.get_shader_parameter(u.name)
  params[str(u.name)]=image_value(v) if v is Texture2D else v
 return [mat.shader.code,mat.resource_name,params]
func mesh_value(mesh):
 var surfaces=[]
 for i in range(mesh.get_surface_count()):
  surfaces.append([mesh.surface_get_primitive_type(i),mesh.surface_get_format(i),mesh.surface_get_arrays(i)])
 return [mesh.get_aabb(),surfaces]
func snapshot(p)->Dictionary:
 var nodes={};var renderers={};var meshes={};var materials={};var textures={}
 for key in p.source_nodes:
  var n=p.source_nodes[key];nodes[key]=[n.transform,n.visible,n.get_meta('source_layer'),n.get_meta('source_active_self')]
 for key in p.meshes:meshes[key]=mesh_value(p.meshes[key])
 for key in p.materials:materials[key]=material_value(p.materials[key])
 for key in p.textures:textures[key]=image_value(p.textures[key])
 for key in p.renderer_nodes:
  var n=p.renderer_nodes[key];var mats=[]
  for i in range(n.mesh.get_surface_count()):mats.append(material_value(n.get_active_material(i)))
  renderers[key]=[n.transform,n.visible,n.layers,n.cast_shadow,mesh_value(n.mesh),mats]
 var bones=[];var skin=p.kite_interactions.skin
 for i in range(skin.skeleton.get_bone_count()):bones.append([skin.skeleton.get_bone_name(i),skin.skeleton.get_bone_rest(i),skin.skeleton.get_bone_pose(i),skin.bind.get_bind_pose(i)])
 var particle_mats={}
 for key in p.water_particles.material_cache:particle_mats[key]=material_value(p.water_particles.material_cache[key])
 return {'nodes':nodes,'renderers':renderers,'meshes':meshes,'materials':materials,'textures':textures,'bones':bones,'data':p.data,'config':p.config,'camera':[p.camera.transform,p.camera_root.transform,p.camera.fov,p.camera.near,p.camera.far,p.camera.cull_mask],'light':[p.source_light.transform,p.source_light.light_color,p.source_light.light_energy],'particle_materials':particle_mats}
func compare(a:Dictionary,b:Dictionary,label:String):
 for field in a:check(var_to_bytes(a[field])==var_to_bytes(b[field]),label+' exact '+field)
func exercise(p):
 p.door_interaction._start('opening')
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=p.window_lamp_interaction.target_screen()
 p.window_lamp_interaction.handle_input(event)
 for i in range(3):
  p.arch_interactions.click_kind('gong');p.kite_interactions.click_kind('kite');p.pumpkin_interaction.click_kind('pumpkin1');p.bush_interactions.click_kind('BushFlower01');p.water_interactions.click_kind('mill_wheel')
 for i in range(45):p.advance_host(1.0/60.0)
func destroy(p):
 p.close_probe();p.queue_free()
func run():
 var compiled=Compiler.compile();check(compiled.ok,'build current bundle')
 DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
 var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_buffer(compiled.bytes);file.close();compiled.clear()
 Store.bundle_path=OUT;Store.clear_cache()
 var baseline=make_probe(false)
 var initial=snapshot(baseline).duplicate(true)
 var candidate=make_probe(true)
 compare(initial,snapshot(candidate),'first build')
 var stats=Store.get_audit()
 check(stats.loads==1 and stats.json_hits==97 and stats.image_hits==16 and stats.misses==0,'first build bypasses all97 JSON parses and16 PNG decodes')
 check(baseline.data==candidate.data,'mutable source data equal')
 check(baseline.materials.values()[0]!=candidate.materials.values()[0] and baseline.meshes.values()[0]!=candidate.meshes.values()[0] and baseline.textures.values()[0]!=candidate.textures.values()[0],'render resources not shared')
 exercise(baseline);exercise(candidate)
 compare(snapshot(baseline),snapshot(candidate),'interactions and clocks')
 # Corrupt every caller-owned mutable category, then build another new match.
 candidate.data.nodes[0].name='poisoned source name';candidate.config.lighting.directional_intensity_normal_play_target=42
 candidate.meshes.values()[0].clear_surfaces()
 candidate.material_factory.animated[0].set_shader_parameter('_SourceTime',999.0)
 var texture=candidate.textures.values()[0];var pixels=texture.get_image();pixels.fill(Color.MAGENTA);texture.update(pixels)
 var old_json_reads=Store.get_audit().raw_json_reads;var old_image_reads=Store.get_audit().raw_image_reads
 var clean=make_probe(true);compare(initial,snapshot(clean),'simultaneous isolated probe')
 destroy(clean);destroy(candidate);destroy(baseline)
 await process_frame;await process_frame
 var count_after_release=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var payload_size=Store.get_audit().serialized_payload_bytes
 for repeat in range(6):
  var fresh=make_probe(true);compare(initial,snapshot(fresh),'new match '+str(repeat))
  exercise(fresh);destroy(fresh)
  await process_frame;await process_frame
  check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==count_after_release,'node count bounded after reset '+str(repeat))
 check(Store.get_audit().loads==1 and Store.get_audit().serialized_payload_bytes==payload_size,'cache bounded across resets')
 check(Store.get_audit().raw_json_reads==old_json_reads and Store.get_audit().raw_image_reads==old_image_reads and Store.get_audit().misses==0,'repeated new matches no JSON parse PNG decode fallback')
 Store.enabled=false;Store.clear_cache()
 print('BOARD_SOURCE_ISOLATION_TEST_', 'PASS' if failures.is_empty() else 'FAIL',' checks=',checks,' failures=',failures.size())
 quit(0 if failures.is_empty() else 1)
