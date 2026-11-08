extends SceneTree
func _initialize():call_deferred('run')
func run():
 var a=preload('res://scripts/native_combat_assets.gd').new();a.setup();var checks:=0;var failures: Array=[]
 var routes=JSON.parse_string(FileAccess.get_file_as_string('res://references/combat_v32/runtime_routes.json')).routes
 for route in ['CS2_025/friendly_area','CS2_062/friendly_area']:
  var parent:=Node3D.new();root.add_child(parent);var state=a.instantiate(routes[route].root_key,parent);state.lights={}
  for key in state.nodes:
   if not a.component(key,'Light').is_empty():
    var light:=OmniLight3D.new();state.nodes[key].add_child(light);state.lights[key]=light
  var name: String='FX_ArcaneExplosion1' if route.begins_with('CS2_025') else 'FX_HellfireShockwaves'
  var clip=a.clips[name];var target_key: String=''
  for schedule in routes[route].event_schedules.values():
   for step in schedule.state_enter_schedule:
    for action in step.actions:
     if action.get('clip_key','')==clip.key:target_key=action.target_object_key
  var target_path: String=str(state.root.get_path_to(state.nodes[target_key]))
  if target_path=='.':target_path=''
  # The clip target is Root, matching original relative path binding.
  for track in clip.data.m_FloatCurves:
   if int(track.classID)!=108:continue
   var node=state.paths[target_path+'/'+str(track.path)];var light=state.lights[node.get_meta('source_key')]
   for sample in track.curve.m_Curve:
    a.sample_clip(state,name,float(sample.time),target_path);checks+=1
    var actual=light.light_energy if track.attribute=='m_Intensity' else (1.0 if light.visible else 0.0)
    var expected=float(sample.value) if track.attribute=='m_Intensity' else (1.0 if float(sample.value)>=0.5 else 0.0)
    if absf(actual-expected)>0.00001:failures.append(name+':'+str(track.attribute)+':'+str(sample.time))
  parent.free()
 print('V32_LIGHT_CLIPS ',JSON.stringify({'checks':checks,'failures':failures}))
 FileAccess.open('/tmp/v32_light_clip_probe.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failures':failures},'  '));quit(0 if failures.is_empty() else 1)
