extends Node
## Source-owned EndGameScreen / EndGameTwoScoop presentation, no account rewards.
## Source CIL: 06004CB2/3, 06004D9B/C/E, 06004E56/5B; build 37.0.0.255130.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Curves=preload("res://scripts/native_summon_curves.gd")
const START_POSITION=Vector3(-7.8,8.2,-5.0)
const PROJECTION_SCALE=0.702
signal source_event(event: String)
signal closed
var game: Node
var assets
var result: Dictionary={}
var state: Dictionary={}
var actor: Dictionary={}
var screen_kind: String=""
var phase: String="idle"
var age: float=0.0
var close_age: float=0.0
var close_scale: Vector3=Vector3.ONE
var close_alpha: float=1.0
var container: Node3D
var projection: Node3D
var scoop: Node3D
var fields: Dictionary={}
var text_renderer
var background_effect
var components
var scene_binder
var cull_adapter
var particles: Dictionary={}
var tweens: Array=[]
var history: Array=[]
var blockers: Array=[]
var binding: Dictionary={}
var root_key: String=""
var source_screen: Dictionary={}
var initial_poses: Dictionary={}

func setup(owner_game: Node,source_assets):
 game=owner_game;assets=source_assets
 background_effect=preload("res://scripts/native_endgame_background.gd").new();add_child(background_effect);background_effect.setup(game)
 var path: String=assets.base_path+"data/hero_portrait_binding.json"
 if FileAccess.file_exists(path):binding=JSON.parse_string(FileAccess.get_file_as_string(path))
 cull_adapter=preload("res://scripts/native_damage_splat.gd").new();add_child(cull_adapter)
 scene_binder=preload("res://scripts/native_combat_effects.gd").new();add_child(scene_binder);scene_binder.game=game
 text_renderer=preload("res://scripts/native_endgame_text.gd").new();text_renderer.setup(assets)

func show(snapshot: Dictionary) -> bool:
 if phase!="idle":return false
 result=snapshot.duplicate(true);screen_kind="victory_screen" if result.get("outcome","")=="win" else "defeat_screen"
 root_key="cab-69c88b234dfa427e02d1fcee9337ae34:-1629742064369035632" if screen_kind=="victory_screen" else "cab-33ac7a42de0e5712cf0d622e368df924:-213764320460570505"
 phase="showing";age=0.0
 history.append({"event":"show","screen":screen_kind,"outcome":result.get("outcome"),"at":age})
 if not game.headless:
  var result_parent: Node3D=background_effect.begin()
  if result_parent==null:result_parent=game.spatial_scene
  container=Node3D.new();container.name="OriginalEndGameScreen";result_parent.add_child(container)
  projection=Node3D.new();container.add_child(projection)
  # Same 15-degree source-board projection as original combat; translation only
  # registers the source screen origin to the native board's centre.
  projection.basis=Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*PROJECTION_SCALE
  projection.position=-(projection.basis*START_POSITION)
  if SourceProjection.from_game(game)!=null:
   # TwoScoop source START_POSITION and phone root override are already world
   # placement. Do not subtract the source origin or add a synthetic 10-unit lift.
   projection.basis=SourceProjection.REFLECTION;projection.position=Vector3.ZERO
  state=assets.instantiate(root_key,projection);state.root.visible=true
  _apply_screen_overrides(state)
  for obj in assets.objects.values():
   if obj.get("class_name","")==("VictoryScreen" if screen_kind=="victory_screen" else "DefeatScreen") and obj.refs.get(".m_GameObject")==root_key:source_screen=obj;break
  var component: Dictionary=assets.objects.get(source_screen.get("refs",{}).get(".m_twoScoop",""),{})
  for field in component.get("refs",{}):
   var target: String=component.refs[field]
   if state.nodes.has(target):fields[str(field).trim_prefix(".")]=state.nodes[target]
  scoop=state.paths.get("TwoScoop");fields["self"]=scoop
  for field in fields:
   var key: String=str(fields[field].get_meta("source_key",""))
   var tr: Dictionary=assets.component(key,"Transform").get("data",{})
   var rotation: Quaternion=state.source_rotations.get(key,Quaternion.IDENTITY)
   initial_poses[field]={"position":Curves.vec(tr.get("m_LocalPosition",{})),"scale":Curves.vec(tr.get("m_LocalScale",{})),"rotation_degrees":rotation.get_euler()*180.0/PI,"quaternion":rotation}
  _reset_positions()
  _setup_actor(component)
  # These controller children depend on real account/game rewards. They are not
  # inferred from a local practice outcome and no reward prefabs are instantiated.
  for field in [".m_noGoldRewardText",".m_gamesWonIndicator"]:
   var record: Dictionary=assets.objects.get(source_screen.get("refs",{}).get(field,""),{})
   var key: String=record.get("refs",{}).get(".m_GameObject",record.get("key",""))
   if state.nodes.has(key):state.nodes[key].visible=false
  text_renderer.build(state,screen_kind,str(result.get("outcome","")))
  components=preload("res://scripts/native_combat_components.gd").new();components.setup(state,assets,33017)
  _start_particles()
  # Source geometry uses the reflected source/board registration. Undo Godot's
  # additional front-face flip, exactly as the verified original damage path.
  # Hand-built Godot text triangles already use native winding and are excluded.
  for scope in [state,actor]:
   for materials in scope.get("materials",{}).values():
    for material in materials:cull_adapter._compensate_reflected_culling(material)
  _schedule_source_show()
  sync();_sample()
 source_event.emit("Action")
 return true

