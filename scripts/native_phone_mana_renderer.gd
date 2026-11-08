extends Node3D
## Original mana meshes/materials and original UberText glyph geometry.
## Attach to an unreflected rendering world; this node applies source Z reflection.
const Curves=preload("res://scripts/native_summon_curves.gd")
const Assets=preload("res://scripts/native_phone_mana_assets.gd")
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const DIR="res://assets/native_phone_mana/"
var assets
var live_crystals:Dictionary={}
var retiring_crystals:Array=[]
var renderer:Node
var profiles:Dictionary={}
var text_specs:Dictionary={}
var pieces:Dictionary={}
var text_nodes:Dictionary={}
var materials:Dictionary={}
var glyph_bundle:Dictionary={}
var blockers:Array=[]
var rendering_ready:=false
var geometry_ready:=false
static func source_transform(t:Dictionary)->Transform3D:
 var q=t.m_LocalRotation;var s=Layout.vector(t.m_LocalScale)
 return Transform3D(Basis(Quaternion(q.x,q.y,q.z,q.w).normalized()).scaled(s),Layout.vector(t.m_LocalPosition))
func setup(card_renderer:Node):
 renderer=card_renderer;transform=Transform3D(Layout.REFLECTION,Vector3.ZERO)
 assets=Assets.new();assets.setup(renderer);assets.gem_material_factory=_material
 profiles=JSON.parse_string(FileAccess.get_file_as_string(DIR+"profiles.json"))
 text_specs=JSON.parse_string(FileAccess.get_file_as_string(DIR+"counter_specs.json"))
 var font_data=JSON.parse_string(FileAccess.get_file_as_string(DIR+"zhcn_glei_glyphs.json"));var glyphs={}
 for glyph in font_data.glyphs:glyphs[glyph.character]=glyph
 var path=DIR+"zhcn_glei_atlas.png"
 var atlas=load(path) if ResourceLoader.exists(path) else Assets.packed_png(path)
 glyph_bundle={"glyphs":glyphs,"atlas":atlas,"size":Vector2(font_data.atlasWidth,font_data.atlasHeight),"metrics":font_data.metrics,"density":font_data.raster_density,"source_font_size":font_data.source_font_size,"font_size_modifier":font_data.font_size_modifier}
 for side in ["friendly","opposing"]:_piece(side+"_counter","counter")
 for i in range(10):_piece("crystal_"+str(i),"crystal")
 geometry_ready=blockers.is_empty();visible=false
func _block(reason:String):
 if not blockers.has(reason):blockers.append(reason)
func _material(key:String)->ShaderMaterial:
 if materials.has(key):return materials[key].duplicate()
 var record:Dictionary=assets.objects.get(key,{})
 if record.is_empty():_block("Missing source material "+key);return null
 if not str(record.refs.get(".m_Shader","")).ends_with(":9099378368919310605"):
  _block("Unported mana shader "+str(record.refs.get(".m_Shader","")));return null
 var props:Dictionary=record.data.m_SavedProperties
 var md={"sourceShaderKey":record.refs['.m_Shader'],"floats":[],"colors":[],"textures":[]}
 for f in props.m_Floats:md.floats.append({"name":f[0],"value":f[1]})
 for c in props.m_Colors:md.colors.append({"name":c[0],"value":c[1]})
 var material:ShaderMaterial=renderer._source_material(md,StandardMaterial3D.new())
 for i in range(props.m_TexEnvs.size()):
  var tx=props.m_TexEnvs[i];var key_texture=str(record.refs.get(".m_SavedProperties.m_TexEnvs[%d][1].m_Texture"%i,""))
  var texture=assets.load_texture(key_texture)
  if texture==null:_block("Missing mana texture "+key_texture);return null
  var parameter={"_MainTex":"main_tex","_ScrollingTex":"scrolling_tex"}.get(tx[0],"")
  if parameter=="":_block("Unbound mana texture slot "+tx[0]);return null
  renderer._bind_verified_texture(material,parameter,texture)
  if tx[0]=="_MainTex":
   var st=tx[1];material.set_shader_parameter("main_st",Vector4(st.m_Scale.x,st.m_Scale.y,st.m_Offset.x,1.0-st.m_Scale.y-st.m_Offset.y))
   var texture_record:Dictionary=assets.objects[key_texture]
   var settings:Dictionary=texture_record.data.get("m_TextureSettings",{})
   material.set_shader_parameter("main_repeat",int(settings.get("m_WrapU",1))==0)
 material.set_meta("source_material",key);materials[key]=material
 return material.duplicate()
