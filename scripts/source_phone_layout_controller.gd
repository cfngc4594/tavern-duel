extends Node
## Atomic registration for the shared source scene, recovered from the phone UI.
## Desktop uses the same visual/input geometry with its own mouse gestures.
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const Policy=preload("res://scripts/source_board_camera_policy.gd")
const SourceProjection=preload("res://scripts/source_board_projection.gd")
var game
var viewport:SubViewport
var camera_root:Node3D
var camera:Camera3D
var snapshot:Dictionary={}
var source_items:Dictionary={}
var context
var blockers:Array=[]
var enabled:=false
var mana_tray:Dictionary={}
var last_tray_frame:=-1
var mana_events:Array=[]
var mana_event_serial:=0
# Runtime layout is static between rule/layout changes; camera shake only reprojects.
var _layout_key:Array=[]
var _projection_key:Array=[]
var layout_builds:=0
var projection_builds:=0
func setup(host):
 game=host
 viewport=SubViewport.new();viewport.name="SourcePhoneLayoutRegistration"
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(viewport)
 camera_root=Node3D.new();viewport.add_child(camera_root)
 camera=Camera3D.new();camera_root.add_child(camera);camera.current=true
 refresh()
func refresh():
 if game==null:return
 var canvas:Vector2=game.presentation_size
 viewport.size=game.board_render_target_size
 Policy.apply(camera,camera_root,{},canvas,true)
 var flow=game.get("flow")
 var temporary=int(flow.temporary_mana[0]) if flow!=null else 0
 var options={"aspect":canvas.x/canvas.y,"permanent_mana_count":game.max_mana,"temporary_mana_count":temporary,"end_turn_enabled":game.player_turn}
 if game.interaction_state==game.Interaction.PLACEMENT_PREVIEW:options.moused_over_slot=game.preview_index+1
 elif not game.pending_battlecry.is_empty():options.moused_over_slot=int(game.pending_battlecry.insertion)+1
 var counts=[game.allies.size(),game.enemies.size()]
 # Endpoints depend on source data/aspect, not the current tween position.
 if source_items.is_empty() or _layout_key.is_empty() or _layout_key[2].get("aspect",0.0)!=options.aspect:
  source_items=Layout.recovered_items(counts[0],counts[1],options)
 options.mana_tray_position=_mana_tray_position(source_items.friendly_mana.tray_endpoints)
 var next_key=[counts[0],counts[1],options]
 var changed=source_items.is_empty() or next_key!=_layout_key
 if changed:
  source_items=Layout.recovered_items(counts[0],counts[1],options)
  _layout_key=next_key.duplicate(true);_projection_key.clear();layout_builds+=1
 _refresh_snapshot()
 blockers=snapshot.blockers.duplicate()
 # An explicit development gate is insufficient by itself: layout/readiness is
 # necessary, and the complete consumer migration must be separately accepted.
 enabled=bool(ProjectSettings.get_setting("native_mobile/source_camera_enabled",false)) and bool(ProjectSettings.get_setting("native_mobile/source_consumers_verified",false)) and snapshot.ready and Policy.source_ui_requested()
 Policy.runtime_layout_verified=enabled
 if not enabled:
  if context!=null:SourceProjection.unregister(game);context=null
  return
 var anchors={}
 for side in range(2):
  var prefix="friendly_" if side==0 else "opposing_"
  for kind in ["hero","power","play","deck","mana"]:
   var row:Dictionary=source_items[prefix+kind]
   anchors[kind+":"+str(side)]={"position":Layout.vector(row.center_world),"rotation":row.get("source_rotation",Quaternion.IDENTITY),"scale":row.get("source_scale",Vector3.ONE),"verified":row.verified,"source":row.source}
 if context==null:context=SourceProjection.install(game,camera,Vector2(viewport.size),canvas,game.presentation_offset,anchors)
 else:
  context.configure(camera,Vector2(viewport.size),canvas,game.presentation_offset,anchors)
  context.blockers.clear()
