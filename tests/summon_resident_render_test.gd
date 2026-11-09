extends SceneTree
## Render-level regression: catches uniform reflection and vertex-data mistakes
## that checkpoint/mesh tests cannot see. Not a performance benchmark.
func _initialize():call_deferred("run")
func run():
 var Assets=load("res://scripts/native_summon_assets.gd")
 var Solver=load("res://scripts/native_summon_particles.gd")
 var Resident=load("res://scripts/summon_resident.gd")
 var assets=Assets.new();assets.setup()
 root.size=Vector2i(800,600)
 var parent=Node3D.new();root.add_child(parent)
 var camera=Camera3D.new();parent.add_child(camera);camera.position=Vector3(0,0,6);camera.current=true
 var node=Node3D.new();parent.add_child(node)
 var rec=assets.objects[Resident.KEY]
 var spec={"system":rec,"renderer":assets.component(str(rec.refs.get(".m_GameObject","")),"ParticleSystemRenderer"),"node":node}
 var a=Solver.new();var b=Solver.new()
 Resident.enabled=false;b.setup(spec,assets,parent,1900)
 Resident.enabled=true;a.setup(spec,assets,parent,1900)
 for i in 20:await process_frame
 var failed=a._resident==null or not a._resident.ready
 if not failed:
  a._resident.draw_material.get_property_list() # Reflection must not reset vec4 tint.
  for t in [.4,1.0]:
   Resident.enabled=false;b.seek(t);Resident.enabled=true;a.seek(t)
   a.mesh_instance.visible=false
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   var cpu=root.get_texture().get_image()
   a.mesh_instance.visible=true;b.mesh_instance.visible=false
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   var gpu=root.get_texture().get_image()
   var equal=cpu.get_data()==gpu.get_data()
   print("RESIDENT_RENDER_FRAME time=",t," equal=",equal)
   if not equal:
    failed=true
    cpu.save_png("res://build/resident-render-failure-cpu.png");gpu.save_png("res://build/resident-render-failure-gpu.png")
 Resident.enabled=false;a.free();b.free();parent.free()
 for i in 3:await process_frame
 if not failed:print("RESIDENT_RENDER_PARITY_PASS")
 else:push_error("RESIDENT_RENDER_PARITY_FAIL")
 quit(1 if failed else 0)
