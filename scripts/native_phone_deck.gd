extends Node3D
## Ordinary classic deck actors. Source-world transforms, with one Z reflection.
## ZoneDeck.UpdateThicknessWithCount 0x0600641f, GetTopOfDeckBoneForThickness 0x06006419.
var renderer
var source:Dictionary={}
var actors:Dictionary={}
var counts:Array=[0,0]
var blockers:Array=[]
func setup(card_renderer:Node)->void:
 renderer=card_renderer
 basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
 source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_deck_runtime.json"))
 var one:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/deck_one_assets.json"))
 renderer.meshes[one.mesh.key]=one.mesh;renderer.materials[one.material.key]=one.material
 for side in range(2):
  for thickness in ["1","25","50","75","Full"]:
   var mesh_data:Dictionary
   var material_data:Dictionary
   if thickness=="1":mesh_data=one.mesh;material_data=one.material
   else:
    var profile:Dictionary=renderer.profiles["deck_"+thickness.to_lower()]
    var render:Dictionary=profile.renderers[0]
    mesh_data=renderer.meshes[render.meshKey];material_data=renderer.materials[render.materialKeys[0]]
   var actor:=Node3D.new();actor.name=("Friendly" if side==0 else "Opposing")+"Deck"+thickness;add_child(actor)
   var row:Dictionary=source.rows[_zone(side)+":m_Thickness"+thickness]
   actor.transform=_matrix(row.phone_world_matrix)
   actor.set_meta("source_actor",row.components);actor.set_meta("source_mesh",mesh_data.key)
   var mesh:=MeshInstance3D.new();mesh.mesh=renderer._geometry(mesh_data);actor.add_child(mesh)
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var texture:Texture2D=renderer.textures.get(material_data.textures[0].key)
   var mat:Material=renderer._world_character_material(material_data,texture)
   if mat==null or texture==null:blockers.append({"mesh":mesh_data.key,"material":material_data.key,"reason":"source material or texture unavailable"})
   mesh.set_surface_override_material(0,mat)
   # RootObject/Mesh are identity in every recovered instance, including Thickness1.
   actor.visible=false;actors[str(side)+":"+thickness]=actor
func set_count(side:int,count:int)->void:
 counts[side]=maxi(0,count)
 var chosen:String=thickness_for_count(count)
 for thickness in ["1","25","50","75","Full"]:
  actors[str(side)+":"+thickness].visible=thickness==chosen and blockers.is_empty()
func top_of_deck(side:int)->Vector3:
 var thickness:String=thickness_for_count(counts[side])
 if thickness=="":thickness="1" # Original GetThicknessForLayout fallback when no active actor.
 var row:Dictionary=source.rows[_zone(side)+":m_Tickness"+thickness+"TopOfDeck"]
 return _vector(row.phone_world_position) # Unity world, before this node's Z reflection.
static func thickness_for_count(count:int)->String:
 if count<=0:return ""
 if count==1:return "1"
 var ratio:float=float(count)/26.0
 if ratio>.75:return "Full"
 if ratio>.5:return "75"
 if ratio>.25:return "50"
 return "25"
static func _zone(side:int)->String:return "Zone_Friendly_Deck" if side==0 else "Zone_Opposing_Deck"
static func _vector(v:Array)->Vector3:return Vector3(v[0],v[1],v[2])
static func _matrix(m:Array)->Transform3D:
 return Transform3D(Basis(Vector3(m[0][0],m[1][0],m[2][0]),Vector3(m[0][1],m[1][1],m[2][1]),Vector3(m[0][2],m[1][2],m[2][2])),Vector3(m[0][3],m[1][3],m[2][3]))
