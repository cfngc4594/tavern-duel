extends Node
## Source serialized HighlightState materials + HighlightRender equations.
## CPU rasterization and Godot plane projection are explicit engine compatibility.
## Never synthesizes an ellipse, frame contour, hero, or unavailable shader.
const CAB := "cab-69c88b234dfa427e02d1fcee9337ae34:"
var bindings: Dictionary = {}
var surfaces: Dictionary = {}
var assets
var entries: Dictionary = {}
var mask_cache: Dictionary = {}
var history: Array = []
var blockers: Array = []
var rng := RandomNumberGenerator.new()
var source_clock := 0.0
var diagnostic_directory: String = ""

func setup(_game: Node, source_assets, source_base: String = "res://assets/original_targeting_v34/") -> void:
 assets=source_assets
 bindings=JSON.parse_string(FileAccess.get_file_as_string(source_base+"data/eligibility_bindings.json"))
 surfaces=JSON.parse_string(FileAccess.get_file_as_string(source_base+"data/eligibility_surface_bindings.json"))
 rng.randomize() # Local visual seed only; source Setup consumes Unity.Random.value.

func set_actor_state(id, actor: Dictionary, kind: String, state: int, attachments: Array = []) -> bool:
 if state in [0,1,29]:
  hide(id);return true
 if kind not in bindings.get("models",{}) or not is_instance_valid(actor.get("root")):
  _block("No verified source actor for "+str(id)+"/"+kind);return false
 if kind not in surfaces:
  _block("No verified Highlight-tag surface map for "+kind);return false
 var spec: Dictionary=bindings.models[kind]
 var state_binding: Dictionary={}
 for candidate in spec.target_states:
  if int(candidate.state)==state:state_binding=candidate;break
 if state_binding.is_empty() or state_binding.get("material_key")==null:
  _block("No recovered source material for "+kind+" state "+str(state));hide(id);return false
 var plane_key: String=spec.plane.key
 var plane: Node3D=actor.get("nodes",{}).get(plane_key)
 if not is_instance_valid(plane):
  _block("Live original actor has no source highlight plane "+plane_key);return false
 if not entries.has(id):
  var mesh:=MeshInstance3D.new();mesh.name="OriginalTargetEligibility"
  mesh.mesh=assets.geometry(str(spec.mesh.key))
  if mesh.mesh==null:_block("Original highlight plane mesh unavailable");mesh.free();return false
  plane.add_child(mesh);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  entries[id]={"actor":actor,"kind":kind,"state":1,"plane":plane,"mesh":mesh,"seed":rng.randf(),"mask_key":"","material":null,"audit":{}}
 var e: Dictionary=entries[id]
 e.actor=actor;e.attachments=attachments
 if not refresh(id):e.mesh.visible=false;return false
 if int(e.state)!=state or e.material==null:
  var material_key: String=str(state_binding.material_key)
  var mat: Material=assets.material(material_key,e.mask)
  if not mat is ShaderMaterial or not "native_summon_highlight" in mat.shader.resource_path:
   _block("Original highlight shader route unavailable for "+material_key);e.mesh.visible=false;return false
  # Dynamic RenderTexture uses Clamp, unlike some authored baked textures.
  # Keep shared summon shader untouched and preserve every material parameter.
  var parameters: Dictionary={}
  for uniform in mat.shader.get_shader_uniform_list():parameters[str(uniform.name)]=mat.get_shader_parameter(str(uniform.name))
  mat.shader=load("res://shaders/native_target_dynamic_highlight.gdshader")
  for parameter in parameters:mat.set_shader_parameter(parameter,parameters[parameter])
  mat.set_meta("source_dynamic_rt_wrap","Clamp U/V/W")
  # Copy source material values through the existing exact loader. Source copies
  # material before overriding _MainTex with the generated scalar silhouette.
  mat.set_shader_parameter("_Seed",e.seed)
  mat.set_shader_parameter("_ShaderTime",source_clock)
  mat.render_priority=-1 if kind=="hero" else 0 # source2999/3000 compressed locally
  e.material=mat;e.mesh.material_override=mat;e.state=state
  var off: Dictionary=state_binding.offset
  e.mesh.position=Vector3(float(off.x),float(off.y),float(off.z))
  history.append({"event":"state","id":id,"state":state,"material":material_key})
 e.mesh.visible=true
 return true

func hide(id) -> void:
 if not entries.has(id):return
 var e: Dictionary=entries[id]
 if is_instance_valid(e.mesh):e.mesh.visible=false
 e.state=1

