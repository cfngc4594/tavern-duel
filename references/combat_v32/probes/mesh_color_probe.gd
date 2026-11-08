extends SceneTree
func _initialize():call_deferred('run')
func run():
 var assets=preload('res://scripts/native_combat_assets.gd').new();assets.setup()
 var checks=0;var failures=[];var records=[]
 for key in assets.mesh_color_channels:
  var spec=assets.mesh_color_channels[key]
  var mesh=assets.geometry(key)
  if mesh==null:failures.append('mesh missing '+key);continue
  var raw=JSON.parse_string(FileAccess.get_file_as_string(assets.BASE+assets.objects[key].files.mesh))
  var expected=raw.colors if raw.colors is Array else []
  for surface in range(mesh.get_surface_count()):
   var colors=mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
   for i in range(colors.size()):
    var want=Color.WHITE if expected.is_empty() else Color(float(expected[i][0])/float(spec.normalization_divisor),float(expected[i][1])/float(spec.normalization_divisor),float(expected[i][2])/float(spec.normalization_divisor),float(expected[i][3])/float(spec.normalization_divisor))
    checks+=1
    if not colors[i].is_equal_approx(want):failures.append(key+':'+str(i))
  records.append({'key':key,'format':spec.format,'source_color':spec.color_present,'surfaces':mesh.get_surface_count()})
 print('V32_MESH_COLOR ',JSON.stringify({'meshes':records.size(),'checks':checks,'failures':failures}))
 quit(0 if failures.is_empty() else 1)