func contains(key:String,point:Vector2)->bool:return enabled and Layout.contains(snapshot,key,point)
func update_units(delta:float=0.0):
 if not enabled:return
 for side in range(2):
  var units=game.allies if side==0 else game.enemies
  var actors=snapshot.items["friendly_play" if side==0 else "opposing_play"].actors
  for i in range(mini(units.size(),actors.size())):
   var unit:Dictionary=units[i];var actor:Dictionary=actors[i]
   unit.source_world_target=actor.source_world_position
   unit.source_world_target_scale=actor.source_scale
   unit.source_world_target_rotation=actor.source_rotation
   # Both recovered ordinary Zone_Play phone matrices have identity rotation.
   # Do not infer Euler angles for unsupported custom zone transforms.
   if actor.source_rotation.is_equal_approx(Quaternion.IDENTITY):unit.source_world_target_euler=Vector3.ZERO
   else:unit.erase("source_world_target_euler");blockers.append("Unrecovered nonidentity play-zone Euler target")
   if not unit.has("source_world_position"):
    unit.source_world_position=actor.source_world_position
    unit.source_world_rotation=actor.source_rotation;unit.source_world_scale=actor.source_scale
   if not unit.animating:
    var transition:Dictionary=unit.get("source_layout_transition",{})
    if transition.is_empty() or not transition.target.is_equal_approx(actor.source_world_position):
     transition={"from":unit.source_world_position,"target":actor.source_world_position,"age":0.0,"delay":float(unit.get("source_transition_delay",0.0)),"from_scale":unit.source_world_scale,"target_scale":actor.source_scale}
     unit.source_transition_delay=0.0;unit.source_layout_transition=transition
    transition.age+=maxf(0.0,delta)
    var t=clampf(transition.age-transition.delay,0.0,1.0)
    var blend=1.0 if t>=1.0 else (0.0 if t<=0.0 else 1.0-pow(2.0,-10.0*t))
    unit.source_world_position=transition.from.lerp(transition.target,blend)
    unit.source_world_scale=transition.from_scale.lerp(transition.target_scale,blend)
    # Ordinary play-row rotations are identical across slots. Nonordinary
    # overrides are rejected by the source layout contract, never slerped here.
    unit.source_world_rotation=actor.source_rotation
    unit.pos=Layout.project(unit.source_world_position,camera,Vector2(viewport.size),game.presentation_size,game.presentation_offset)
   var source_basis=Basis(unit.source_world_rotation)
   var source_scale:Vector3=unit.source_world_scale
   var current_pose=Transform3D(Basis(source_basis.x*source_scale.x,source_basis.y*source_scale.y,source_basis.z*source_scale.z),unit.source_world_position)
   var from_target:Transform3D=current_pose*actor.source_pose.affine_inverse()
   var moved_corners=[]
   for corner in actor.hit_polygon_world:moved_corners.append(from_target*corner)
   unit.source_hit_polygon=Geometry2D.convex_hull(Layout.project_polygon(moved_corners,camera,Vector2(viewport.size),game.presentation_size,game.presentation_offset));unit.target=actor.center

func reproject():
 if enabled:_refresh_snapshot()

func _refresh_snapshot():
 var key=[camera.get_camera_transform(),camera.get_camera_projection(),viewport.size,game.presentation_size,game.presentation_offset]
 if snapshot.is_empty() or key!=_projection_key:
  snapshot=Layout.build(source_items,camera,Vector2(viewport.size),game.presentation_size,game.presentation_offset)
  _projection_key=key;projection_builds+=1

func audit()->Dictionary:
 return {"enabled":enabled,"layout_ready":snapshot.get("ready",false),"blockers":blockers.duplicate(),"production_gate":bool(ProjectSettings.get_setting("native_mobile/source_consumers_verified",false)),"original_source":"37.0.0.255130.254477 managed phone branch and serialized phone prefabs; not verified Android binary","visual_device_verified":false,"projection":"Original perspective camera with one source-world Z reflection","movement":"ZonePlay.UpdateLayout .ctor duration 1.0, default easeOutExpo16; Card transition delay, ordinary source rotations only"}

func _mana_tray_position(endpoints:Dictionary)->Vector3:
 var hand=game.get("native_phone_hand")
 var desired=hand!=null and bool(hand.enlarged)
 # Current historical basic deck has no DeckAction entities. Future support must
 # publish the source HasDeckAction result, not infer it from spell targeting.
 if game.get("source_held_has_deck_action")==true:desired=false
 var target:Vector3=endpoints.shown if desired else endpoints.hidden
 if mana_tray.is_empty():
  mana_tray={"shown":desired,"position":target,"from":target,"target":target,"age":0.0,"duration":0.0}
 if mana_tray.shown!=desired or not mana_tray.target.is_equal_approx(target):
  # SlidingTray.DoShowLogic 0x0600e8ab resets to hiddenBone before an animated show.
  # Only a false->true state change does this; hide keeps its current start pose.
  var start:Vector3=endpoints.hidden if desired and not mana_tray.shown else mana_tray.position
  mana_tray={"shown":desired,"position":start,"from":start,"target":target,"age":0.0,"duration":float(endpoints.show_duration if desired else endpoints.hide_duration)}
 var frame=Engine.get_process_frames()
 if frame!=last_tray_frame:
  var delta=game.get("source_visual_delta")
  mana_tray.age+=maxf(0.0,float(delta)) if delta!=null else 0.0
  last_tray_frame=frame
 var t=clampf(mana_tray.age/maxf(mana_tray.duration,.000001),0.0,1.0)
 var blend=(1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*t)) if desired else t
 mana_tray.position=mana_tray.from.lerp(mana_tray.target,blend)
 return mana_tray.position

func record_mana_spend(side:int,cost:int,temporary:int):
 mana_event_serial+=1
 mana_events.append({"serial":mana_event_serial,"side":side,"cost":cost,"temporary_used":temporary,"permanent_used":cost-temporary,"source_order":"NotifyUsedTempMana, DestroyTempMana, then ordinary spent"})
 if mana_events.size()>64:mana_events.pop_front()