func _piece(key:String,profile:String):
 var root=Node3D.new();root.name=key;add_child(root)
 var spec:Dictionary=profiles[profile];var mesh=MeshInstance3D.new();root.add_child(mesh)
 mesh.transform=source_transform(spec.local_transform);mesh.mesh=assets.geometry(spec.mesh)
 if mesh.mesh==null:_block("Missing mana mesh "+str(spec.mesh));return
 for i in range(mesh.mesh.get_surface_count()):
  var material=_material(spec.materials[mini(i,spec.materials.size()-1)])
  if material==null:return
  mesh.set_surface_override_material(i,material)
 pieces[key]={"root":root,"mesh":mesh,"profile":profile};root.visible=false
func sync(snapshot:Dictionary,values:Dictionary):
 # values supplies counter strings when the original localized format is needed;
 # states/clip samples remain explicit rather than invented darkened materials.
 blockers.clear();rendering_ready=false;visible=false
 if not geometry_ready:_block("Mana geometry/material initialization incomplete");return
 if not snapshot.get("ready",false):_block("Source layout snapshot is not rendering_ready");return
 for side in ["friendly","opposing"]:
  pieces[side+"_counter"].root.transform=snapshot.items[side+"_mana"].source_pose
  pieces[side+"_counter"].root.visible=true
  if values.get("counter_flip_times",{}).has(side):_sample_counter(pieces[side+"_counter"],snapshot.items[side+"_mana"].source_pose,float(values.counter_flip_times[side]))
 var hidden_poses:Dictionary=values.get("hidden_crystal_poses",{})
 for index in live_crystals:
  if int(index)<10:continue
  if not hidden_poses.get(index) is Transform3D:
   _block("Missing recovered hidden crystal parent pose: "+str(index));continue
  pieces["crystal_"+str(index)].root.transform=hidden_poses[index]
  pieces["crystal_"+str(index)].root.visible=true
  pieces["crystal_"+str(index)].mesh.visible=false
  live_crystals[index].set_source_active(false)
  for reason in live_crystals[index].blockers:_block(str(reason))
 var crystals:Array=snapshot.items.friendly_mana.crystals
 for i in range(10):
  var piece:Dictionary=pieces["crystal_"+str(i)];piece.root.visible=i<crystals.size()
  if i<crystals.size():
   piece.root.transform=crystals[i].source_pose
   var material_key="cab-3563ba8b89db13ca6eb196aa111591f1:1211368574384928431" if crystals[i].kind=="temporary" else profiles.crystal.materials[0]
   var mat=_material(material_key)
   if mat!=null:piece.mesh.set_surface_override_material(0,mat)
   var samples:Array=values.get("crystal_samples",[])
   if live_crystals.has(i):
    piece.mesh.visible=false;live_crystals[i].transform=Transform3D.IDENTITY
    live_crystals[i].set_source_active(true)
    for reason in live_crystals[i].blockers:_block(str(reason))
   elif i<samples.size():piece.mesh.visible=true;_sample_crystal(piece,samples[i])
   else:_block("Missing explicit crystal sample "+str(i))

 for key in text_specs:
  if not values.has(key):_block("Missing source counter text/value: "+key);continue
  _text(key,str(values[key]),snapshot,values)
  if key=="friendly_counter" and text_nodes.has(key):
   var tint=Curves.color(text_specs[key].data.m_TextColor)
   tint.a*=clampf(float(values.get("friendly_counter_alpha",1.0)),0.0,1.0)
   text_nodes[key].glyph.mesh.surface_get_material(0).set_shader_parameter("text_tint",tint)
 for player in retiring_crystals:
  for reason in player.blockers:_block(str(reason))
 rendering_ready=blockers.is_empty();visible=rendering_ready
