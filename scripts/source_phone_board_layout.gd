extends RefCounted
## Source-world -> existing logical canvas contract. Never guesses missing anchors.
## Caller supplies verified source poses/collider geometry; source camera gate stays
## closed until the complete snapshot and every draw/input consumer are migrated.
static var _source_cache:Dictionary={}
static func source_json(path:String)->Dictionary:
 if not _source_cache.has(path):_source_cache[path]=JSON.parse_string(FileAccess.get_file_as_string(path))
 return _source_cache[path]
const REQUIRED=["friendly_hero","opposing_hero","friendly_power","opposing_power","friendly_play","opposing_play","end_turn","friendly_mana","opposing_mana","friendly_deck","opposing_deck"]
const CameraPolicy=preload("res://scripts/source_board_camera_policy.gd")
const REFLECTION=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
static func vector(value)->Vector3:
 if value is Vector3:return value
 if value is Dictionary:return Vector3(value.x,value.y,value.z)
 return Vector3(value[0],value[1],value[2])
static func project(source_world:Vector3,camera:Camera3D,viewport_size:Vector2,canvas:Vector2,offset:Vector2)->Vector2:
 return camera.unproject_position(REFLECTION*source_world)*canvas/viewport_size-offset
static func project_polygon(points:Array,camera:Camera3D,viewport_size:Vector2,canvas:Vector2,offset:Vector2)->PackedVector2Array:
 var result=PackedVector2Array()
 for point in points:result.append(project(vector(point),camera,viewport_size,canvas,offset))
 return result
static func contains(snapshot:Dictionary,key:String,logical_point:Vector2)->bool:
 if not snapshot.get("ready",false) or not snapshot.items.has(key):return false
 var item=snapshot.items[key]
 return item.get("interactive",true) and item.get("enabled",true) and item.hit_polygon.size()>=3 and Geometry2D.is_point_in_polygon(logical_point,item.hit_polygon)
static func build(source_items:Dictionary,camera:Camera3D,viewport_size:Vector2,canvas:Vector2,offset:Vector2)->Dictionary:
 var result={"ready":false,"blockers":[],"items":{},"camera":camera,"viewport_size":viewport_size,"canvas_size":canvas,"presentation_offset":offset,"coordinate_space":"game logical canvas; source-world Z reflected exactly once"}
 if not is_instance_valid(camera) or not camera.get_meta("native_phone_registered",false):
  result.blockers.append("Source phone camera is not registered");return result
 if viewport_size.x<=0 or viewport_size.y<=0:
  result.blockers.append("Invalid camera viewport size");return result
 for key in REQUIRED:
  if not source_items.has(key):
   result.blockers.append("Missing verified source item: "+key);continue
  var row:Dictionary=source_items[key]
  if not row.get("verified",false) or str(row.get("source","")).is_empty():
   result.blockers.append("Unverified source item: "+key);continue
  if row.has("source_aspect") and absf(float(row.source_aspect)-canvas.x/canvas.y)>0.0001:result.blockers.append(key+": Source aspect differs from canvas; rebuild recovered_items with options.aspect")
  for blocker in row.get("blockers",[]):result.blockers.append(key+": "+str(blocker))
  if not row.has("center_world"):
   result.blockers.append("Missing source center: "+key);continue
  if row.get("interactive",true) and row.get("hit_polygon_world",[]).size()<3:result.blockers.append("Missing source hit polygon: "+key)
  var item={"center":project(vector(row.center_world),camera,viewport_size,canvas,offset),"hit_polygon":project_polygon(row.get("hit_polygon_world",[]),camera,viewport_size,canvas,offset),"source":row.source,"source_center_world":vector(row.center_world)}
  if row.get("hit_convex_hull",false):item.hit_polygon=Geometry2D.convex_hull(item.hit_polygon)
  if row.has("visual_polygon_world"):
   item.visual_polygon_world=row.visual_polygon_world
   item.visual_world_corners=row.visual_polygon_world
   item.visual_polygon=Geometry2D.convex_hull(project_polygon(row.visual_polygon_world,camera,viewport_size,canvas,offset))
  if row.has("slots_world"):item.slots=project_polygon(row.slots_world,camera,viewport_size,canvas,offset)
  for field in ["hit_polygon_world","source_pose","source_world_position","source_rotation","source_scale","interactive","enabled","actors","crystals","counter_pose","state_contract","tray_endpoints"]:
   if row.has(field):item[field]=row[field]
  for field in ["actors","crystals"]:
   if item.has(field):
    item[field]=item[field].duplicate(true)
    for actor in item[field]:
     actor.center=project(actor.source_world_position,camera,viewport_size,canvas,offset)
     if actor.has("visual_polygon_world"):actor.visual_polygon=Geometry2D.convex_hull(project_polygon(actor.visual_polygon_world,camera,viewport_size,canvas,offset))
     actor.hit_polygon=Geometry2D.convex_hull(project_polygon(actor.get("hit_polygon_world",[]),camera,viewport_size,canvas,offset)) if not actor.get("hit_polygon_world",[]).is_empty() else PackedVector2Array()
  result.items[key]=item
 result.ready=result.blockers.is_empty()
 return result

