extends SceneTree
## Real GPU parity, not a performance benchmark or whole-game fidelity proof.
## Launch on the approved isolated desktop with -- --privacy-guard-test.
## Root stays masked; only the production highlighter's offscreen textures are read.
const Highlight=preload("res://scripts/native_target_highlight_gpu.gd")
var results: Array=[]
var guard
var baseline: Dictionary
var candidate: Dictionary

func _initialize() -> void:
 call_deferred("run")

func require(ok: bool,message: String) -> bool:
 if not ok:
  push_error("TARGET_HIGHLIGHT_RENDER_FAIL "+message)
  quit(1)
 return ok

func geometry(offset: float=0.0) -> ArrayMesh:
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 # Stay inside the source depth interval, not exactly on its clipping plane.
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-0.65+offset,-0.5,-0.55),Vector3(0.55+offset,-0.5,-0.35),Vector3(-0.15+offset,-0.5,0.65)])
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func fixture(enabled: bool,source: ArrayMesh) -> Dictionary:
 var highlighter=Highlight.new();root.add_child(highlighter)
 highlighter.defer_unchanged_surface_arrays=enabled
 for kind in ["constant","multisample","multisample_blend","mask_blend"]:
  highlighter.gpu_shaders[kind]=load("res://shaders/native_target_highlight_"+kind+".gdshader")
 var actor_root:=Node3D.new();root.add_child(actor_root)
 var body:=MeshInstance3D.new();body.mesh=source;actor_root.add_child(body)
 var plane:=Node3D.new();actor_root.add_child(plane)
 var output:=MeshInstance3D.new();output.mesh=PlaneMesh.new();plane.add_child(output)
 highlighter.surfaces={"unit":{"body":{"surfaces":[{"verified":true,"eligible":true}]}},"attached":{"extra":{"surfaces":[{"verified":true,"eligible":true}]}}}
 highlighter.bindings={"models":{"unit":{"components":[{"class_name":"HighlightRender","data":{"m_SilouetteRenderSize":0.2,"m_SilouetteClipSize":0.2}}]}}}
 highlighter.entries[1]={"actor":{"root":actor_root,"renderers":{"body":body}},"kind":"unit","plane":plane,"mesh":output,"mask_key":"","material":null,"audit":{}}
 var anchor:=Node3D.new();root.add_child(anchor)
 var extra:=MeshInstance3D.new();anchor.add_child(extra)
 return {"highlight":highlighter,"root":actor_root,"body":body,"plane":plane,"anchor":anchor,"extra":extra}

func root_is_black() -> bool:
 if not require(guard.runtime_evidence().active,"Privacy guard became inactive"):return false
 var image:=root.get_texture().get_image()
 if not require(not image.is_empty(),"Missing root privacy frame"):return false
 image.convert(Image.FORMAT_RGBA8)
 var bytes:=image.get_data()
 for i in range(0,bytes.size(),4):
  if not require(bytes[i]==0 and bytes[i+1]==0 and bytes[i+2]==0 and bytes[i+3]==255,"Root is not opaque black at byte "+str(i)):return false
 return true

func digest(bytes: PackedByteArray) -> String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
 return context.finish().hex_encode()