func _text(key:String,text:String,snapshot:Dictionary,values:Dictionary):
 var spec:Dictionary=text_specs[key];var d:Dictionary=spec.data
 if int(d.m_Font.m_PathID)!=4766376857981636630:_block("Unsupported mana font identity");return
 if d.m_ResizeToFit or d.m_ResizeToFitAndGrow:_block("Mana dynamic font layout not ported");return
 var pose=Transform3D.IDENTITY
 for row in spec.counter_relative_chain:
  var local=source_transform(row.transform)
  if row.name=="ManaTrayPhone":local.origin=Layout.vector(values.get("mana_tray_position",snapshot.items.friendly_mana.tray_endpoints.shown))
  pose=pose*local
 if text_nodes.has(key) and text_nodes[key].text==text:
  text_nodes[key].root.transform=pose;return
 if text_nodes.has(key):text_nodes[key].root.queue_free()
 var root=Node3D.new();add_child(root);root.transform=pose
 var bundle:Dictionary=glyph_bundle
 if bundle.is_empty():_block("Original zhCN GLEI glyph bundle unavailable");root.queue_free();return
 var glyphs:Dictionary=bundle.glyphs.duplicate(true)
 # UberText.SetFontSize: single-precision product followed by conv.i4.
 # Preserve float32 rounding: 40 * 1.149999976158142 becomes 46, not 45.
 var actual_font_size=int(PackedFloat32Array([float(d.m_FontSize)*float(bundle.font_size_modifier)])[0])
 var ratio=float(actual_font_size)/float(bundle.source_font_size)
 for ch in glyphs:
  for field in ["advance","minX","minY","maxX","maxY"]:glyphs[ch][field]*=ratio
 var text_spec={"role":"cost","characterSize":d.m_CharacterSize,"width":d.m_Width,"height":d.m_Height,"outline":bool(d.m_Outline),"outlineSize":float(d.m_OutlineSize)*float(bundle.density)/ratio,"color":d.m_TextColor,"outlineColor":d.m_OutlineColor}
 var glyph=renderer._add_direct_glyphs(root,text,text_spec,glyphs,bundle.atlas,bundle.size,actual_font_size,bundle.metrics)
 if glyph==null:_block("Missing original mana glyph: "+text);return
 # UberText AnchorOptions.Middle=1, AlignmentOptions.Center=1.
 # SetupTextMeshAlignment maps this pair to Unity TextAnchor.MiddleCenter=4.
 # The direct glyph bridge already uses MiddleCenter; no extra vertical shift.
 if int(d.m_Anchor)!=1 or int(d.m_Alignment)!=1:_block("Unsupported mana text alignment")
 text_nodes[key]={"root":root,"text":text,"glyph":glyph.node}
func get_audit()->Dictionary:
 return {"ready":rendering_ready,"geometry_ready":geometry_ready,"runtime_complete":true,"runtime_missing":[],"live_supported":["birth", "temporary birth", "used", "restore", "proposed", "cancel", "temporary destroy", "normal destroy"],"live_count":live_crystals.size(),"retiring_count":retiring_crystals.size(),"blockers":blockers.duplicate(),"pieces":pieces.size(),"texts":text_nodes.size(),"source":"original prefab mesh/materials, UberText fields and zhCN FontTable resolved GLEI font; no painted panel","compatibility":"Original zhCN GLEI font hhea/hmtx metrics; localized font46 with modifier1.15; FreeType raster at4x, not Unity raster. Original source-material backend bridge, not GPU parity. Hidden Legacy Animation clock and time-zero audio use explicit Godot continuation; Unity inactive equivalence unverified"}

func _sample_crystal(piece:Dictionary,sample:Dictionary):
 var state=str(sample.get("state",""))
 if state=="ready":return # Original material, settled rendering_ready pose.
 var clip_name=str(sample.get("clip","ManaGemUsed" if state=="used" else ""))
 if not clip_name in ["ManaGemUsed","ManaGem_Restore"] or not assets.clips.has(clip_name):
  _block("Unported mana animation state: "+str(sample));return
 var duration:float=assets.clip_length(clip_name);var time=float(sample.get("time",duration))
 # Live spent animation also has particle/object tracks; do not silently omit them.
 if time<duration:
  _block("Live mana transition requires original FX child player: "+clip_name);return
 var material:ShaderMaterial=piece.mesh.get_surface_override_material(0)
 var colors={"_tint":Vector3.ZERO,"_Fade":Vector3.ONE}
 for track in assets.clips[clip_name].data.get("m_FloatCurves",[]):
  if str(track.path)!="":continue
  var bits=str(track.attribute).split(".")
  if bits.size()!=2 or not colors.has(bits[0]):_block("Unknown mana material curve "+str(track.attribute));continue
  var index=["r","g","b"].find(bits[1])
  if index>=0:colors[bits[0]][index]=Curves.scalar_keys(track.curve.m_Curve,time)
 material.set_shader_parameter("scroll_tint",colors._tint)
 material.set_shader_parameter("fade_rgb",colors._Fade)

