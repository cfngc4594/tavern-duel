extends Node3D
## Original HistoryManager/HistoryCard tile assets and layout, presented through
## the shared source phone camera. No screenshot crops, panel drawing or name matching.
## Modern source client 37.0; Godot lighting/rasterization remain compatibility.
const BASE="res://assets/native_history/"
const Transmission=preload("res://scripts/native_combat_transmission.gd")
const SOURCE_REFLECTION=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
# Original CullBack render state. The Unity-to-Godot mirrored root changes
# triangle handedness, as in native_card_renderer._geometry(flipped_surfaces).
# Keep source culling, adapt indices; never hide this with a two-sided shader.
const SOURCE_CULL_BACK=["-5812771937585292081","-9095043052161131177","143677912420122213","-1208607894637808160"]
# These source materials are immutable (history movement changes transforms).
# Keep a deduplicated process-lifetime asset cache so a tile/reset cannot free
# a material before Godot finishes removing its render-instance dependencies.
# The key covers source parameters, source portrait identity and exact tint;
# the fixed source card set bounds this cache, rather than the number of events.
static var shared_material_cache:Dictionary={}
var game
var source:Dictionary={}
var entries:Dictionary={}
var mesh_cache:Dictionary={}
var texture_cache:Dictionary={}
var blockers:Array=[]
var last_serials:Array=[]
var last_frame:=-1
var displayed:Array=[]
func setup(host):
 game=host;basis=SOURCE_REFLECTION
 source=JSON.parse_string(FileAccess.get_file_as_string(BASE+"runtime.json"))
func vector(v)->Vector3:return Vector3(v.x,v.y,v.z)
func tint(v)->Color:return Color(v.r,v.g,v.b,v.a)
func top_position()->Vector3:
 # HistoryManager.GetTopTilePosition0x06005929 divides serialized size by local scale.
 var m=source.manager;var c=m.base_collider
 return vector(m.m_LocalPosition)+vector(c.m_Center)+Vector3(0,-0.3199999928474426,float(c.m_Size.z)/2.0/float(m.m_LocalScale.z))
func _texture(id:String):
 if not source.textures.has(id):return null
 if not texture_cache.has(id):texture_cache[id]=load(BASE+source.textures[id])
 return texture_cache[id]
