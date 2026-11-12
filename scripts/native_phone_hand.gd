extends RefCounted
## ZoneHand source-world layout and pointer math. Camera registration is explicit;
## this is not an official phone camera/runtime equivalence claim.
const BOUNDS_PATH="res://assets/native_cards/phone_hand_bounds.json"
const FIELDS_PATH="res://assets/native_cards/phone_hand_fields.json"
var game
var bounds:Dictionary
var fields:Dictionary
var preview_bone_local:=Vector3.ZERO
var standin_child:=Transform3D.IDENTITY
var standin_box:=AABB()
var targeting_mode:=false
var restore_enlarged_after_target:=false
# Explicit local choice; original NetCache live feature value is unavailable.
var mini_hand_play_enabled:=false
var require_phone_camera_registration:=true
var enlarged:=false
var focus:=-1
var touched_slot:=-1
var touch_origin:=Vector2.ZERO
var touch_age:=0.0
var transitions:Dictionary={}
var generation:=0
var layout_duration:=0.5
var enlarging_remaining:=0.0
func setup(host):
 game=host;bounds=JSON.parse_string(FileAccess.get_file_as_string(BOUNDS_PATH))
 fields=JSON.parse_string(FileAccess.get_file_as_string(FIELDS_PATH))[0].data
 var standin=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_hand_standin.json")).objects
 var child=standin["-2826040235444366730"].data
 var p=child.m_LocalPosition;var q=child.m_LocalRotation;var sc=child.m_LocalScale
 var cb=Basis(Quaternion(q.x,q.y,q.z,q.w))
 standin_child=Transform3D(Basis(cb.x*sc.x,cb.y*sc.y,cb.z*sc.z),Vector3(p.x,p.y,p.z))
 var box=standin["1176097159316017782"].data
 var size=Vector3(box.m_Size.x,box.m_Size.y,box.m_Size.z)
 standin_box=AABB(Vector3(box.m_Center.x,box.m_Center.y,box.m_Center.z)-size*.5,size)
 for bone in JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_hand_bones.json")):
  if bone.name=="MouseOverCardHeight":
   var bp=bone.transform.m_LocalPosition;preview_bone_local=Vector3(bp.x,bp.y,bp.z)
