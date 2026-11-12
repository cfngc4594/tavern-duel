extends Node
# Original TurnIndicator geometry/UV plus Unity-sampled font57 glyph atlas; Godot renderer, not original runtime.
const BASE='res://assets/native_turn_banner/'
const STAGE_SIZE=Vector2i(3200,1800)
# Godot SubViewport requires at least 2 pixels per axis. Logical stage layout never shrinks.
const IDLE_STAGE_SIZE=Vector2i(2,2)
const SOURCE_PIXELS_PER_UNIT=900.0/.72
const WARMUP_ARG="--mac-turn-banner-warmup"
const SKIP_WARMUP_ARG="--mac-skip-turn-banner-warmup"
const WARMUP_SETTING="render_quality/macos_turn_banner_warmup"
const RETAIN_TARGETS_ARG="--mac-turn-banner-retain-targets"
var viewport:SubViewport
var frames=0
var audit={}
var text_targets=[]
var layer_targets={}
var banner_blend_targets={}
var presentation_targets={}
var rays_mask_links=[]
var shadow_materials=[]
var shadow_background:SubViewport
var display_active=false
var timeline=preload("res://scripts/native_turn_timeline.gd").new()
var fade_materials=[]
var aa_mask_links=[]
var rays
var burst
var screen_sprite:Sprite2D
var font
var native_glyph_bundle={}
var _warmup_enabled:=false
var _keep_idle_targets:=false
var _warmup_complete:=false
var _warmup_started_usec:=0
var _warmup_callback:=Callable()
var _warmup_canvas:SubViewport
var _warmup_sprite_transform:=Transform2D.IDENTITY
var _warmup_burst_snapshot:Dictionary={}
func setup(_game):
 if OS.has_feature("macos") and DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility":
  var args:=OS.get_cmdline_user_args()
  _keep_idle_targets=args.has(RETAIN_TARGETS_ARG)
  _warmup_enabled=not args.has(SKIP_WARMUP_ARG) and (args.has(WARMUP_ARG) or _keep_idle_targets or bool(ProjectSettings.get_setting(WARMUP_SETTING,false)))
 viewport=_new_stage_rt(true)
 var root=Node3D.new();root.scale.z=-1;viewport.add_child(root)
 var data=JSON.parse_string(FileAccess.get_file_as_string(BASE+'-8390915935271638251.mesh.json'))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);var ps=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
 for v in data.positions:ps.append(Vector3(v[0],v[1],v[2]))
 for v in data.uvs:uv.append(Vector2(v[0],1-v[1]))
 for sub in data.triangles:
  for t in sub:indices.append_array(PackedInt32Array([t[0],t[2],t[1]]))
 arrays[Mesh.ARRAY_VERTEX]=ps;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var mi=MeshInstance3D.new();mi.mesh=mesh;root.add_child(mi)
 var mat=ShaderMaterial.new();mat.shader=load('res://assets/native_cards/source_materials/original_opaque_back.gdshader');mat.set_shader_parameter('original_shader_kind',0);mat.set_shader_parameter('main_tex',load(BASE+'-2774723153666027043.png'));mi.material_override=mat
 var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=float(STAGE_SIZE.x)/SOURCE_PIXELS_PER_UNIT;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.position=Vector3(0,0,1);cam.current=true;viewport.add_child(cam)
 # Project original local transforms through the explicitly application-owned orthographic mapping.
 # Camera KEEP_WIDTH preserves horizontal width .72; units-to-pixels=900/.72.
 var scale_px=900.0/.72
 var binding=JSON.parse_string(FileAccess.get_file_as_string(BASE+'banner_binding.json'))
 font=load('res://assets/native_cards/OriginalCards/Fonts/GLEI00M_t_Outline__4016971574774461928.ttf')
 var sample_path=BASE+'unity57/glyphs.json'
 if FileAccess.file_exists(sample_path):
  var sample=JSON.parse_string(FileAccess.get_file_as_string(sample_path));var glyphs={}
  for glyph in sample.glyphs:if glyph.available:glyphs[glyph.character]=glyph
  native_glyph_bundle={'sample':sample,'glyphs':glyphs,'atlas':load(BASE+'unity57/atlas_rgba.png')}
 else:
  push_error('Required native Unity57 sample missing; no substitute font rendering.');return
 var canvas=CanvasLayer.new();viewport.add_child(canvas)
 audit={'original_geometry':true,'vertices':ps.size(),'source_prefab':'TurnIndicator','source_build':binding.source_build,'source_base_blend':'One Zero','enemy_banner':false,'text':'你的回合','screen_projection':'application-owned 1250 pixels/local-unit, padded 3200x1800 RT; logical viewport unchanged','layers':[]}
 for entry in binding.layers:_build_text_layer(entry,canvas,scale_px)
 if ResourceLoader.exists('res://scripts/native_turn_rays.gd'):
  rays=load('res://scripts/native_turn_rays.gd').new();rays.setup(viewport,root)
 if ResourceLoader.exists("res://scripts/native_turn_burst.gd"):
  burst=load("res://scripts/native_turn_burst.gd").new();burst.setup(viewport,root)
 _setup_shadow_background()
 _setup_banner_blend()
 RenderingServer.frame_pre_draw.connect(_sync_mask_materials)
 screen_sprite=Sprite2D.new();screen_sprite.texture=presentation_targets.merged.get_texture();screen_sprite.position=Vector2(800,466);screen_sprite.scale=Vector2(.7,.7);screen_sprite.z_index=90;screen_sprite.visible=false
 var screen_material=ShaderMaterial.new();screen_material.shader=load(BASE+'shaders/banner_premul.gdshader');screen_sprite.material=screen_material;_game.world_canvas.add_child(screen_sprite)
 # Rays setup can enable its parent viewport. Finish setup with all six stage passes dormant.
 _set_banner_redraw(false)

