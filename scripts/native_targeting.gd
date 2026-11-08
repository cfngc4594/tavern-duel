extends Node
## Recovered TargetReticleManager CIL and Target_Arrow_Bullseye/Link prefabs.
## No polygon dashes, generic rings, prohibited glyphs, or invalid recolor.
## Camera registration and the local AI's prelaunch selection are adaptations.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Assets=preload("res://scripts/native_state_assets.gd")
const SCALE: float=0.78*0.9
const LINK_LENGTH: float=1.2000000476837158
const PARABOLA_HEIGHT: float=1.5
const LINK_SPEED: float=0.5
var text_indicator=preload("res://scripts/native_target_text.gd").new()
var audio: Node
var game: Node
var assets=Assets.new()
var active: Dictionary={}
var history: Array=[]
var root: Node3D
var projection: Node3D
var arrow: Dictionary={}
var links: Array=[]
var link_offset:=0.0
var source_missing: Array=[]
var _last_target_status:=""
var _last_side_turn: Array=[]
var _serial:=0

func setup(owner_game: Node):
 game=owner_game
 assets.setup(game.native_card_renderer,"res://assets/original_targeting_v34/")
 for label in ["arrow_bullseye","arrow_link"]:
  if not assets.manifest.get("root_labels",{}).has(label):source_missing.append(label)
 _last_side_turn=game.side_turn.duplicate()
 text_indicator.setup(game,assets)
 audio=preload("res://scripts/native_target_audio.gd").new();add_child(audio);audio.setup_target(game)

func _projection_basis() -> Basis:
 if SourceProjection.from_game(game)!=null:return SourceProjection.REFLECTION
 return Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*SCALE

func _source_point(point: Vector2) -> Vector3:
 var projection=SourceProjection.from_game(game)
 if projection!=null:
  # TargetReticleManager.UpdateArrowPosition0x060060ff 01b5..01d4:
  # the same original layer9 collider hit as PositionHeldCard, not guessed Y.
  var held=game.get("source_held_motion")
  if held!=null:
   if held.game==null:held.setup(game)
   var hit:Dictionary=held.hit(point)
   return hit.source_world if not hit.is_empty() else Vector3.INF
  # Explicit-plane contract is retained for isolated projection tests only.
  var anchor=projection.resolve_anchor("targeting_plane")
  if anchor.is_empty() or not anchor.get("plane") is Plane:
   projection.block("Target reticle pointer requires the verified original targeting plane");return Vector3.INF
  var hit=projection.screen_to_source_on_plane(point,anchor.plane)
  return hit.position if not hit.is_empty() else Vector3.INF
 return Vector3((point.x-800.0)/(100.0*SCALE),0.0,(450.0-point.y)/(100.0*SCALE*cos(PI/12.0)))

func _screen_point(point: Vector3) -> Vector2:
 var projection=SourceProjection.from_game(game)
 if projection!=null:return projection.source_to_screen(point)
 var mapped: Vector3=_projection_basis()*point
 return Vector2(800.0+mapped.x*100.0,450.0-mapped.y*100.0)

