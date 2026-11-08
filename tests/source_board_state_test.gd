extends SceneTree
const State=preload('res://original_board/scripts/source_board_state.gd')
const Factory=preload('res://original_board/scripts/board_materials.gd')
const SHADERS=['source_diffuse.gdshader','source_diffuse_color.gdshader','source_split.gdshader','source_split_mask.gdshader','source_wind.gdshader','source_water.gdshader','source_water_particle_transparent.gdshader','source_water_particle_additive.gdshader']
class Probe extends Node3D:
 var data:Dictionary
 var config:Dictionary
 var source_nodes:Dictionary={}
 var source_light:DirectionalLight3D
 var material_factory
var checks=0
var failures:Array=[]
var probe
var state
var registered:Array=[]
func _initialize():call_deferred('_run')
func check(value:bool,message:String):
 checks+=1
 if not value:
  failures.append(message);push_error(message)
func near(a:float,b:float)->bool:return absf(a-b)<0.000002
func check_lighting(c:Color,energy:float):
 check(near(probe.source_light.light_energy,energy),'DirectionalLight3D energy must track source')
 for mat in registered:
  var a:Vector3=mat.get_shader_parameter('_UnitySHW')
  var d:Vector3=mat.get_shader_parameter('_MainLightColor')
  check(a.is_equal_approx(Vector3(c.r,c.g,c.b)),'Registered shader ambient tracks shared lighting')
  check(d.is_equal_approx(Vector3(1,0.8812277913093567,0.6745097637176514)*energy),'Registered shader directional color tracks shared lighting')
func _run():
 probe=Probe.new();root.add_child(probe)
 probe.data=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/assets/phone/scene_phone.json'))
 probe.config=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/references/minimum_scene_config.json'))
 probe.source_light=DirectionalLight3D.new();probe.add_child(probe.source_light)
 var snapshots={}
 for row in probe.data.nodes:
  var node=Node3D.new();probe.add_child(node);node.visible=bool(row.active)
  node.position=Vector3(row.position.x,row.position.y,row.position.z)
  probe.source_nodes[row.id]=node;snapshots[row.id]=node.transform
 probe.material_factory=Factory.new();probe.material_factory.setup(probe)
 for shader in SHADERS:
  var mat=ShaderMaterial.new();mat.shader=load('res://original_board/shaders/'+shader)
  check(mat.shader!=null,'Shader exists: '+shader)
  registered.append(mat);probe.material_factory.register_lighting_material(mat)
 state=State.new();state.setup(probe)
 var base=state.ambient_target;var target=state.directional_target
 check(state.split_node.visible and not state.combined_node.visible,'Exact serialized split/combined initial activation')
 check_lighting(base,target)
 state.set_mulligan_lighting();state.combined_surface()
 check(not state.split_node.visible and state.combined_node.visible,'CombinedSurface enables only combined')
 check_lighting(State.MULLIGAN_AMBIENT,0)
 # Repeated surface and lighting calls are idempotent; they never move ancestors.
 state.combined_surface();state.set_mulligan_lighting()
 for id in snapshots:check(probe.source_nodes[id].transform==snapshots[id],'No geometry or ancestor transform changes')
 check(state.raise_lights(),'First raise begins')
 check(state.raised_lights and state.tween_active,'Raise guard is set at launch, not completion')
 check(near(state.tween_duration,3.0),'Ordinary duration is 3 seconds')
 state.advance(0.75)
 check_lighting(State.MULLIGAN_AMBIENT,0)
 check(not state.raise_lights(5),'Repeated quick raise must not restart/accelerate active tween')
 check(near(state.tween_elapsed,0.75) and near(state.tween_duration,3),'Repeated raise preserves elapsed and duration')
 state.advance(0.75)
 check_lighting(State.MULLIGAN_AMBIENT.lerp(base,0.125),target*0.125)
 # Source direct write does not cancel running ValueTo or clear m_raisedLights.
 state.set_mulligan_lighting();check_lighting(State.MULLIGAN_AMBIENT,0)
 check(state.tween_active and state.raised_lights,'SetMulliganLighting preserves running tween and raised flag')
 state.advance(0.75);check_lighting(State.MULLIGAN_AMBIENT.lerp(base,0.5),target*0.5)
 state.advance(0.75);check_lighting(State.MULLIGAN_AMBIENT.lerp(base,0.875),target*0.875)
 check(state.tween_active,'Crossing duration only updates percentage, source callback completes next tick')
 state.advance(0.1);check_lighting(base,target)
 check(not state.tween_active,'Exact endpoint completes')
 state.set_mulligan_lighting()
 check(not state.raise_lights(),'Set after completion does not reset raised flag')
 state.advance(99);check_lighting(State.MULLIGAN_AMBIENT,0)
 state.reset_for_board_load();state.set_mulligan_lighting();check(state.raise_lights_quickly(),'New Board lifecycle can raise again')
 check(near(state.tween_duration,0.6),'Quick duration is 3/5 seconds')
 state.advance(0.3);state.advance(0.3);check_lighting(State.MULLIGAN_AMBIENT.lerp(base,0.5),target*0.5)
 state.advance(0.01);check_lighting(base,target)
 # Joining materials receive the CURRENT source, rather than serialized targets.
 state.reset_for_board_load();state.set_mulligan_lighting()
 var late=ShaderMaterial.new();late.shader=load('res://original_board/shaders/source_water_particle_transparent.gdshader')
 probe.material_factory.register_lighting_material(late);registered.append(late);check_lighting(State.MULLIGAN_AMBIENT,0)
 var count=probe.material_factory.lighting_materials.size();probe.material_factory.register_lighting_material(late)
 check(probe.material_factory.lighting_materials.size()==count,'Duplicate registration is bounded')
 state.raise_lights();state.advance(0.2);state.reset_for_board_load();state.advance(10)
 check_lighting(base,target);check(not state.tween_active and not state.raised_lights,'New Board cancels old tween')
 state.combined_surface();state.split_surface();check(state.split_node.visible and not state.combined_node.visible,'SplitSurface restores flags')
 var missing=state.split_node;state.split_node=null
 check(not state.combined_surface() and not state.combined_node.visible,'Source missing reference changes neither surface')
 state.split_node=missing
 check(not state.raise_lights(0) and not state.raise_lights(-1),'Invalid adapter speed rejected')
 state.set_mulligan_lighting();state.raise_lights();state.close();state.advance(10)
 check_lighting(State.MULLIGAN_AMBIENT,0);check(not state.tween_active,'Close cancels callbacks')
 probe.material_factory.close();probe.queue_free()
 print('SOURCE_BOARD_STATE_'+('PASS' if failures.is_empty() else 'FAIL')+' checks=',checks,' shaders=',SHADERS.size(),' source frame order and interruption covered failures=',failures)
 quit(0 if failures.is_empty() else 1)
