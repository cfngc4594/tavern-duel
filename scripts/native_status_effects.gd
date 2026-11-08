extends "res://scripts/native_combat_effects.gd"
## The original status FSMs use the shared mesh/material/curve/particle engine.
## Added actions are status-specific source operations, never generic visuals.
var controller: Node

func setup_status(owner_game: Node,source_assets,owner_controller: Node,source_routes: Dictionary):
 controller=owner_controller;super.setup(owner_game,source_assets);routes=source_routes
 particle_script=preload("res://scripts/native_status_particles.gd")

func _spawn(root_key: String,anchor: Vector2,route_id: String,owner_serial: int) -> Dictionary:
 var effect: Dictionary=super._spawn(root_key,anchor,route_id,owner_serial)
 if effect.is_empty():return effect
 effect.animation_speeds={}
 if not game.headless:
  for materials in effect.state.materials.values():
   for material in materials:game.native_damage._compensate_reflected_culling(material)
 return effect

func _target_key(effect: Dictionary,action: Dictionary) -> String:
 var params: Dictionary=action.params
 var target: Dictionary=params.get("gameObject",params.get("m_GameObject",params.get("m_gameObj",{})))
 var value=_value(effect,target.get("gameObject",{}))
 if value is String:return value
 if action.get("target_object_key")!=null:return str(action.target_object_key)
 return effect.root_key if int(target.get("ownerOption",0))==0 else ""

func _action(effect: Dictionary,action: Dictionary,moment: float):
 if not bool(action.get("enabled",true)):return
 var params: Dictionary=action.params;var key: String=_target_key(effect,action)
 match str(action.class_name):
  "SendEventBasedOnEntityTagAction":
   effect.events.append({"event":"source_current_pool_branch","source":routes.get(effect.route_id,{}).get("branch_proof",{}),"time":moment})
  "SetPosition":
   var node: Node3D=effect.state.get("nodes",{}).get(key)
   if is_instance_valid(node):
    var value: Vector3=node.position
    for axis in ["x","y","z"]:
     var spec: Dictionary=params.get(axis,{})
     if not (bool(spec.get("useVariable",false)) and str(spec.get("name",""))==""):value[["x","y","z"].find(axis)]=float(_value(effect,spec,0.0))
    # Frozen Birth's literal xyz=(0,0,0), local space=1. Board registration
    # stays on its parent and never changes rules positions.
    if int(params.get("space",1))==1:node.position=value
    else:effect.unsupported.append("SetPosition world-space adapter not used by current status routes")
  "SetProperty":
   var property: Dictionary=params.get("targetProperty",{})
   var target_key: String=str(action.get("reference_keys",{}).get("params.targetProperty.TargetObject.value",""))
   var target: Dictionary=assets.objects.get(target_key,{})
   if target.get("type","")=="ParticleSystem" and property.get("PropertyName","")=="playbackSpeed":
    var ps_key: String=str(target.refs.get(".m_GameObject",""))
    var speed: float=float(_value(effect,property.get("FloatParameter",{}),1.0))
    if effect.has("components"):effect.components.set_particle_speed(ps_key,speed,moment)
    effect.events.append({"event":"source_particle_speed","value":speed,"source_key":target_key,"time":moment})
   else:super._action(effect,action,moment)
  "ParticleClearAction":
   var targets: Array=_descendants(key) if bool(_value(effect,params.get("m_IncludeChildren"),false)) else [key]
   for target in targets:
    if effect.particles.has(target):effect.particles[target].node.clear_particles(moment-float(effect.particles[target].start))
   effect.events.append({"event":"source_particle_clear","source_key":key,"time":moment})
  "SpellInitActorVariables":
   for field in ["m_actorObject","m_rootObject","m_rootObjectMesh"]:
    var name: String=str(params.get(field,{}).get("name",""))
    if name!="":effect.variables[name]="__status_actor"
  "HighlightContinuousUpdateAction":
   effect.events.append({"event":"source_highlight_refresh","duration":_value(effect,params.get("m_updateTime"),0.0),"time":moment})
  "SetAnimationSpeed":
   var value: float=float(_value(effect,params.get("speed"),1.0));effect.animation_speeds[key]=value
   if effect.clips.has(key):_set_clip_speed(effect.clips[key],value,moment)
   if bool(params.get("everyFrame",false)):effect.continuous.append({"kind":"status_animation_speed","key":key,"params":params,"start":moment})
  "CurveFloat":
   effect.animations.append({"kind":"status_curve_float","name":str(params.floatVariable.name),"curve":params.animCurve.curve,"params":params,"initial":float(_value(effect,params.floatVariable,0.0)),"start":moment+float(_value(effect,params.get("delay"),0.0))})
  "AudioPlaythroughAction","AudioPlayClipAction":
   var result: Dictionary=controller.audio.trigger_action(effect,action,moment)
   effect.events.append({"event":"source_status_audio","action":action.class_name,"time":moment,"dispatch":result})
  _:super._action(effect,action,moment)