func _process(_delta):
 frames+=1
 if timeline.running:
  _apply_original_timeline(timeline.advance(_delta))

 for target in text_targets:
  if frames==target.freeze_frame:target.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 # Text caches warm independently; animated full-stage passes exist at full size only while displayed.
func get_texture():
 if not is_instance_valid(viewport):return null
 if banner_blend_targets.is_empty():
  _setup_banner_capture()
  _set_banner_redraw(display_active)
 return banner_blend_targets.merged.get_texture()
func get_audit():
 var result=audit.duplicate(true)
 result.rays=rays.get_audit() if is_instance_valid(rays) else {}
 result.burst=burst.get_audit() if is_instance_valid(burst) else {}
 result.shadow_count=shadow_materials.size();result.display_active=display_active
 result.stage_targets=[];result.stage_pixels=0
 for target in _stage_targets():
  result.stage_targets.append({"id":target.get_instance_id(),"size":target.size,"update_mode":target.render_target_update_mode})
  result.stage_pixels+=target.size.x*target.size.y
 result.stage_lifecycle="Same ViewportTexture references; 3200x1800 while displayed; disabled at full size while idle" if _keep_idle_targets else "Same ViewportTexture references; restore 3200x1800 before visible; hidden/disabled 2x2 while idle; GPU first-frame verification required"
 result.timeline=timeline.get_audit();result.fade_semantics="recursive material _Color.a target, not final opacity"
 return result

func _rgba(d):return Color(d.r,d.g,d.b,d.a)
func _new_rt(size):
 var vp=SubViewport.new();vp.size=size;vp.disable_3d=true;vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp);return vp
func _new_stage_rt(with_3d:bool):
 var vp=SubViewport.new();vp.size=IDLE_STAGE_SIZE;vp.disable_3d=not with_3d;vp.transparent_bg=true;vp.own_world_3d=with_3d;vp.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(vp);return vp
