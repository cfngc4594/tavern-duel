extends SceneTree
class Probe extends Node3D:
 var config:Dictionary
 var data:Dictionary
 var source_light:DirectionalLight3D
 var textures:Dictionary={}
 var audit={'errors':[],'materials':[]}
func _initialize():call_deferred('_run')
func _run():
 var p=Probe.new();root.add_child(p)
 p.config=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/references/minimum_scene_config.json'))
 p.data=JSON.parse_string(FileAccess.get_file_as_string('res://original_board/assets/scene.json'))
 p.source_light=DirectionalLight3D.new();p.add_child(p.source_light)
 var old_path='/tmp/tavernduel-phone-board-p5/TavernDuel/original_board/scripts/board_materials.gd'
 var baseline=load(old_path).new();baseline.setup(p)
 var candidate=load('res://original_board/scripts/board_materials.gd').new();candidate.setup(p)
 var supported=0;var checked=0
 for key in p.data.materials:
  var old=baseline.build(key);var current=candidate.build(key)
  assert((old==null)==(current==null),'Desktop route support changed')
  if old==null:continue
  supported+=1
  for name in ['_UnitySHW','_MainLightColor','_MainLightPosition','_LightingBlend']:
   assert(old.get_shader_parameter(name)==current.get_shader_parameter(name),'Desktop initial uniform changed: '+str(key)+' '+name)
   checked+=1
  var clone=current.duplicate(false)
  candidate.register_lighting_material(clone)
  assert(clone.get_shader_parameter('_UnitySHW')==old.get_shader_parameter('_UnitySHW'))
  assert(clone.get_shader_parameter('_MainLightColor')==old.get_shader_parameter('_MainLightColor'))
 print('SOURCE_BOARD_DESKTOP_LIGHTING_PASS supported_materials=',supported,' unchanged_uniforms=',checked,' clones=',supported)
 candidate.close();baseline.owner_probe=null;baseline.animated.clear();baseline.default_textures.clear()
 p.queue_free();quit()