func _apply_screen_overrides(scope: Dictionary):
 # TransformOverride.Awake -> UpdateObject. Phone=1, PC=4.
 # Only enabled components participate, using closest category >= current.
 var category:int=1 if SourceProjection.from_game(game)!=null else 4
 for key in scope.nodes:
  for ref in assets.objects.get(key,{}).get("refs",{}).values():
   var record: Dictionary=assets.objects.get(ref,{})
   if record.get("class_name","")!="TransformOverride" or not bool(record.get("data",{}).get("m_Enabled",true)):continue
   var data: Dictionary=record.data;var selected: int=-1;var difference: int=2147483647
   for index in range(data.get("m_screenCategory",[]).size()):
    var delta: int=int(data.m_screenCategory[index])-category
    if delta>=0 and delta<difference:selected=index;difference=delta
   if selected<0:continue
   var node: Node3D=scope.nodes[key]
   node.position=Curves.vec(data.m_localPosition[selected])
   var q: Dictionary=data.m_localRotation[selected]
   var rotation:=Quaternion(q.x,q.y,q.z,q.w)
   node.basis=Basis(rotation)*Basis.from_scale(Curves.vec(data.m_localScale[selected]))
   scope.source_rotations[key]=rotation
   history.append({"event":"source_screen_transform_override","source":record.key,"target":key,"category":category,"index":selected,"at":0.0})

func _setup_actor(component: Dictionary):
 if binding.is_empty():blockers.append("Original HeroActor binding metadata unavailable");return
 var bone_key: String=str(component.get("refs",{}).get(".m_heroBone",""))
 var bone: Node3D=state.nodes.get(bone_key)
 if not is_instance_valid(bone):blockers.append("Original hero bone missing");return
 actor=assets.instantiate(str(binding.actor_root),scoop)
 _apply_screen_overrides(actor)
 actor.root.transform=bone.transform;actor.root.visible=true
 var health_key: String=binding.actor_component.refs.get(".m_healthObject","")
 if actor.nodes.has(health_key):actor.nodes[health_key].visible=false
 # ShowImpl.SetFullDefFromEntity -> UpdateTextComponentsDef selects base-card
 # ATK tag47. Both local basic hero definitions have ATK0; original
 # UpdateAttackTextMesh060128A9 explicitly disables the whole AttackObject.
 var attack_key: String=binding.actor_component.refs.get(".m_attackObject","")
 if actor.nodes.has(attack_key):actor.nodes[attack_key].visible=false
 var portrait_key: String=binding.portrait_game_object.key
 var card_id: String=str(result.get("hero_cards",["HERO_08"])[0])
 for row in binding.portraits:
  if row.card_id!=card_id:continue
  var mi: MeshInstance3D=actor.renderers.get(portrait_key)
  if mi!=null:
   var original_key: String=binding.portrait_renderer.refs.get(".m_Materials[1]","")
   var mat: Material=assets.material(original_key,assets.load_texture(row.portrait_texture))
   mi.set_surface_override_material(1,mat);actor.materials[portrait_key][1]=mat
 history.append({"event":"hero_actor_attached","actor":binding.actor_root,"bone":bone_key,"card":card_id,"health_hidden":true,"at":age})

