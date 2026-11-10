extends "native_target_highlight.gd"
## GPU draft: source 5 constant raster + 5 postprocess passes, no CPU pixel loop.
## Source projection/depth clipping happen on actual mesh vertices on CPU.
## Canvas GPU triangle raster and RGBA8 red-for-R8 are explicit compatibility.
## Nested viewports encode strict dependency order: deepest source pass first.
var gpu_pipelines: Dictionary={}
var gpu_shader_directory: String="res://shaders/"
var gpu_shaders: Dictionary={}
var gpu_serial: int=0
var gpu_frame_pending: bool=false
# Whole-scene A/B improves average load but not all hitch tails; keep disabled.
# No geometry cache: changed signatures still read the current mesh arrays.
var defer_unchanged_surface_arrays: bool=false

func setup(game: Node, source_assets, source_base: String = "res://assets/original_targeting_v34/") -> void:
 super.setup(game,source_assets,source_base)
 if not FileAccess.file_exists(gpu_shader_directory+"native_target_highlight_constant.gdshader"):
  gpu_shader_directory=get_script().resource_path.get_base_dir()+"/shaders/"
 for kind in ["constant","multisample","multisample_blend","mask_blend"]:
  gpu_shaders[kind]=load(gpu_shader_directory+"native_target_highlight_"+kind+".gdshader")

func refresh(id) -> bool:
 var e: Dictionary=entries[id]
 var actor: Dictionary=e.actor
 var root: Node3D=actor.root
 var plane: Node3D=e.plane
 var plane_local: Transform3D=relative_transform(plane,root)
 var selected: Array=[]
 var signature_parts: Array=[e.kind,str(plane_local)]
 var candidates: Array=[]
 for key in actor.get("renderers",{}):candidates.append({"key":str(key),"mesh":actor.renderers[key],"routes":surfaces[e.kind]})
 for instance in e.get("attachments",[]):
  for key in instance.get("renderers",{}):
   var attachment_candidate: Dictionary={"key":str(key),"mesh":instance.renderers[key],"routes":surfaces.get("attached",{})}
   if instance.has("actor_relative_anchor"):
    attachment_candidate.relative_anchor=instance.actor_relative_anchor
    attachment_candidate.anchor_to_actor=instance.get("actor_relative_transform",Transform3D.IDENTITY)
   candidates.append(attachment_candidate)
 for candidate in candidates:
  var key: String=candidate.key
  var mi=candidate.mesh
  if not mi is MeshInstance3D or mi.mesh==null or not mi.is_visible_in_tree():continue
  var route: Dictionary=candidate.routes.get(key,{})
  if route.is_empty():continue
  var local: Transform3D=_surface_relative(candidate,root)
  for i in range(mini(mi.mesh.get_surface_count(),route.surfaces.size())):
   if not bool(route.surfaces[i].get("verified",false)):
    _block("Unverified silhouette material "+str(route.surfaces[i]));return false
   if not bool(route.surfaces[i].eligible):continue
   var source: Dictionary={"source_key":key,"surface_index":i,"transform":local}
   if defer_unchanged_surface_arrays and _can_defer_surface_arrays(mi.mesh,i):
    source.deferred_mesh=mi.mesh
   else:
    var arrays: Array=mi.mesh.surface_get_arrays(i)
    if arrays.is_empty():continue
    source.vertices=arrays[Mesh.ARRAY_VERTEX];source.indices=arrays[Mesh.ARRAY_INDEX]
   selected.append(source)
   signature_parts.append([key,i,mi.mesh.get_rid().get_id(),str(local)])
 if selected.is_empty():_block("No visible original Highlight-tag surfaces for "+str(id));return false
 var signature: String=str(signature_parts).sha256_text()
 if signature==e.mask_key:return true
 for source in selected:
  if source.has("deferred_mesh"):
   var arrays: Array=_read_deferred_surface(source.deferred_mesh,source.surface_index)
   source.vertices=arrays[Mesh.ARRAY_VERTEX];source.indices=arrays[Mesh.ARRAY_INDEX]
   source.erase("deferred_mesh")
 var model: Dictionary=bindings.models[e.kind]
 var hr: Dictionary={}
 for c in model.components:
  if c.class_name=="HighlightRender":hr=c.data
 var shape: Dictionary=_project_source(selected,plane_local,e.mesh.mesh,float(hr.m_SilouetteRenderSize),float(hr.m_SilouetteClipSize))
 if shape.is_empty():return false
 if not gpu_pipelines.has(id):gpu_pipelines[id]=_create_pipeline(id,shape)
 var pipeline: Dictionary=gpu_pipelines[id]
 if pipeline.is_empty():return false
 _update_pipeline(pipeline,shape)
 e.mask=pipeline.passes[9].viewport.get_texture();e.mask_key=signature;e.audit=shape.audit
 e.audit["gpu_passes"]=pipeline.audit;e.audit["capture_pending"]=true
 if e.material is ShaderMaterial:e.material.set_shader_parameter("_MainTex",e.mask)
 history.append({"event":"gpu_mask_scheduled","id":id,"key":signature,"surface_count":selected.size()})
 return true