func _build_text_layer(entry,canvas,scale_px):
 var spec=entry.ubertext;var width=float(spec.m_Width);var height=float(spec.m_Height)
 var rt_size=Vector2i(int(spec.m_Resolution),int(spec.m_Resolution*height/width))
 var char_size=float(spec.m_CharacterSize)*.01
 if not native_glyph_bundle.is_empty():char_size=float(native_glyph_bundle.sample.texts[0].characterSize)
 var min_char=float(spec.m_MinCharacterSize)*.01;var steps=0
 var native_bounds=native_glyph_bundle.sample.texts[0].localBounds.m_Extent
 var bounds=Vector2(float(native_bounds.x)*2.0/char_size/.1,float(native_bounds.y)*2.0/char_size/.1)
 var line_height=bounds.y
 while (bounds.x*char_size*.1>width or line_height*char_size*.1>height) and steps<40:
  char_size=maxf(min_char,char_size*.95);steps+=1
 var rgb=_new_rt(rt_size);var mask=_new_rt(rt_size)
 for pass_index in range(2):
  var target=rgb if pass_index==0 else mask
  var clear=ColorRect.new();clear.size=rt_size
  var clear_mat=ShaderMaterial.new();clear_mat.shader=load(BASE+'shaders/clear.gdshader')
  var clear_color=_rgba(spec.m_OutlineColor) if spec.m_Outline else _rgba(spec.m_TextColor)
  if pass_index==1:clear_color=Color(0,0,0,1)
  else:clear_color.a=0
  clear.color=clear_color;clear_mat.set_shader_parameter('clear_rgba',clear_color);clear.material=clear_mat;target.add_child(clear)
  var material=ShaderMaterial.new();material.shader=load(BASE+'shaders/glyph_rtt.gdshader')
  material.set_shader_parameter('outline_enabled',bool(spec.m_Outline));material.set_shader_parameter('outline_texels',spec.m_OutlineSize)
  material.set_shader_parameter('outline_color',_rgba(spec.m_OutlineColor));material.set_shader_parameter('text_tint',_rgba(spec.m_TextColor));material.set_shader_parameter('alpha_mask_pass',pass_index==1)
  _draw_glyph_source(target,material,rt_size,char_size,width,height)
  text_targets.append({'viewport':target,'freeze_frame':4})
 var merged=_new_rt(rt_size);var rect=TextureRect.new();rect.size=rt_size;rect.texture=rgb.get_texture();var merge=ShaderMaterial.new();merge.shader=load('res://assets/native_cards/source_alpha_merge.gdshader');merge.set_shader_parameter('rgb_rt',rgb.get_texture());merge.set_shader_parameter('mask_rt',mask.get_texture());rect.material=merge;merged.add_child(rect);text_targets.append({'viewport':merged,'freeze_frame':7})
 layer_targets[entry.name]={'rgb':rgb,'mask':mask,'merged':merged}
 var display=TextureRect.new();display.texture=merged.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.size=Vector2(width,height)*scale_px
 var tr=entry.transform.m_LocalPosition;display.position=Vector2(STAGE_SIZE)*.5+Vector2(tr.x*scale_px,-tr.y*scale_px)-display.size*.5
 var aa=ShaderMaterial.new();aa.shader=load(BASE+'shaders/final_aa_gradient.gdshader');aa.set_shader_parameter('aa_offset',Vector2.ONE/Vector2(rt_size)*float(spec.m_AntiAliasAmount));aa.set_shader_parameter('aa_edge',spec.m_AntiAliasEdge)
 fade_materials.append(aa)
 aa.set_shader_parameter('upper_color',_rgba(spec.m_GradientLowerColor));aa.set_shader_parameter('lower_color',_rgba(spec.m_GradientUpperColor));display.material=aa
 if spec.m_Shadow:_add_shadow(canvas,merged,spec,display.position,display.size,scale_px)
 canvas.add_child(display)
 audit.layers.append({'name':entry.name,'rt_size':rt_size,'font_size':57,'character_size':char_size,'resize_steps':steps,'outline_texels':spec.m_OutlineSize if spec.m_Outline else 0,'aa_amount':spec.m_AntiAliasAmount,'aa_edge':spec.m_AntiAliasEdge,'gradient_upper':spec.m_GradientUpperColor,'gradient_lower':spec.m_GradientLowerColor,'glyph_backend':'Unity6000.3.10f1 sampled CharacterInfo/atlas','font_sha256':native_glyph_bundle.sample.fontSha256,'shadow_status':'original Hidden/TextShadow eight-neighbor algebra, explicit pre-shadow scene RT, DstColor/OneMinusSrcAlpha; destination alpha unchanged' if spec.m_Shadow else 'disabled by source'})