func _sample_counter(piece:Dictionary,base:Transform3D,time:float):
 var clip_name="Resource_Large_phone_Flip"
 if not assets.clips.has(clip_name):_block("Missing original phone counter flip clip");return
 var local=source_transform(profiles.counter.root_local_transform);local.origin=Vector3.ZERO
 var source_parent=base*local.affine_inverse()
 var d:Dictionary=assets.clips[clip_name].data
 var scale_value=local.basis.get_scale();var rotation=local.basis.orthonormalized().get_rotation_quaternion()
 for track in d.get("m_PositionCurves",[]):
  if str(track.path)=="":local.origin=Curves.vector_curve(track.curve,time)
 for track in d.get("m_ScaleCurves",[]):
  if str(track.path)=="":scale_value=Curves.vector_curve(track.curve,time)
 for track in d.get("m_RotationCurves",[]):
  if str(track.path)=="":rotation=Curves.quaternion_curve(track.curve,time)
 local.basis=Basis(rotation).scaled(scale_value);piece.root.transform=source_parent*local

## Explicit identity/index ownership: call clear_live on replay or source crystal removal.
## sync remains the only source pose owner; advance_live uses the same visual clock.
func begin_live(index:int,temporary:bool,already_present:bool=false,initial_state:int=0,source_pose=null,hidden:bool=false):
 if index<0:return null
 if not pieces.has("crystal_"+str(index)):_piece("crystal_"+str(index),"crystal")
 if source_pose is Transform3D:pieces["crystal_"+str(index)].root.transform=source_pose
 elif index>=10:
  _block("Hidden source crystal requires recovered parent pose");return null
 clear_live(index)
 var player=preload("res://scripts/native_phone_mana_live.gd").new()
 pieces["crystal_"+str(index)].root.add_child(player)
 player.setup(assets,temporary,already_present);live_crystals[index]=player
 if already_present:player.prime_state(initial_state)
 if not already_present:player.create()
 player.set_source_active(not hidden)
 pieces["crystal_"+str(index)].root.visible=true
 pieces["crystal_"+str(index)].mesh.visible=false
 return player
func set_live_state(index:int,source_state:int):
 if live_crystals.has(index):
  var player=live_crystals[index];player.request_state(source_state)
  if source_state==3:
   # Source count may shrink immediately, but the original actor outlives it.
   # Detach with its last source pose so snapshot compaction cannot move it.
   player.reparent(self,true);retiring_crystals.append(player);live_crystals.erase(index)
   pieces["crystal_"+str(index)].mesh.visible=index<10
   if index>=10:pieces["crystal_"+str(index)].root.visible=false
func advance_live(delta:float):
 for player in live_crystals.values():player.advance(delta)
 for player in retiring_crystals:player.advance(delta)
 for i in range(retiring_crystals.size()-1,-1,-1):
  if retiring_crystals[i].finished:retiring_crystals[i].queue_free();retiring_crystals.remove_at(i)
func clear_live(index:int=-1):
 if index<0:
  for player in retiring_crystals:player.visible=false;player.queue_free()
  retiring_crystals.clear()
 var keys=live_crystals.keys() if index<0 else [index]
 for key in keys:
  if live_crystals.has(key):
   live_crystals[key].visible=false;live_crystals[key].queue_free();live_crystals.erase(key)
   pieces["crystal_"+str(key)].mesh.visible=int(key)<10
   if int(key)>=10:pieces["crystal_"+str(key)].root.visible=false
func remap_live(mapping:Dictionary)->bool:
 # Transactional slot migration. Preserve the live source object, clip clock,
 # material and surviving particles. Parent sync then supplies its new pose.
 var next:Dictionary={}
 for old in live_crystals:
  var target=int(mapping.get(old,old))
  if target<0 or next.has(target):return false
  next[target]=live_crystals[old]
 for target in next:
  if not pieces.has("crystal_"+str(target)):_piece("crystal_"+str(target),"crystal")
 for old in live_crystals:
  pieces["crystal_"+str(old)].mesh.visible=int(old)<10
  if int(old)>=10:pieces["crystal_"+str(old)].root.visible=false
 live_crystals=next
 for index in live_crystals:
  var player=live_crystals[index]
  player.reparent(pieces["crystal_"+str(index)].root,false)
  player.transform=Transform3D.IDENTITY
  pieces["crystal_"+str(index)].mesh.visible=false
 return true

func set_live_hidden(index:int,hidden:bool):
 if live_crystals.has(index):live_crystals[index].set_source_active(not hidden)
func set_live_pose(index:int,pose:Transform3D):
 if pieces.has("crystal_"+str(index)):pieces["crystal_"+str(index)].root.transform=pose