func _set_field(field: String,property: String,value):
 if not fields.has(field):return
 initial_poses[field][property]=value
 var node: Node3D=fields[field]
 if property=="position":node.position=value;return
 if property=="rotation_degrees":initial_poses[field].quaternion=Basis.from_euler(value*PI/180.0,EULER_ORDER_YXZ).get_rotation_quaternion()
 node.basis=Basis(initial_poses[field].quaternion)*Basis.from_scale(initial_poses[field].scale)
 state.source_rotations[node.get_meta("source_key","")]=initial_poses[field].quaternion

func _reset_positions():
 _set_field("self","position",START_POSITION);_set_field("self","rotation_degrees",Vector3(0,180,0));_set_field("self","scale",Vector3.ONE*.01)
 if screen_kind=="victory_screen":
  _set_field("m_rightTrumpet","position",Vector3(.23,-.6,.16));_set_field("m_rightTrumpet","scale",Vector3.ONE)
  _set_field("m_leftTrumpet","position",Vector3(-.23,-.6,.16));_set_field("m_leftTrumpet","scale",Vector3(-1,1,1))
  for field in ["m_rightBanner","m_leftBanner"]:_set_field(field,"scale",Vector3(1,1,.08))
  _set_field("m_rightCloud","position",Vector3(-.2,-.8,.26));_set_field("m_leftCloud","position",Vector3(.16,-.8,.2))
  _set_field("m_godRays","rotation_degrees",Vector3(0,29,0));_set_field("m_godRays2","rotation_degrees",Vector3(0,-29,0))
  _set_field("m_crown","position",Vector3(-.041,-.04,-.834))
  _set_field("m_rightLaurel","rotation_degrees",Vector3(0,-90,0));_set_field("m_rightLaurel","scale",Vector3.ONE*.7)
  _set_field("m_leftLaurel","rotation_degrees",Vector3(0,90,0));_set_field("m_leftLaurel","scale",Vector3(-.7,.7,.7))
 else:
  _set_field("m_rightTrumpet","scale",Vector3.ONE*.1)
  for field in ["m_rightTrumpet","m_leftTrumpet"]:_set_field(field,"rotation_degrees",Vector3(0,-180,0))
  _set_field("m_rightBanner","scale",Vector3(1,1,-.0375));_set_field("m_rightBannerShred","scale",Vector3(1,1,.05))
  _set_field("m_rightCloud","position",Vector3(-.036,-.3,.46));_set_field("m_leftCloud","position",Vector3(-.047,-.3,.41))
  _set_field("m_crown","rotation_degrees",Vector3(-.026,17,.2));_set_field("m_defeatBanner","rotation_degrees",Vector3(0,180,0))

func _schedule_source_show():
 # The controller's blocking flag is cleared by PunchEndGameTwoScoop at .5,
 # before its .15-second final scale settles.
 _tween("self","scale",Vector3.ONE*2.5,0.0,.5,16 if screen_kind=="victory_screen" else 24)
 _tween("self","scale",Vector3.ONE*2.3,.5,.15,16)
 _tween("self","position",START_POSITION+Vector3.ONE*.005,0.0,1.5,16)
 _loop("self","position",START_POSITION+Vector3.ONE*.2,START_POSITION,1.5,10.0,21)
 if screen_kind=="defeat_screen":
  _loop("m_leftTrumpet","rotation_degrees",Vector3(0,-184,0),Vector3(0,-180,0),0.0,5.0,20)
  _loop("m_rightTrumpet","rotation_degrees",Vector3(0,-172,0),Vector3(0,-180,0),0.0,8.0,20)
  _loop("m_crown","rotation_degrees",Vector3(0,1.8,0),Vector3(0,17,0),0.0,.75,21)
 _load_source_timeline()

