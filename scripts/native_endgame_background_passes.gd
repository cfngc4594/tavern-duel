extends RefCounted
## Exact current URP pass topology; shader equations supplied by source DXBC ports.
## RecordRenderGraph060162A7, callbacks060162A9..B1, source RGBA8 blur targets.
const PATH="res://shaders/native_endgame_bg_"
var owner: Node
var board: Texture2D
var size: Vector2i
var graph: Node
var stages: Dictionary={}
var views: Array=[]
var big_size: Vector2i
var half_size: Vector2i
var blend: float=0.0
var output: Texture2D
var ready: bool=false
var warnings: Array=[]
var mask_texture: Texture2D
const MASK_PATH="res://assets/original_endgame_v33/background/vignette_mask.png"
func setup(parent: Node,source: Texture2D,dimensions: Vector2i) -> bool:
 owner=parent;board=source;size=dimensions
 for suffix in ["desaturation","vignette","blur","blend"]:
  if not ResourceLoader.exists(PATH+suffix+".gdshader"):
   warnings.append("Original background shader pending: "+suffix);return false
 graph=Node.new();graph.name="OriginalFullScreenFXPassGraph";owner.add_child(graph)
 big_size=Vector2i(2048,int(round(2048.0*size.y/size.x))) if size.x>size.y else Vector2i(int(round(2048.0*size.x/size.y)),2048)
 half_size=Vector2i(int(round(big_size.x*.5)),int(round(big_size.y*.5)))
 stages.luminance=_pass("desaturation",0,board,size,"DesatLuminance")
 stages.desaturate=_pass("desaturation",1,stages.luminance.texture,size,"DesatApply",board)
 stages.vignette=_pass("vignette",0,stages.desaturate.texture,size,"Vignetting",stages.desaturate.texture)
 var mask_image:=preload("res://scripts/packed_png.gd").load_png(MASK_PATH)
 if mask_image==null or mask_image.is_empty():warnings.append("Original Vignette PID18 mask missing; background not accepted")
 else:
  mask_texture=ImageTexture.create_from_image(mask_image)
  stages.vignette.material.set_shader_parameter("_MaskTex",mask_texture)
 stages.blur1=_pass("blur",0,stages.vignette.texture,big_size,"Blur1")
 stages.blur2=_pass("blur",0,stages.blur1.texture,half_size,"Blur2")
 # Both branches are allocated once, but only the original selected branch
 # renders. The intermediate branch writes Blur1-size, then source Blend applies
 # over the original vignetted target. Fully blended output writes camera-size.
 stages.blur3_full=_pass("blur",0,stages.blur2.texture,size,"Blur3Output")
 stages.blur3_intermediate=_pass("blur",0,stages.blur2.texture,big_size,"Blur3Intermediate")
 stages.blend=_pass("blend",0,stages.blur3_intermediate.texture,size,"BlurBlend",stages.vignette.texture)
 stages.blur1.material.set_shader_parameter("_BlurOffset",1.0)
 stages.blur2.material.set_shader_parameter("_BlurOffset",1.149999976158142)
 for name in ["blur3_full","blur3_intermediate"]:stages[name].material.set_shader_parameter("_BlurOffset",1.2999999523162842)
 # Callback060162AC sets1, overriding serialized/preset Brightness .5.
 for name in ["blur1","blur2","blur3_full","blur3_intermediate"]:stages[name].material.set_shader_parameter("_Brightness",1.0)
 ready=true;update(0.0);return true
func _pass(suffix: String,index: int,texture: Texture2D,dimensions: Vector2i,label: String,destination: Texture2D=null) -> Dictionary:
 var view:=SubViewport.new();view.name="Source"+label;view.size=dimensions;view.disable_3d=true;view.transparent_bg=false;view.use_hdr_2d=false
 view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;graph.add_child(view);views.append(view)
 var quad:=ColorRect.new();quad.size=Vector2(dimensions);quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var mat:=ShaderMaterial.new();mat.shader=load(PATH+suffix+".gdshader");quad.material=mat
 mat.set_shader_parameter("_Pass",index);mat.set_shader_parameter("_BlitTexture",texture)
 mat.set_shader_parameter("_DestinationTexture",destination)
 var source_size: Vector2=texture.get_size()
 mat.set_shader_parameter("_BlitTexture_TexelSize",Vector4(1.0/source_size.x,1.0/source_size.y,source_size.x,source_size.y))
 view.add_child(quad)
 return {"view":view,"texture":view.get_texture(),"material":mat,"size":dimensions,"source_size":source_size}
func update(value: float):
 blend=clampf(value,0.0,1.0)
 if not ready:return
 stages.desaturate.material.set_shader_parameter("_Desaturation",pow(1.0-.5*blend,3.0))
 stages.vignette.material.set_shader_parameter("_Amount",1.0-pow(1.0-.4000000059604645*blend,3.0))
 stages.blend.material.set_shader_parameter("_Amount",blend)
 var full: bool=blend>=1.0
 stages.blur3_full.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if full else SubViewport.UPDATE_DISABLED
 for name in ["blur3_intermediate","blend"]:stages[name].view.render_target_update_mode=SubViewport.UPDATE_DISABLED if full else SubViewport.UPDATE_ALWAYS
 output=stages.blur3_full.texture if full else stages.blend.texture
func get_texture() -> Texture2D:
 return output if ready else board
func dispose():
 for stage in stages.values():
  stage.material.set_shader_parameter("_BlitTexture",null);stage.material.set_shader_parameter("_DestinationTexture",null)
 for view in views:
  if is_instance_valid(view):view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 if is_instance_valid(graph):graph.queue_free()
 graph=null;stages.clear();views.clear();output=null;board=null;ready=false
func get_audit() -> Dictionary:
 return {"ready":ready,"mask_restored":mask_texture!=null,"target_format":"RGBA8_UNorm","sampling":"bilinear; original mask repeat","blend":blend,"dimensions":[size.x,size.y],"blur1_size":[big_size.x,big_size.y],"blur2_size":[half_size.x,half_size.y],"live_viewports":views.size(),"blur_brightness_runtime":1.0,"blur_offsets":[1.0,1.149999976158142,1.2999999523162842],"desaturation_uniform":pow(1.0-.5*blend,3.0),"vignette_uniform":1.0-pow(1.0-.4000000059604645*blend,3.0),"warnings":warnings.duplicate(),"source":"FullScreenEffectsPass.RecordRenderGraph060162A7"}
