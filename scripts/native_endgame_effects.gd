extends "res://scripts/native_combat_effects.gd"
## Only end-game-specific actions are added here. Source meshes/curves/particles,
## render-to-texture, material sampling and retirement keep the common renderer.
var controller: Node
func setup_endgame(owner_game: Node,source_assets,owner_controller: Node,source_routes: Dictionary):
 controller=owner_controller
 super.setup(owner_game,source_assets)
 routes=source_routes

func _action(effect: Dictionary,action: Dictionary,moment: float):
 var params: Dictionary=action.params
 match str(action.class_name):
  "AudioPlaythroughAction","AudioPlayAction","AudioPlayClipAction","AudioStopAction","AudioVolumeFadeAction":
   controller.on_source_audio_action(effect,action,moment)
  "SetProperty":
   var property: Dictionary=params.get("targetProperty",{})
   var target_key: String=str(action.get("reference_keys",{}).get("params.targetProperty.TargetObject.value",""))
   var target: Dictionary=assets.objects.get(target_key,{})
   if target.get("type","")=="ParticleSystem" and property.get("PropertyName","")=="playbackSpeed":
    var key: String=str(target.refs.get(".m_GameObject",""))
    var value: float=float(_value(effect,property.get("FloatParameter",{}),1.0))
    # Unity PS exists before Play. Cache its absolute speed before the lazy
    # compatibility particle wrapper is born in the following source action.
    if effect.has("components"):effect.components.set_particle_speed(key,value,moment)
    effect.events.append({"event":"source_particle_speed","source_key":target_key,"game_object":key,"value":value,"time":moment,"before_player_creation":not effect.particles.has(key)})
   else:super._action(effect,action,moment)
  "SpellInitActorVariables":
   for field in ["m_actorObject","m_rootObject","m_rootObjectMesh"]:
    var name: String=str(params.get(field,{}).get("name",""))
    if name!="":effect.variables[name]="__endgame_hero_body_"+str(effect.context.side)
  "SetVisibilityRecursiveAction":
   var key: String=_target_key(effect,action)
   if key.begins_with("__endgame_hero_body_"):controller.set_hero_body_visible(int(effect.context.side),bool(_value(effect,params.get("visible"),true)),moment)
   else:
    if bool(params.get("resetOnExit",false)):
     var keys: Array=_descendants(key) if bool(params.get("includeChildren",true)) else [key]
     for child_key in keys:
      var renderer: Node3D=effect.state.get("renderers",{}).get(child_key)
      if is_instance_valid(renderer):effect.restores.append({"node":renderer,"property":"visible","value":renderer.visible})
    super._action(effect,action,moment)
  "ActorSetVisibility":controller.set_hero_body_visible(int(effect.context.side),bool(_value(effect,params.get("m_Visible"),true)),moment)
  "InvokeMethod":
   var behaviour: String=str(_value(effect,params.get("behaviour"),""));var method: String=str(_value(effect,params.get("methodName"),""))
   if behaviour=="AssignActorPortraitToChildren" and method=="AssignPortraitToAllChildren":controller.assign_actor_portrait(effect,_target_key(effect,action),moment)
   else:super._action(effect,action,moment)
  "ScaleTime","SetTimeScaleAction":
   var item: Dictionary={"kind":"endgame_time_scale","params":params,"start":moment}
   effect.continuous.append(item);_apply_continuous(effect,item)
  "SendEventBasedOnEntityTagAction","GetPetModelAction","GameObjectIsNull":
   # These source branches must have been resolved explicitly for the current
   # basic heroes/no-pet context by the normalized source schedule.
   effect.events.append({"event":"source_resolved_branch","action":action.class_name,"time":moment})
  _ :super._action(effect,action,moment)

func _apply_continuous(effect: Dictionary,action: Dictionary):
 if action.kind=="endgame_time_scale":
  var params: Dictionary=action.params
  controller.set_source_time_scale(effect,float(_value(effect,params.get("timeScale",params.get("m_Scale")),1.0)))
 else:super._apply_continuous(effect,action)