func _draw_glyph_source(target,material,rt_size,char_size,width,height):
 _draw_native_glyphs(target,material,rt_size,char_size,width)

func show_original():
 timeline.start()
 if is_instance_valid(burst):burst.restart()
 _apply_original_timeline(timeline.get_audit())

func cancel_original():
 timeline.cancel()
 if is_instance_valid(burst):burst.cancel()
 _apply_original_timeline(timeline.get_audit())

func advance_shader_warmup(game:Node)->bool:
 if not _warmup_enabled or _warmup_complete:return true
 if _warmup_callback.is_valid():return false
 if not game.native_initial_loading or game.world_canvas.visible or display_active or timeline.running:return true
 _warmup_started_usec=Time.get_ticks_usec()
 _warmup_sprite_transform=screen_sprite.transform
 if is_instance_valid(burst):
  if not burst.particles.is_empty():return true
  _warmup_burst_snapshot={"elapsed":burst.elapsed_seconds,"seed":burst.seed_value,"audit":burst.audit.duplicate()}
  burst.restart(0)
 # Draw one real animation sample while the gameplay canvas is hidden.
 _apply_original_timeline(timeline.sample(.15))
 _warmup_canvas=SubViewport.new()
 _warmup_canvas.name="TurnBannerWarmupComposite"
 _warmup_canvas.disable_3d=true
 _warmup_canvas.size=Vector2i(game.get_viewport().get_visible_rect().size)
 _warmup_canvas.render_target_update_mode=SubViewport.UPDATE_ONCE
 add_child(_warmup_canvas)
 _warmup_canvas.add_child(screen_sprite.duplicate())
 game.native_startup_timing.mark("turn_banner_shader_warmup_begin",{"targets":_stage_targets().size(),"retain_targets":_keep_idle_targets})
 _warmup_callback=_shader_warmup_drawn.bind(game)
 RenderingServer.frame_post_draw.connect(_warmup_callback,Object.CONNECT_ONE_SHOT|Object.CONNECT_DEFERRED)
 return false

func _shader_warmup_drawn(game:Node):
 if not _warmup_callback.is_valid():return
 var draw_calls:=0
 var targets:=_stage_targets()
 targets.append(_warmup_canvas)
 for target:SubViewport in targets:
  draw_calls+=target.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
  draw_calls+=target.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
 cancel_shader_warmup()
 if is_instance_valid(game):
  game.native_startup_timing.mark("turn_banner_shader_warmup_drawn",{"wall_usec":Time.get_ticks_usec()-_warmup_started_usec,"targets":targets.size(),"draw_calls":draw_calls,"retain_targets":_keep_idle_targets,"timeline_serial":timeline.serial})

func cancel_shader_warmup():
 if not _warmup_callback.is_valid():return
 if RenderingServer.frame_post_draw.is_connected(_warmup_callback):RenderingServer.frame_post_draw.disconnect(_warmup_callback)
 _warmup_callback=Callable()
 _warmup_complete=true
 if is_instance_valid(_warmup_canvas):_warmup_canvas.queue_free()
 _warmup_canvas=null
 if is_instance_valid(screen_sprite):
  _apply_original_timeline(timeline.get_audit())
  screen_sprite.transform=_warmup_sprite_transform
 if is_instance_valid(burst) and not _warmup_burst_snapshot.is_empty():
  burst.cancel()
  burst.set_elapsed(_warmup_burst_snapshot.elapsed)
  burst.seed_value=_warmup_burst_snapshot.seed
  burst.audit=_warmup_burst_snapshot.audit
 _warmup_burst_snapshot.clear()

