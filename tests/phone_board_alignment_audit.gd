extends SceneTree
const Policy=preload("res://scripts/source_board_camera_policy.gd")
func _initialize():call_deferred("run")
func run():
 var d=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/assets/scene.json"));var tr={};var pending=d.nodes.duplicate()
 while not pending.is_empty():
  for n in pending.duplicate():
   if n.parent!="" and not tr.has(n.parent):continue
   var local=Policy.raw_transform({"m_LocalPosition":n.position,"m_LocalRotation":n.rotation,"m_LocalScale":n.scale})
   tr[n.id]=(Transform3D.IDENTITY if n.parent=="" else tr[n.parent])*local;pending.erase(n)
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var vp=SubViewport.new();vp.size=Vector2i(1600,900);root.add_child(vp);var cr=Node3D.new();vp.add_child(cr);var cam=Camera3D.new();cr.add_child(cam)
 for phone in [false,true]:
  Policy.apply(cam,cr,config,Vector2(1600,900),phone)
  for n in d.nodes:
   if n.name.begins_with("HeroBackPlate"):
    print("PHONE=",phone," ",n.name," center=",cam.unproject_position(tr[n.id].origin))
 quit()