func _can_defer_surface_arrays(mesh: Mesh,surface: int) -> bool:
 # Native ArrayMesh with a valid nonempty surface returns ARRAY_MAX slots.
 # Do not infer this for PrimitiveMesh, custom Mesh, or scripted resources.
 # Surface count/visibility/routes/transforms are checked anew every refresh.
 # Same-RID geometry edits retain the existing mask-key behavior, unchanged.
 return mesh.get_class()=="ArrayMesh" and mesh.get_script()==null and mesh.surface_get_array_len(surface)>0

func _read_deferred_surface(mesh: Mesh,surface: int) -> Array:
 return mesh.surface_get_arrays(surface)

func _project_source(selected: Array,plane: Transform3D,plane_mesh: Mesh,render_size: float,clip_size: float) -> Dictionary:
 var bounds: AABB=plane*plane_mesh.get_aabb()
 var w: float=bounds.size.x
 var h: float=maxf(bounds.size.y,bounds.size.z)
 if minf(w,h)<=0.0:_block("Degenerate original highlight plane bounds");return {}
 var size:=Vector2i(256,int(256.0*h/w)) if w>h else Vector2i(int(256.0*w/h),256)
 if size.x<1 or size.y<1:size=Vector2i(256,256)
 var base: float=h*0.5
 var render_scale: float=plane.basis.x.length()
 var camera_basis: Basis=plane.basis.orthonormalized()*Basis.from_euler(Vector3(PI/2.0,PI,0.0))*Basis.from_scale(Vector3(1,1,-1))
 var view: Transform3D=Transform3D(camera_basis,plane.origin).affine_inverse()
 var projected: Array=[]
 for s in selected:
  var pts:=PackedVector3Array()
  for v in s.vertices:pts.append(view*(s.transform*v))
  projected.append({"points":pts,"indices":s.indices})
 return {"view":view,"plane":plane,"size":size,"base":base,"render_scale":render_scale,"render_size":render_size,"clip_size":clip_size,"projected":projected,"audit":{"size":[size.x,size.y],"base_ortho":base,"render_scale":render_scale,"render_size":render_size,"clip_size":clip_size,"source_near":1.0-render_scale,"source_far":1.0+render_scale,"view_matrix":str(view),"contributing_surfaces":selected.size(),"source_surfaces":selected.map(func(surface):return {"source_key":surface.source_key,"surface_index":surface.surface_index}),"passes":10,"storage":"RGBA8 numeric red channel substitutes source R8; no HDR2D, MSAA, mips, sRGB sampling","compatibility":"Actual source triangles; CPU source orthographic projection and signed-Z clipping (GDScript float64 operations narrow into Vector2f positions); GPU canvas raster edge convention and viewport render-target bridge require independent GPU capture"}}

func _f32(value: float) -> float:
 return PackedFloat32Array([value])[0]

func _source_passes(shape: Dictionary) -> Array:
 var full: Vector2i=shape.size
 var s30:=Vector2i(maxi(1,int(full.x*0.30000001192092896)),maxi(1,int(full.y*0.30000001192092896)))
 var s50:=Vector2i(maxi(1,int(full.x*0.5)),maxi(1,int(full.y*0.5)))
 var s92:=Vector2i(maxi(1,int(full.x*0.9200000166893005)),maxi(1,int(full.y*0.9200000166893005)))
 var b: float=shape.base
 var r: float=shape.render_size
 return [
  {"label":"01_dark","type":"constant","size":s30,"ortho":_f32(b-_f32(0.20000000298023224*r)),"value":0.25},
  {"label":"02_grey","type":"constant","size":s30,"ortho":_f32(b-_f32(0.25*r)),"value":0.5},
  {"label":"03_blend1","type":"multisample_blend","size":s30,"main":0,"blend":1,"blur":-1.25},
  {"label":"04_light1","type":"constant","size":s50,"ortho":_f32(b-_f32(0.009999999776482582*r)),"value":0.75},
  {"label":"05_blend2","type":"multisample_blend","size":s50,"main":2,"blend":3,"blur":-1.25},
  {"label":"06_light2","type":"constant","size":full,"ortho":_f32(b+_f32(0.05000000074505806*r)),"value":0.75},
  {"label":"07_blend3","type":"multisample_blend","size":full,"main":4,"blend":5,"blur":-1.0},
  {"label":"08_blur","type":"multisample","size":full,"main":6,"blur":-1.5},
  {"label":"09_clip","type":"constant","size":s92,"ortho":_f32(b+_f32(0.10000000149011612*float(shape.clip_size))),"value":1.0},
  {"label":"10_silhouette","type":"mask_blend","size":full,"main":7,"blend":8,"blur":-0.8}]

