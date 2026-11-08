extends SceneTree
var checks:=0
var failures: Array=[]
var rows: Array=[]
class ParticleStub:
 extends RefCounted
 var playback_speed:=1.0
 var calls: Array=[]
 var mesh_instance: MeshInstance3D
 func set_playback_speed(value,at):playback_speed=value;calls.append([value,at])
func check(value: bool,label: String):
 checks+=1
 if not value:failures.append(label)
func _initialize():call_deferred('run')
func run():
 var assets=preload('res://scripts/native_combat_assets.gd').new();assets.setup()
 var routes=JSON.parse_string(FileAccess.get_file_as_string('res://references/combat_v32/runtime_routes.json')).routes
 var roots: Dictionary={}
 for route in routes:roots[routes[route].root_key]=route
 for label in assets.manifest.root_labels:
  if str(label).begins_with("attack_") and assets.objects[assets.manifest.root_labels[label]].type=="GameObject":roots[assets.manifest.root_labels[label]]=label
 for key in roots:
  var parent:=Node3D.new();root.add_child(parent)
  var state: Dictionary=assets.instantiate(key,parent);state.particle_players={}
  var component=preload('res://scripts/native_combat_components.gd').new();component.setup(state,assets,7783)
  var before: Dictionary={}
  for r in component.records:before[r.source_key]=state.source_rotations[r.key]
  component.update(0.1);component.late_update(0.1)
  for r in component.records:
   var node: Node3D=state.nodes[r.key]
   if r.class_name=='RotateOverTime':
    var expected: Quaternion=before[r.source_key]
    if r.active:
     expected=expected*Quaternion(Vector3.LEFT,deg_to_rad(float(r.data.RotateSpeedX)*0.1))*Quaternion(Vector3.UP,deg_to_rad(float(r.data.RotateSpeedY)*0.1))*Quaternion(Vector3.BACK,deg_to_rad(float(r.data.RotateSpeedZ)*0.1))
    check(absf(expected.normalized().dot(state.source_rotations[r.key]))>0.999999,roots[key]+':'+r.source_key+' local rotation')
   if r.class_name=='ScrollingUVs':check(not r.active and r.offset==Vector2.ZERO,'disabled scrolling')
   if r.class_name=='SetRenderQue' and r.active:
    var renderer: Dictionary=assets.component(r.key,'MeshRenderer')
    if renderer.is_empty():renderer=assets.component(r.key,'ParticleSystemRenderer')
    if not renderer.is_empty():check(component.sorting_orders[r.key]==int(renderer.data.m_SortingOrder)+int(r.data.queue),'sort once')
   if r.class_name=='ParticlePlaybackSpeed' and r.active:
    for pk in r.captured:check(component.particle_speeds[pk]==1.5,'absolute source speed')
   rows.append({'route':roots[key],'source_key':r.source_key,'class_name':r.class_name,'active':r.active})
  var q: Dictionary={}
  for r in component.records:q[r.source_key]=state.source_rotations[r.key]
  component.update(0.1);component.late_update(0.1)
  for r in component.records:check(absf(q[r.source_key].dot(state.source_rotations[r.key]))>0.999999,'same-age no extra rotation')
  # Source lifecycle excludes inactive descendants and preserves one-time Start.
  state.root.visible=false;component.update(0.2)
  for r in component.records:check(not r.active,'inactive root stops Update')
  state.root.visible=true;component.update(0.3)
  for r in component.records:check(r.starts<=1,'Start must not repeat')
  component.dispose(0.3);parent.free();component=null
 # Synthetic zero-scale rotation retains exact scale and causes no Quaternion error.
 var holder:=Node3D.new();root.add_child(holder);var node:=Node3D.new();holder.add_child(node);node.scale=Vector3.ZERO
 var component=preload('res://scripts/native_combat_components.gd').new()
 component._rotate_local(node,Vector3.LEFT,45);check(node.scale==Vector3.ZERO,'zero authored scale retained');holder.free()
 print('V32_COMPONENTS ',JSON.stringify({'checks':checks,'failures':failures,'rows':rows.size()}))
 FileAccess.open('/tmp/v32_component_probe.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failures':failures,'rows':rows},'  '))
 quit(0 if failures.is_empty() else 1)