func hide_all() -> void:
 for id in entries:hide(id)

func advance(delta: float, shared_shader_time: float = -1.0) -> void:
 # ShaderTime.UpdateShaderAnimationTime0x06015547: deltaTime/20, single
 # subtract at >65535; retain across state changes. Prefer shared source clock.
 if shared_shader_time>=0.0:source_clock=shared_shader_time
 else:
  source_clock=PackedFloat32Array([source_clock+PackedFloat32Array([delta/20.0])[0]])[0]
  if source_clock>65535.0:
   source_clock=PackedFloat32Array([source_clock-65535.0])[0]
   if source_clock<=0.0:source_clock=0.00009999999747378752
 for id in entries:
  var e: Dictionary=entries[id]
  if not is_instance_valid(e.mesh) or not is_instance_valid(e.actor.get("root")):continue
  if e.material is ShaderMaterial:e.material.set_shader_parameter("_ShaderTime",source_clock)

func relative_transform(node: Node3D, reference: Node3D) -> Transform3D:
 # Source SetupRenderObjects normalizes the Actor's world transform before
 # rendering its hierarchy. Compose local chains, never inverse(global)*global:
 # that roundtrip includes the animated board scale and can flip RT dimensions.
 var reference_ancestors: Dictionary={}
 var cursor: Node=reference
 var reference_to_parent:=Transform3D.IDENTITY
 while is_instance_valid(cursor):
  reference_ancestors[cursor.get_instance_id()]=reference_to_parent
  if cursor is Node3D:reference_to_parent=cursor.transform*reference_to_parent
  cursor=cursor.get_parent()
 cursor=node
 var node_to_parent:=Transform3D.IDENTITY
 while is_instance_valid(cursor):
  if reference_ancestors.has(cursor.get_instance_id()):
   var ref_to_common: Transform3D=reference_ancestors[cursor.get_instance_id()]
   # Descendants hit reference itself, whose transform is exactly identity.
   # Sibling branches invert only their private local branch, not world space.
   return ref_to_common.affine_inverse()*node_to_parent
  if cursor is Node3D:node_to_parent=cursor.transform*node_to_parent
  cursor=cursor.get_parent()
 _block("No common source transform ancestor")
 return Transform3D.IDENTITY

func _surface_relative(candidate: Dictionary,actor_root: Node3D) -> Transform3D:
 if candidate.has("relative_anchor"):
  return candidate.get("anchor_to_actor",Transform3D.IDENTITY)*relative_transform(candidate.mesh,candidate.relative_anchor)
 return relative_transform(candidate.mesh,actor_root)

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
  var route: Dictionary=candidate.routes.get(str(key),{})
  if route.is_empty():continue # No verified Highlight tag means no inclusion.
  var local: Transform3D=_surface_relative(candidate,root)
  for i in range(mini(mi.mesh.get_surface_count(),route.surfaces.size())):
   if not bool(route.surfaces[i].get("verified",false)):
    _block("Unverified silhouette material "+str(route.surfaces[i]));return false
   if not bool(route.surfaces[i].eligible):continue
   var arrays: Array=mi.mesh.surface_get_arrays(i)
   if arrays.is_empty():continue
   selected.append({"vertices":arrays[Mesh.ARRAY_VERTEX],"indices":arrays[Mesh.ARRAY_INDEX],"transform":local})
   signature_parts.append([str(key),i,mi.mesh.get_rid().get_id(),str(local)])
 if selected.is_empty():_block("No visible original Highlight-tag surfaces for "+str(id));return false
 var signature: String=str(signature_parts).sha256_text()
 if signature==e.mask_key:return true
 if not mask_cache.has(signature):
  var model: Dictionary=bindings.models[e.kind]
  var hr: Dictionary={}
  for c in model.components:
   if c.class_name=="HighlightRender":hr=c.data
  var result: Dictionary=_build_mask(selected,plane_local,e.mesh.mesh,float(hr.m_SilouetteRenderSize),float(hr.m_SilouetteClipSize))
  if result.is_empty():return false
  mask_cache[signature]=result
 var cached: Dictionary=mask_cache[signature]
 e.mask=cached.texture;e.mask_key=signature;e.audit=cached.audit
 if e.material is ShaderMaterial:e.material.set_shader_parameter("_MainTex",e.mask)
 history.append({"event":"mask_ready","id":id,"key":signature,"audit":e.audit})
 return true

