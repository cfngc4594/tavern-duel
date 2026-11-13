extends Node3D
## ZoneHand enemy branch + Card_Hidden original mesh and default card-back material.
## Hidden ordinary cards only. Revealed/opponent spectator state is not inferred.
const Hand=preload("res://scripts/native_phone_hand.gd")
const Transmission=preload("res://scripts/native_combat_transmission.gd")
var game
var row:Dictionary
var raw:Array
var pieces:Array[Dictionary]=[]
var mesh_transform:=Transform3D.IDENTITY
var collider:=AABB()
var blockers:Array[String]=[]
var draw_queue:Array[Dictionary]=[]
var deck_bones:Dictionary={}
var draw_clock:float=0.0
var source_audio_serial:=0
var source_audio_results:Array=[]
var logical_only_mode:=false
func setup(host,logical_only:bool=false):
 logical_only_mode=logical_only
 game=host;draw_clock=game.elapsed;basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
 row=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_opposing_hand.json")).rows.Zone_Opposing_Hand
 if logical_only_mode:return # Same source poses/queue, no renderer or image allocation.
 raw=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_hidden_actor.json"))
 var assets=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_hidden_assets.json"))
 var renderer=game.native_card_renderer
 for mesh in assets.meshes:renderer.meshes[mesh.key]=mesh
 for material in assets.materials:renderer.materials[material.key]=material
 for texture in assets.textures:
  var image=Image.new()
  var error=image.load_png_from_buffer(FileAccess.get_file_as_bytes(texture.path))
  if error!=OK:
   blockers.append("Cannot decode packed original card-back PNG "+str(texture.path));continue
  renderer.textures[texture.key]=ImageTexture.create_from_image(image)
 for node in raw:
  if node.name!="Mesh":continue
  for c in node.components:
   if c.type=="Transform":mesh_transform=local_transform(c.data)
   if c.type=="BoxCollider":
    var size=renderer.vec(c.data.m_Size);collider=AABB(renderer.vec(c.data.m_Center)-size*.5,size)
func local_transform(d:Dictionary)->Transform3D:
 var r=d.m_LocalRotation;var b=Basis(Quaternion(r.x,r.y,r.z,r.w));var s=game.native_card_renderer.vec(d.m_LocalScale)
 return Transform3D(Basis(b.x*s.x,b.y*s.y,b.z*s.z),game.native_card_renderer.vec(d.m_LocalPosition))
func source_pose(index:int,count:int)->Dictionary:
 var center=Hand.vector(row.collider_bounds.center)
 var step=minf(1.2708040475845337,float(row.collider_bounds.size[0])/maxi(count,1))
 var yaw=20.0-40.0*index/float(count-1) if count>3 else 0.0
 var bend=pow(index+.5-count*.5,2)/(6.0*maxi(count,1)) if count>3 else 0.0
 var lip=sin(absf(deg_to_rad(yaw)))*step*.5 if yaw<0 else 0.0
 return {"position":center+Vector3((2*index-(count-1))*step*.5,0,bend+lip),"rotation":Vector3(0,yaw,352.5),"scale":Vector3(.6819999814033508,.125,.6819999814033508)}
func make_piece()->Dictionary:
 var renderer=game.native_card_renderer
 var holder=Node3D.new();add_child(holder)
 var actor=Node3D.new();actor.name="Card_Hidden";holder.add_child(actor)
 var root_object=Node3D.new();root_object.name="RootObject";actor.add_child(root_object)
 var result={"root":holder,"actor":actor,"meshes":[]}
 for node in raw:
  if node.name not in ["Mesh","Shadow"]:continue
  var container=Node3D.new();container.name=node.name;root_object.add_child(container)
  var mesh_id="";var material_id="6363512783986347805" if node.name=="Mesh" else "-8971777006715196974"
  for c in node.components:
   if c.type=="Transform":container.transform=local_transform(c.data)
   if c.type=="MeshFilter":mesh_id=str(c.data.m_Mesh.m_PathID)
  var mesh_key="CAB-66e7137de3b79380e05eb711ae004556:"+mesh_id
  var md=renderer.materials["CAB-3563ba8b89db13ca6eb196aa111591f1:"+material_id] if renderer.materials.has("CAB-3563ba8b89db13ca6eb196aa111591f1:"+material_id) else null
  if md==null:
   for material in renderer.materials.values():
    if str(material.key).ends_with(":"+material_id):md=material;break
  var tex=renderer.textures[md.textures[0].key]
  var material=renderer._world_character_material(md,tex)
  var mi=MeshInstance3D.new();mi.mesh=renderer._geometry(renderer.meshes[mesh_key]);mi.material_override=material;container.add_child(mi);result.meshes.append(mi)
  Transmission.register_fixed_source(mi)
  if material==null:blockers.append("Unported Card_Hidden material "+material_id);holder.visible=false
 return result