func _play_clip(effect: Dictionary,key: String,name: String,start: float,speed: float=1.0,blend: float=0.0):
 super._play_clip(effect,key,name,start,1.0,blend)
 var player: Dictionary=effect.clips[key]
 player.status_speed=float(effect.get("animation_speeds",{}).get(key,speed))
 player.status_clip_time=0.0;player.status_clock_age=start

func _advance_clip_clock(player: Dictionary,time: float):
 # Unity AnimationState.speed integrates elapsed playback time. Re-evaluating
 # (age-start)*newSpeed would jump backward on the source taunt Death curve.
 if not player.has("status_speed"):return
 var elapsed: float=maxf(0.0,time-float(player.status_clock_age))
 player.status_clip_time=maxf(0.0,float(player.status_clip_time)+elapsed*float(player.status_speed))
 player.status_clock_age=maxf(time,float(player.status_clock_age))
 # Shared clip sampler accepts an effective origin. Unit speed also preserves
 # a stopped source animation's current pose rather than resetting it to zero.
 player.start=time-float(player.status_clip_time);player.speed=1.0

func _set_clip_speed(player: Dictionary,value: float,time: float):
 _advance_clip_clock(player,time);player.status_speed=value

func _apply_continuous(effect: Dictionary,action: Dictionary):
 if action.kind=="status_animation_speed":
  var speed: float=float(_value(effect,action.params.get("speed"),1.0));effect.animation_speeds[action.key]=speed
  if effect.clips.has(action.key):_set_clip_speed(effect.clips[action.key],speed,float(effect.get("status_action_time",effect.age)))
 else:super._apply_continuous(effect,action)

func _project(effect: Dictionary):
 super._project(effect)
 if not is_instance_valid(effect.container):return
 if SourceProjection.from_game(game)!=null and not effect.get("source_projection_valid",false):return
 var unit: Dictionary=effect.get("follow_unit",{})
 var shown: bool=unit.is_empty() or (not unit.get("hidden",false) and not unit.get("native_summon_hidden",false))
 var previous_shown: bool=bool(effect.get("source_actor_shown",true))
 effect.source_actor_shown=shown
 if bool(effect.get("cached_none",false)):
  effect.container.visible=false;return
 # Actual Spell.Show(false->true) invokes OnExitedNoneState for every non-None
 # active state, even Death. This is not a Birth or an animation/audio restart.
 if shown and not previous_shown:
  _enable_source_container(effect)
  effect.events.append({"event":"source_show_container_enabled","time":effect.age,"state":effect.source_event})
 effect.container.visible=shown
 if not unit.is_empty():
  if game.spatial_scene.pieces.has(int(unit.id)):
   var piece: Dictionary=game.spatial_scene.pieces[int(unit.id)]
   if piece.get("native_actor",false):
    # The source status spell is attached to the live actor, carrying its
    # original combat/summon pose rather than a second screen-space ellipse.
    effect.projection.global_transform=piece.actor.root.global_transform

func _audit(effect: Dictionary) -> Dictionary:
 var result: Dictionary=super._audit(effect)
 result.status=effect.get("status_name","");result.subject=effect.get("subject","");result.keyword_death=effect.get("keyword_death",{});result.cached_none=effect.get("cached_none",false);result.activation=effect.get("status_activation",0)
 for particle in result.particles:
  for field in particle.get("unsupported",[]):
   var issue: String="particle:"+str(particle.get("source_key",""))+":"+str(field)
   if not result.unsupported.has(issue):result.unsupported.append(issue)
 return result