func _build_mask(selected: Array,plane: Transform3D,plane_mesh: Mesh,render_size: float,clip_size: float) -> Dictionary:
 # Source SetupRenderObjects resets root world scale/rotation. Relative actor
 # transforms above reproduce that snapshot without mutating the live actor.
 var bounds: AABB=plane*plane_mesh.get_aabb()
 var w: float=bounds.size.x
 var h: float=maxf(bounds.size.y,bounds.size.z)
 if minf(w,h)<=0.0:_block("Degenerate original highlight plane bounds");return {}
 var size:=Vector2i(256,int(256.0*h/w)) if w>h else Vector2i(int(256.0*w/h),256)
 size.x=maxi(size.x,1);size.y=maxi(size.y,1)
 var base: float=h*0.5
 var render_scale: float=plane.basis.x.length()
 var camera_basis: Basis=plane.basis.orthonormalized()*Basis.from_euler(Vector3(PI/2.0,PI,0.0))*Basis.from_scale(Vector3(1,1,-1))
 var view: Transform3D=Transform3D(camera_basis,plane.origin).affine_inverse()
 var projected: Array=[]
 for s in selected:
  var pts:=PackedVector3Array()
  for v in s.vertices:pts.append(view*(s.transform*v))
  projected.append({"points":pts,"indices":s.indices})
 var s30:=Vector2i(maxi(1,int(size.x*0.30000001192092896)),maxi(1,int(size.y*0.30000001192092896)))
 var s50:=Vector2i(maxi(1,int(size.x*0.5)),maxi(1,int(size.y*0.5)))
 var s92:=Vector2i(maxi(1,int(size.x*0.9200000166893005)),maxi(1,int(size.y*0.9200000166893005)))
 var timings: Dictionary={}
 var stamp: int=Time.get_ticks_usec()
 var dark:=_raster(projected,s30,base-0.20000000298023224*render_size,render_scale,0.25)
 timings["dark_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var grey:=_raster(projected,s30,base-0.25*render_size,render_scale,0.5)
 timings["grey_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var a:=_filter(dark,grey,s30,-1.25,1)
 timings["a_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var light1:=_raster(projected,s50,base-0.009999999776482582*render_size,render_scale,0.75)
 timings["light1_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var b:=_filter(a,light1,s50,-1.25,1)
 timings["b_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var light2:=_raster(projected,size,base+0.05000000074505806*render_size,render_scale,0.75)
 timings["light2_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var c:=_filter(b,light2,size,-1.0,1)
 timings["c_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var blurred:=_filter(c,null,size,-1.5,0)
 timings["blurred_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var clip:=_raster(projected,s92,base+0.10000000149011612*clip_size,render_scale,1.0)
 timings["clip_usec"]=Time.get_ticks_usec()-stamp;stamp=Time.get_ticks_usec()
 var result:=_filter(blurred,clip,size,-0.8,2)
 timings["result_usec"]=Time.get_ticks_usec()-stamp
 if not diagnostic_directory.is_empty():
  DirAccess.make_dir_recursive_absolute(diagnostic_directory)
  var pass_images: Dictionary={"01_dark":dark,"02_grey":grey,"03_blend1":a,"04_light1":light1,"05_blend2":b,"06_light2":light2,"07_blend3":c,"08_blur":blurred,"09_clip":clip,"10_silhouette":result}
  for label in pass_images:pass_images[label].save_png(diagnostic_directory+"/"+label+".png")
 var audit: Dictionary={"size":[size.x,size.y],"base_ortho":base,"render_scale":render_scale,"render_size":render_size,"clip_size":clip_size,"contributing_surfaces":projected.size(),"passes":10,"timings":timings,"mask_hex_sha256":result.get_data().hex_encode().sha256_text(),"compatibility":"CPU center-sampled triangle coverage, UNorm8 pass quantization, bilinear clamp sampling compatibility (source RT wrap default unresolved), source scalar equations; raster top-left-edge tie and backend texture quantization not GPU-validated"}
 return {"texture":ImageTexture.create_from_image(result),"image":result,"audit":audit}

func _raster(surfaces_to_draw: Array,size: Vector2i,ortho: float,render_scale: float,value: float) -> Image:
 var image:=Image.create(size.x,size.y,false,Image.FORMAT_R8)
 var q: float=float(clampi(roundi(value*255.0),0,255))/255.0
 for s in surfaces_to_draw:
  var points: PackedVector3Array=s.points
  var indices: PackedInt32Array=s.indices
  var count: int=indices.size() if not indices.is_empty() else points.size()
  for n in range(0,count-2,3):
   var va: Vector3=points[indices[n] if not indices.is_empty() else n]
   var vb: Vector3=points[indices[n+1] if not indices.is_empty() else n+1]
   var vc: Vector3=points[indices[n+2] if not indices.is_empty() else n+2]
   var a:=Vector2((va.x/ortho+1.0)*0.5*size.x,(1.0-va.y/ortho)*0.5*size.y)
   var b:=Vector2((vb.x/ortho+1.0)*0.5*size.x,(1.0-vb.y/ortho)*0.5*size.y)
   var c:=Vector2((vc.x/ortho+1.0)*0.5*size.x,(1.0-vc.y/ortho)*0.5*size.y)
   var area: float=(b-a).cross(c-a)
   if absf(area)<0.00000001:continue
   # Exact constant replacement shaders have CullOff, ZTestAlways, ZWriteOff.
   var x0: int=maxi(0,int(floor(minf(a.x,minf(b.x,c.x)))))
   var x1: int=mini(size.x-1,int(ceil(maxf(a.x,maxf(b.x,c.x)))))
   var y0: int=maxi(0,int(floor(minf(a.y,minf(b.y,c.y)))))
   var y1: int=mini(size.y-1,int(ceil(maxf(a.y,maxf(b.y,c.y)))))
   for y in range(y0,y1+1):
    for x in range(x0,x1+1):
     var p:=Vector2(x+0.5,y+0.5)
     var wa: float=(b-p).cross(c-p)/area
     var wb: float=(c-p).cross(a-p)/area
     var wc: float=1.0-wa-wb
     if minf(wa,minf(wb,wc)) < -0.0000001:continue
     var depth: float=wa*va.z+wb*vb.z+wc*vc.z
     # Unity Ortho uses signed camera-space Z. Projection near/far below are
     # source1-renderScale/source1+renderScale, not an arbitrary board depth.
     if depth < -(1.0+render_scale) or depth > -(1.0-render_scale):continue
     image.set_pixel(x,y,Color(q,q,q,1))
 return image

func _sample(image: Image,uv: Vector2) -> float:
 var x: float=uv.x*image.get_width()-0.5
 var y: float=uv.y*image.get_height()-0.5
 var x0: int=int(floor(x));var y0: int=int(floor(y))
 var fx: float=x-x0;var fy: float=y-y0
 var a: float=image.get_pixel(clampi(x0,0,image.get_width()-1),clampi(y0,0,image.get_height()-1)).r
 var b: float=image.get_pixel(clampi(x0+1,0,image.get_width()-1),clampi(y0,0,image.get_height()-1)).r
 var c: float=image.get_pixel(clampi(x0,0,image.get_width()-1),clampi(y0+1,0,image.get_height()-1)).r
 var d: float=image.get_pixel(clampi(x0+1,0,image.get_width()-1),clampi(y0+1,0,image.get_height()-1)).r
 return lerpf(lerpf(a,b,fx),lerpf(c,d,fx),fy)

func _four(image: Image,uv: Vector2,offset: Vector2) -> float:
 return _sample(image,uv+offset)+_sample(image,uv-offset)+_sample(image,uv+Vector2(offset.x,-offset.y))+_sample(image,uv+Vector2(-offset.x,offset.y))

func _filter(main: Image,blend: Image,size: Vector2i,blur: float,mode: int) -> Image:
 var out:=Image.create(size.x,size.y,false,Image.FORMAT_R8)
 var offset:=Vector2(blur/main.get_width(),blur/main.get_height())
 for y in range(size.y):
  for x in range(size.x):
   var uv:=Vector2((x+0.5)/size.x,(y+0.5)/size.y)
   var value: float=_four(main,uv,offset)*0.25
   if mode==1:value=maxf(value,_sample(blend,uv))
   elif mode==2:value=0.30000001192092896*(_four(main,uv,offset)-_four(blend,uv,offset))
   var q: float=float(clampi(roundi(value*255.0),0,255))/255.0
   out.set_pixel(x,y,Color(q,q,q,1))
 return out

func _block(message: String) -> void:
 if not blockers.has(message):blockers.append(message)

func snapshot() -> Dictionary:
 var states: Dictionary={}
 for id in entries:
  var e: Dictionary=entries[id]
  states[str(id)]={"kind":e.kind,"state":e.state,"visible":is_instance_valid(e.mesh) and e.mesh.visible,"mask_key":e.mask_key,"audit":e.audit}
 return {"entries":states,"mask_cache_count":mask_cache.size(),"blockers":blockers.duplicate(),"history":history.duplicate(),"validation":"Source CPU draft; GPU/complete live board integration pending"}