func _create_pipeline(id,shape: Dictionary) -> Dictionary:
 for kind in gpu_shaders:
  if gpu_shaders[kind]==null:_block("Missing source GPU pass shader "+str(kind));return {}
 var specs: Array=_source_passes(shape)
 var pass_nodes: Array=[]
 for spec in specs:
  var vp:=SubViewport.new();vp.name=spec.label;vp.size=spec.size
  vp.disable_3d=true;vp.transparent_bg=true;vp.use_hdr_2d=false
  vp.snap_2d_transforms_to_pixel=false;vp.snap_2d_vertices_to_pixel=false
  vp.msaa_2d=Viewport.MSAA_DISABLED;vp.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
  vp.render_target_update_mode=SubViewport.UPDATE_DISABLED
  vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
  vp.canvas_item_default_texture_repeat=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_REPEAT_DISABLED
  vp.world_2d=World2D.new()
  var mat:=ShaderMaterial.new();mat.shader=gpu_shaders[spec.type]
  var drawable: CanvasItem
  if spec.type=="constant":
   var mi:=MeshInstance2D.new();mi.material=mat;drawable=mi
  else:
   var rect:=ColorRect.new();rect.position=Vector2.ZERO;rect.size=Vector2(spec.size);rect.color=Color.WHITE;rect.material=mat;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;drawable=rect
  vp.add_child(drawable)
  pass_nodes.append({"viewport":vp,"drawable":drawable,"material":mat,"spec":spec})
 # Child-before-parent render order. The deepest viewport is pass1, the
 # outermost pass10. Child SubViewports do not draw into their parent's canvas.
 var parent_node: Node=self
 for i in range(9,-1,-1):
  parent_node.add_child(pass_nodes[i].viewport);parent_node=pass_nodes[i].viewport
 var audit: Array=[]
 for i in range(pass_nodes.size()):
  var p: Dictionary=pass_nodes[i];var spec: Dictionary=p.spec
  if spec.type!="constant":
   p.material.set_shader_parameter("main_mask",pass_nodes[spec.main].viewport.get_texture())
   if spec.has("blend"):p.material.set_shader_parameter("blend_mask",pass_nodes[spec.blend].viewport.get_texture())
  audit.append({"label":spec.label,"type":spec.type,"size":[spec.size.x,spec.size.y],"parent_pass":i+2 if i<9 else 0,"snap_2d_transforms_to_pixel":false,"snap_2d_vertices_to_pixel":false,"hdr_2d":false,"transparent_bg":true,"msaa_2d":0,"mips":false,"source_near":1.0-float(shape.render_scale),"source_far":1.0+float(shape.render_scale),"ortho":spec.get("ortho"),"constant":spec.get("value"),"blur_offset":spec.get("blur"),"main_texel_size":[1.0/specs[spec.main].size.x,1.0/specs[spec.main].size.y] if spec.has("main") else null,"source_main_size":[specs[spec.main].size.x,specs[spec.main].size.y] if spec.has("main") else null,"source_blend_size":[specs[spec.blend].size.x,specs[spec.blend].size.y] if spec.has("blend") else null,"sampler":"bilinear clamp; U/V measured with near-version Unity6000.3.10f1 Metal constructor probe, exact source client environment unverified; W unused in 2D","storage":"GL_RGBA8 with transparent_bg=true and noHDR; red numeric UNorm8 mirrors sourceR8; alpha0clear/1draw is not sourceR8 implicit alpha1 and is never consumed"})
 var textures: Dictionary={}
 for p in pass_nodes:textures[str(p.spec.label).substr(3)]=p.viewport.get_texture()
 gpu_serial+=1
 return {"textures":textures,"id":id,"serial":gpu_serial,"passes":pass_nodes,"root":pass_nodes[9].viewport,"audit":audit,"updates":0,"completed_generation":0,"completed_frame":-1}

