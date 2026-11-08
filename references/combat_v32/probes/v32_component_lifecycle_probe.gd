extends SceneTree
var checks:=0
var failures: Array=[]
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
 var parent:=Node3D.new();root.add_child(parent)
 var component=preload('res://scripts/native_combat_components.gd').new()
 component.state={'source_rotations':{}}
 var node:=Node3D.new();parent.add_child(node);node.set_meta('source_key','test')
 for scale in [Vector3.ZERO,Vector3(0,2,3),Vector3(-2,0,3),Vector3(-2,4,-3),Vector3(0.00000001,2,3)]:
  var q:=Quaternion.from_euler(Vector3(0.2,0.3,0.4));component.state.source_rotations.test=q;node.quaternion=q;node.scale=scale
  var expected:=q
  for i in range(5):
   component._rotate_local(node,Vector3.LEFT,17);component._rotate_local(node,Vector3.UP,23);component._rotate_local(node,Vector3.BACK,-11)
   expected=(expected*Quaternion(Vector3.LEFT,deg_to_rad(17))*Quaternion(Vector3.UP,deg_to_rad(23))*Quaternion(Vector3.BACK,deg_to_rad(-11))).normalized()
   check(absf(expected.dot(component.state.source_rotations.test))>0.999999,'independent quaternion accumulated')
   check(node.basis.x.length()<0.000000001 if scale.x==0 else absf(node.basis.x.length()-absf(scale.x))<0.00001,'preserve X length')
   check(node.basis.y.length()<0.000000001 if scale.y==0 else absf(node.basis.y.length()-absf(scale.y))<0.00001,'preserve Y length')
   check(node.basis.z.length()<0.000000001 if scale.z==0 else absf(node.basis.z.length()-absf(scale.z))<0.00001,'preserve Z length')
  node.scale=Vector3(1,2,3)
  component._rotate_local(node,Vector3.UP,19);expected=(expected*Quaternion(Vector3.UP,deg_to_rad(19))).normalized()
  check(absf(expected.dot(node.quaternion))>0.999999,'restored scale retains all rotation')
 parent.free()
 # Test actual source speed owner, without changing production manifest.
 var route={'root_key':assets.manifest.root_labels.attack_friendly}
 parent=Node3D.new();root.add_child(parent)
 var state=assets.instantiate(route.root_key,parent);state.particle_players={}
 component=preload('res://scripts/native_combat_components.gd').new();component.setup(state,assets,735)
 var owners=component.records.filter(func(r):return r.class_name=='ParticlePlaybackSpeed' and r.active)
 check(not owners.is_empty(),'actual active speed owner')
 for record in owners:
  var captured: Dictionary=record.captured.duplicate();component.update(0.0)
  for key in captured:
   var stub=ParticleStub.new();state.particle_players[key]={'node':stub,'start':0.2};component.on_particle_created(key,state.particle_players[key])
   check(stub.playback_speed==1.5,'late Play sees source Update speed')
   check(stub.calls==[[1.5,0.0]],'late creation begins at age zero')
  record.data.m_RestoreSpeedOnDisable=true
  component.set_enabled(record.key,'ParticlePlaybackSpeed',false,0.3)
  for key in captured:
   check(state.particle_players[key].node.playback_speed==captured[key],'OnDisable restores captured absolute speed')
   check(absf(state.particle_players[key].node.calls[-1][1]-0.1)<0.0000001,'restore uses local player time')
  component.set_enabled(record.key,'ParticlePlaybackSpeed',true,0.4);component.update(0.4)
  for key in captured:check(state.particle_players[key].node.playback_speed==1.5,'OnEnable resets previous sentinel')
  check(record.starts==1,'Start only once across reenabling')
 component.dispose(0.5);state.particle_players.clear();parent.free()
 print('V32_COMPONENT_LIFECYCLE ',JSON.stringify({'checks':checks,'failures':failures}))
 FileAccess.open('/tmp/v32_component_lifecycle_probe.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failures':failures},'  '))
 quit(0 if failures.is_empty() else 1)