func _load_source_timeline():
 var path: String=assets.base_path+"data/result_screen_timeline.json"
 if not FileAccess.file_exists(path):
  blockers.append("Source AnimateAll timeline not yet bound")
  return
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 for row in data.get(screen_kind.trim_suffix("_screen"),[]):
  if not fields.has(row.field):continue
  var property: String={"MoveTo":"position","ScaleTo":"scale","RotateTo":"rotation_degrees"}.get(row.kind,"")
  var params: Dictionary=row.params
  var value: Vector3=initial_poses[row.field][property]
  var vector_name: String={"MoveTo":"position","ScaleTo":"scale","RotateTo":"rotation"}.get(row.kind,"")
  if params.has(vector_name):value=Vector3(params[vector_name][0],params[vector_name][1],params[vector_name][2])
  for i in range(3):
   if params.has(["x","y","z"][i]):value[i]=float(params[["x","y","z"][i]])
  _tween(str(row.field),property,value,float(row.at),float(params.time),int(params.get("easetype",16)))
 var win: bool=screen_kind=="victory_screen"
 for side in ["right","left"]:
  var field: String="m_"+side+"Cloud"
  var initial: Vector3=initial_poses[field].position
  var back: Vector3=initial;var to: Vector3=initial
  back.x=(-1.227437973 if side=="right" else 1.053243995) if win else (-.81 if side=="right" else .824)
  to.x=(-.92 if side=="right" else .82) if win else (-.38 if side=="right" else .443)
  _loop(field,"position",to,back,5.25,10.0,21)
 if win:
  _loop("m_rightLaurel","rotation_degrees",Vector3.ZERO,Vector3(0,2,0),.75,10.0,21)
  _loop("m_leftLaurel","rotation_degrees",Vector3.ZERO,Vector3(0,-2,0),.75,10.0,21)
  _loop("m_crown","position",Vector3(-.041,-.04,-.78),Vector3(-.041,-.04,-.834),0.0,5.0,28)
  _loop("m_godRays","rotation_degrees",Vector3(0,-20,0),Vector3(0,20,0),0.0,20.0,21)
  _loop("m_godRays2","rotation_degrees",Vector3(0,20,0),Vector3(0,-20,0),0.0,20.0,21)

func _tween(field: String,property: String,value,at: float,duration: float,ease_type: int):
 tweens.append({"field":field,"property":property,"to":value,"at":at,"duration":duration,"ease":ease_type,"begun":false})

func _loop(field: String,property: String,to,back,at: float,duration: float,ease_type: int):
 tweens.append({"field":field,"property":property,"to":to,"back":back,"at":at,"duration":duration,"ease":ease_type,"begun":false,"loop":true})

func _start_particles():
 state.particle_players={}
 for key in state.get("particles",{}):
  var spec: Dictionary=state.particles[key]
  if bool(spec.system.data.get("playOnAwake",false)) and spec.node.is_visible_in_tree():
   var player=preload("res://scripts/native_combat_particles.gd").new();player.setup(spec,assets,projection,33017+particles.size())
   particles[key]=player;state.materials[key]=[player.material]
   state.particle_players[key]={"node":player,"start":0.0}
   if components!=null:components.on_particle_created(key,state.particle_players[key])

func _sample():
 if state.is_empty():return
 if components!=null:components.update(age)
 for tween in tweens:
  if age<float(tween.at) or not fields.has(tween.field):continue
  var node: Node3D=fields[tween.field]
  if not tween.begun:tween.from=initial_poses[tween.field][tween.property];tween.begun=true
  var elapsed: float=age-float(tween.at)
  var value_from=tween.from;var value_to=tween.to
  if tween.get("loop",false):
   var cycle: int=int(floor(elapsed/float(tween.duration)))
   if cycle>0:value_from=tween.to if cycle%2==1 else tween.back
   value_to=tween.back if cycle%2==1 else tween.to
   elapsed=fmod(elapsed,float(tween.duration))
  elif elapsed>float(tween.duration) and tween.get("done",false):continue
  _set_field(tween.field,tween.property,value_from.lerp(value_to,_ease(clampf(elapsed/float(tween.duration),0,1),int(tween.ease))))
  if not tween.get("loop",false) and elapsed>=float(tween.duration):tween.done=true
 var fade: float=_ease(clampf(age/.25,0,1),16)
 if phase=="closing":
  var t: float=_ease(clampf(close_age/.25,0,1),16)
  _set_field("self","scale",close_scale.lerp(Vector3.ONE*.01,t));fade=close_alpha*(1.0-t)
 _fade_scoop(fade)
 if components!=null:components.late_update(age)
 for player in particles.values():
  player.seek(age)
  if is_instance_valid(player.source_node):player.mesh_instance.visible=player.source_node.is_visible_in_tree()
 scene_binder._bind_scene_inputs({"state":state})
 scene_binder._bind_scene_inputs({"state":actor})
 text_renderer.set_continue_visible(phase!="closing")