func _apply_original_timeline(state):
 # Original _Color alpha is overwritten, not multiplied by serialized initial alpha.
 for material in fade_materials:material.set_shader_parameter("source_color_alpha",state.alpha)
 for material in shadow_materials:
  var color=material.get_shader_parameter("shadow_color")
  if color is Color: color.a=state.alpha
  else: color.w=state.alpha
  material.set_shader_parameter("shadow_color",color)
 if is_instance_valid(rays) and rays.material:
  var color=Vector4(.4339999855,.4130842984,.1690682769,state.alpha)
  rays.material.set_shader_parameter("original_color",color)
 if is_instance_valid(burst):
  burst.set_elapsed(float(state.elapsed))
  burst.material.set_shader_parameter("original_color",Vector4(1,1,1,state.alpha))
 set_display(state.visible,1.0)
 screen_sprite.scale=Vector2.ONE*.7*float(state.scale)/9.800000190734863
 # Source desktop anchor and world camera are not transplanted: retain project projection.
 # Original world drift (+x,+y,+z); project screen x/right,y/down using the same 900/.72 * .7/9.8 projection per world unit.
 screen_sprite.position=Vector2(800,466)+Vector2(state.position_delta.x,-state.position_delta.y)*(900.0/.72*.7/9.800000190734863)

func set_display(active:bool,opacity:float):
 # Hide before releasing storage; restore the entire dependency graph before exposing it.
 if not active and is_instance_valid(screen_sprite):screen_sprite.visible=false
 if active!=display_active:_set_banner_redraw(active)
 display_active=active
 if is_instance_valid(screen_sprite):
  screen_sprite.visible=active;screen_sprite.material.set_shader_parameter('opacity',clampf(opacity,0,1))
func _exit_tree():
 cancel_shader_warmup()
 if RenderingServer.frame_pre_draw.is_connected(_sync_mask_materials):RenderingServer.frame_pre_draw.disconnect(_sync_mask_materials)
 if is_instance_valid(screen_sprite):screen_sprite.queue_free()

func _draw_native_glyphs(target,material,rt_size,char_size,width):
 var glyphs=native_glyph_bundle.glyphs;var text='你的回合';var advance=0.0
 for ch in text:
  if not glyphs.has(ch):push_error('Native57 incomplete: '+ch);return
  advance+=float(glyphs[ch].advance)
 var factor=char_size*.1*float(rt_size.x)/width
 # Font hhea (same original GLEI): 1024 units, ascent900, descent-124, lineGap6.
 # MiddleCenter baseline formula verified for earlier sampled sizes; native57 is independently checked.
 var baseline_pixels=-57.0*900.0/1024.0+57.0*1030.0/1024.0/2.0
 var pen=-advance*.5
 var scale_y=char_size*.1*float(rt_size.y)/float(layer_height_for_native())
 for ch in text:
  var g=glyphs[ch];var vertices=PackedVector2Array();var uv=PackedVector2Array()
  for corner in ['BottomLeft','BottomRight','TopRight','TopLeft']:
   var x=g.minX if corner.ends_with('Left') else g.maxX
   var y=g.minY if corner.begins_with('Bottom') else g.maxY
   vertices.append(Vector2(rt_size.x*.5+(pen+x)*factor,rt_size.y*.5-(baseline_pixels+y)*scale_y))
   var u=g['uv'+corner];uv.append(Vector2(u.x*native_glyph_bundle.sample.atlasWidth,(1.0-u.y)*native_glyph_bundle.sample.atlasHeight))
  var quad=Polygon2D.new();quad.polygon=vertices;quad.uv=uv;quad.texture=native_glyph_bundle.atlas;quad.material=material;quad.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;target.add_child(quad);pen+=g.advance