const SOURCE_PATH="res://original_board/references/phone_board_layout_runtime.json"
const ROW_NAMES={"friendly_hero":"Zone_Friendly_Hero","opposing_hero":"Zone_Opposing_Hero","friendly_power":"Zone_Friendly_HeroPower","opposing_power":"Zone_Opposing_HeroPower","friendly_play":"Zone_Friendly_Play","opposing_play":"Zone_Opposing_Play","friendly_deck":"Zone_Friendly_Deck","opposing_deck":"Zone_Opposing_Deck","end_turn":"EndTurnButton"}
static func normal_slots(row:Dictionary,count:int,moused_over_slot:int=-1)->Array:
 # ZonePlay.GetCardPosition0x060065c0: preserve >=0 versus GetSlotWidth >=1.
 # Ordinary sortable classic entities only; no reserved slot/GameEntity override.
 var result=[]
 if count<0 or count>int(row.spacing.max_slots):return result
 var center=vector(row.collider_bounds.center)
 var width_count=clampi(count+(1 if moused_over_slot>=1 else 0),0,int(row.spacing.max_slots))
 var width=float(row.collider_bounds.size[0])/float(row.spacing.max_slots)*(1.0+float(row.spacing.phone_width_modifiers[width_count]))
 var layout_count=count+(1 if moused_over_slot>=0 else 0)
 for i in range(count):
  var shift=1 if moused_over_slot>=0 and moused_over_slot<=i+1 else 0
  result.append(center+Vector3((float(i+shift)-float(layout_count-1)*0.5)*width,0,0))
 return result
const VISUAL_PATH="res://original_board/references/phone_actor_visual_bounds.json"
const INTERACTION_PATH="res://original_board/references/phone_interaction_runtime.json"
static func matrix(a:Array)->Transform3D:
 return Transform3D(Basis(Vector3(a[0][0],a[1][0],a[2][0]),Vector3(a[0][1],a[1][1],a[2][1]),Vector3(a[0][2],a[1][2],a[2][2])),Vector3(a[0][3],a[1][3],a[2][3]))
static func pose_fields(t:Transform3D)->Dictionary:
 return {"source_pose":t,"source_world_position":t.origin,"source_rotation":t.basis.orthonormalized().get_rotation_quaternion(),"source_scale":t.basis.get_scale()}
static func box_corners(t:Transform3D,center:Vector3,size:Vector3)->Array:
 var result=[]
 for x in [-1,1]:
  for y in [-1,1]:
   for z in [-1,1]:result.append(t*(center+Vector3(x*size.x,y*size.y,z*size.z)*0.5))
 return result
static func collider_corners(pose:Transform3D,colliders:Array)->Array:
 var result=[]
 for collider in colliders:
  if collider.is_trigger or not collider.serialized_enabled:continue
  result.append_array(box_corners(pose*matrix(collider.relative_matrix),vector(collider.local_center),vector(collider.local_size)))
 return result
static func visual_corners(pose:Transform3D,profile:String)->Array:
 var data=source_json(VISUAL_PATH);var result=[]
 for mesh in data.profiles[profile]:
  result.append_array(box_corners(pose*matrix(mesh.actor_relative_matrix),vector(mesh.mesh_local_bounds.center),vector(mesh.mesh_local_bounds.size)))
 return result