func _fade_scoop(alpha: float):
 for scope in [state,actor]:
  for key in scope.get("materials",{}):
   var node: Node3D=scope.get("nodes",{}).get(key)
   if node!=null and not (node==scoop or scoop.is_ancestor_of(node)):continue
   for mat in scope.materials[key]:
    if mat is ShaderMaterial and mat.get_meta("source_colors",{}).has("_Color"):
     assets.set_material_float(mat,"_Color.a",alpha)
 text_renderer.set_banner_alpha(alpha)

func can_close() -> bool:
 return phase in ["showing","shown"]

func close() -> bool:
 if not can_close():return false
 phase="closing";close_age=0.0;close_alpha=_ease(clampf(age/.25,0,1),16)
 if is_instance_valid(scoop):close_scale=initial_poses.self.scale
 history.append({"event":"close","at":age});source_event.emit("Death")
 return true

func advance(delta: float):
 if phase in ["idle","closed"]:return
 age+=maxf(delta,0.0)
 if background_effect!=null:background_effect.advance(delta)
 if phase=="showing" and age>=.5:phase="shown"
 if phase=="closing":close_age+=maxf(delta,0.0)
 _sample()
 if phase=="closing" and close_age>=.25:
  phase="closed"
  if is_instance_valid(container):container.visible=false
  history.append({"event":"all_hidden","at":age});closed.emit()

func sync():
 if is_instance_valid(container):
  container.position=Vector3.ZERO if SourceProjection.from_game(game)!=null else game.spatial_scene.screen_to_world(Vector2(800,450),1000)
 if background_effect!=null:background_effect.sync()

func clear():
 if components!=null:components.dispose(age)
 if is_instance_valid(container):container.visible=false;container.queue_free()
 container=null;projection=null;scoop=null;state={};actor={};fields.clear();initial_poses.clear();tweens.clear();particles.clear();history.clear();blockers.clear()
 result.clear();phase="idle";age=0.0;close_age=0.0;components=null
 if text_renderer!=null:text_renderer.clear()
 if background_effect!=null:background_effect.release()

func get_audit() -> Dictionary:
 return {"phase":phase,"age":age,"screen":screen_kind,"source_root":root_key,"outcome":result.get("outcome",""),"source_mesh_renderers":state.get("renderers",{}).size(),"source_actor_renderers":actor.get("renderers",{}).size(),"source_particles":particles.size(),"can_close":can_close(),"source_tweens":tweens.size(),"dynamic_rewards_instantiated":false,"text":text_renderer.get_audit() if text_renderer!=null else {},"background":background_effect.get_audit() if background_effect!=null else {},"history":history.duplicate(true),"blockers":blockers.duplicate(),"projection":("Source phone camera; original TwoScoop world placement and enabled phone TransformOverrides" if SourceProjection.from_game(game)!=null else "Source 15-degree board basis; source origin translated to board centre, 0.702 scene scale")}

func _ease(t: float,kind: int) -> float:
 match kind:
  0:return t*t
  1:return t*(2.0-t)
  4:return 1.0-pow(1.0-t,3.0)
  16:return 1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*t)
  20:
   var x: float=t*2.0
   if x<1.0:return -.5*(sqrt(maxf(0,1.0-x*x))-1.0)
   x-=2.0;return .5*(sqrt(maxf(0,1.0-x*x))+1.0)
  24:
   if t<1.0/2.75:return 7.5625*t*t
   if t<2.0/2.75:t-=1.5/2.75;return 7.5625*t*t+.75
   if t<2.5/2.75:t-=2.25/2.75;return 7.5625*t*t+.9375
   t-=2.625/2.75;return 7.5625*t*t+.984375
  30:
   if t==0.0 or t==1.0:return t
   return pow(2.0,-10.0*t)*sin((t-.075)*TAU/.3)+1.0
  28:
   var x: float=t*2.0;var s: float=1.70158*1.525
   if x<1.0:return .5*(x*x*((s+1.0)*x-s))
   x-=2.0;return .5*(x*x*((s+1.0)*x+s)+2.0)
 return t
