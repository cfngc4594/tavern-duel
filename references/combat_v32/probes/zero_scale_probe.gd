extends SceneTree
const PS=preload('res://scripts/native_combat_particles.gd')
var checks=0
var failures=[]
func _initialize():call_deferred('run')
func ck(value,label):
 checks+=1
 if not value:failures.append(label);push_error(label)
func run():
 var ps=PS.new();root.add_child(ps);ps.simulation_time=0
 var parent=Node3D.new();root.add_child(parent)
 var child=Node3D.new();parent.add_child(child)
 var leaf=Node3D.new();child.add_child(leaf)
 parent.rotation=Vector3(.2,.7,-.1);child.rotation=Vector3(.4,-.6,.2);leaf.rotation=Vector3(.8,.1,-.2)
 for node in [parent,child,leaf]:
  for scale in [Vector3.ZERO,Vector3(0,2,3),Vector3(2,0,3),Vector3(2,3,0),Vector3(-2,3,4),Vector3.ONE*.0001]:
   node.scale=Vector3.ONE
   var healthy=leaf.global_transform
   node.scale=scale
   var collapsed=leaf.global_transform
   for reverse in [false,true]:
    ps.last_emitter=healthy if reverse else collapsed
    var destination=collapsed if reverse else healthy
    for w in [0.0,.25,.5,.75,1.0]:
     var actual=ps._birth_frame(w,1,destination)
     ck(actual.is_finite(),'finite '+str(scale)+' '+str(w))
     if w==0:ck(actual.is_equal_approx(ps.last_emitter),'exact start')
     if w==1:ck(actual.is_equal_approx(destination),'exact end')
     if ps._rotation_decomposable(collapsed.basis) and ps._rotation_decomposable(healthy.basis):ck(actual.is_equal_approx(ps.last_emitter.interpolate_with(destination,w)),'nonzero path unchanged')
   node.scale=Vector3.ONE
 ps.queue_free();parent.queue_free();await process_frame
 print('V32_ZERO_SCALE ',JSON.stringify({'checks':checks,'failures':failures}));quit(0 if failures.is_empty() else 1)
