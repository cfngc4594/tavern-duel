extends RefCounted
## Exact source BoxCollider OBBs, phone TransformOverride selected before world TRS.
const Hand=preload("res://scripts/native_phone_hand.gd")
static var rows:Dictionary={}
static func source_rows()->Dictionary:
 if rows.is_empty():rows=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_input_hitboxes.json")).rows
 return rows
static func hit_ray(ray:Dictionary,layer:int,active_overrides:Dictionary={},only_name:String="")->Dictionary:
 if ray.is_empty():return {}
 var nearest={};var distance=INF
 for key in source_rows():
  var row=rows[key];var name=str(row.chain_child_to_root[0])
  if int(row.layer)!=layer or (not only_name.is_empty() and name!=only_name):continue
  var active=true
  for member in row.serialized_active_chain:
   active=active and bool(active_overrides.get(member.name,member.active))
  if not active:continue
  var m=row.phone_world_matrix
  var transform=Transform3D(Basis(Vector3(m[0][0],m[1][0],m[2][0]),Vector3(m[0][1],m[1][1],m[2][1]),Vector3(m[0][2],m[1][2],m[2][2])),Vector3(m[0][3],m[1][3],m[2][3]))
  var inverse=transform.affine_inverse()
  for collider in row.colliders:
   if not collider.enabled or collider.type!="BoxCollider":continue
   var data=collider.data
   var size=Vector3(data.m_Size.x,data.m_Size.y,data.m_Size.z)
   var center=Vector3(data.m_Center.x,data.m_Center.y,data.m_Center.z)
   var local_hit=AABB(center-size*.5,size).intersects_ray(inverse*ray.origin,inverse.basis*ray.direction)
   if local_hit==null:continue
   var world=transform*local_hit;var d=ray.origin.distance_squared_to(world)
   if d<distance:distance=d;nearest={"position":world,"name":name,"layer":layer}
 return nearest
static func hit(context,point:Vector2,layer:int,active_overrides:Dictionary={},only_name:String="")->Dictionary:
 return hit_ray(context.screen_ray_to_source(point),layer,active_overrides,only_name)
