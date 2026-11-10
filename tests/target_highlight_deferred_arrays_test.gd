extends SceneTree
## CPU-only regression for the default-off readback deferral. No GPU pass renders.

class Probe:
 extends "res://scripts/native_target_highlight_gpu.gd"
 var reads: int=0
 var updates: int=0
 var sources: Array=[]
 func _read_deferred_surface(mesh: Mesh,surface: int) -> Array:
  reads+=1
  return super._read_deferred_surface(mesh,surface)
 func _project_source(selected: Array,_plane: Transform3D,_plane_mesh: Mesh,_render_size: float,_clip_size: float) -> Dictionary:
  sources=selected.duplicate(true)
  return {"audit":{}}
 func _create_pipeline(_id,_shape: Dictionary) -> Dictionary:
  var viewport:=SubViewport.new()
  add_child(viewport)
  var passes: Array=[]
  for i in range(10):passes.append({"viewport":viewport})
  return {"passes":passes,"audit":[]}
 func _update_pipeline(_pipeline: Dictionary,_shape: Dictionary) -> void:
  updates+=1

class ScriptedMesh:
 extends ArrayMesh

func _initialize() -> void:
 call_deferred("run")

func triangle(offset: float=0.0) -> ArrayMesh:
 var mesh:=ArrayMesh.new()
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(offset,0,0),Vector3(1+offset,0,0),Vector3(offset,1,0)])
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func fixture(enabled: bool) -> Dictionary:
 var probe:=Probe.new();root.add_child(probe)
 probe.defer_unchanged_surface_arrays=enabled
 var actor_root:=Node3D.new();root.add_child(actor_root)
 var mi:=MeshInstance3D.new();mi.mesh=triangle();actor_root.add_child(mi)
 var plane:=Node3D.new();actor_root.add_child(plane)
 var output:=MeshInstance3D.new();output.mesh=PlaneMesh.new();plane.add_child(output)
 probe.surfaces={"unit":{"body":{"surfaces":[{"verified":true,"eligible":true}]}},"attached":{"extra":{"surfaces":[{"verified":true,"eligible":true}]}}}
 probe.bindings={"models":{"unit":{"components":[{"class_name":"HighlightRender","data":{"m_SilouetteRenderSize":1.0,"m_SilouetteClipSize":1.0}}]}}}
 probe.entries[1]={"actor":{"root":actor_root,"renderers":{"body":mi}},"kind":"unit","plane":plane,"mesh":output,"mask_key":"","material":null,"audit":{}}
 return {"probe":probe,"root":actor_root,"mi":mi,"plane":plane}

