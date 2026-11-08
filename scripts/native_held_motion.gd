extends RefCounted
## InputManager.PositionHeldCard: direct hit on original layer9 DragPlane.
## Original GrabCard ScaleTo(.7,.2), default iTween easeOutExpo.
const PLANE="cab-995e7cbc44ff3e7f4314fc93360989d0:6104921002894357617"
const MESH="res://original_board/assets/meshes/MoP_DragPlane__3592162201817902808.mesh.json"
const HAND_SCALE=0.699999988079071
const SCALE_SECONDS=0.20000000298023224
var game
var triangle_vertices:=PackedVector3Array()
var source_mesh_file:=""
func setup(host):
 game=host
 _load_source_mesh(MESH)
func _load_source_mesh(path:String)->void:
 triangle_vertices.clear();source_mesh_file=path
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 for sub in data.triangles:
  for tri in sub:
   for index in tri:
    var v=data.vertices[int(index)];triangle_vertices.append(Vector3(v[0],v[1],-v[2]))
func hit(board_pointer:Vector2)->Dictionary:
 if not is_instance_valid(game.original_board_bridge):return {}
 var bridge=game.original_board_bridge
 if not is_instance_valid(bridge.probe) or not is_instance_valid(bridge.probe.camera):return {}
 var probe=bridge.probe
 var plane_id=str(probe.get_meta("source_drag_plane_id",PLANE))
 var mesh_file=str(probe.get_meta("source_drag_plane_mesh_file",MESH))
 if not probe.source_nodes.has(plane_id):return {}
 if source_mesh_file!=mesh_file:_load_source_mesh(mesh_file)
 var node:Node3D=probe.source_nodes[plane_id]
 var camera:Camera3D=probe.camera
 var point=(board_pointer+game.presentation_offset)*Vector2(bridge.viewport.size)/game.presentation_size
 var inverse=node.global_transform.affine_inverse()
 var origin=inverse*camera.project_ray_origin(point)
 var direction=inverse.basis*camera.project_ray_normal(point)
 var nearest=null;var distance=INF
 for i in range(0,triangle_vertices.size(),3):
  var result=Geometry3D.ray_intersects_triangle(origin,direction,triangle_vertices[i],triangle_vertices[i+1],triangle_vertices[i+2])
  if result!=null and origin.distance_squared_to(result)<distance:
   nearest=result;distance=origin.distance_squared_to(result)
 if nearest==null:return {}
 var world=node.global_transform*nearest
 return {"world":world,"source_world":Vector3(world.x,world.y,-world.z),"camera":camera,"viewport_size":Vector2(bridge.viewport.size)}
func board_projection(camera:Camera3D,world:Vector3,viewport_size:Vector2)->Vector2:
 return camera.unproject_position(world)*game.presentation_size/viewport_size-game.presentation_offset
static func source_scale_at(start:float,age:float)->float:
 var t=clampf(age/SCALE_SECONDS,0.0,1.0)
 return HAND_SCALE if t>=1.0 else lerpf(start,HAND_SCALE,1.0-pow(2.0,-10.0*t))
func apply(card:Dictionary,board_pointer:Vector2,dt:float)->bool:
 var sampled=hit(board_pointer)
 if sampled.is_empty():return false # Source leaves the last transform if ray misses.
 var camera:Camera3D=sampled.camera
 var height=3.35 if game.definitions[card.key].kind=="minion" else 3.23
 var center=board_projection(camera,sampled.world,sampled.viewport_size)
 var x=board_projection(camera,sampled.world+Vector3.RIGHT,sampled.viewport_size)-center
 var y=board_projection(camera,sampled.world+Vector3(0,0,-1),sampled.viewport_size)-center
 var unit_scale=Vector2(x.length(),y.length())*height/242.0
 if not card.has("source_grab_age"):
  card.source_grab_age=0.0
  # Preserve visible pickup size when converting the existing baked hand into
  # source units; source phone hand-enlargement is a separate unfinished route.
  card.source_grab_start_scale=float(card.scale)/maxf(unit_scale.y,0.0001)
 card.source_grab_age+=dt
 var scale_value=source_scale_at(float(card.source_grab_start_scale),float(card.source_grab_age))
 var camera_offset=Vector3(-0.0553,0,0.0408) if height==3.35 else Vector3(-0.05385,0,0.04296)
 var pose_pos=board_projection(camera,sampled.world+camera_offset*scale_value,sampled.viewport_size)
 card.pos=center;card.scale=unit_scale.y*scale_value;card.angle=0.0;card.spring=Vector2.ZERO
 card.source_world_position=sampled.source_world
 card.source_held_face_pose={"pos":pose_pos,"scale":unit_scale*scale_value,"angle":0.0}
 return true