func _sample_animations(effect: Dictionary,time: float):
 for player in effect.clips.values():_advance_clip_clock(player,time)
 super._sample_animations(effect,time)
 for animation in effect.animations:
  if animation.kind!="status_curve_float" or time<float(animation.start):continue
  var params: Dictionary=animation.params;var curve: Dictionary=animation.curve
  var keys: Array=curve.get("m_Curve",[])
  if keys.is_empty():continue
  var end_time: float=float(keys[-1].time)
  var age: float=clampf(time-float(animation.start),0.0,end_time)
  var sampled: float=Curves.scalar_keys(keys,age)
  var start_value: float=float(_value(effect,params.get("fromValue"),0.0))
  var end_value: float=float(_value(effect,params.get("toValue"),1.0))
  # Original CurveFsmAction calculation4, unset time/speed branch. It mixes
  # from/to by curve(t)*(t/end), NOT AnimateFloatV2's reverse subtraction.
  if int(params.get("calculation",4))==4:
   effect.variables[animation.name]=start_value+sampled*(end_value-start_value)*(age/end_time if end_time>0.0 else 1.0)
  else:
   if not effect.unsupported.has("CurveFloat calculation outside source taunt4"):effect.unsupported.append("CurveFloat calculation outside source taunt4")

func _ease(t: float,type: int) -> float:
 if type==27:
  var s: float=1.7015800476074219;var q: float=t-1.0
  return q*q*((s+1.0)*q+s)+1.0
 return super._ease(t,type)

func _exit_state(effect: Dictionary,moment: float):
 effect.status_action_time=moment
 super._exit_state(effect,moment)
 effect.erase("status_action_time")

func _enable_source_container(effect: Dictionary):
 # Unity user components are MonoBehaviour objects whose class_name is Spell;
 # the shared component helper intentionally matches built-in `type` only.
 var spell: Dictionary={}
 for component_key in assets.objects.get(effect.root_key,{}).get("refs",{}).values():
  var component: Dictionary=assets.objects.get(component_key,{})
  if component.get("class_name","")=="Spell":spell=component;break
 if spell.is_empty():
  push_error("Original status Spell component unavailable: "+str(effect.root_key));return
 var container_key: String=str(spell.get("refs",{}).get(".m_ObjectContainer",""))
 for key in _descendants(container_key) if container_key!="" else []:
  if not effect.state.get("renderers",{}).has(key):continue
  var source_node: Node3D=effect.state.get("nodes",{}).get(key)
  var active_in_source:=true
  while is_instance_valid(source_node) and source_node!=effect.projection:
   if not source_node.visible:active_in_source=false;break
   source_node=source_node.get_parent() as Node3D
  if active_in_source:effect.state.renderers[key].visible=true

func _start_event(effect: Dictionary,event: String,start: float):
 if event=="Birth" and str(effect.get("source_event",""))=="None":
  # None->Birth enables container; direct Death->Birth does not. Actual Show
  # is the separate edge in _project above, including while still Death.
  _enable_source_container(effect)
 effect.status_activation=int(effect.get("status_activation",0))+1
 super._start_event(effect,event,start)

func _particles(effect: Dictionary,key: String,moment: float,include_children: bool,play: bool):
 var existing: Array=[]
 if play and not game.headless:
  for target in (_descendants(key) if include_children else [key]):
   if effect.particles.has(target):existing.append(target)
 super._particles(effect,key,moment,include_children,play)
 for target in existing:
  var player: Dictionary=effect.particles[target]
  player.node.source_play(moment-float(player.start))

func release_instance(effect: Dictionary):
 effect.force_release=true
 _dispose(effect)

func _dispose(effect: Dictionary):
 if not controller.clearing and not effect.get("force_release",false) and effect.has("identity"):
  # Original Actor.m_ownedSpells retains Spell at None; no new prefab/FSM on
  # reapplication. Keep the clock and particle solver alive behind render gate.
  effect.cached_none=true;effect.source_event="None";effect.expires=0.0
  effect.events.append({"event":"source_cached_none","time":effect.age})
  if is_instance_valid(effect.container):effect.container.visible=false
  return
 if effect.has("identity"):controller.instances.erase(effect.identity)
 controller.audio.release_owner(int(effect.serial))
 super._dispose(effect)

func get_audit() -> Dictionary:
 var result: Dictionary=super.get_audit()
 result.cached_none=result.active.filter(func(row):return bool(row.get("cached_none",false)))
 result.active=result.active.filter(func(row):return not bool(row.get("cached_none",false)))
 result.active_count=result.active.size()
 result.cached_none_count=result.cached_none.size()
 return result
