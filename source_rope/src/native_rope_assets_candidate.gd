extends 'res://scripts/native_rope_assets.gd'
## Independent candidate, NOT installed in native_rope.gd or the APK.
## The source spiral material is CullBack. Adapt its triangle handedness for
## the existing single Unity->Godot reflection, as the verified card/history path.
## Wick and shadow source materials are CullOff and retain original indices.
const SPIRAL_MESH='cab-66e7137de3b79380e05eb711ae004556:1059280820689413847'
var mirrored_geometry:Dictionary={}
func geometry(key:String)->ArrayMesh:
 var original:ArrayMesh=super.geometry(key)
 if original==null or key!=SPIRAL_MESH:return original
 if mirrored_geometry.has(key):return mirrored_geometry[key]
 var converted:=ArrayMesh.new()
 for surface in range(original.get_surface_count()):
  var arrays:Array=original.surface_get_arrays(surface)
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for index in range(0,indices.size(),3):
   var second=indices[index+1];indices[index+1]=indices[index+2];indices[index+2]=second
  arrays[Mesh.ARRAY_INDEX]=indices
  converted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 converted.set_meta('source_mesh',key)
 converted.set_meta('source_cull','CullBack with mirrored-root index adaptation; Android not yet verified')
 mirrored_geometry[key]=converted
 return converted