func _local_request() -> Dictionary:
 if not game._is_aiming() or not game.player_turn or game.busy or game.game_over or not game.flow.accepts_actions() or game.help_visible or game.settings_visible:return {}
 var origin: Vector2=game.PLAYER_HERO
 var key:="";var unit_id:=-1;var origin_kind:="hero";var interaction: int=game.interaction_state
 match interaction:
  game.Interaction.ATTACK_AIM:
   var unit: Dictionary=game.unit_by_id(game.selected_unit)
   if unit.is_empty() or not game.can_attack(unit):return {}
   origin=unit.pos;key=unit.key;unit_id=unit.id;origin_kind="attacker"
  game.Interaction.SPELL_AIM:
   if game.drag_index<0 or game.drag_index>=game.cards.size():return {}
   key=game.cards[game.drag_index].key
  game.Interaction.POWER_AIM:
   origin=game.POWER_POS;key="CS2_034";origin_kind="hero_power"
  game.Interaction.BATTLECRY_AIM:
   if game.pending_battlecry.is_empty():return {}
   origin=game.pending_battlecry.pos;origin_kind="battlecry_source"
   key=game.cards[game.pending_battlecry.index].key
 var feedback: Dictionary=game._target_feedback_at(game.pointer)
 var source: Vector3
 var projection=SourceProjection.from_game(game)
 if projection!=null:
  var anchor:Dictionary={}
  match origin_kind:
   "hero":anchor=projection.resolve_anchor("hero:0")
   "hero_power":anchor=projection.resolve_anchor("power:0")
   "attacker":anchor=projection.resolve_anchor(game.unit_by_id(unit_id))
   "battlecry_source":anchor=projection.resolve_anchor(game.pending_battlecry)
  if anchor.is_empty():return {}
  source=anchor.position
 else:source=_source_point(origin)
 var endpoint:Vector3=_source_point(game.pointer)
 if not source.is_finite():return {}
 if not endpoint.is_finite():
  # Source returns early on a layer9 miss, retaining the last reticle point.
  var identity="friendly:%d:%s:%d"%[interaction,key,unit_id]
  if active.get("identity","")!=identity or not active.has("rendered_endpoint"):return {}
  endpoint=active.rendered_endpoint
 if origin_kind=="hero":source.z+=1.0 # UpdateArrowOriginPosition: friendly Hero only.
 return {"identity":"friendly:%d:%s:%d"%[interaction,key,unit_id],"side":0,"type":"friendly","interaction":game.Interaction.keys()[interaction],"card_id":key,"unit_id":unit_id,"source":source,"origin_kind":origin_kind,"endpoint":endpoint,"target_status":feedback.get("status","none"),"target":feedback.get("target",{}),"bullseye":feedback.get("status","")=="valid","binding":"InputManager→TargetReticleManager; legality uses unchanged 5834 rules"}

func _opponent_request() -> Dictionary:
 if game.player_turn or game.game_over or not is_instance_valid(game.native_combat):return {}
 for entry in game.native_combat.instances:
  if entry.get("stage","")!="ready":continue
  var side: int=int(entry.get("side",entry.get("unit",{}).get("side",-1)))
  if side!=1 or entry.get("target",{}).is_empty():continue
  var origin: Vector2=game.ENEMY_HERO
  var unit_id: int=-1;var origin_kind:="hero"
  if entry.kind=="attack":origin=entry.unit.pos;unit_id=entry.unit.id;origin_kind="attacker"
  elif not game.rules.needs_target(entry.key) and entry.key!="CS2_034":continue
  elif entry.key=="CS2_034":origin=Vector2(948,196);origin_kind="hero_power"
  var source:Vector3
  var endpoint:Vector3
  var projection=SourceProjection.from_game(game)
  if projection!=null:
   var anchor=projection.resolve_anchor(entry.unit if origin_kind=="attacker" else ("power:1" if origin_kind=="hero_power" else "hero:1"))
   var target=projection.resolve_anchor(entry.target)
   if anchor.is_empty() or target.is_empty():return {}
   source=anchor.position;endpoint=target.position
  else:source=_source_point(origin);endpoint=_source_point(entry.target.pos)
  return {"identity":"enemy:%d"%entry.serial,"side":1,"type":"enemy","interaction":entry.kind,"card_id":entry.key,"unit_id":unit_id,"source":source,"origin_kind":origin_kind,"endpoint":endpoint,"target_status":"valid","target":entry.target,"bullseye":false,"binding":"Local AI ready phase mapped to original enemy arrow; no remote network hover data"}
 return {}

