extends RefCounted
## Source prefab/mesh/OverlayUI coordinate transplant, isolated from game rules.
## Candidate only: original Unity glyph bounds, RTT outline and
## dynamic text measurement still need original-render validation.
const DATA = "res://assets/native_phone_name_banner/"
var contract:Dictionary
var geometry:Dictionary
var texture:Texture2D
var font:Font
var _state_key:String=""
var _commands:Array=[]
var audit:Array=[]

func setup() -> void:
 contract=JSON.parse_string(FileAccess.get_file_as_string(DATA+"contract.json"))
 geometry=JSON.parse_string(FileAccess.get_file_as_string(DATA+"geometry.json"))
 texture=load(DATA+"NameBannersAlpha.png")
 font=load(contract.font.path)

func source_transform(node:Dictionary) -> Transform3D:
 var p:Array=node.position;var q:Array=node.rotation;var s:Array=node.scale
 return Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized()).scaled(Vector3(s[0],s[1],s[2])),Vector3(p[0],p[1],p[2]))

func source_world(spec:Dictionary,path:String,overrides:Dictionary={}) -> Transform3D:
 var local:Transform3D=overrides.get(path,source_transform(spec.nodes[path]))
 var parent:String=path.get_base_dir()
 if spec.nodes.has(parent):return source_world(spec,parent,overrides)*local
 return local

func screen_position(spec:Dictionary,point:Vector3,canvas:Vector2) -> Vector2:
 var anchor:=Vector2(canvas.x if spec.anchor=="bottom_right" else 0.0,canvas.y)
 return anchor+Vector2(point.x,-point.z)*(canvas.y/float(contract.overlay.reference_height))

func source_horizontal_margin(canvas:Vector2) -> float:
 var a:float=canvas.x/canvas.y
 var b:Dictionary=contract.bnet_horizontal_margin
 var t:Array=b.aspect_thresholds
 var v:Array=b.values
 if a<=float(t[1]):return lerpf(v[0],v[1],clampf((a-float(t[0]))/(float(t[1])-float(t[0])),0.0,1.0))
 return lerpf(v[1],v[2],clampf((a-float(t[1]))/(float(t[2])-float(t[1])),0.0,1.0))

func _matrix(raw:Dictionary) -> Transform3D:
 return Transform3D(Basis(Vector3(raw.e00,raw.e10,raw.e20),Vector3(raw.e01,raw.e11,raw.e21),Vector3(raw.e02,raw.e12,raw.e22)),Vector3(raw.e03,raw.e13,raw.e23))

func _source_text_layout(raw:Dictionary,text:String) -> Dictionary:
 var size:int=int(contract.font.runtime_font_size)
 var pixels:Vector2=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
 var source_per_pixel:float=float(raw.m_CharacterSize)*0.001
 var measured:Vector2=Vector2(pixels.x,font.get_height(size))*source_per_pixel
 var ratio:float=minf(float(raw.m_Width)/maxf(measured.x,.00001),float(raw.m_Height)/maxf(measured.y,.00001))
 if bool(raw.m_ResizeToFit):
  if bool(raw.m_ResizeToFitAndGrow):
   source_per_pixel=maxf(float(raw.m_MinCharacterSize)*0.001,source_per_pixel*ratio)
  else:
   # ReduceText_CharSize (0x060000ba), nonwrapped single-line branch.
   # The source uses 0.95 steps, not a one-shot exact box-fit ratio.
   for step in range(40):
    measured=Vector2(pixels.x,font.get_height(size))*source_per_pixel
    if measured.x<=float(raw.m_Width) and measured.y<=float(raw.m_Height):break
    source_per_pixel=maxf(float(raw.m_MinCharacterSize)*0.001,source_per_pixel*0.949999988079071)
 return {"text":text,"raw":raw,"font_size":size,"source_per_pixel":source_per_pixel,"source_bounds":Vector2(pixels.x,font.get_height(size))*source_per_pixel,"font_pixel_width":pixels.x}

