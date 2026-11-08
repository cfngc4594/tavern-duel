extends RefCounted
## Exact per-vertex projection of the existing card bake and original selection
## plane through the registered phone camera. No screen-space guessed scale.
## The underlying face remains a bake, not an original relief actor migration.
static func source_local(pixel:Vector2,kind:String)->Vector3:
 var height=3.35 if kind=="minion" else 3.23
 var center=Vector2(-0.0553,-0.0408) if kind=="minion" else Vector2(-0.05385,-0.04296)
 return Vector3(center.x+pixel.x*height/242.0,0,center.y-pixel.y*height/242.0)
static func screen_mesh(base:ArrayMesh,hand,pose:Dictionary,kind:String,spatial,depth:float,shake:Vector2)->ArrayMesh:
 var output=ArrayMesh.new()
 for surface in range(base.get_surface_count()):
  var arrays=base.surface_get_arrays(surface)
  var vertices=PackedVector3Array()
  for vertex in arrays[Mesh.ARRAY_VERTEX]:
   # Existing baked-face and projected-selection meshes use 100px/world unit.
   var point=hand.project_local(pose,source_local(Vector2(vertex.x,-vertex.y)*100.0,kind))
   vertices.append(spatial.screen_to_world(point+shake,0)+Vector3(0,0,depth+vertex.z))
  arrays[Mesh.ARRAY_VERTEX]=vertices
  arrays[Mesh.ARRAY_NORMAL]=null;arrays[Mesh.ARRAY_TANGENT]=null
  output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return output