func _mesh(id:String,flipped_surfaces:Array=[])->ArrayMesh:
 var cache_key=id+str(flipped_surfaces)
 if mesh_cache.has(cache_key):return mesh_cache[cache_key]
 var d=JSON.parse_string(FileAccess.get_file_as_string(BASE+source.meshes[id]));var a=[];a.resize(Mesh.ARRAY_MAX)
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
 for v in d.vertices:vertices.append(Vector3(v[0],v[1],v[2]))
 for n in d.normals:normals.append(Vector3(n[0],n[1],n[2]))
 for uv in d.uv0:uvs.append(Vector2(uv[0],1.0-uv[1]))
 for c in (d.colors if d.colors is Array else []):colors.append(Color(c[0],c[1],c[2],c[3]))
 if colors.size()!=vertices.size():colors.resize(vertices.size());colors.fill(Color.WHITE)
 a[Mesh.ARRAY_VERTEX]=vertices;a[Mesh.ARRAY_NORMAL]=normals;a[Mesh.ARRAY_TEX_UV]=uvs;a[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new()
 for surface_index in range(d.triangles.size()):
  var surface=d.triangles[surface_index]
  var indices=PackedInt32Array()
  for tri in surface:
   indices.append_array(PackedInt32Array([int(tri[0]),int(tri[2]),int(tri[1])]) if surface_index in flipped_surfaces else PackedInt32Array([int(tri[0]),int(tri[1]),int(tri[2])]))
  a[Mesh.ARRAY_INDEX]=indices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 mesh_cache[cache_key]=mesh;return mesh
func _portrait(key:String):
 var source_key=_portrait_material_key(key)
 if not source.get("portrait_pixels",{}).has(source_key):
  blockers.append("No verified history portrait: "+key);return null
 var cache_key="portrait:"+source_key
 if not texture_cache.has(cache_key):texture_cache[cache_key]=load(BASE+source.portrait_pixels[source_key].file)
 return texture_cache[cache_key]
func _portrait_material_key(key:String)->String:
 return {"CS2_034":"HERO_08bp","CS2_056":"HERO_07bp"}.get(key,key)
func _material(record:Dictionary,portrait:Texture2D=null,frame_color:Color=Color.WHITE)->Material:
 var portrait_key=""
 if portrait!=null:portrait_key=portrait.resource_path if portrait.resource_path!="" else "instance:"+str(portrait.get_instance_id())
 var cache_key=JSON.stringify([record,portrait_key,frame_color.r,frame_color.g,frame_color.b,frame_color.a])
 if shared_material_cache.has(cache_key):return shared_material_cache[cache_key]
 var routes={"-5812771937585292081":"native_combat_diffuse_color","-5773009347599192354":"native_combat_multiply_rgb","-9095043052161131177":"native_history_icon","143677912420122213":"native_mana_unlit_texture","-1208607894637808160":"native_history_portrait"}
 if not routes.has(record.shader_id):blockers.append("Unported history shader "+str(record.shader_id));return null
 var material=ShaderMaterial.new();material.shader=load("res://shaders/"+routes[record.shader_id]+".gdshader")
 for name in record.floats:material.set_shader_parameter(name,float(record.floats[name]))
 for name in record.colors:material.set_shader_parameter(name,tint(record.colors[name]))
 for name in record.textures:
  var tx:Dictionary=record.textures[name]
  var texture=portrait if portrait!=null and name=="_MainTex" else _texture(str(tx.id))
  if texture!=null:material.set_shader_parameter(name,texture)
  material.set_shader_parameter(name+"_ST",Vector4(tx.scale.x,tx.scale.y,tx.offset.x,1.0-tx.scale.y-tx.offset.y))
 if record.shader_id=="-5812771937585292081":material.set_shader_parameter("_Color",frame_color)
 material.set_meta("history_source_shader",record.shader_id)
 shared_material_cache[cache_key]=material
 return material
func _make(event:Dictionary)->Dictionary:
 var kind=str(event.kind);if not source.profiles.has(kind):return {}
 var profile=source.profiles[kind];var root=Node3D.new();root.name="OriginalHistory_"+str(event.serial);add_child(root)
 var nodes={};var collider={};var source_key=_portrait_material_key(str(event.key));var half=kind!="played"
 var portrait=_portrait(str(event.key))
 if portrait==null:root.queue_free();return {}
 var frame_color=Color(source.friendly_tint[0],source.friendly_tint[1],source.friendly_tint[2],1) if int(event.side)==0 else Color(source.opponent_tint[0],source.opponent_tint[1],source.opponent_tint[2],1)
 for spec in profile.nodes:
  var node=Node3D.new();node.name=spec.name;nodes[spec.id]=node
  var parent=root if spec.parent=="" else nodes[spec.parent];parent.add_child(node)
  # LoadTileImpl resets prefab root transform and copies HistoryManager scale.
  if spec.parent=="":node.scale=vector(source.manager.m_LocalScale)
  else:
   node.position=vector(spec.position);node.quaternion=Quaternion(spec.rotation.x,spec.rotation.y,spec.rotation.z,spec.rotation.w).normalized();node.scale=vector(spec.scale)
  node.visible=bool(spec.active)
  if spec.has("collider"):collider={"node":node,"data":spec.collider}
  if spec.has("mesh"):
   var flipped_surfaces=[]
   for i in range(spec.materials.size()):
    if str(source.materials[spec.materials[i]].shader_id) in SOURCE_CULL_BACK:flipped_surfaces.append(i)
   var mesh=MeshInstance3D.new();mesh.name="SourceMesh";mesh.mesh=_mesh(spec.mesh,flipped_surfaces);node.add_child(mesh);mesh.visible=bool(spec.renderer_enabled)
   for i in range(spec.materials.size()):
    var record:Dictionary=source.materials[spec.materials[i]];var tx:Texture2D=null
    if spec.name=="Mesh" and i==1:
     tx=portrait
     if source.portraits.has(source_key):record=source.portraits[source_key].get("half" if half else "full",record)
    var mat=_material(record,tx,frame_color)
    if mat==null:root.visible=false
    else:mesh.set_surface_override_material(i,mat)
   Transmission.register_fixed_source(mesh)
 var size=0.0;var polygon=[]
 if not collider.is_empty():
  var co=collider.data;var pose=root.global_transform.affine_inverse()*collider.node.global_transform
  var low=INF;var high=-INF
  for x in [-1,1]:
   for y in [-1,1]:
    for z in [-1,1]:
     var v=pose*(vector(co.center)+vector(co.size)*Vector3(x,y,z)*0.5);polygon.append(v);low=minf(low,v.z);high=maxf(high,v.z)
  size=high-low
 root.position=top_position()-Vector3(20,0,0)
 return {"root":root,"event":event.duplicate(true),"size":size,"half":half,"local_corners":polygon,"start":root.position,"target":root.position,"age":0.0}
func layout_events(events:Array)->Array:
 var visible_events=[];var height=0.0
 var capacity=float(source.manager.base_collider.m_Size.z)*float(source.manager.m_LocalScale.z)
 for event in events:
  var serial=int(event.serial)
  if not entries.has(serial):
   var state=_make(event)
   if state.is_empty():continue
   entries[serial]=state
  var state:Dictionary=entries[serial]
  var next=height+float(state.size)+(float(source.placement_gap) if not visible_events.is_empty() else 0.0)
  if next>capacity:break
  height=next;visible_events.append(serial)
 return visible_events
func sync():
 visible=game.source_projection!=null
 if not visible:
  if game.native_history_events.entries.is_empty():
   for state in entries.values():state.root.queue_free()
   entries.clear();displayed.clear();last_serials.clear()
  return
 var frame=Engine.get_process_frames();var delta=float(game.source_visual_delta) if frame!=last_frame else 0.0;last_frame=frame
 var wanted=game.native_history_events.entries
 var serials=wanted.map(func(e):return int(e.serial))
 if serials!=last_serials:
  last_serials=serials;displayed=layout_events(wanted)
  var offset=0.0;var top=top_position()
  for serial in displayed:
   var state:Dictionary=entries[serial]
   state.start=state.root.position;state.target=top+Vector3(0,0,-offset+(float(state.size)*0.5 if state.half else 0.0));state.age=0.0
   offset+=float(state.size)+float(source.placement_gap)
  for serial in entries.keys():
   if not displayed.has(serial):entries[serial].root.queue_free();entries.erase(serial)
 for state in entries.values():
  state.age=minf(1.0,float(state.age)+delta)
  # iTween.Defaults.easeType=16 (easeOutExpo), exact endpoint at t=1.
  var amount=1.0 if state.age>=1.0 else 1.0-pow(2.0,-10.0*float(state.age))
  state.root.position=state.start.lerp(state.target,amount)
func get_audit()->Dictionary:
 var rows=[]
 for serial in displayed:
  var state:Dictionary=entries[serial]
  rows.append({"serial":serial,"key":state.event.key,"side":state.event.side,"kind":state.event.kind,"size":state.size,"source_position":state.root.position,"target":state.target})
 return {"tiles":rows,"blockers":blockers.duplicate(),"source_build":source.get("source_build",""),"layout":"Original HistoryManager collider capacity, 0.15 gap, full/half geometry; source world shared phone camera","legacy_label_matching":false,"native_pixel_equivalence":false,"limitations":["Source shader arithmetic with existing Godot GL color bridge and compatibility scene lighting","History hover expansion/child-card actor presentation not yet ported"]}