func _append_banner(kind:String,text:String,subtext:String,canvas:Vector2,margin:float) -> void:
 var spec:Dictionary=contract.prefabs[kind]
 var root:String=spec.root
 var overrides:Dictionary={}
 var root_pose:Transform3D=source_transform(spec.nodes[root])
 # CIL SetMobilePositionOffset; caller supplies actual BnetBar.HorizontalMargin.
 if kind=="gameplay_opponent":root_pose.origin.x+=margin*0.15620000660419464
 overrides[root]=root_pose
 var name_path:String=root+"/PlayerName"
 var name_node:Dictionary=spec.nodes[name_path]
 var layout:Dictionary=_source_text_layout(name_node.ubertext,text)
 if kind=="gameplay_opponent":
  # AdjustBanner ordinary phone branch: m_medalAlphaBannerMiddle is null,
  # so expand the whole AlphaBanner when required, not just its middle slice.
  # RTT text mesh is detached and scale1. Canvas world scale cancels in ratio.
  var middle_path:String=root+"/AlphaBanner/AlphaBanner2"
  var middle_mesh:Dictionary=geometry.meshes[spec.nodes[middle_path].mesh]
  var middle_world:Transform3D=source_world(spec,middle_path,overrides)
  var left:float=INF;var right:float=-INF
  for raw_vertex in middle_mesh.vertices:
   var x:float=(middle_world*Vector3(raw_vertex[0],raw_vertex[1],raw_vertex[2])).x
   left=minf(left,x);right=maxf(right,x)
  var width:float=float(layout.source_bounds.x)*source_world(spec,name_path,overrides).basis.get_scale().x
  var desired:float=width*(1.0+float(spec.nodes[root].name_banner.FUDGE_FACTOR))
  if desired>right-left:
   var alpha_path:String=root+"/AlphaBanner"
   var alpha:Transform3D=source_transform(spec.nodes[alpha_path])
   alpha.basis=alpha.basis.scaled(Vector3(desired/(right-left),1,1))
   overrides[alpha_path]=alpha
 var local_pose:Transform3D=source_transform(name_node)
 var namebone:String=root+("/AlphaBanner/NameBone" if kind=="gameplay_opponent" else "/NameBone")
 if subtext.is_empty():
  # PositionNameText: source sets WORLD position to NameBone position.
  local_pose.origin=source_world(spec,root,overrides).affine_inverse()*source_world(spec,namebone,overrides).origin
 else:
  # SetSubtext sets LOCAL position to ClassBone.localPosition.
  var classbone:String=root+("/AlphaBanner/ClassBone" if kind=="gameplay_opponent" else "/ClassBone")
  local_pose.origin=source_transform(spec.nodes[classbone]).origin
 overrides[name_path]=local_pose
 var sublayout:Dictionary={}
 if not subtext.is_empty():sublayout=_source_text_layout(spec.nodes[name_path+"/ClassName"].ubertext,subtext)
 if kind!="gameplay_opponent":
  var bone:String=root+"/NameBannerSkinned/joint1/joint2"
  var bp:Transform3D=source_transform(spec.nodes[bone])
  var width:float=float(layout.source_bounds.x)
  if not sublayout.is_empty():width=maxf(width,float(sublayout.source_bounds.x))
  # Ordinary non-medal branch NameBanner.AdjustSkinnedBanner.
  bp.origin.x=minf(-width-1.0,-12.0)
  overrides[bone]=bp
 for path in spec.nodes:
  var n:Dictionary=spec.nodes[path]
  if not n.has("mesh"):continue
  if "Medal" in path:continue
  var mesh:Dictionary=geometry.meshes.get(n.mesh,{})
  if mesh.is_empty():continue
  var vertices:=PackedVector2Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
  var world:Transform3D=source_world(spec,path,overrides)
  for i in range(mesh.vertices.size()):
   var v:Array=mesh.vertices[i];var point:=Vector3(v[0],v[1],v[2])
   if not n.bones.is_empty():
    var bi:int=int(mesh.bone_indices[i][0])
    point=source_world(spec,n.bones[bi],overrides)*(_matrix(mesh.bindposes[bi])*point)
   else:point=world*point
   vertices.append(screen_position(spec,point,canvas))
   uv.append(Vector2(mesh.uv0[i][0],1.0-mesh.uv0[i][1]))
   colors.append(Color.WHITE)
  for sub in mesh.triangles:
   for tri in sub:
    for index in tri:indices.append(int(index))
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
  var draw_mesh:=ArrayMesh.new();draw_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  _commands.append({"mesh":draw_mesh})
 var name_world:Transform3D=source_world(spec,name_path,overrides)
 layout["world"]=name_world;layout["anchor"]=screen_position(spec,name_world.origin,canvas);layout["canvas_scale"]=canvas.y/160.0
 _commands.append(layout)
 audit.append({"kind":kind,"name_origin_px":[layout.anchor.x,layout.anchor.y],"glyph_source_bounds":[layout.source_bounds.x,layout.source_bounds.y],"source_world_scale":name_world.basis.get_scale(),"anchor":spec.anchor,"font_size":layout.font_size,"raw_character_size":name_node.ubertext.m_CharacterSize,"compatibility":"Godot text bounds/raster; no Unity GPU equivalence claim"})
 if not sublayout.is_empty():
  var subworld:Transform3D=source_world(spec,name_path+"/ClassName",overrides)
  sublayout["world"]=subworld;sublayout["anchor"]=screen_position(spec,subworld.origin,canvas);sublayout["canvas_scale"]=canvas.y/160.0
  _commands.append(sublayout)