func layer_height_for_native():return .05000000074505806

func _setup_banner_capture():
 # Only the standalone framebuffer-alpha capture needs this mask and merge.
 var mask=_new_stage_rt(true)
 for source_child in viewport.get_children():
  var copy=source_child.duplicate();mask.add_child(copy);_mask_tree(copy)
 var merged=_new_stage_rt(false);var rect=ColorRect.new();rect.size=STAGE_SIZE;var material=ShaderMaterial.new();material.shader=load('res://assets/native_cards/source_alpha_merge.gdshader');material.set_shader_parameter('rgb_rt',viewport.get_texture());material.set_shader_parameter('mask_rt',mask.get_texture());rect.material=material;merged.add_child(rect)
 banner_blend_targets={'mask':mask,'merged':merged}

func _setup_banner_blend():
 var coverage=_new_stage_rt(true)
 for source_child in viewport.get_children():
  var copy=source_child.duplicate();coverage.add_child(copy);_mask_tree(copy,true)
 var output=_new_stage_rt(false);var output_rect=ColorRect.new();output_rect.size=STAGE_SIZE
 var output_material=ShaderMaterial.new();output_material.shader=load('res://assets/native_cards/source_alpha_merge.gdshader');output_material.set_shader_parameter('rgb_rt',viewport.get_texture());output_material.set_shader_parameter('mask_rt',coverage.get_texture());output_rect.material=output_material;output.add_child(output_rect)
 presentation_targets={'coverage':coverage,'merged':output}
 audit.presentation='Separate destination attenuation: opaque coverage1, AA source alpha, rays source alpha, additive particles zero attenuation. Framebuffer alpha retained independently.'
 audit.final_blend='per-pass replay: opaque One/Zero, rays One/OneMinus, text AA SrcAlpha/OneMinus; RGB retained including emissive zero-alpha; mask red merged as output alpha'
func _mask_tree(node,coverage=false):
 node.set_process(false)
 if node is CanvasItem and node.get_meta("source_shadow",false):node.visible=false;return
 if node is MeshInstance3D and node.mesh!=null:
  if coverage and node.material_override is ShaderMaterial and node.material_override.shader.code.contains("blend_add"):
   node.visible=false;return
  if node.material_override is ShaderMaterial:node.material_override=_mask_material(node.material_override,coverage)
  for surface in range(node.mesh.get_surface_count()):
   var mat=node.get_surface_override_material(surface)
   if mat is ShaderMaterial:node.set_surface_override_material(surface,_mask_material(mat,coverage))
 if node is CanvasItem and node.material is ShaderMaterial:node.material=_mask_material(node.material,coverage)
 for child in node.get_children():_mask_tree(child,coverage)
func _mask_material(source,coverage=false):
 var snapshot={}
 for uniform in source.shader.get_shader_uniform_list():
  var value=source.get_shader_parameter(uniform.name)
  if value is Color and int(uniform.type)==TYPE_VECTOR4:value=Vector4(value.r,value.g,value.b,value.a)
  if value!=null:snapshot[uniform.name]=value
 var material=source.duplicate();var code=source.shader.code
 if code.contains('uniform bool alpha_mask_pass'):
  if not coverage:
   material.set_shader_parameter('alpha_mask_pass',true);return material
  var opaque_shader=Shader.new();opaque_shader.code=code.insert(code.rfind('}'),'\n ALBEDO=vec3(1.0);\n');material.shader=opaque_shader
  for name in snapshot:material.set_shader_parameter(name,snapshot[name])
  return material
 if code.contains('shader_type spatial'):
  var original=FileAccess.get_file_as_string('res://assets/native_cards/source_materials/original_opaque_double.gdshader');var start=original.find('vec3 mask_backend_inverse(');var inverse=original.substr(start,original.find('void vertex()',start)-start)
  code=code.insert(code.find('void vertex()'),inverse)
  code=code.insert(code.rfind('}'),'\n ALBEDO=mask_backend_inverse(vec3(clamp(ALPHA,0.0,1.0)));\n')
  rays_mask_links.append({'source':source,'mask':material})
 else:
  code=code.insert(code.rfind('}'),'\n COLOR=vec4(vec3(1.0),COLOR.a);\n' if coverage else '\n COLOR=vec4(COLOR.a);\n')
  aa_mask_links.append({"source":source,"mask":material})
 var shader=Shader.new();shader.code=code;material.shader=shader
 # Assigning a new Shader resets overrides; preserve every original source parameter explicitly.
 for name in snapshot:material.set_shader_parameter(name,snapshot[name])
 return material

