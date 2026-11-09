extends SceneTree
const Solver=preload("res://scripts/native_combat_particles.gd")
var failed:=false
var checks:=0
func require(ok:bool,label:String):
 if not ok:push_error("MESH_SURFACE_CACHE_FAIL "+label);failed=true
func arrays(offset:float,complete:bool=true)->Array:
 var a:Array=[];a.resize(Mesh.ARRAY_MAX)
 a[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(offset,0,0),Vector3(offset+1,0,0),Vector3(offset,1,0)])
 if complete:
  a[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK])
  a[Mesh.ARRAY_COLOR]=PackedColorArray([Color(.2,.3,.4,.5),Color(.8,.7,.6,.9),Color.WHITE])
  a[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN])
  a[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
 return a
func compare(reference,cached,label:String):
 for frame in [Transform3D.IDENTITY,Transform3D(Basis.from_euler(Vector3(.2,-.3,.6)).scaled(Vector3(1.3,.5,-.8)),Vector3(.4,-.2,.9)),Transform3D(Basis.from_scale(Vector3.ZERO),Vector3(1,2,3))]:
  for color in [Color.WHITE,Color(.3,.7,.2,.4)]:
   for first in [0,17]:
    Solver.mesh_surface_cache_enabled=false
    var expected:Dictionary=reference._mesh_particle_geometry(frame,color,first)
    Solver.mesh_surface_cache_enabled=true
    var actual:Dictionary=cached._mesh_particle_geometry(frame,color,first)
    require(var_to_bytes(expected)==var_to_bytes(actual),label+" exact output arrays")
    checks+=1
func _initialize():call_deferred("run")
func run():
 var reference=Solver.new();var cached=Solver.new()
 var source:=ArrayMesh.new();source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(0))
 source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(2,false))
 reference.source_render_mesh=source;cached.source_render_mesh=source
 compare(reference,cached,"initial/repeated multisurface")
 require(cached._cached_renderer_surfaces_valid,"cache populated")
 require(cached._cached_renderer_surfaces.size()==2,"both surfaces retained")
 # A normal geometry rebuild changes contents without changing final surface count.
 source.clear_surfaces()
 source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(5))
 source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(9,false))
 compare(reference,cached,"same-count rebuild")
 source.emit_changed()
 require(not cached._cached_renderer_surfaces_valid,"changed signal invalidates")
 compare(reference,cached,"explicit changed refresh")
 var replacement:=ArrayMesh.new();replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(-3,false))
 reference.source_render_mesh=replacement;cached.source_render_mesh=replacement
 compare(reference,cached,"mesh identity replacement")
 require(not source.changed.is_connected(cached._invalidate_renderer_surface_cache),"old mesh disconnected")
 replacement.clear_surfaces()
 compare(reference,cached,"empty mesh")
 require(cached._cached_renderer_surfaces.is_empty(),"empty cache")
 replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(7))
 compare(reference,cached,"empty to nonempty")
 reference.source_render_mesh=null;cached.source_render_mesh=null
 compare(reference,cached,"null mesh")
 require(cached._cached_renderer_mesh==null,"null releases previous source")
 require(not replacement.changed.is_connected(cached._invalidate_renderer_surface_cache),"null disconnects source")
 reference.source_render_mesh=source;cached.source_render_mesh=source
 compare(reference,cached,"restore source")
 Solver.mesh_surface_cache_enabled=false
 cached._mesh_particle_geometry(Transform3D.IDENTITY,Color.WHITE,0)
 require(cached._cached_renderer_mesh==null,"disabled releases cache ownership")
 require(not source.changed.is_connected(cached._invalidate_renderer_surface_cache),"disabled disconnects source")
 reference.free();cached.free()
 if not failed:print("MESH_SURFACE_CACHE_PASS comparisons=",checks," exact geometry; rebuild/changed/replacement/empty/null/disabled")
 quit(1 if failed else 0)