func sync_from_game(delta: float=0.0):
 if game.game_over:
  clear("game_over");return
 if _last_side_turn!=game.side_turn:
  clear("turn_changed");_last_side_turn=game.side_turn.duplicate()
 var request: Dictionary=_local_request()
 if request.is_empty():request=_opponent_request()
 if request.is_empty():
  clear("aim_ended");return
 if active.is_empty() or active.identity!=request.identity:
  clear("source_changed");_serial+=1;active=request.duplicate();active.serial=_serial;active.events=[];active.offset=link_offset
  active.rendered_endpoint=request.source if request.type=="enemy" else request.endpoint
  _record("begin",{"source_binding":request.binding});_ensure_visuals()
 else:
  var old_endpoint: Vector3=active.rendered_endpoint
  active.merge(request,true);active.rendered_endpoint=old_endpoint
 active.rendered_endpoint=active.rendered_endpoint.lerp(request.endpoint,0.10000000149011612) if active.type=="enemy" else request.endpoint
 if _last_target_status!=active.target_status:
  _record("target_status",{"status":active.target_status,"ring":active.bullseye});_last_target_status=active.target_status
 var delta_source: Vector3=active.rendered_endpoint-active.source
 var length: float=Vector2(delta_source.x,delta_source.z).length()
 var prior_tip_y: float=float(active.get("samples",{}).get("tip_y",0.0))
 active.samples=sample_links(length,link_offset)
 if active.samples.count==0:active.samples.tip_y=prior_tip_y
 active.offset=link_offset;active.length=length
 _render(delta_source)
 text_indicator.sync(active)
 # Original increments after sampling; no advancement when no active links.
 if active.samples.count>0:
  link_offset+=maxf(0.0,delta)*LINK_SPEED
  if link_offset>LINK_LENGTH:link_offset-=LINK_LENGTH

func sample_links(length: float,offset: float) -> Dictionary:
 var count: int=int(floor(length/LINK_LENGTH))+1
 if count==1:count=0
 var rows: Array=[];var tip_z: float=-0.34883952140808105
 if count==0:return {"count":0,"links":[],"tip_y":0.0,"tip_pitch":300.0,"tip_z":tip_z}
 var mid: float=-length*0.5;var coefficient: float=-PARABOLA_HEIGHT/(mid*mid)
 for index in range(mini(count,15)):
  var z: float=-LINK_LENGTH*(index+1)+offset
  var height: float=coefficient*pow(z-mid,2.0)+PARABOLA_HEIGHT
  var alpha: float=1.0
  if index==0 and z>-LINK_LENGTH:alpha=pow(z/-LINK_LENGTH,6.0)
  elif index==count-1:alpha=pow(offset/LINK_LENGTH,2.0)
  rows.append({"z":z,"y":height,"pitch":180.0-rad_to_deg(atan(2.0*coefficient*(z-mid))),"alpha":clampf(alpha,0.0,1.0)})
 var tip_pitch: float=rad_to_deg(atan(2.0*coefficient*(tip_z-mid)))
 if tip_pitch<0.0:tip_pitch+=360.0
 return {"count":count,"links":rows,"tip_y":coefficient*pow(tip_z-mid,2.0)+PARABOLA_HEIGHT,"tip_pitch":tip_pitch,"tip_z":tip_z}

func _ensure_visuals():
 if game.headless or not source_missing.is_empty() or not is_instance_valid(game.spatial_scene):return
 if is_instance_valid(root):root.visible=true;return
 root=Node3D.new();root.name="OriginalTargetReticle";game.spatial_scene.add_child(root)
 projection=Node3D.new();projection.basis=_projection_basis();root.add_child(projection)
 arrow=assets.instantiate(assets.manifest.root_labels.arrow_bullseye,projection)
 _compensate(arrow)

func _compensate(state: Dictionary):
 if not is_instance_valid(game.native_damage):return
 for materials in state.get("materials",{}).values():
  for material in materials:game.native_damage._compensate_reflected_culling(material)