func enqueue_draw(index:int,deck_count:int,tracker:int,ticket:int=-1):
 draw_queue.append({"index":index,"deck_count":deck_count,"tracker":tracker,"ticket":ticket,"started":false})
func draws_pending()->bool:
 return not draw_queue.is_empty()
func advance_draws():
 if draw_queue.is_empty():draw_clock=game.elapsed;return
 if deck_bones.is_empty():deck_bones=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_deck_runtime.json")).rows
 if not deck_bones.has("OpponentDrawCard"):
  if "Missing source OpponentDrawCard bone" not in blockers:blockers.append("Missing source OpponentDrawCard bone")
  return
 var entry=draw_queue[0]
 if not entry.started:
  if preload("res://scripts/native_hand_burn_timeline.gd").blocks_draw(game,1,int(entry.get("ticket",-1))):
   draw_clock=game.elapsed;return
  source_audio_serial+=1
  var sound=get_node_or_null("/root/SoundManager")
  if sound!=null:source_audio_results.append(sound.play_phone_source_audio("opposing_draw",{"scope_id":"source-opponent-draw:"+str(get_instance_id())+":"+str(source_audio_serial),"event_token":"flight-start","source_side":1}))
  entry.started=true;entry.begin=draw_clock;entry.time_scale=preload("res://scripts/native_phone_draw.gd").time_scale(entry.tracker)
  entry.start=Hand.vector(deck_bones["Zone_Opposing_Deck:m_Tickness"+preload("res://scripts/native_phone_draw.gd").thickness(entry.deck_count)+"TopOfDeck"].phone_world_position)
  entry.target=source_pose(entry.index,game.enemy_hand.size())
 var age=maxf(0,game.elapsed-entry.begin)
 entry.pose=preload("res://scripts/native_phone_opponent_draw.gd").flight(entry.start,Hand.vector(deck_bones.OpponentDrawCard.phone_world_position),entry.target,age,entry.time_scale)
 if age>=1.75*entry.time_scale:
  draw_clock=entry.begin+1.75*entry.time_scale;draw_queue.pop_front();advance_draws()
func sync():
 advance_draws()
 if logical_only_mode:return
 var count=game.enemy_hand.size()
 while pieces.size()>count:
  var old=pieces.pop_back();old.root.queue_free()
 for i in count:
  if i>=pieces.size():pieces.append(make_piece())
  var pose=source_pose(i,count);var drawing_hidden=false
  for entry in draw_queue:
   if entry.index==i:
    if entry.has("pose"):pose=entry.pose
    else:drawing_hidden=true
  var b=Hand.source_basis(pose.rotation)
  pieces[i].root.transform=Transform3D(Basis(b.x*pose.scale.x,b.y*pose.scale.y,b.z*pose.scale.z),pose.position)
  pieces[i].root.visible=blockers.is_empty() and not drawing_hidden
func contains(point:Vector2)->bool:
 if not visible or game.source_projection==null:return false
 var ray=game.source_projection.screen_ray_to_source(point)
 if ray.is_empty():return false
 for piece in pieces:
  if not piece.root.visible:continue
  var inverse:Transform3D=(piece.root.transform*mesh_transform).affine_inverse()
  if collider.intersects_ray(inverse*ray.origin,inverse.basis*ray.direction)!=null:return true
 return false