func _target_key(effect: Dictionary,action: Dictionary) -> String:
 var params: Dictionary=action.params
 var target: Dictionary=params.get("gameObject",params.get("m_GameObject",{}))
 var value=_value(effect,target.get("gameObject",{}))
 if value is String:return value
 if action.get("target_object_key")!=null:return str(action.target_object_key)
 return effect.root_key if int(target.get("ownerOption",0))==0 else ""

func _spawn(root_key: String,anchor: Vector2,route_id: String,owner_serial: int) -> Dictionary:
 var effect: Dictionary=super._spawn(root_key,anchor,route_id,owner_serial)
 if not effect.is_empty() and not game.headless:
  # Same reflected source/board basis as damage. Preserve original CullBack
  # front faces by compensating the backend's negative-model front-face flip.
  for materials in effect.state.materials.values():
   for material in materials:game.native_damage._compensate_reflected_culling(material)
 return effect

func _run_schedules(effect: Dictionary):
 for schedule in effect.schedules:
  while int(schedule.cursor)<schedule.data.size():
   var step: Dictionary=schedule.data[int(schedule.cursor)]
   var ideal: float=float(schedule.start)+float(step.at)+float(schedule.get("offset",0.0))
   if float(effect.age)+0.0000001<ideal:break
   if int(schedule.cursor)>0:
    var previous: Dictionary=schedule.data[int(schedule.cursor)-1]
    var has_animate: bool=previous.actions.any(func(a):return str(a.class_name)=="AnimateFloatV2")
    if has_animate and float(step.at)>float(previous.at):
     if not schedule.has("eligible_frame"):
      schedule.eligible_frame=controller.frame_id;break
     if controller.frame_id<=int(schedule.eligible_frame):break
   schedule.erase("eligible_frame")
   var moment: float=maxf(ideal,float(effect.age))
   schedule.offset=float(schedule.get("offset",0.0))+moment-ideal
   _exit_state(effect,moment)
   effect.current_state=step.state_name
   effect.events.append({"event":"state_enter","state":step.state_name,"time":moment,"frame":controller.frame_id})
   for action in step.actions:_action(effect,action,moment)
   schedule.cursor+=1
   if str(step.state_name)=="None State" and not effect.get("notified_finished",false):
    effect.notified_finished=true
    controller.on_source_callback(effect,{"event":"OnSpellFinished","source":"entered original None state"},moment)

func _start_event(effect: Dictionary,event: String,start: float):
 var source: Dictionary=routes.get(effect.route_id,{}).get("event_schedules",{}).get(event,{})
 effect.source_event=event;effect.source_event_origin=start;effect.expires=0.0
 if event=="Action":effect.notified_finished=false
 if source.is_empty():return
 var rows: Array=source.get("state_enter_schedule",[]).duplicate(true)
 var offset:=0.0
 if source.has("random_offset"):
  var random: Dictionary=source.random_offset
  offset=visual_rng.randf_range(float(random.min),float(random.max))
  for row in rows:
   if not str(row.state_name) in random.applies_to_states_except:row.at=float(row.at)+offset
 effect.random_offset=offset
 effect.schedules=[{"data":rows,"cursor":0,"start":start,"offset":0.0}]
 _run_schedules(effect)
 # None does not destroy these cached hero spells. Their original ObjectContainer
 # is null; original firework particles keep running until the session is retired.

func _audit(effect: Dictionary) -> Dictionary:
 var audit: Dictionary=super._audit(effect)
 for particle in audit.particles:_surface_particle_unknowns(particle,audit.unsupported)
 return audit

func _surface_particle_unknowns(particle: Dictionary,unknowns: Array):
 for field in particle.get("unsupported",[]):
  var message: String="particle:"+str(particle.get("source_key",""))+":"+str(field)
  if not unknowns.has(message):unknowns.append(message)
 for child in particle.get("subemitter_audits",[]):_surface_particle_unknowns(child,unknowns)