func _render(direction: Vector3):
 if not is_instance_valid(root) or active.is_empty():return
 root.visible=true
 var source_projection=SourceProjection.from_game(game)
 if source_projection!=null:root.position=SourceProjection.source_to_render(active.rendered_endpoint)
 else:root.position=game.spatial_scene.screen_to_world(_screen_point(active.rendered_endpoint)+game.shake_offset)
 var yaw: float=atan2(direction.x,direction.z)
 arrow.root.quaternion=Quaternion(Vector3.UP,yaw)
 var tip: Node3D=arrow.paths.get("TargetArrow_ArrowMesh")
 var ring: Node3D=arrow.paths.get("TargetArrow_TargetMesh")
 if is_instance_valid(tip):
  tip.position=Vector3(0,active.samples.tip_y,active.samples.tip_z)
  tip.quaternion=Quaternion(Vector3.UP,PI)*Quaternion(Vector3.RIGHT,deg_to_rad(active.samples.tip_pitch))
 for renderer in arrow.renderers.values():renderer.visible=true
 if is_instance_valid(ring):
  var ring_key: String=ring.get_meta("source_key","")
  if arrow.renderers.has(ring_key):arrow.renderers[ring_key].visible=active.bullseye
 while links.size()<mini(int(active.samples.count),15):
  var link: Dictionary=assets.instantiate(assets.manifest.root_labels.arrow_link,arrow.root)
  _compensate(link);links.append(link)
 for i in range(links.size()):
  var link: Dictionary=links[i];var visible: bool=i<int(active.samples.count)
  link.root.visible=visible
  if not visible:continue
  var sample: Dictionary=active.samples.links[i]
  link.root.position=Vector3(0,sample.y,sample.z)
  # Source world Euler is (pitch,reticle.localYaw,0); under
  # the reticle yaw parent the exact local rotation is X pitch.
  link.root.quaternion=Quaternion(Vector3.RIGHT,deg_to_rad(sample.pitch))
  for renderer in link.renderers.values():renderer.visible=true
  for materials in link.materials.values():
   for material in materials:assets.set_material_float(material,"_Color.a",sample.alpha)

func _record(event: String,extra: Dictionary={}):
 if active.is_empty():return
 var row: Dictionary={"event":event,"time":game.indicator_time};row.merge(extra,true);active.events.append(row)

func note_invalid_attempt(reason: String):
 _record("invalid_attempt_retained",{"reason":reason,"rules_committed":false})

func cancel_target_mode() -> bool:
 var had_target: bool=game._is_aiming() or not game.pending_battlecry.is_empty()
 if had_target and is_instance_valid(audio):audio.trigger_cancel(game.Interaction.keys()[game.interaction_state])
 clear("cancel")
 return had_target

func clear(reason: String="clear"):
 if reason in ["restart","exit_tree","game_over"] and is_instance_valid(audio):audio.stop_all()
 if not active.is_empty():
  _record("clear",{"reason":reason,"cancelled":reason=="cancel"})
  var audit: Dictionary=_active_audit();audit.clear_reason=reason;history.append(audit)
  if history.size()>64:history.pop_front()
 active={};_last_target_status="";text_indicator.clear()
 if is_instance_valid(root):root.visible=false
 # TargetReticleManager caches links and animation offset. Don't fabricate a
 # collapse/fade animation or reset offset on a target change/cancel.

func _active_audit() -> Dictionary:
 if active.is_empty():return {}
 var row: Dictionary=active.duplicate(true)
 row.erase("target")
 for key in ["source","endpoint","rendered_endpoint"]:
  var value: Vector3=row[key];row[key]=[value.x,value.y,value.z]
 row.source_prefabs=assets.manifest.get("root_labels",{}).duplicate()
 row.visual_available=is_instance_valid(root)
 return row

func get_audit() -> Dictionary:
 return {"active":_active_audit(),"active_count":0 if active.is_empty() else 1,"history":history.duplicate(true),"source_missing":source_missing.duplicate(),"untranslated_materials":assets.material_audit.duplicate(),"cached_links":links.size(),"original_meshes":true,"invalid_recolor":false,"handmade_arrow":false,"damage_text":text_indicator.get_audit(),"audio":audio.get_audit() if is_instance_valid(audio) else {},"projection":("Source phone camera; raw source reticle and original layer9 hit geometry" if SourceProjection.from_game(game)!=null else "Fixed 15-degree orthographic board registration, not recovered original camera")}