func run() -> void:
 var baseline=fixture(false)
 var candidate=fixture(true)
 var a=baseline.probe;var b=candidate.probe
 var defaults:=Probe.new()
 assert(not defaults.defer_unchanged_surface_arrays)
 defaults.free()
 baseline.mi.mesh=candidate.mi.mesh
 assert(a.refresh(1) and b.refresh(1))
 assert(b.reads==1 and b.updates==1)
 assert(a.sources[0].vertices==b.sources[0].vertices)
 assert(a.sources[0].indices==b.sources[0].indices)
 assert(a.entries[1].mask_key==b.entries[1].mask_key)
 var key: String=b.entries[1].mask_key
 assert(b.refresh(1));assert(b.reads==1 and b.updates==1)
 assert(b.entries[1].mask_key==key)
 # Transforms and source plane changes must re-read fresh arrays.
 candidate.mi.position.x=2
 baseline.mi.position.x=2
 assert(b.refresh(1));assert(b.reads==2 and b.updates==2)
 assert(a.refresh(1));assert(a.entries[1].mask_key==b.entries[1].mask_key)
 assert(b.sources[0].transform.origin.x==2)
 candidate.plane.position.y=1
 baseline.plane.position.y=1
 assert(b.refresh(1));assert(b.reads==3 and b.updates==3)
 assert(a.refresh(1));assert(a.entries[1].mask_key==b.entries[1].mask_key)
 candidate.mi.mesh=triangle(4)
 baseline.mi.mesh=candidate.mi.mesh
 assert(b.refresh(1));assert(b.reads==4 and b.updates==4)
 assert(a.refresh(1));assert(a.entries[1].mask_key==b.entries[1].mask_key)
 assert(b.sources[0].vertices[0].x==4)
 # Same-RID edits keep the preexisting signature semantics, in both paths.
 key=b.entries[1].mask_key
 candidate.mi.mesh.clear_surfaces()
 assert(not b.refresh(1));assert(b.reads==4)
 assert(not a.refresh(1))
 assert(b.blockers[-1].begins_with("No visible original"))
 candidate.mi.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle(8).surface_get_arrays(0))
 assert(b.refresh(1));assert(b.entries[1].mask_key==key and b.reads==4)
 assert(a.refresh(1));assert(a.entries[1].mask_key==key and a.updates==4)
 # Even an unchanged mask must not bypass visibility or verification checks.
 candidate.mi.visible=false
 assert(not b.refresh(1));assert(b.reads==4)
 candidate.mi.visible=true
 b.surfaces.unit.body.surfaces[0].verified=false
 assert(not b.refresh(1));assert(b.blockers[-1].begins_with("Unverified silhouette"))
 b.surfaces.unit.body.surfaces[0].verified=true
 b.surfaces.unit.body.surfaces[0].eligible=false
 assert(not b.refresh(1))
 b.surfaces.unit.body.surfaces[0].eligible=true
 # Attachment add/remove and actor-relative transforms are part of selection.
 var extra:=MeshInstance3D.new();extra.mesh=triangle(10);candidate.root.add_child(extra)
 b.entries[1].attachments=[{"renderers":{"extra":extra}}]
 assert(b.refresh(1));assert(b.reads==6 and b.sources.size()==2)
 extra.position.z=3
 assert(b.refresh(1));assert(b.reads==8 and b.sources[1].transform.origin.z==3)
 b.entries[1].attachments=[]
 assert(b.refresh(1));assert(b.reads==9 and b.sources.size()==1)
 # Uncertain mesh kinds retain the eager path. No cache grows with resources.
 var primitive:=BoxMesh.new()
 assert(not b._can_defer_surface_arrays(primitive,0))
 var scripted:=ScriptedMesh.new()
 scripted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle().surface_get_arrays(0))
 assert(not b._can_defer_surface_arrays(scripted,0))
 candidate.mi.mesh=primitive
 assert(b.refresh(1));assert(b.reads==9)
 assert(b.sources[0].vertices==primitive.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
 candidate.mi.mesh=scripted
 assert(b.refresh(1));assert(b.reads==9)
 assert(b.sources[0].vertices==scripted.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
 # An attachment can live outside the actor and supply an explicit anchor.
 candidate.mi.mesh=triangle()
 var anchor:=Node3D.new();root.add_child(anchor)
 extra.reparent(anchor,false)
 b.entries[1].attachments=[{"renderers":{"extra":extra},"actor_relative_anchor":anchor,"actor_relative_transform":Transform3D(Basis.IDENTITY,Vector3(7,0,0))}]
 assert(b.refresh(1));assert(b.sources[1].transform.origin==Vector3(7,0,3))
 var reads_before: int=b.reads
 b.surfaces.attached.extra.surfaces[0].verified=false
 assert(not b.refresh(1));assert(b.reads==reads_before)
 b.surfaces.attached.extra.surfaces[0].verified=true
 b.entries[1].attachments[0].actor_relative_transform.origin.x=9
 assert(b.refresh(1));assert(b.sources[1].transform.origin.x==9)
 b.entries[1].attachments=[]
 anchor.free()
 candidate.mi.mesh=null
 assert(not b.refresh(1))
 baseline.root.free();candidate.root.free();a.free();b.free()
 print("TARGET_HIGHLIGHT_DEFERRED_ARRAYS_PASS")
 quit()