func _sync_mask_materials():
 for pair in rays_mask_links:
  if is_instance_valid(pair.source) and is_instance_valid(pair.mask):
   pair.mask.set_shader_parameter('elapsed_seconds',pair.source.get_shader_parameter('elapsed_seconds'))
   pair.mask.set_shader_parameter('original_color',pair.source.get_shader_parameter('original_color'))
 for pair in aa_mask_links:
  if is_instance_valid(pair.source) and is_instance_valid(pair.mask):pair.mask.set_shader_parameter('source_color_alpha',pair.source.get_shader_parameter('source_color_alpha'))

func _add_shadow(canvas,merged,spec,position,size,scale_px):
 assert(shadow_materials.is_empty(),'Recovered TurnIndicator contains one Bottom shadow; multiple shadows require separate ordered destination stages.')
 var shadow=TextureRect.new();shadow.texture=merged.get_texture();shadow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shadow.size=size
 # SetupShadow local vector=(-offset*.01,depth*.01,-offset*.01).
 # Shadow is a child of the plane, whose non-widget rotation is Rx(-90):
 # banner XY=(-offset,-offset), therefore screen XY=(-offset,+offset).
 shadow.position=position+Vector2(-float(spec.m_ShadowOffset)*.01,float(spec.m_ShadowOffset)*.01)*scale_px
 var material=ShaderMaterial.new();material.shader=load(BASE+'shaders/source_text_shadow.gdshader');material.set_shader_parameter('shadow_offset',Vector2.ONE/Vector2(merged.size)*float(spec.m_ShadowBlur));material.set_shader_parameter('shadow_color',_rgba(spec.m_ShadowColor));shadow.material=material;shadow_materials.append(material);shadow.set_meta('source_shadow',true);canvas.add_child(shadow)

func _stage_targets() -> Array:
 var targets:Array=[]
 if is_instance_valid(shadow_background):targets.append(shadow_background)
 if is_instance_valid(viewport):targets.append(viewport)
 for target in banner_blend_targets.values():
  if is_instance_valid(target):targets.append(target)
 for target in presentation_targets.values():
  if is_instance_valid(target):targets.append(target)
 return targets

func _set_banner_redraw(active:bool):
 var targets=_stage_targets()
 # Resize every dependency before enabling any pass. No object or material is recreated.
 if not active:
  for target in targets:target.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for target in targets:
  if active:target.size=STAGE_SIZE
  elif not _keep_idle_targets:target.size=IDLE_STAGE_SIZE
 if active:
  for target in targets:target.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func _setup_shadow_background():
 if shadow_materials.is_empty():return
 shadow_background=_new_stage_rt(true)
 for source_child in viewport.get_children():
  if source_child is CanvasLayer:continue
  var copy=source_child.duplicate();shadow_background.add_child(copy);_disable_process_tree(copy)
 for material in shadow_materials:material.set_shader_parameter('destination_texture',shadow_background.get_texture())
func _disable_process_tree(node):
 node.set_process(false)
 for child in node.get_children():_disable_process_tree(child)