func _update_pipeline(pipeline: Dictionary,shape: Dictionary) -> void:
 pipeline["source_shape"]=shape
 var specs: Array=_source_passes(shape)
 for i in range(10):
  var p: Dictionary=pipeline.passes[i];var spec: Dictionary=specs[i]
  p.viewport.size=spec.size;p.spec=spec
  if spec.type=="constant":
   p.material.set_shader_parameter("constant_value",float(spec.value))
   p.drawable.mesh=_canvas_mesh(shape.projected,spec.size,float(spec.ortho),float(shape.render_scale))
  else:
   p.drawable.size=Vector2(spec.size)
   var main_size: Vector2i=specs[spec.main].size
   p.material.set_shader_parameter("main_texel_size",Vector2(1.0/main_size.x,1.0/main_size.y))
   p.material.set_shader_parameter("blur_offset",float(spec.blur))
  p.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 pipeline.updates+=1
 if not gpu_frame_pending:
  gpu_frame_pending=true
  RenderingServer.frame_post_draw.connect(_on_gpu_frame_completed,CONNECT_ONE_SHOT)

func _on_gpu_frame_completed() -> void:
 gpu_frame_pending=false
 for id in gpu_pipelines:
  var p: Dictionary=gpu_pipelines[id]
  if int(p.completed_generation)==int(p.updates):continue
  p.completed_generation=p.updates
  p.completed_frame=Engine.get_frames_drawn()
  if entries.has(id):entries[id].audit["capture_pending"]=false

func _clip_depth(polygon: Array,bound: float,keep_greater: bool) -> Array:
 var out: Array=[]
 if polygon.is_empty():return out
 var previous: Vector3=polygon[-1]
 var previous_inside: bool=previous.z>=bound if keep_greater else previous.z<=bound
 for vertex in polygon:
  var current: Vector3=vertex
  var inside: bool=current.z>=bound if keep_greater else current.z<=bound
  if inside!=previous_inside:
   var fraction: float=(bound-previous.z)/(current.z-previous.z)
   out.append(previous.lerp(current,fraction))
  if inside:out.append(current)
  previous=current;previous_inside=inside
 return out

func _canvas_mesh(sources: Array,size: Vector2i,ortho: float,render_scale: float) -> ArrayMesh:
 var vertices:=PackedVector2Array()
 for source in sources:
  var pts: PackedVector3Array=source.points
  var indices: PackedInt32Array=source.indices
  var count: int=indices.size() if not indices.is_empty() else pts.size()
  for n in range(0,count-2,3):
   var polygon: Array=[pts[indices[n] if not indices.is_empty() else n],pts[indices[n+1] if not indices.is_empty() else n+1],pts[indices[n+2] if not indices.is_empty() else n+2]]
   polygon=_clip_depth(polygon,-(1.0+render_scale),true)
   polygon=_clip_depth(polygon,-(1.0-render_scale),false)
   for k in range(1,polygon.size()-1):
    for point in [polygon[0],polygon[k],polygon[k+1]]:
     vertices.append(Vector2((point.x/ortho+1.0)*0.5*size.x,(1.0-point.y/ortho)*0.5*size.y))
 var mesh:=ArrayMesh.new()
 if vertices.is_empty():return mesh
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
 return mesh

func advance(delta: float, shared_shader_time: float = -1.0) -> void:
 super.advance(delta,shared_shader_time)
 for id in gpu_pipelines.keys():
  if not entries.has(id) or not is_instance_valid(entries[id].actor.get("root")):
   gpu_pipelines[id].root.queue_free();gpu_pipelines.erase(id);entries.erase(id)

func capture_gpu_passes(directory: String) -> Dictionary:
 # Invoke from a real rendered QA run. No GPU is started by source worker.
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(directory)
 var captures: Dictionary={}
 for id in gpu_pipelines:
  var pipeline: Dictionary=gpu_pipelines[id];var paths: Array=[]
  for p in pipeline.passes:
   var img: Image=p.viewport.get_texture().get_image()
   if img==null or img.is_empty():continue
   var path: String=directory+"/"+str(id)+"_"+str(p.spec.label)+".png"
   img.save_png(path);paths.append(path)
  captures[str(id)]={"paths":paths,"updates":pipeline.updates,"completed_generation":pipeline.completed_generation,"completed_frame":pipeline.completed_frame,"audit":pipeline.audit}
 return captures

func snapshot() -> Dictionary:
 var out: Dictionary=super.snapshot();var states: Dictionary={}
 for id in gpu_pipelines:
  var p: Dictionary=gpu_pipelines[id]
  states[str(id)]={"updates":p.updates,"completed_generation":p.completed_generation,"completed_frame":p.completed_frame,"serial":p.serial,"passes":p.audit}
 out["gpu_pipelines"]=states;out["validation"]="Source GPU draft. CPU equations/projection independently verified; actual GPU targets/order/raster/quantization require QA capture."
 return out