static func vector(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func center()->Vector3:
 return vector(bounds.phone_enlarged.center_world if enlarged else bounds.phone_collapsed.center_world)+Vector3(0,0,-float(fields.m_handHidingDistance) if enlarged and targeting_mode else 0.0)
func width()->float:return float(bounds.phone_enlarged.size_world[0] if enlarged else bounds.phone_collapsed.size_world[0])-(float(fields.m_heroWidthInHand) if enlarged and targeting_mode else 0.0)
func spacing(count:int)->float:
 return minf(float(fields.m_enlargedHandDefaultCardSpacing) if enlarged else 1.2708040475845337,width()/maxi(count,1))
func yaw(index:int,count:int)->float:
 if count<=3:return 0.0
 var span=40.0+2.0*count
 return span*index/float(count-1)-span*0.5
func source_pose(index:int,count:int,focused:bool=false)->Dictionary:
 var c=center();var step=spacing(count);var angle=yaw(index,count)
 var bend=pow(float(index)+0.5-float(count)*0.5,2.0)/(6.0*maxi(count,1)) if count>3 else 0.0
 var lip=sin(absf(deg_to_rad(angle)))*step*0.5 if angle>0 else 0.0
 var position=Vector3(c.x+(2*index-(count-1))*step*0.5,c.y,c.z-bend-lip)
 if enlarged and targeting_mode:
  var hero_width=float(fields.m_heroWidthInHand)
  if count%2==1:
   if index<(count+1)/2:position.x-=hero_width
  else:position.x+=-hero_width*0.5 if index<count/2 else hero_width*0.5
 var rotation=Vector3(0,angle,352.5)
 var scale_value=Vector3(0.75,0.2800000011920929,0.75)
 if focused:
  position.x=clampf(position.x,float(fields.m_enlargedHandCardMinX),float(fields.m_enlargedHandCardMaxX))
  # Recovered MouseOverCardHeight bone world Z + phone offset -1.6.
  position.y=c.y+1.0+(0.0 if enlarged else float(fields.m_tinyHandMouseOverYOffset))
  var zone_scale=vector(bounds.phone_enlarged.scale_world if enlarged else bounds.phone_collapsed.scale_world)
  position.z=c.z+preview_bone_local.z*zone_scale.z+phone_value(fields.m_SelectCardOffsetZ)+(0.0 if enlarged else float(fields.m_tinyHandMouseOverZOffset))
  rotation=Vector3.ZERO;scale_value=Vector3(1.5499999523162842,0.2800000011920929,1.5499999523162842)
 return {"position":position,"rotation":rotation,"scale":scale_value}
static func source_basis(degrees:Vector3)->Basis:
 # Unity Quaternion.Euler applies Z then X then Y.
 return Basis(Vector3.UP,deg_to_rad(degrees.y))*Basis(Vector3.RIGHT,deg_to_rad(degrees.x))*Basis(Vector3.BACK,deg_to_rad(degrees.z))
func camera_context()->Dictionary:
 if game==null or not is_instance_valid(game.original_board_bridge):return {}
 var bridge=game.original_board_bridge
 if not is_instance_valid(bridge.probe) or not is_instance_valid(bridge.probe.camera):return {}
 if require_phone_camera_registration and not bridge.probe.camera.get_meta("native_phone_registered",false):return {}
 return {"camera":bridge.probe.camera,"size":Vector2(bridge.viewport.size)}
func project(world:Vector3)->Vector2:
 var context=camera_context()
 if context.is_empty():return Vector2.INF
 return context.camera.unproject_position(Vector3(world.x,world.y,-world.z))*game.presentation_size/context.size-game.presentation_offset
func project_local(pose:Dictionary,local:Vector3)->Vector2:
 return project(pose.position+source_basis(pose.rotation)*(local*pose.scale))
func card_polygon(pose:Dictionary,kind:String)->PackedVector2Array:
 var height=3.35 if kind=="minion" else 3.23
 var cx=-0.0553 if kind=="minion" else -0.05385
 var cz=-0.0408 if kind=="minion" else -0.04296
 var points=PackedVector2Array()
 for corner in [Vector2(-82,-121),Vector2(82,-121),Vector2(82,121),Vector2(-82,121)]:
  points.append(project_local(pose,Vector3(cx+corner.x*height/242.0,0,cz-corner.y*height/242.0)))
 return points
func layout_count()->int:
 if game==null:return 0
 var count=0
 for card in game.cards:
  if not card.get("drawing",false) or card.get("source_draw_phase","")=="seat":count+=1
 return count
func hit_card(point:Vector2)->int:
 var context=camera_context()
 if context.is_empty():return -1
 var screen=(point+game.presentation_offset)*context.size/game.presentation_size
 var camera:Camera3D=context.camera
 var origin=camera.project_ray_origin(screen);origin.z=-origin.z
 var direction=camera.project_ray_normal(screen);direction.z=-direction.z
 var best=-1;var nearest=INF
 for i in range(game.cards.size()):
  if game.cards[i].get("drawing",false) or game.cards[i].get("returning",false):continue
  # Original Card_Collider_Standin prefab is a child OBB, not baked-face alpha
  # or the moved/expanded preview. Pose comes from GetCardPosition/Rotation/Scale.
  var pose=source_pose(i,layout_count())
  var b=source_basis(pose.rotation)
  var transform=Transform3D(Basis(b.x*pose.scale.x,b.y*pose.scale.y,b.z*pose.scale.z),pose.position)*standin_child
  var inverse=transform.affine_inverse()
  var hit=standin_box.intersects_ray(inverse*origin,inverse.basis*direction)
  if hit!=null:
   var distance=origin.distance_squared_to(transform*hit)
   if distance<nearest:nearest=distance;best=i
 return best
func card_width_window(count:int)->float:
 var c=center();var step=spacing(count)*0.5
 var a=game.board_to_screen(project(c+Vector3(step,0,0)))
 var b=game.board_to_screen(project(c-Vector3(step,0,0)))
 return absf((game.get_viewport().get_stretch_transform()*a).x-(game.get_viewport().get_stretch_transform()*b).x)
static func current_slot(touched:int,last:int,delta:Vector2,card_width:float)->int:
 if touched<0 or card_width<=0:return -1
 var resistance=10.0+maxf(0.0,-delta.y)*0.800000011920929
 var anchor=(last-touched)*card_width
 var dx=minf(anchor,delta.x+resistance) if delta.x<anchor else maxf(anchor,delta.x-resistance)
 return touched+int(dx/card_width)
func enter_spell_target(friendly_hero_valid:bool):
 # EnterOptionTargetMode: ordinary spells cannot target cards in hand.
 targeting_mode=friendly_hero_valid
 restore_enlarged_after_target=restore_enlarged_after_target or enlarged
 if enlarged:set_enlarged(false)
func finish_spell_target_drop():
 targeting_mode=false
 if restore_enlarged_after_target:
  restore_enlarged_after_target=false;set_enlarged(true)
func set_enlarged(value:bool):
 if enlarged==value:return
 enlarged=value;release_previous_focus();focus=-1;generation+=1;layout_duration=0.25;enlarging_remaining=0.25
func set_focus(value:int):
 if focus==value:return
 release_previous_focus();focus=value;generation+=1;layout_duration=0.5
func release_previous_focus():
 if game==null or focus<0 or focus>=game.cards.size():return
 var card:Dictionary=game.cards[focus]
 if not card.has("source_phone_transition"):return
 var normal=source_pose(focus,layout_count(),false)
 normal.position.z+=0.5
 card.source_phone_transition.pose=normal
static func phone_value(record:Dictionary)->float:
 for i in record.screens.size():
  if int(record.screens[i])==1:return float(record.values[i])
 for i in record.screens.size():
  if int(record.screens[i])==4:return float(record.values[i])
 return 0.0
func begin_touch(slot:int,window_position:Vector2):
 touched_slot=slot;touch_origin=window_position;touch_age=0.0
 if enlarged or not mini_hand_play_enabled:set_focus(slot)
func release_touch():touched_slot=-1;set_focus(-1)
func update_touch(window_position:Vector2)->int:
 var slot=current_slot(touched_slot,focus,window_position-touch_origin,card_width_window(layout_count()))
 if slot<0 or slot>=game.cards.size():slot=-1
 set_focus(slot)
 return slot
static func source_ease(t:float)->float:return 1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*maxf(t,0.0))
func sample(index:int,count:int,dt:float)->Dictionary:
 var target=source_pose(index,count,index==focus)
 var card:Dictionary=game.cards[index]
 if not card.has("source_phone_transition"):
  card.source_phone_transition={"generation":generation,"count":count,"age":0.0,"from":target.duplicate(true),"pose":target.duplicate(true),"target":target.duplicate(true),"duration":layout_duration}
 var entry:Dictionary=card.source_phone_transition
 if entry.generation!=generation or entry.count!=count:
  entry.ease_type=16;entry.other_duration=0.25
  entry["from"]=entry.pose.duplicate(true);entry.age=0.0;entry.target=target;entry.generation=generation;entry.count=count;entry.duration=layout_duration
  if index==focus:
   # FocusCard immediately applies source scale/zero rotation and target Y/Z-.1.
   entry["from"].scale=target.scale;entry["from"].rotation=target.rotation
   entry["from"].position=Vector3(target.position.x if absf(target.position.x-source_pose(index,count).position.x)>0.00001 else entry.pose.position.x,target.position.y,target.position.z-0.10000000149011612)
 entry.age+=dt
 var move_ease=source_ease(entry.age/entry.duration)
 var other_ease=source_ease(entry.age/float(entry.get("other_duration",0.25)))
 if int(entry.get("ease_type",16))==15:
  move_ease=(0.0 if entry.age<=0 else pow(2.0,10.0*(minf(entry.age/entry.duration,1.0)-1.0)))
  other_ease=(0.0 if entry.age<=0 else pow(2.0,10.0*(minf(entry.age/float(entry.get("other_duration",0.25)),1.0)-1.0)))
 entry.pose={"position":entry["from"].position.lerp(entry.target.position,move_ease),"rotation":lerp_source_angles(entry["from"].rotation,entry.target.rotation,other_ease),"scale":entry["from"].scale.lerp(entry.target.scale,other_ease)}
 return entry.pose
func apply_card(card:Dictionary,index:int,count:int,dt:float)->bool:
 if camera_context().is_empty():return false
 var pose=sample(index,count,dt);card.source_phone_pose=pose
 var polygon=card_polygon(pose,game.definitions[card.key].kind)
 card.pos=(polygon[0]+polygon[2])*0.5
 card.scale=(polygon[3]-polygon[0]).length()/242.0
 card.angle=(polygon[1]-polygon[0]).angle();card.spring=Vector2.ZERO;card.lift=0.0
 return true

static func lerp_source_angles(a:Vector3,b:Vector3,t:float)->Vector3:
 return preload("res://scripts/source_itween_rotation.gd").interpolate(a,b,t)


func advance(dt:float):
 if enlarging_remaining<=0:return
 enlarging_remaining=maxf(0.0,enlarging_remaining-dt)
 if enlarging_remaining==0 and game!=null and game.mouse_down and game.active_touch_index>=0:
  var slot=hit_card(game.pointer)
  if slot>=0:
   begin_touch(slot,game._touch_window_position(game.screen_pointer));game.pressed_card=slot