func compare_phase(label: String,expected_updates: int) -> bool:
 var a=baseline.highlight;var b=candidate.highlight
 if not require(a.refresh(1) and b.refresh(1),label+": refresh failed"):return false
 if not require(a.entries[1].mask_key==b.entries[1].mask_key,label+": signature mismatch"):return false
 # UPDATE_ONCE passes use child-before-parent dependencies. Await real draws,
 # then verify completion bookkeeping, not just texture allocation.
 for frame in range(3):
  await process_frame
  await RenderingServer.frame_post_draw
  if not root_is_black():return false
 var ap: Dictionary=a.gpu_pipelines[1];var bp: Dictionary=b.gpu_pipelines[1]
 if not require(ap.updates==expected_updates and bp.updates==expected_updates,label+": unexpected regeneration"):return false
 if not require(ap.completed_generation==expected_updates and bp.completed_generation==expected_updates,label+": pending rendering"):return false
 var passes: Array=[]
 for i in range(10):
  var ai: Image=ap.passes[i].viewport.get_texture().get_image()
  var bi: Image=bp.passes[i].viewport.get_texture().get_image()
  if not require(not ai.is_empty() and not bi.is_empty(),label+": missing pass "+str(i)):return false
  if not require(ai.get_size()==bi.get_size() and ai.get_format()==bi.get_format(),label+": pass format mismatch "+str(i)):return false
  var ab:=ai.get_data();var bb:=bi.get_data()
  if not require(ab==bb,label+": unequal raw pixels in pass "+str(i)):return false
  var rgba: Image=ai.duplicate();rgba.convert(Image.FORMAT_RGBA8)
  var bytes: PackedByteArray=rgba.get_data();var nonzero:=0
  for n in range(0,bytes.size(),4):
   if bytes[n]>0:nonzero+=1
  if not require(nonzero>0,label+": all-black pass "+str(i)):return false
  passes.append({"pass":i+1,"label":ap.passes[i].spec.label,"width":ai.get_width(),"height":ai.get_height(),"format":ai.get_format(),"red_nonzero_pixels":nonzero,"sha256":digest(ab)})
 if not results.is_empty():
  var previous: Dictionary=results[-1]
  var pixels_changed:=false
  for i in range(10):
   if previous.passes[i].sha256!=passes[i].sha256:pixels_changed=true
  if not require(pixels_changed==(expected_updates!=int(previous.updates)),label+": pixels did not track changed/unchanged fixture"):return false
 results.append({"phase":label,"updates":expected_updates,"passes":passes})
 print("TARGET_HIGHLIGHT_RENDER_PHASE_PASS ",label," updates=",expected_updates)
 return true

func run() -> void:
 guard=root.get_node_or_null("PrivacyTestGuard")
 if not require(guard!=null and guard.runtime_evidence().active,"Requires active privacy guard (--privacy-guard-test on debug binary)"):return
 if not require(DisplayServer.get_name()!="headless","Requires real graphical renderer"):return
 root.unfocusable=true
 var source:=geometry()
 baseline=fixture(false,source);candidate=fixture(true,source)
 if not await compare_phase("initial",1):return
 if not await compare_phase("unchanged_fast_hit",1):return
 for f in [baseline,candidate]:f.body.position.x=0.17
 if not await compare_phase("source_transform",2):return
 for f in [baseline,candidate]:f.plane.position.z=0.13
 if not await compare_phase("plane_transform",3):return
 source=geometry(-0.12)
 for f in [baseline,candidate]:f.body.mesh=source
 if not await compare_phase("mesh_replacement",4):return
 var attachment:=geometry(0.25)
 for f in [baseline,candidate]:
  f.extra.mesh=attachment
  f.highlight.entries[1].attachments=[{"renderers":{"extra":f.extra},"actor_relative_anchor":f.anchor,"actor_relative_transform":Transform3D(Basis.IDENTITY,Vector3(0.15,0,0.15))}]
 if not await compare_phase("attachment_added",5):return
 for f in [baseline,candidate]:f.highlight.entries[1].attachments[0].actor_relative_transform.origin.x=-0.2
 if not await compare_phase("attachment_anchor_changed",6):return
 for f in [baseline,candidate]:f.extra.visible=false
 if not await compare_phase("attachment_hidden",7):return
 for f in [baseline,candidate]:f.highlight.entries[1].attachments=[]
 if not await compare_phase("hidden_attachment_removed_fast_hit",7):return
 var report: Dictionary={"passed":true,"scope":"Exact raw GPU pixels for ten production passes on deterministic fixture; not whole-scene or performance proof","environment":guard.runtime_evidence(),"phases":results}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--parity-output="):
   var path: String=arg.trim_prefix("--parity-output=")
   var file:=FileAccess.open(path,FileAccess.WRITE)
   if not require(file!=null,"Cannot write parity report "+path):return
   file.store_string(JSON.stringify(report,"  "));file.close()
 print("TARGET_HIGHLIGHT_DEFERRED_RENDER_PASS ",JSON.stringify(report))
 for f in [baseline,candidate]:f.root.free();f.anchor.free();f.highlight.free()
 quit()