static func recovered_items(friendly_count:int,opposing_count:int,options:Dictionary={})->Dictionary:
 # Ordinary classic/default hero frame and no additional power subzones.
 # options can explicitly reject unsupported modes rather than silently using these poses.
 var source=source_json(SOURCE_PATH)
 var interaction=source_json(INTERACTION_PATH);var result={}
 var actor_keys={"hero":"Card_Play_Hero:-2507336562026496370","power":"Card_Play_HeroPower:-8408782285185036916","minion":"Card_Play_Ally:7379369862269225637"}
 for key in ROW_NAMES:
  var name=ROW_NAMES[key];var row:Dictionary=source.rows[name]
  var pose=matrix(row.phone_world_matrix)
  var item={"verified":true,"source":SOURCE_PATH+"#"+name,"center_world":pose.origin,"hit_polygon_world":[],"hit_convex_hull":true,"blockers":[],"source_row":row,"interactive":true,"enabled":true}
  if key.ends_with("_play"):
   item.hit_polygon_world=box_corners(Transform3D.IDENTITY,vector(row.collider_bounds.center),vector(row.collider_bounds.size))
   var count=friendly_count if key=="friendly_play" else opposing_count
   var gap=int(options.get("moused_over_slot",-1)) if key=="friendly_play" else -1
   item.slots_world=normal_slots(row,count,gap);item.actors=[]
   if count<0 or count>7:item.blockers.append("Play count outside recovered classic max7")
   if options.get("reserved_slot",false) or options.get("do_not_sort_cards",false) or options.get("play_zone_override",false):item.blockers.append("Non-resting play layout needs explicit source branch")
   for point in item.slots_world:
    var actor_pose=Transform3D(pose.basis.orthonormalized().scaled(vector(row.phone_card_target_scale)),point)
    var actor=pose_fields(actor_pose);actor.hit_polygon_world=collider_corners(actor_pose,interaction.colliders[actor_keys.minion]);actor.visual_polygon_world=visual_corners(actor_pose,"minion_in_play");item.actors.append(actor)
  elif key.ends_with("_hero") or key.ends_with("_power"):
   var kind="hero" if key.ends_with("_hero") else "power"
   item.hit_polygon_world=collider_corners(pose,interaction.colliders[actor_keys[kind]])
   item.visual_polygon_world=visual_corners(pose,"hero_in_play" if kind=="hero" else "hero_power")
   if kind=="hero" and options.get("custom_hero_frame",false):item.blockers.append("Custom hero frame offset not supplied")
   if kind=="power" and options.get("additional_power_subzones",false):item.blockers.append("Additional-power alternate pose not selected")
  elif key=="end_turn":
   pose=matrix(interaction.end_turn.world_matrix);item.center_world=pose.origin
   item.hit_polygon_world=collider_corners(pose,interaction.colliders["EndTurnButton:-4134783282888560028"])
   item.enabled=options.get("end_turn_enabled",false) and not options.get("input_blocked",false)
   item.state_contract=interaction.end_turn.enabled_rule
  else:
   item.interactive=false # Deck zone anchors are visual/draw endpoints, not guessed hit boxes.
  item.merge(pose_fields(pose));result[key]=item
 result.merge(recovered_mana_items(options))
 return result

static func recovered_mana_items(options:Dictionary={})->Dictionary:
 # Mana-only callers must not rebuild every hero/play zone and hit polygon.
 var interaction=source_json(INTERACTION_PATH);var result:Dictionary={}
 # Mana counters are display-only. Their matrices are source prefab bindings.
 for side in ["friendly","opposing"]:
  var data=interaction.mana[side+"_large_resource"];var pose=matrix(data.root_world_matrix)
  var item={"verified":true,"source":INTERACTION_PATH+"#mana/"+side+"_large_resource","center_world":pose.origin,"hit_polygon_world":[],"interactive":false,"blockers":[],"crystals":[],"counter_pose":pose,"state_contract":data.animation}
  item.merge(pose_fields(pose))
  if side=="friendly":
   var gem=interaction.mana["ManaGemBone:7409025516337681387"]
   var tray=interaction.mana.tray_animation
   var aspect=float(options.get("aspect",16.0/9.0));item.source_aspect=aspect
   var shown=CameraPolicy.aspect_position(tray.aspect_position_bones.ManaTrayShownBone,aspect)
   var hidden=CameraPolicy.aspect_position(tray.aspect_position_bones.ManaTrayHiddenBone,aspect)
   item.tray_endpoints={"shown":shown,"hidden":hidden,"show_duration":tray.show_duration,"hide_duration":tray.hide_duration,"show_ease":tray.show_ease,"hide_ease":tray.hide_ease}
   # Caller supplies current source tray position during a tween; default is the
   # explicitly requested shown endpoint, not a fabricated screen-space animation.
   var tray_position=vector(options.get("mana_tray_position",hidden if options.get("mana_tray_hidden",false) else shown))
   var start=vector(gem.world_position)+tray_position-vector(tray.shown)
   var permanent=maxi(0,int(options.get("permanent_mana_count",0)));var temporary=maxi(0,int(options.get("temporary_mana_count",0)))
   var basis=matrix(gem.world_matrix).basis;var step=float(interaction.mana.crystal_placement.phone_spacing_world_z)
   for i in range(mini(10,permanent+temporary)):
    var crystal=pose_fields(Transform3D(basis,start+Vector3(0,0,i*step)))
    crystal.kind="permanent" if i<permanent else "temporary"
    crystal.list_index=permanent-1-i if i<permanent else i-permanent
    item.crystals.append(crystal)
  result[side+"_mana"]=item
 return result
