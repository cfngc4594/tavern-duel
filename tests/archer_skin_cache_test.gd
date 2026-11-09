extends SceneTree
const SkinSolver=preload("res://scripts/native_archer_skin.gd")
const Assets=preload("res://scripts/native_combat_assets.gd")
const Source=preload("res://scripts/native_source_manifest.gd")
var failed:bool=false
func check(ok:bool,label:String):
 if not ok:failed=true;push_error("ARCHER_SKIN_CACHE_FAIL "+label)
func compare(a,b,label:String):
 check(a.skinned.size()==b.skinned.size(),label+" skin count")
 for i in range(a.skinned.size()):
  var x=a.skinned[i];var y=b.skinned[i]
  check(x.mesh.get_surface_count()==y.mesh.get_surface_count(),label+" surfaces")
  for surface in range(x.mesh.get_surface_count()):
   check(var_to_bytes(x.mesh.surface_get_arrays(surface))==var_to_bytes(y.mesh.surface_get_arrays(surface)),label+" exact arrays "+str(i))
   check(y.instance.get_surface_override_material(surface)==y.materials[surface],label+" material binding")
func _initialize():call_deferred("run")
func run():
 var assets=Assets.new();assets.setup()
 var extra:Dictionary=Source.load_manifest("res://assets/original_combat_v32/archer/manifest.json")
 assets.objects=assets.objects.duplicate();assets.objects.merge(extra.objects,true)
 for key in extra.objects:
  if extra.objects[key].type=="AnimationClip":assets.clips[key]=extra.objects[key]
 assets._prepare_render_order()
 var routes:Dictionary=Source.load_source_dictionary("res://assets/original_combat_v32/archer/routes.json").routes
 var host=Node3D.new();root.add_child(host)
 var observed:Array=[]
 for route in ["CS2_189/missile","CS2_189/impact"]:
  var variants:Array=[]
  for config in [{"cache":false,"skip":false},{"cache":true,"skip":false},{"cache":false,"skip":true},{"cache":true,"skip":true}]:
   var parent=Node3D.new();host.add_child(parent)
   var state:Dictionary=assets.instantiate(routes[route].root_key,parent)
   SkinSolver.cache_inputs=config.cache;SkinSolver.skip_unchanged=config.skip
   var skin=SkinSolver.new();skin.setup(assets,state)
   check(not skin.skinned.is_empty(),route+" real skin")
   for s in skin.skinned:
    if not observed.has(s.source):observed.append(s.source)
   variants.append({"skin":skin,"state":state,"parent":parent,"config":config})
  for frame in range(75):
   var at:float=frame/60.0
   for v in variants:
    v.parent.position=Vector3(0.1,0.2,-0.3) if frame>=20 else Vector3.ZERO
    v.parent.scale=Vector3(-1.0,0.8,1.2) if frame>=40 else Vector3.ONE
    v.parent.rotation=Vector3(0.1,0.2,0.3) if frame>=55 else Vector3.ZERO
    for clip in assets.clips:
     if str(clip).begins_with("cab-e988"):assets.sample_clip(v.state,clip,at)
    for s in v.skin.skinned:
     if not s.bones.is_empty():s.bones[0].rotation.z=sin(at)*0.15
     s.instance.visible=frame%2==0
    SkinSolver.cache_inputs=v.config.cache;SkinSolver.skip_unchanged=v.config.skip
    v.skin._skin()
    # Repeated same-pose sample exercises exact matrix skip.
    v.skin._skin()
   for i in range(1,variants.size()):compare(variants[0].skin,variants[i].skin,route+" frame"+str(frame)+" variant"+str(i))
  # Source mesh notification invalidates the template/matrix cache.
  for source in observed:
   var changed_surfaces:Array=[]
   for surface in range(source.get_surface_count()):
    var arrays:Array=source.surface_get_arrays(surface)
    if arrays[Mesh.ARRAY_TEX_UV]!=null and arrays[Mesh.ARRAY_TEX_UV].size()>0:
     arrays[Mesh.ARRAY_TEX_UV][0]+=Vector2(0.125,0.25)
    changed_surfaces.append(arrays)
   source.clear_surfaces()
   for arrays in changed_surfaces:source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   source.emit_changed()
  for v in variants:
   for s in v.skin.skinned:
    if not s.materials.is_empty():s.materials[0]=StandardMaterial3D.new()
   SkinSolver.cache_inputs=v.config.cache;SkinSolver.skip_unchanged=v.config.skip;v.skin._skin()
  for i in range(1,variants.size()):compare(variants[0].skin,variants[i].skin,route+" source changed/material replace")
  # Parsed JSON inputs are explicitly immutable until owner invalidation.
  for v in variants:
   for s in v.skin.skinned:
    s.data.vertices[0][0]+=0.03125
    if not s.data.bone_weights[0].is_empty():s.data.bone_weights[0][0]*=0.875
   v.skin.invalidate_inputs()
   SkinSolver.cache_inputs=v.config.cache;SkinSolver.skip_unchanged=v.config.skip;v.skin._skin()
  for i in range(1,variants.size()):compare(variants[0].skin,variants[i].skin,route+" explicit data invalidation")
  # Replacing the source object must reconnect and invalidate automatically.
  for v in variants:
   for s in v.skin.skinned:
    var replacement=ArrayMesh.new()
    for surface in range(s.source.get_surface_count()):
     var arrays:Array=s.source.surface_get_arrays(surface)
     if arrays[Mesh.ARRAY_TEX_UV]!=null and arrays[Mesh.ARRAY_TEX_UV].size()>0:arrays[Mesh.ARRAY_TEX_UV][0]+=Vector2(0.0625,0.125)
     replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    s.source=replacement;observed.append(replacement)
   SkinSolver.cache_inputs=v.config.cache;SkinSolver.skip_unchanged=v.config.skip;v.skin._skin()
  for i in range(1,variants.size()):compare(variants[0].skin,variants[i].skin,route+" source object replacement")
  # Same instance: cached A -> baseline B -> restored A cached.
  # Compare against baseline at the exact restored live transforms, not against
  # pre-roundtrip bytes. Bones can be shared between multiple skin surfaces.
  var toggled=variants[3].skin
  SkinSolver.cache_inputs=true;SkinSolver.skip_unchanged=true;toggled._skin()
  var poses:Dictionary={}
  for s in toggled.skinned:
   poses[s.node]=s.node.transform
   for bone in s.bones:poses[bone]=bone.transform
  for node in poses:node.position+=Vector3(0.03125,0.125,-0.0625)
  SkinSolver.cache_inputs=false;SkinSolver.skip_unchanged=false;toggled._skin()
  for s in toggled.skinned:
   check(s.cache.last_matrices.is_empty(),route+" baseline invalidates cached pose")
  for node in poses:node.transform=poses[node]
  SkinSolver.cache_inputs=true;SkinSolver.skip_unchanged=true;toggled._skin()
  var restored_arrays:Array=[]
  for s in toggled.skinned:
   var surfaces:Array=[]
   for surface in range(s.mesh.get_surface_count()):surfaces.append(var_to_bytes(s.mesh.surface_get_arrays(surface)))
   restored_arrays.append(surfaces)
  toggled._skin_baseline()
  for i in range(toggled.skinned.size()):
   for surface in range(toggled.skinned[i].mesh.get_surface_count()):
    check(var_to_bytes(toggled.skinned[i].mesh.surface_get_arrays(surface))==restored_arrays[i][surface],route+" cache/baseline/cache exact restored pose")
  for v in variants:v.skin=null
  variants.clear()
 SkinSolver.cache_inputs=false;SkinSolver.skip_unchanged=false
 host.free()
 for source in observed:
  for connection in source.changed.get_connections():
   check(connection.callable.get_method()!="invalidate","cache observer released")
 if not failed:print("ARCHER_SKIN_CACHE_PASS exact surface bytes all four modes, repeated poses, transforms, source invalidation, materials, cleanup")
 quit(1 if failed else 0)