func prepare(mode:String,names:Dictionary,canvas:Vector2,classes:Dictionary={},bnet_horizontal_margin:float=-1.0) -> void:
 if contract.is_empty():setup()
 if bnet_horizontal_margin<0.0:bnet_horizontal_margin=source_horizontal_margin(canvas)
 var key:String=JSON.stringify([mode,names,canvas,classes,bnet_horizontal_margin])
 if key==_state_key:return
 _state_key=key;_commands.clear();audit.clear()
 if mode=="mulligan":
  _append_banner("mulligan_opponent",str(names.get("opponent","")),str(classes.get("opponent","")),canvas,0)
  _append_banner("mulligan_friendly",str(names.get("friendly","")),str(classes.get("friendly","")),canvas,0)
 elif mode=="gameplay":
  _append_banner("gameplay_opponent",str(names.get("opponent","")),"",canvas,bnet_horizontal_margin)

func draw(target:CanvasItem,offset:Vector2=Vector2.ZERO) -> void:
 # offset must cancel fixed_canvas.presentation_offset if the host centers1600x900.
 for cmd in _commands:
  if cmd.has("mesh"):
   target.draw_set_transform(offset)
   target.draw_mesh(cmd.mesh,texture,Transform2D.IDENTITY)
   continue
  var raw:Dictionary=cmd.raw
  var alignment:int=int(raw.m_Alignment)
  var world:Transform3D=cmd.world
  var source_scale:Vector3=world.basis.get_scale()
  var scale2:=Vector2(source_scale.x,source_scale.y)*float(cmd.canvas_scale)*float(cmd.source_per_pixel)
  var anchor:Vector2=cmd.anchor+offset
  if alignment!=1:anchor.x+=(float(raw.m_Width)*0.5*(1.0 if alignment==2 else -1.0))*source_scale.x*float(cmd.canvas_scale)
  target.draw_set_transform(anchor,0.0,scale2)
  var x:float=0.0 if alignment==0 else (-float(cmd.font_pixel_width) if alignment==2 else -float(cmd.font_pixel_width)*.5)
  var y:float=(font.get_ascent(cmd.font_size)-font.get_descent(cmd.font_size))*.5
  # Middle anchor. Godot dynamic-font outline is a compatibility rendering only.
  target.draw_string_outline(font,Vector2(x,y),cmd.text,HORIZONTAL_ALIGNMENT_LEFT,-1,cmd.font_size,int(round(float(raw.m_OutlineSize))),Color.BLACK)
  var c:Dictionary=raw.m_TextColor
  target.draw_string(font,Vector2(x,y),cmd.text,HORIZONTAL_ALIGNMENT_LEFT,-1,cmd.font_size,Color(c.r,c.g,c.b,c.a))
 target.draw_set_transform(Vector2.ZERO)
