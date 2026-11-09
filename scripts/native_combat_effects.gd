extends Node
## Source SpellState animations and decoded PlayMaker schedules.
const SourceDictionary=preload("res://scripts/native_source_manifest.gd")
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Curves=preload("res://scripts/native_summon_curves.gd")
const PROJECTION_SCALE=0.78*0.9
var game: Node
var assets
var routes: Dictionary={}
var stages: Dictionary={}
var cards: Dictionary={}
var effects: Array=[]
var history: Array=[]
var serial:=0
var clock_seconds:=0.0
var particle_script
var visual_rng:=RandomNumberGenerator.new()
var camera_offset:=Vector2.ZERO
var active_camera_shake: Dictionary={} # Retained API only; game owns the sole main-camera manager.
var shake_update_id:=0
var shake_update_delta:=0.0
var minion_shake=preload("res://scripts/native_combat_minion_shake.gd").new()

var profile_rows:Array=[]

func setup(owner_game: Node,source_assets):
	game=owner_game;assets=source_assets;visual_rng.seed=320947;minion_shake.setup(game)
	var path:="res://references/combat_v32/runtime_routes.json"
	if FileAccess.file_exists(path):routes=SourceDictionary.load_source_dictionary(path).get("routes",{})
	for card in SourceDictionary.load_source_dictionary("res://references/combat_v32/card_visual_matrix.json").cards:cards[card.card_id]=card
	stages=SourceDictionary.load_source_dictionary("res://assets/original_combat_v32/data/spell_stage_schedule.json")
	var ps_path:="res://scripts/native_combat_particles.gd" if ResourceLoader.exists("res://scripts/native_combat_particles.gd") else "res://scripts/native_summon_particles.gd"
	particle_script=load(ps_path)

func supports_spell(key: String) -> bool:
	return cards.has(key)

func _event_for(route_id: String,preferred: String) -> String:
	var events: Dictionary=routes.get(route_id,{}).get("event_schedules",{})
	if events.has(preferred):return preferred
	for event in ["Action","Birth","Death"]:
		if events.has(event):return event
	return preferred

func _area_route(key: String,side: int) -> String:
	var preferred: String=key+("/friendly_area" if side==0 else "/opponent_area")
	if routes.has(preferred):return preferred
	for route in [key+"/friendly_area",key+"/opponent_area"]:
		if routes.has(route):return route
	return ""

func _range(spec: Dictionary,name: String) -> float:
	return visual_rng.randf_range(float(spec.get(name+"Min",0.0)),float(spec.get(name+"Max",spec.get(name+"Min",0.0))))

func spell_route(key: String,target: Dictionary,side: int) -> Dictionary:
	var spec: Dictionary=stages.get(key,{}).get("stages",{})
	var missile: Dictionary=spec.get("m_MissileInfo",{})
	var flight: float=_range(missile,"m_PathDuration") if routes.has(key+"/missile") else 0.0
	var impact: float=flight+(_range(spec.get("m_ImpactInfo",{}),"m_SpawnDelaySec") if routes.has(key+"/impact") else 0.0)
	var delay: float=_range(spec.get("m_ImpactInfo",{}),"m_GameDelaySec") if routes.has(key+"/impact") else 0.0
	var area:=_area_route(key,side)
	var event:=_event_for(area,"Action")
	var hit: float=impact+delay
	var finish: float=maxf(hit,impact+_callback(key+"/impact","Death",0.0))
	if key=="CS2_027":hit=_callback(key+"/root","Action",0.25);finish=hit
	elif area!="" and not routes.has(key+"/impact"):
		hit=_callback(area,event,0.0);finish=hit
	return {"key":key,"side":side,"flight":flight,"hit_time":hit,"impact_time":impact,"finished_time":finish,"area_route":area,"area_event":event,"ease":int(missile.get("m_PathEaseType",21)),"target_position":[float(target.get("pos",Vector2(800,450)).x),float(target.get("pos",Vector2(800,450)).y)],"rules_dispatch":"Single historical 5834 atomic resolution at source presentation gate, not modern metadata slicing"}

func _callback(route_id: String,event: String,fallback: float) -> float:
	var maximum:=fallback
	for callback in routes.get(route_id,{}).get("event_schedules",{}).get(event,{}).get("callbacks",[]):
		if str(callback.event)=="OnSpellFinished" and callback.get("at")!=null:maximum=maxf(maximum,float(callback.at))
	return maximum

func _location(entry: Dictionary,location: int) -> Vector2:
	var side: int=entry.side
	var target_side: int=int(entry.target.get("side",entry.target.get("unit",{}).get("side",1-side)))
	match location:
		1:return entry.source
		2:return (game.POWER_POS if side==0 else Vector2(948,196)) if entry.key in ["CS2_034","CS2_056"] else (game.PLAYER_HERO if side==0 else game.ENEMY_HERO)
		3:return game.PLAYER_HERO if side==0 else game.ENEMY_HERO
		4:return game.POWER_POS if side==0 else Vector2(948,196)
		5:return Vector2(800,game.FRIEND_Y if side==0 else game.ENEMY_Y)
		6,7:return entry.target.get("pos",Vector2(800,450))
		8:return game.PLAYER_HERO if target_side==0 else game.ENEMY_HERO
		9:return game.POWER_POS if target_side==0 else Vector2(948,196)
		10:return Vector2(800,game.FRIEND_Y if target_side==0 else game.ENEMY_Y)
		14:return Vector2(800,game.FRIEND_Y)
		17:return Vector2(800,game.ENEMY_Y)
	# NONE retains the prefab transform, under the fixed board's world registration.
	return Vector2(800,450)

func _source_location(entry:Dictionary,location:int,root_key:String="")->Dictionary:
	var projection=SourceProjection.from_game(game)
	if projection==null:return {}
	var side:int=int(entry.get("side",0))
	var target:Dictionary=entry.get("target",{})
	var target_side:int=int(target.get("side",target.get("unit",{}).get("side",1-side)))
	match location:
		0:
			# SpellUtils.GetSpellLocationObject0x06014ab8 returns null for NONE;
			# SetPositionFromLocation0x06014ab9 returns without writing position.
			# Retain the verified parentless prefab's serialized world origin.
			if root_key!="" and assets!=null:
				var transform:Dictionary=assets.component(root_key,"Transform").get("data",{})
				if transform.has("m_LocalPosition") and int(transform.get("m_Father",{}).get("m_PathID",-1))==0:
					return {"position":Curves.vec(transform.m_LocalPosition),"source":"parentless source prefab "+root_key+"; SpellUtils0x06014ab8/ab9 NONE preserves placement"}
		1:return projection.resolve_anchor(entry)
		2:return projection.resolve_anchor(("power:" if entry.get("key","") in ["CS2_034","CS2_056"] else "hero:")+str(side))
		3:return projection.resolve_anchor("hero:"+str(side))
		4:return projection.resolve_anchor("power:"+str(side))
		5:return projection.resolve_anchor("play:"+str(side))
		6,7:return projection.resolve_anchor(target)
		8:return projection.resolve_anchor("hero:"+str(target_side))
		9:return projection.resolve_anchor("power:"+str(target_side))
		10:return projection.resolve_anchor("play:"+str(target_side))
		14:return projection.resolve_anchor("play:0")
		17:return projection.resolve_anchor("play:1")
	projection.block("Phone effect location %d requires its recovered source-world placement"%location)
	return {}

func _source_stage_location(entry:Dictionary,stage:String)->Dictionary:
	var root:Dictionary=cards.get(entry.get("key",""),{}).get("root_settings",{})
	var mapping={"start":"m_StartInfo","missile":"m_MissileInfo","impact":"m_ImpactInfo","friendly_area":"m_FriendlyAreaEffectInfo","opponent_area":"m_OpponentAreaEffectInfo"}
	var info:Dictionary=stages.get(entry.get("key",""),{}).get("stages",{}).get(mapping.get(stage,""),{})
	var location:int=int(root.get("m_Location",2)) if bool(info.get("m_UseSuperSpellLocation",true)) else int(info.get("m_Location",0))
	return _source_location(entry,location,str(routes.get(str(entry.get("key",""))+"/"+stage,{}).get("root_key","")))

func _stage_location(entry: Dictionary,stage: String) -> Vector2:
	var root: Dictionary=cards.get(entry.key,{}).get("root_settings",{})
	var mapping: Dictionary={"start":"m_StartInfo","missile":"m_MissileInfo","impact":"m_ImpactInfo","friendly_area":"m_FriendlyAreaEffectInfo","opponent_area":"m_OpponentAreaEffectInfo"}
	var info: Dictionary=stages.get(entry.key,{}).get("stages",{}).get(mapping.get(stage,""),{})
	var location: int=int(root.get("m_Location",2)) if bool(info.get("m_UseSuperSpellLocation",true)) else int(info.get("m_Location",0))
	return _location(entry,location)

func _launch_missile(entry: Dictionary,target: Dictionary,flight: float) -> Dictionary:
	var missile: Dictionary=stages[entry.key].stages.m_MissileInfo
	var source:=_stage_location(entry,"missile")
	var effect=_spawn_route(entry.key+"/missile",source,"Birth",entry.serial,entry)
	if not effect.is_empty():
		effect.motion={"start":source,"end":target.get("pos",Vector2(800,450)),"flight":flight,"ease":entry.route.ease,"height":float(missile.m_TargetHeightOffset),"joint":str(missile.m_TargetJoint),"orient":bool(missile.m_OrientToPath),"begin":0.0,"center":float(missile.m_CenterOffsetPercent)*0.01,"center_height":_range(missile,"m_CenterPointHeight"),"right":_range(missile,"m_Right"),"left":_range(missile,"m_Left"),"distance_scale":float(missile.m_DistanceScaleFactor),"side_choice":visual_rng.randf()<0.5}
		var projection=SourceProjection.from_game(game)
		if projection!=null:
			var start=_source_stage_location(entry,"missile");var end=projection.resolve_anchor(target)
			if not start.is_empty() and not end.is_empty():
				effect.motion.source_start=start.position;effect.motion.source_end=end.position
		_sample(effect)
	return effect

func start_ready_time(key: String) -> float:
	var schedule: Dictionary=routes.get(key+"/start",{}).get("event_schedules",{}).get("Birth",{})
	for callback in schedule.get("callbacks",[]):
		if str(callback.get("event",""))=="OnStateFinished" and str(callback.get("previous_state",""))=="Birth":return float(callback.get("at",0.0))
	return 0.0

func prepare_spell_start(entry: Dictionary) -> Dictionary:
	if not routes.has(str(entry.key)+"/start"):return {}
	return _spawn_route(str(entry.key)+"/start",_stage_location(entry,"start"),"Birth",entry.serial,entry)

func cancel_spell_start(effect: Dictionary,instant: bool=false):
	if effect.is_empty() or not effects.has(effect):return
	if instant:_dispose(effect)
	else:_start_event(effect,"Cancel",float(effect.age))

func spell_launch(entry: Dictionary):
	var key: String=entry.key
	if routes.has(key+"/missile"):entry.missile_effect=_launch_missile(entry,entry.target,float(entry.route.flight))
	if routes.has(key+"/start"):
		var start: Dictionary=entry.get("start_effect",{})
		if start.is_empty() or not effects.has(start):start=_spawn_route(key+"/start",_stage_location(entry,"start"),_event_for(key+"/start","Action"),entry.serial,entry)
		else:
			start.owner_serial=entry.serial
			var current_age: float=start.age
			var moment: float=maxf(current_age,float(entry.get("start_action_time",current_age)))
			start.age=moment;_run_schedules(start)
			_start_event(start,_event_for(key+"/start","Action"),moment)
			start.age=current_age
		if not start.is_empty():
			var start_time: float=maxf(float(start.age),float(entry.get("start_action_time",start.age)))
			var finish:=_callback(key+"/start","Action",0.0)
			if bool(entry.get("defer_start_death",false)):pass
			elif finish<=0.0:_start_event(start,"Death",start_time)
			else:start.pending_death=start_time+finish
			entry.start_effect=start
	if str(entry.route.area_route)!="":
		var area: String=entry.route.area_route
		_spawn_route(area,_stage_location(entry,area.get_slice("/",1)),entry.route.area_event,entry.serial,entry)
	if key=="CS2_027":
		var root=_spawn_route(key+"/root",_location(entry,2),"Action",entry.serial,entry)
		if not root.is_empty():root.expires=1.0

func spell_impact(entry: Dictionary):
	if entry.has("missile_effect") and effects.has(entry.missile_effect):_start_event(entry.missile_effect,"Death",float(entry.missile_effect.age))
	if routes.has(str(entry.key)+"/impact"):
		if entry.key=="CS2_032":
			for unit in (game.enemies if int(entry.side)==0 else game.allies):
				var copy: Dictionary=entry.duplicate();copy.target={"type":"unit","unit":unit,"pos":unit.pos}
				_spawn_route(str(entry.key)+"/impact",_stage_location(copy,"impact"),"Death",entry.serial,entry)
		else:_spawn_route(str(entry.key)+"/impact",_stage_location(entry,"impact"),"Death",entry.serial,entry)

func attack_cancel(unit: Dictionary):
	var key: String=assets.manifest.root_labels["attack_friendly" if int(unit.side)==0 else "attack_opponent"]
	var effect=_spawn(key,unit.pos,"",-1)
	if effect.is_empty():return
	effect.follow_unit=unit;_external_state(effect,4,0.0)

func attack_launch(entry: Dictionary):
	var key: String=assets.manifest.root_labels["attack_friendly" if int(entry.unit.side)==0 else "attack_opponent"]
	var effect=_spawn(key,entry.unit.pos,"",entry.serial)
	if effect.is_empty():return
	effect.follow_unit=entry.unit;effect.return_at=float(entry.contact_time)-float(entry.launch_time)
	_external_state(effect,3,0.0)
	entry.attack_effect=effect

func attack_impact(entry: Dictionary):
	if entry.has("attack_effect") and effects.has(entry.attack_effect):_external_state(entry.attack_effect,5,float(entry.attack_effect.age))
	var damage:=int(entry.unit.atk)
	var tier: String="small" if damage<=2 else ("medium" if damage<=5 else ("large" if damage<=7 else "mega"))
	var effect=_spawn(assets.manifest.root_labels["attack_impact_"+tier],entry.target.pos,"",entry.serial)
	if effect.is_empty():return
	var projection=SourceProjection.from_game(game)
	if projection!=null:effect.source_anchor=projection.resolve_anchor(entry.target)
	effect.impact_tier=tier;_external_state(effect,5,0.0)
	if entry.target.get("type","")=="unit":
		effect.hit_unit=entry.target.unit
		effect.hit_unit_key=entry.target.unit.key
		effect.actor_clip="AllyAttack_IMPACT_Hit"

func _spawn_route(route_id: String,anchor: Vector2,event: String,owner_serial: int,context: Dictionary={}) -> Dictionary:
	if not routes.has(route_id):return {}
	var effect=_spawn(str(routes[route_id].root_key),anchor,route_id,owner_serial)
	if not effect.is_empty():
		effect.context={"key":context.get("key",""),"side":context.get("side",0),"source":context.get("source",anchor),"target":context.get("target",{}).duplicate()}
		var projection=SourceProjection.from_game(game)
		if projection!=null:
			if context.has("source_world_position"):effect.context.source_world_position=context.source_world_position
			effect.source_anchor=_source_stage_location(effect.context,route_id.get_slice("/",1)) if cards.has(effect.context.key) else projection.resolve_anchor(effect.context.target)
			effect.source_actor_anchor=not cards.has(effect.context.key) and effect.context.target.get("type","")=="hero"
			_project(effect)
		_start_event(effect,"__start__",0.0)
		_start_event(effect,"None",0.0)
		_start_event(effect,event,0.0)
	return effect

func _spawn(root_key: String,anchor: Vector2,route_id: String,owner_serial: int) -> Dictionary:
	if not assets.objects.has(root_key):return {}
	var profile_started:int=Time.get_ticks_usec() if game!=null and bool(game.get("profile_frame_stages")) else -1
	serial+=1
	var effect: Dictionary={"serial":serial,"owner_serial":owner_serial,"root_key":root_key,"route_id":route_id,"anchor":anchor,"age":0.0,"container":null,"projection":null,"state":{},"schedules":[],"clips":{},"particles":{},"variables":{},"animations":[],"continuous":[],"events":[],"unsupported":[],"observed_materials":{},"expires":0.0,"source_event":"","shakes":[],"restores":[]}
	for entries in routes.get(route_id,{}).get("variables",{}).values():
		if entries is Array:
			for variable in entries:
				if variable is Dictionary and variable.has("name"):effect.variables[variable.name]=variable.get("value")
	if not game.headless:
		var container:=Node3D.new();container.name="OriginalCombat_%d"%serial;game.spatial_scene.add_child(container);effect.container=container
		var source_projection=SourceProjection.from_game(game)
		if source_projection!=null:container.visible=false
		else:container.position=game.spatial_scene.screen_to_world(anchor+game.shake_offset)
		var projection:=Node3D.new();container.add_child(projection);effect.projection=projection
		projection.basis=Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*PROJECTION_SCALE
		if source_projection!=null:projection.basis=SourceProjection.REFLECTION
		effect.state=assets.instantiate(root_key,projection);effect.state.root.visible=true
		effect.state.particle_players=effect.particles
		_setup_source_lights(effect)
		effect.components=preload("res://scripts/native_combat_components.gd").new();effect.components.setup(effect.state,assets,effect.serial*32003)
	if not game.headless:
		effect.trails=preload("res://scripts/native_combat_trails.gd").new();effect.trails.setup(effect.state,assets,effect.projection)
	effects.append(effect)
	for particle_key in effect.state.get("particles",{}):
		var spec: Dictionary=effect.state.particles[particle_key]
		if bool(spec.system.data.get("playOnAwake",false)) and spec.node.is_visible_in_tree():_particles(effect,particle_key,0.0,false,true)
	if not game.headless and ResourceLoader.exists("res://scripts/native_combat_rendertexture.gd"):
		var rt=load("res://scripts/native_combat_rendertexture.gd").new();add_child(rt);rt.setup(effect.state,assets,effect.projection,owner_serial);effect.rendertexture=rt
	if profile_started>=0:_profile_effect_row(effect,"spawn",profile_started,{})
	return effect

func _setup_source_lights(effect: Dictionary):
	effect.state.lights={}
	for key in effect.state.nodes:
		var record: Dictionary=assets.component(key,"Light")
		if record.is_empty():continue
		var data: Dictionary=record.data
		var light: Light3D
		match int(data.get("m_Type",2)):
			0:
				light=SpotLight3D.new();light.spot_range=float(data.get("m_Range",10.0));light.spot_angle=float(data.get("m_SpotAngle",30.0))*0.5
			1:light=DirectionalLight3D.new()
			_:light=OmniLight3D.new();light.omni_range=float(data.get("m_Range",10.0))
		effect.state.nodes[key].add_child(light);light.rotation.y=PI
		light.light_color=Curves.color(data.get("m_Color",{"r":1,"g":1,"b":1,"a":1}));light.light_energy=float(data.get("m_Intensity",1.0));light.visible=bool(data.get("m_Enabled",true));light.shadow_enabled=false
		effect.state.lights[key]=light
	if not effect.state.lights.is_empty():effect.unsupported.append("scene-light:source local light properties applied; Godot attenuation and fixed board lighting response are compatibility")

func _start_event(effect: Dictionary,event: String,start: float):
	var route: Dictionary=routes.get(effect.route_id,{})
	var schedule: Dictionary=route.get("event_schedules",{}).get(event,{})
	effect.source_event=event
	if schedule.is_empty():return
	effect.expires=0.0
	effect.schedules.clear()
	effect.schedules.append({"data":schedule.get("state_enter_schedule",[]),"cursor":0,"start":start})
	var realized: Array=schedule.get("state_enter_schedule",[]).duplicate(true)
	var sample:=visual_rng.randf()
	for step in realized:
		if step.get("at")==null:step.at=lerpf(float(step.get("at_min",0.0)),float(step.get("at_max",0.0)),sample)
	effect.schedules[-1].data=realized
	var duration: float=float(schedule.get("nominal_duration",0.0)) if schedule.get("nominal_duration")!=null else lerpf(float(schedule.duration_range[0]),float(schedule.duration_range[1]),sample)
	if event in ["Death","Cancel"] or (not realized.is_empty() and str(realized[-1].state_name).to_lower().begins_with("none")):effect.expires=maxf(effect.expires,start+maxf(duration,0.000001))
	_run_schedules(effect)

func _external_state(effect: Dictionary,type: int,start: float):
	var members:=_descendants(effect.root_key)
	for object in assets.objects.values():
		if object.type!="MonoBehaviour" or not object.data.has("m_StateType") or int(object.data.m_StateType)!=type:continue
		if not members.has(str(object.refs.get(".m_GameObject",""))):continue
		var specs: Array=object.data.get("m_ExternalAnimatedObjects",[])
		for i in range(specs.size()):
			var spec: Dictionary=specs[i]
			if not bool(spec.get("m_Enabled",true)) or int(spec.m_Target)!=0:continue
			var clip_key: String=object.refs.get(".m_ExternalAnimatedObjects[%d].m_AnimClip"%i,"")
			if not assets.objects.has(clip_key):continue
			var target_key: String=object.refs.get(".m_ExternalAnimatedObjects[%d].m_GameObject"%i,effect.root_key)
			_play_clip(effect,target_key,clip_key,start,float(spec.get("m_AnimSpeed",1.0)))
			var length: float=assets.clip_length(clip_key)
			effect.expires=maxf(effect.expires,start+length)
		# Mono camera shaker's recovered curve is triggered by StartShake event.
		effect.state_component=object.key
		effect.events.append({"event":"external_state","type":type,"time":start,"source_key":object.key})

func _descendants(key: String) -> Array:
	var members: Array=[key]
	var transform: Dictionary=assets.component(key,"Transform")
	for field in transform.get("refs",{}):
		if str(field).begins_with(".m_Children["):
			var child: Dictionary=assets.objects.get(transform.refs[field],{})
			members.append_array(_descendants(str(child.get("refs",{}).get(".m_GameObject",""))))
	return members

func _play_clip(effect: Dictionary,key: String,name: String,start: float,speed: float=1.0,blend: float=0.0):
	var path: String=""
	var state: Dictionary=effect.state
	if not state.is_empty() and state.nodes.has(key):
		path=str(state.root.get_path_to(state.nodes[key]));if path==".":path=""
	var previous: Dictionary=effect.clips.get(key,{}).duplicate()
	effect.clips[key]={"clip":name,"path":path,"key":key,"start":start,"speed":speed,"event_cursor":0,"blend":blend,"previous":previous,"initial_pose":assets.capture_float_pose(state,name,path) if blend>0.0 else {}}

func _value(effect: Dictionary,value,default=null):
	if not value is Dictionary:return value if value!=null else default
	if bool(value.get("useVariable",false)) and str(value.get("name",""))!="" and effect.variables.has(str(value.get("name",""))):return effect.variables[str(value.name)]
	return value.get("value",default)

func _target_key(effect: Dictionary,action: Dictionary) -> String:
	if action.has("target_object_key"):return str(action.target_object_key)
	var params: Dictionary=action.params
	var target=params.get("gameObject",params.get("m_GameObject",{}))
	if int(target.get("ownerOption",0))==0:return effect.root_key
	var id: String=str(target.get("gameObject",{}).get("value",{}).get("m_PathID","0"))
	for key in assets.objects:
		if str(key).get_slice(":",1)==id:return key
	return ""

func _run_schedules(effect: Dictionary):
	for schedule in effect.schedules:
		while int(schedule.cursor)<schedule.data.size():
			var step: Dictionary=schedule.data[int(schedule.cursor)]
			var moment: float=float(schedule.start)+float(step.get("at",step.get("at_seconds_nominal",0.0)))
			if float(effect.age)+0.0000001<moment:break
			_exit_state(effect,moment)
			effect.events.append({"event":"state_enter","state":step.state_name,"time":moment})
			for action in step.actions:_action(effect,action,moment)
			schedule.cursor+=1

func _exit_state(effect: Dictionary,moment: float):
	_sample_animations(effect,moment)
	for action in effect.continuous:_apply_continuous(effect,action)
	for restore in effect.restores:
		if is_instance_valid(restore.node):restore.node.set(restore.property,restore.value)
	effect.restores.clear();effect.continuous.clear()
	# Exiting a state cancels unissued actions only. A dispatched manager shake
	# has no OnExit stop and must keep running through the next FSM state.
	effect.shakes.clear()
	# PlayMaker curves/eases stop with their state. iTween owns a separate driver
	# and continues unless the original stopOnExit option was enabled.
	effect.animations=effect.animations.filter(func(a):return a.kind in ["scale","fade"] and not bool(a.get("stop_on_exit",false)))

func _action(effect: Dictionary,action: Dictionary,moment: float):
	var params: Dictionary=action.params;var key:=_target_key(effect,action)
	var node: Node3D=effect.state.get("nodes",{}).get(key)
	var name: String=action.class_name
	match name:
		"SetVisibility":
			if effect.state.get("renderers",{}).has(key):
				var renderer: Node3D=effect.state.renderers[key]
				if bool(_value(effect,params.get("resetOnExit"),false)):effect.restores.append({"node":renderer,"property":"visible","value":renderer.visible})
				renderer.visible=not renderer.visible if bool(_value(effect,params.get("toggle"),false)) else bool(_value(effect,params.get("visible"),true))
		"ActivateGameObject":
			if is_instance_valid(node):
				if bool(_value(effect,params.get("resetOnExit"),false)):effect.restores.append({"node":node,"property":"visible","value":node.visible})
				var prior_visible: bool=node.visible
				node.visible=bool(_value(effect,params.get("activate"),true))
				if node.visible and not prior_visible:
					for child_key in _descendants(key):
						var spec: Dictionary=effect.state.get("particles",{}).get(child_key,{})
						if not spec.is_empty() and bool(spec.system.data.get("playOnAwake",false)) and spec.node.is_visible_in_tree():_particles(effect,child_key,moment,false,true)
		"SetScale":
			if is_instance_valid(node):
				var vector=_value(effect,params.get("vector"),{})
				node.scale=Curves.vec(vector) if vector is Dictionary and str(params.get("vector",{}).get("name",""))!="" else Vector3(float(_value(effect,params.get("x"),node.scale.x)),float(_value(effect,params.get("y"),node.scale.y)),float(_value(effect,params.get("z"),node.scale.z)))
		"iTweenScaleTo":
			if is_instance_valid(node):effect.animations.append({"kind":"scale","node":node,"origin":node.scale,"destination":Curves.vec(_value(effect,params.get("vectorScale"),{})),"start":moment+float(_value(effect,params.get("delay"),0.0)),"duration":float(_value(effect,params.get("time"),0.0)),"ease":int(params.get("easeType",21)),"stop_on_exit":bool(_value(effect,params.get("stopOnExit"),false))})
		"AnimateFloat":
			effect.animations.append({"kind":"float","name":str(params.floatVariable.name),"curve":params.animCurve.curve,"start":moment})
		"AnimateFloatV2":
			effect.animations.append({"kind":"float_v2","name":str(params.floatVariable.name),"curve":params.animCurve.curve,"params":params,"initial":float(_value(effect,params.floatVariable,0.0)),"start":moment+float(_value(effect,params.get("delay"),0.0))})
		"PlayAnimation","AnimationPlaythroughAction","SpellStateAnimation":
			var clip: String=str(action.get("clip_key",""))
			if clip=="":clip=str(_value(effect,params.get("animName",params.get("m_AnimName")),""))
			_play_clip(effect,key,clip,moment,float(params.get("m_AnimSpeed",1.0)),float(_value(effect,params.get("blendTime",params.get("m_CrossFadeSec")),0.0)))
		"ParticlePlayAction":_particles(effect,key,moment,bool(_value(effect,params.get("m_IncludeChildren"),false)),true)
		"ParticleEmitAction":
			if not game.headless:
				var spec: Dictionary=effect.state.get("particles",{}).get(key,{}).duplicate()
				if not spec.is_empty():
					if not effect.particles.has(key):
						spec.autoplay=false
						var particle=particle_script.new();_setup_particle(particle,spec,effect);effect.particles[key]={"node":particle,"start":moment};effect.state.materials[key]=[particle.material]
						if effect.has("components"):effect.components.on_particle_created(key,effect.particles[key])
					var player: Dictionary=effect.particles[key]
					if player.node.has_method("emit_count"):player.node.emit_count(int(_value(effect,params.get("m_Count"),0)),moment-float(player.start))
		"ParticleStopAction":_particles(effect,key,moment,bool(_value(effect,params.get("m_IncludeChildren"),false)),false)
		"SetVisibilityRecursiveAction":
			var keys: Array=_descendants(key) if bool(params.get("includeChildren",true)) else [key]
			for child_key in keys:
				if effect.state.get("renderers",{}).has(child_key):effect.state.renderers[child_key].visible=bool(_value(effect,params.get("visible"),true))
				if effect.state.get("trail_renderers",{}).has(child_key):effect.state.trail_renderers[child_key].visible=bool(_value(effect,params.get("visible"),true))
		"SetRotation":
			if is_instance_valid(node):
				var radians:=Vector3(float(_value(effect,params.get("xAngle"),0.0)),float(_value(effect,params.get("yAngle"),0.0)),float(_value(effect,params.get("zAngle"),0.0)))*PI/180.0
				var q:=Basis.from_euler(radians).get_rotation_quaternion();node.quaternion=q;effect.state.source_rotations[key]=q
		"SetAnimationSpeed":
			if effect.clips.has(key):effect.clips[key].speed=float(_value(effect,params.get("speed"),1.0))
		"EaseColor","EaseFloat":
			effect.animations.append({"kind":"ease_color" if name=="EaseColor" else "ease_float","name":str(params.get("colorVariable",params.get("floatVariable",{})).get("name","")),"origin":_value(effect,params.get("fromValue")),"destination":_value(effect,params.get("toValue")),"start":moment+float(_value(effect,params.get("delay"),0.0)),"duration":float(_value(effect,params.get("time"),0.0)),"ease":int(params.get("easeType",21)),"stop_on_exit":bool(_value(effect,params.get("stopOnExit"),false))})
		"AnimateColor":effect.animations.append({"kind":"color","name":str(params.colorVariable.name),"params":params,"initial":_value(effect,params.colorVariable,{}).duplicate(),"start":moment+float(_value(effect,params.get("delay"),0.0))})
		"SetMaterialColor","SetMaterialFloat","SetColorRGBA":
			var continuous: Dictionary={"kind":name,"key":key,"params":params,"start":moment}
			if bool(params.get("everyFrame",false)):effect.continuous.append(continuous)
			_apply_continuous(effect,continuous)
		"iTweenFadeToAction":
			var keys: Array=_descendants(key) if bool(_value(effect,params.get("m_IncludeChildren"),false)) else [key]
			for child_key in keys:
				for mat in effect.state.get("materials",{}).get(child_key,[]):effect.animations.append({"kind":"fade","material":mat,"origin":_alpha(mat),"destination":float(_value(effect,params.get("m_Alpha"),0.0)),"start":moment+float(_value(effect,params.get("delay"),0.0)),"duration":float(_value(effect,params.get("time"),0.0)),"ease":int(params.get("easeType",21)),"stop_on_exit":bool(_value(effect,params.get("stopOnExit"),false))})
		"SetAlphaRecursiveAction":
			var record: Dictionary={"kind":"alpha","key":key,"params":params,"start":moment}
			_apply_continuous(effect,record)
			if bool(params.get("m_EveryFrame",false)):effect.continuous.append(record)
		"ShakeMinionsAction":
			var options: Dictionary=params.duplicate();options.radius_value=float(_value(effect,params.get("radius"),0.0));options.custom=float(_value(effect,params.get("customShakeIntensity"),0.1))
			var shake_context:Dictionary=effect.get("context",{}).duplicate()
			if SourceProjection.from_game(game)!=null:
				var origin:Dictionary=SourceProjection.from_game(game).resolve_anchor(effect.follow_unit) if effect.has("follow_unit") else effect.get("source_anchor",{})
				if not origin.is_empty():shake_context.source_world_position=origin.position
			minion_shake.trigger(options,shake_context,effect.anchor)
		"MainCameraShakerAction":
			var value=_value(effect,params.get("m_Amount"),{})
			if value is Dictionary and value.has("x"):
				effect.shakes.append(game.camera_shake.new_action(Curves.vec(value),float(_value(effect,params.get("m_Time"),0.0)),float(_value(effect,params.get("m_Delay"),0.0)),shake_update_id,str(effect.route_id)+":MainCameraShakerAction"))
		"SetProperty":
			var property: Dictionary=params.get("targetProperty",{})
			var target_id: String=str(property.get("TargetObject",{}).get("value",{}).get("m_PathID","0"))
			if target_id=="0":effect.events.append({"event":"source_null_property_target","time":moment})
			else:
				var record: Dictionary={"kind":"property","target_id":target_id,"params":property,"start":moment}
				if bool(params.get("everyFrame",false)):effect.continuous.append(record)
				_apply_continuous(effect,record)
		"SpellStateAction","SpellFinishAction","Wait","AudioPlayAction","AudioPlaythroughAction","AudioPlayClipAction","AudioStopAction","AudioVolumeFadeAction","AudioSetVolumeAction","AudioPlayRandomClipAction","SpellCardIdAudioPlayAction","SpellCardIdAudioPlayClipAction","RandomWaitAction":pass
		"SetLightIntensity":
			var record: Dictionary={"kind":"light","key":key,"params":params,"start":moment}
			_apply_continuous(effect,record)
			if bool(params.get("everyFrame",false)):effect.continuous.append(record)
		"EnableBehaviour":
			if effect.has("components"):effect.components.set_enabled(key,str(_value(effect,params.get("behaviour"),"")),bool(_value(effect,params.get("enable"),true)),moment)
			if str(_value(effect,params.get("behaviour"),""))=="Light" and effect.state.get("lights",{}).has(key):effect.state.lights[key].visible=bool(_value(effect,params.get("enable"),true))
		"GetBoardAmbientColorAction":
			var color:=Color("e3e4e3") # Existing fixed-board WorldEnvironment input.
			effect.variables[str(params.m_Color.name)]={"r":color.r,"g":color.g,"b":color.b,"a":color.a}
			if not effect.unsupported.has("scene-global:original BoardManager ambient unavailable; fixed-board environment color bound"):effect.unsupported.append("scene-global:original BoardManager ambient unavailable; fixed-board environment color bound")
		"FindGameObject":
			# Do not substitute a differently named light for the original scene object.
			effect.variables[str(params.store.name)]=null
			if not effect.unsupported.has("scene-global:"+str(_value(effect,params.objectName,""))):effect.unsupported.append("scene-global:"+str(_value(effect,params.objectName,"")))
		_:
			if not effect.unsupported.has(name):effect.unsupported.append(name)

# Only creation inside _sample guarantees a normal seek before returning to
# rendering. Spawn/autoplay, independent setup and unknown adapters stay eager.
func _setup_particle(node,spec:Dictionary,effect:Dictionary):
	if bool(effect.get("_sampling_particle_setup",false)) and get_script().resource_path=="res://scripts/native_death_effects.gd" and node.get_script().resource_path=="res://scripts/native_death_particles.gd":
		node.defer_initial_geometry=true
	node.setup(spec,assets,effect.projection,effect.serial*391+effect.particles.size())

func _particles(effect: Dictionary,key: String,moment: float,include_children: bool,play: bool):
	effect.events.append({"event":"particle_play" if play else "particle_stop","source_key":key,"time":moment})
	if game.headless:return
	var targets: Array=[key]
	if include_children:targets=_descendants(key)
	for target_key in targets:
		if not effect.state.particles.has(target_key):continue
		if play:
			if effect.particles.has(target_key):continue
			var node=particle_script.new();_setup_particle(node,effect.state.particles[target_key],effect)
			effect.particles[target_key]={"node":node,"start":moment}
			effect.state.materials[target_key]=[node.material]
			if effect.has("components"):effect.components.on_particle_created(target_key,effect.particles[target_key])
		else:
			if effect.particles.has(target_key):effect.particles[target_key].node.stop_emitting(moment-float(effect.particles[target_key].start))

func _animation_event(effect: Dictionary,player: Dictionary,event: Dictionary,moment: float):
	var name: String=event.functionName
	effect.events.append({"event":name,"time":moment,"clip":player.clip,"source_key":player.key})
	if name.begins_with("PlayNewParticles"):
		var field: String={"PlayNewParticles3":".m_Target","PlayNewParticles3andChilds":".m_Target2","PlayNewParticles3andChilds2":".m_Target3","PlayNewParticles3andChilds3":".m_Target4"}.get(name,"")
		for object in assets.objects.values():
			if object.type=="MonoBehaviour" and str(object.refs.get(".m_GameObject",""))==str(player.key) and object.refs.has(field):
				_particles(effect,str(object.refs[field]),moment,true,true)
	elif name=="StartShake":
		for object in assets.objects.values():
			if object.type=="MonoBehaviour" and object.data.has("m_IntensityCurve") and str(object.refs.get(".m_GameObject",""))==str(player.key):
				game.camera_shake.request_curve(Curves.vec(object.data.m_Amount),object.data.m_IntensityCurve,float(object.data.get("m_HoldAtSec",0.0)) if bool(object.data.get("m_Hold",false)) else null,bool(object.data.get("m_IsOverride",false)),str(effect.route_id)+":CameraShaker.StartShake")

func _ease(t: float,type: int) -> float:
	match type:
		0:return t*t
		1:return t*(2.0-t)
		4:return 1.0-pow(1.0-t,3.0)
		16:return 1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*t)
	return t

func _spline3(start: Vector3,midpoint: Vector3,end: Vector3,t: float) -> Vector3:
	# Original iTween path control-point extrapolation, evaluated as Catmull-Rom.
	var u:=t*2.0
	var a: Vector3;var b: Vector3;var c: Vector3;var d: Vector3
	if u<1.0:a=start+(start-midpoint);b=start;c=midpoint;d=end
	else:u-=1.0;a=start;b=midpoint;c=end;d=end+(end-midpoint)
	return 0.5*((2.0*b)+(-a+c)*u+(2.0*a-5.0*b+4.0*c-d)*u*u+(-a+3.0*b-3.0*c+d)*u*u*u)

func _source_look_at(node: Node3D,target: Vector3,world_up: Vector3):
	# Godot look_at rejects valid extremely short source paths. Work in the
	# original object's parent frame and construct the same +Z LookRotation.
	var parent: Node3D=node.get_parent() as Node3D
	var inverse: Transform3D=parent.global_transform.affine_inverse() if is_instance_valid(parent) else Transform3D.IDENTITY
	var forward: Vector3=(inverse*target)-node.position
	if forward==Vector3.ZERO:return
	forward=forward.normalized()
	var up: Vector3=(inverse.basis*world_up).normalized()
	var right: Vector3=up.cross(forward)
	if right.length_squared()<1.0e-20:
		# Collinear source LookRotation has no unique roll. Retain prior X axis.
		right=node.basis.x-forward*node.basis.x.dot(forward)
		if right.length_squared()<1.0e-20:
			right=Vector3.RIGHT if absf(forward.x)<0.9 else Vector3.BACK
			right-=forward*right.dot(forward)
	right=right.normalized();up=forward.cross(right).normalized()
	var rotation:=Basis(right,up,forward).get_rotation_quaternion()
	node.quaternion=rotation
	return rotation

func _project(effect: Dictionary):
	var source_projection=SourceProjection.from_game(game)
	if source_projection!=null:
		_project_phone(effect,source_projection);return
	if is_instance_valid(effect.container):
		if effect.has("follow_unit"):effect.anchor=effect.follow_unit.pos
		effect.container.position=game.spatial_scene.screen_to_world(effect.anchor+game.shake_offset)
		if effect.has("motion"):
			var motion: Dictionary=effect.motion
			var t:=_ease(clampf((float(effect.age)-float(motion.begin))/maxf(0.000001,float(motion.flight)),0.0,1.0),int(motion.ease))
			var start_world: Vector3=game.spatial_scene.screen_to_world(motion.start+game.shake_offset)
			var end_world: Vector3=game.spatial_scene.screen_to_world(motion.end+game.shake_offset)
			var joint: Node3D
			for path in effect.state.paths:
				if str(path).contains(str(motion.get("joint","TargetJoint"))) and str(motion.get("joint","TargetJoint"))!="":joint=effect.state.paths[path];break
			var midpoint: Vector3=start_world.lerp(end_world,float(motion.get("center",0.5)))
			var up: Vector3=effect.projection.global_basis.y.normalized()
			var distance:=start_world.distance_to(end_world)/PROJECTION_SCALE
			var distance_scale: float=distance/maxf(float(motion.get("distance_scale",8.0)),0.000001)
			var height: float=float(motion.get("center_height",0.0))
			if motion.start==motion.end and height<=0.0:midpoint+=up*2.0*PROJECTION_SCALE
			else:
				midpoint+=up*height*distance_scale*PROJECTION_SCALE
				var sideways: Vector3=(end_world-start_world).cross(up).normalized()
				midpoint+=sideways*(float(motion.get("right",0.0)) if bool(motion.get("side_choice",false)) else -float(motion.get("left",0.0)))*distance_scale*PROJECTION_SCALE
			if is_instance_valid(joint):
				if motion.start!=motion.end:
					var rotation=_source_look_at(effect.state.root,end_world,up)
					if rotation is Quaternion:effect.state.source_rotations[effect.root_key]=rotation
				end_world+=up*float(motion.height)*PROJECTION_SCALE
				joint.global_position=_spline3(start_world,midpoint,end_world,t)
			else:
				effect.state.root.global_position=_spline3(start_world,midpoint,end_world,t)
				if motion.orient and t<0.9999:
					var next:=_spline3(start_world,midpoint,end_world,minf(1.0,t+0.001))
					if effect.state.root.global_position.distance_squared_to(next)>0.0000001:
						var rotation=_source_look_at(effect.state.root,next,up)
						if rotation is Quaternion:effect.state.source_rotations[effect.root_key]=rotation

func _project_phone(effect:Dictionary,projection):
	if not is_instance_valid(effect.container):return
	var anchor:Dictionary=projection.resolve_anchor(effect.follow_unit) if effect.has("follow_unit") else effect.get("source_anchor",{})
	if anchor.is_empty() and not effect.has("source_anchor") and effect.has("context"):
		anchor=projection.resolve_anchor(effect.context.get("target",{}))
	effect.source_projection_valid=not anchor.is_empty()
	if anchor.is_empty():
		effect.container.visible=false
		var reason="Phone effect lacks a verified source anchor"
		if not effect.unsupported.has(reason):effect.unsupported.append(reason)
		return
	effect.container.visible=true
	effect.container.position=SourceProjection.source_to_render(anchor.position)
	if effect.get("source_actor_anchor",false):
		if not anchor.has("rotation") or not anchor.has("scale"):
			effect.source_projection_valid=false;effect.container.visible=false
			projection.block("Hero-attached effect requires complete source Card pose");return
		effect.projection.basis=SourceProjection.REFLECTION*Basis(anchor.rotation)*Basis.from_scale(anchor.scale)
	if not effect.has("motion"):return
	var motion:Dictionary=effect.motion
	if not motion.has("source_start") or not motion.has("source_end"):
		effect.container.visible=false;projection.block("Phone missile requires explicit source start/end");return
	var t:float=_ease(clampf((float(effect.age)-float(motion.begin))/maxf(0.000001,float(motion.flight)),0.0,1.0),int(motion.ease))
	var start:Vector3=motion.source_start;var end:Vector3=motion.source_end
	var midpoint:Vector3=start.lerp(end,float(motion.get("center",0.5)))
	var up:=Vector3.UP
	var distance_scale:float=start.distance_to(end)/maxf(float(motion.get("distance_scale",8.0)),0.000001)
	var height:float=float(motion.get("center_height",0.0))
	if start==end and height<=0.0:midpoint+=up*2.0
	else:
		midpoint+=up*height*distance_scale
		var sideways:Vector3=(end-start).cross(up).normalized()
		midpoint+=sideways*(float(motion.get("right",0.0)) if bool(motion.get("side_choice",false)) else -float(motion.get("left",0.0)))*distance_scale
	var joint:Node3D
	for path in effect.state.paths:
		if str(path).contains(str(motion.get("joint","TargetJoint"))) and str(motion.get("joint","TargetJoint"))!="":joint=effect.state.paths[path];break
	if is_instance_valid(joint):
		if start!=end:
			var rotation=_source_look_at(effect.state.root,SourceProjection.source_to_render(end),up)
			if rotation is Quaternion:effect.state.source_rotations[effect.root_key]=rotation
		end+=up*float(motion.height)
		joint.global_position=SourceProjection.source_to_render(_spline3(start,midpoint,end,t))
	else:
		effect.state.root.global_position=SourceProjection.source_to_render(_spline3(start,midpoint,end,t))
		if motion.orient and t<0.9999:
			var next:Vector3=SourceProjection.source_to_render(_spline3(start,midpoint,end,minf(1.0,t+0.001)))
			if effect.state.root.global_position.distance_squared_to(next)>0.0000001:
				var rotation=_source_look_at(effect.state.root,next,up)
				if rotation is Quaternion:effect.state.source_rotations[effect.root_key]=rotation

func sync_projection():
	for effect in effects:_project(effect)

func _sample(effect: Dictionary):
	if get_script().resource_path=="res://scripts/native_death_effects.gd" and preload("res://scripts/native_combat_particles.gd").death_initial_geometry_defer_enabled:
		effect._sampling_particle_setup=true
	var profiling:bool=game!=null and bool(game.get("profile_frame_stages"))
	var profile_started:int=Time.get_ticks_usec() if profiling else 0
	var stage_started:int=profile_started
	var stages:Dictionary={}
	_project(effect)
	if profiling:stage_started=_profile_effect_stage(stages,"project",stage_started)
	if effect.has("pending_death") and float(effect.age)>=float(effect.pending_death):
		var moment: float=effect.pending_death;effect.erase("pending_death");_start_event(effect,"Death",moment)
	_run_schedules(effect)
	if profiling:stage_started=_profile_effect_stage(stages,"schedules",stage_started)
	if effect.has("components"):effect.components.update(float(effect.age))
	if profiling:stage_started=_profile_effect_stage(stages,"components_update",stage_started)
	_sample_animations(effect,float(effect.age))
	if profiling:stage_started=_profile_effect_stage(stages,"animations",stage_started)
	for player in effect.clips.values():
		var time: float=maxf(0.0,(float(effect.age)-float(player.start))*float(player.speed))
		assets.sample_clip(effect.state,player.clip,time,player.path)
		if float(player.get("blend",0.0))>0.0 and float(effect.age)-float(player.start)<float(player.blend):
			var previous: Dictionary=player.previous
			assets.sample_float_crossfade(effect.state,player.clip,time,player.path,previous,(float(effect.age)-float(previous.get("start",effect.age)))*float(previous.get("speed",1.0)),clampf((float(effect.age)-float(player.start))/float(player.blend),0.0,1.0),player.initial_pose)
		if assets.clips.has(player.clip):
			var events: Array=assets.clips[player.clip].data.get("m_Events",[])
			while int(player.event_cursor)<events.size() and float(events[int(player.event_cursor)].time)<=time+0.0000001:
				var event: Dictionary=events[int(player.event_cursor)];_animation_event(effect,player,event,float(player.start)+float(event.time)/float(player.speed));player.event_cursor+=1
	if profiling:stage_started=_profile_effect_stage(stages,"clips",stage_started)
	for action in effect.continuous:_apply_continuous(effect,action)
	if profiling:stage_started=_profile_effect_stage(stages,"continuous",stage_started)
	if effect.has("components"):effect.components.late_update(float(effect.age))
	if profiling:stage_started=_profile_effect_stage(stages,"components_late",stage_started)
	for player in effect.particles.values():
		player.node.seek(float(effect.age)-float(player.start))
		if is_instance_valid(player.node.source_node):player.node.mesh_instance.visible=player.node.source_node.is_visible_in_tree()
	effect.erase("_sampling_particle_setup")
	if profiling:stage_started=_profile_effect_stage(stages,"particles",stage_started)
	for node_materials in effect.state.get("materials",{}).values():
		for mat in node_materials:
			if mat is ShaderMaterial:mat.set_shader_parameter("_UnityTimeX",clock_seconds*0.05)
	if profiling:stage_started=_profile_effect_stage(stages,"materials",stage_started)
	if effect.has("trails"):effect.trails.advance(float(effect.age))
	if profiling:stage_started=_profile_effect_stage(stages,"trails",stage_started)
	_bind_scene_inputs(effect)
	if profiling:stage_started=_profile_effect_stage(stages,"scene_inputs",stage_started)
	if effect.has("rendertexture") and is_instance_valid(effect.rendertexture):effect.rendertexture.sync(effect.age)
	if profiling:stage_started=_profile_effect_stage(stages,"rendertexture",stage_started)
	for shake_action in effect.shakes:game.camera_shake.update_action(shake_action,shake_update_delta,shake_update_id)
	if effect.has("hit_unit") and str(effect.hit_unit.key)==str(effect.hit_unit_key) and float(effect.age)<assets.clip_length(effect.actor_clip):
		game.native_combat._pose(effect.hit_unit,effect.actor_clip,effect.age)
	elif effect.has("hit_unit") and str(effect.hit_unit.key)==str(effect.hit_unit_key):
		game.native_combat._clear_pose(effect.hit_unit);effect.erase("hit_unit")
	if profiling:stage_started=_profile_effect_stage(stages,"shake_actor_pose",stage_started)
	_record_materials(effect)
	if profiling:
		stage_started=_profile_effect_stage(stages,"audit",stage_started)
		_profile_effect_row(effect,"sample",profile_started,stages)

func _bind_scene_inputs(effect: Dictionary):
	if game.headless or not is_instance_valid(game.spatial_scene):return
	var camera: Camera3D=game.spatial_scene.camera
	var vp: Projection=camera.get_camera_projection()*Projection(camera.get_camera_transform().affine_inverse())
	var ambient: Color=Color("e3e4e3").srgb_to_linear()*0.33
	var main: DirectionalLight3D=game.spatial_scene.get_node_or_null("SoftWarmBoardLight")
	for key in effect.state.get("materials",{}):
		var node: Node3D=effect.state.get("renderers",{}).get(key,effect.state.get("nodes",{}).get(key))
		if not is_instance_valid(node):continue
		for mat in effect.state.materials[key]:
			if not mat is ShaderMaterial:continue
			var path: String=mat.get_meta("source_base_shader_path",mat.shader.resource_path)
			if path.contains("addmultiply_world"):
				mat.set_shader_parameter("_SourceViewProjection",vp);mat.set_shader_parameter("_GodotToSourceWorld",Transform3D.IDENTITY)
			if path.contains("fresnel"):
				mat.set_shader_parameter("_SourceCameraObject",node.to_local(camera.global_position));mat.set_shader_parameter("_GodotToSourceObject",Transform3D.IDENTITY)
			mat.set_shader_parameter("_UnitySHW",Vector3(ambient.r,ambient.g,ambient.b))
			if path.contains("urp_simple_lit"):
				mat.set_shader_parameter("_UnitySHAr",Vector4(0,0,0,ambient.r));mat.set_shader_parameter("_UnitySHAg",Vector4(0,0,0,ambient.g));mat.set_shader_parameter("_UnitySHAb",Vector4(0,0,0,ambient.b))
			if is_instance_valid(main):
				var direction: Vector3=main.global_basis.z.normalized();var color: Color=main.light_color.srgb_to_linear()*main.light_energy
				mat.set_shader_parameter("_MainLightPosition",Vector4(direction.x,direction.y,direction.z,0.0))
				mat.set_shader_parameter("_MainLightColor",Vector4(color.r,color.g,color.b,1) if path.contains("urp_simple_lit") else Vector3(color.r,color.g,color.b))
			if not (path.contains("diffuse") or path.contains("urp_simple_lit")):continue
			var positions:=PackedVector4Array();var colors:=PackedVector4Array();var attenuation:=PackedVector4Array();var directions:=PackedVector4Array()
			for light in effect.state.get("lights",{}).values():
				if not light is OmniLight3D or not light.is_visible_in_tree() or positions.size()>=8:continue
				var position: Vector3=light.global_position;var color: Color=light.light_color.srgb_to_linear()*light.light_energy
				var range_squared: float=pow(light.omni_range*light.global_basis.x.length(),2.0)
				positions.append(Vector4(position.x,position.y,position.z,1.0));colors.append(Vector4(color.r,color.g,color.b,1.0));attenuation.append(Vector4(1.0/maxf(range_squared,0.000001),0,0,1));directions.append(Vector4(0,0,1,0))
			var count:=positions.size();positions.resize(8);colors.resize(8);attenuation.resize(8);directions.resize(8)
			mat.set_shader_parameter("_SourceAdditionalCount",count);mat.set_shader_parameter("_AdditionalLightsPosition",positions);mat.set_shader_parameter("_AdditionalLightsColor",colors);mat.set_shader_parameter("_AdditionalLightsAttenuation",attenuation);mat.set_shader_parameter("_AdditionalLightsSpotDir",directions)

func _source_animate_value(effect: Dictionary,params: Dictionary,curve: Dictionary,age: float,calculation: int,initial: float) -> float:
	var keys: Array=curve.m_Curve
	if keys.is_empty():return initial
	var time_param: Dictionary=params.get("time",{})
	var speed_param: Dictionary=params.get("speed",{})
	var has_time: bool=not (bool(time_param.get("useVariable",true)) and str(time_param.get("name",""))=="")
	var has_speed: bool=not (bool(speed_param.get("useVariable",true)) and str(speed_param.get("name",""))=="")
	var sample_time:=age*(float(_value(effect,speed_param,1.0)) if has_speed else 1.0)
	if has_time:sample_time=sample_time/maxf(float(_value(effect,time_param,0.0)),0.000001)*float(keys[-1].time)
	if bool(_value(effect,params.get("ignoreCurveOffset"),false)):sample_time+=float(keys[0].time)
	var curve_value:=Curves.scalar_keys(keys,sample_time)
	match calculation:
		0:return initial
		1:return curve_value
		2:return initial+curve_value
		3:return initial-curve_value
		4:return curve_value-initial
		5:return initial*curve_value
		6:return initial/curve_value if curve_value!=0.0 else 3.4028234663852886e38
		7:return curve_value/initial if initial!=0.0 else 3.4028234663852886e38
	return curve_value

func _sample_animations(effect: Dictionary,time: float):
	for animation in effect.animations:
		if time<float(animation.start):continue
		var age: float=maxf(0.0,time-float(animation.start))
		if animation.kind=="float":effect.variables[animation.name]=Curves.scalar_keys(animation.curve.m_Curve,age)
		elif animation.kind=="float_v2":effect.variables[animation.name]=_source_animate_value(effect,animation.params,animation.curve,age,int(animation.params.calculation),float(animation.initial))
		elif animation.kind=="color":
			var color: Dictionary={}
			for channel in ["R","G","B","A"]:color[channel.to_lower()]=_source_animate_value(effect,animation.params,animation.params["curve"+channel].curve,age,int(animation.params.get("calculation"+channel,1)),float(animation.initial.get(channel.to_lower(),0.0)))
			effect.variables[animation.name]=color
		elif animation.kind in ["ease_color","ease_float"]:
			var t:=_ease(clampf(age/maxf(animation.duration,0.000001),0.0,1.0),int(animation.ease))
			if animation.kind=="ease_float":effect.variables[animation.name]=lerpf(float(animation.origin),float(animation.destination),t)
			else:
				var color:=Curves.color(animation.origin).lerp(Curves.color(animation.destination),t)
				effect.variables[animation.name]={"r":color.r,"g":color.g,"b":color.b,"a":color.a}
		elif animation.kind=="fade" and is_instance_valid(animation.material):assets.set_material_float(animation.material,"_Color.a",lerpf(animation.origin,animation.destination,_ease(clampf(age/maxf(animation.duration,0.000001),0.0,1.0),int(animation.ease))))
		elif animation.kind=="scale" and is_instance_valid(animation.node):animation.node.scale=animation.origin.lerp(animation.destination,_ease(clampf(age/maxf(animation.duration,0.000001),0.0,1.0),int(animation.ease)))

func _alpha(mat: Material) -> float:
	if mat is ShaderMaterial:
		var color=mat.get_shader_parameter("_Color")
		return color.a if color is Color else 1.0
	return mat.albedo_color.a if mat is StandardMaterial3D else 1.0

func _apply_continuous(effect: Dictionary,action: Dictionary):
	var params: Dictionary=action.params
	if action.kind=="light":
		if effect.state.get("lights",{}).has(action.key):effect.state.lights[action.key].light_energy=float(_value(effect,params.lightIntensity,0.0))
	elif action.kind=="SetColorRGBA":
		var color: Dictionary=_value(effect,params.colorVariable,{}).duplicate()
		for field in {"red":"r","green":"g","blue":"b","alpha":"a"}:
			var wrapper: Dictionary=params.get(field,{})
			if not bool(wrapper.get("useVariable",false)) or str(wrapper.get("name",""))!="":color[{"red":"r","green":"g","blue":"b","alpha":"a"}[field]]=float(_value(effect,wrapper,0.0))
		effect.variables[str(params.colorVariable.name)]=color
	elif action.kind in ["SetMaterialColor","SetMaterialFloat","alpha"]:
		var materials: Array=effect.state.get("materials",{}).get(action.key,[])
		if action.kind=="alpha" and bool(params.get("m_IncludeChildren",false)):
			materials=[]
			for key in _descendants(action.key):materials.append_array(effect.state.get("materials",{}).get(key,[]))
		var index:=int(_value(effect,params.get("materialIndex"),0))
		if index>=0 and index<materials.size() and action.kind!="alpha":materials=[materials[index]]
		for mat in materials:
			if not is_instance_valid(mat):continue
			if action.kind=="SetMaterialColor":
				var uniform: String=str(_value(effect,params.get("namedColor"),"_Color"))
				var color:=Curves.color(_value(effect,params.get("color"),{}))
				if mat is ShaderMaterial:
					mat.set_shader_parameter(uniform,color)
					var colors: Dictionary=mat.get_meta("source_colors",{});colors[uniform]=color;mat.set_meta("source_colors",colors)
			elif action.kind=="SetMaterialFloat":assets.set_material_float(mat,str(_value(effect,params.get("namedFloat"),"_Intensity")),float(_value(effect,params.get("floatValue"),0.0)))
			else:assets.set_material_float(mat,"_Color.a",float(_value(effect,params.m_Alpha,1.0)))
	elif action.kind=="property":
		var target: Dictionary={}
		for key in assets.objects:
			if str(key).get_slice(":",1)==str(action.target_id):target=assets.objects[key];break
		if target.get("class_name","")=="RenderToTexture" and effect.has("rendertexture"):
			var value=_value(effect,params.get("ColorParameter"),{}) if str(params.PropertyName)=="m_TintColor" else _value(effect,params.get("FloatParameter"),0.0)
			effect.rendertexture.set_source_property(str(target.key),str(params.PropertyName),value)
		elif target.get("type","")=="ParticleSystem":
			var key: String=target.refs.get(".m_GameObject","")
			if effect.particles.has(key):
				var player: Dictionary=effect.particles[key]
				if str(params.PropertyName)=="playbackSpeed":
					if effect.has("components"):effect.components.set_particle_speed(key,float(_value(effect,params.FloatParameter,1.0)),float(effect.age))
					else:player.node.set_playback_speed(float(_value(effect,params.FloatParameter,1.0)),float(effect.age)-float(player.start))
				elif str(params.PropertyName)=="emissionRate":player.node.set_emission_rate(float(_value(effect,params.FloatParameter,0.0)),float(effect.age)-float(player.start))
				elif str(params.PropertyName)=="enableEmission" and not bool(_value(effect,params.BoolParameter,true)):player.node.stop_emitting(float(effect.age)-float(player.start))
				else:
					if not effect.unsupported.has("property:"+str(params.PropertyName)):effect.unsupported.append("property:"+str(params.PropertyName))
		else:
			if not effect.unsupported.has("property:"+str(params.PropertyName)):effect.unsupported.append("property:"+str(params.PropertyName))

func advance(delta: float):
	shake_update_id+=1;shake_update_delta=maxf(delta,0.0)
	clock_seconds+=shake_update_delta;camera_offset=Vector2.ZERO
	for effect in effects.duplicate():
		effect.age+=shake_update_delta;_sample(effect)
		if float(effect.expires)>0.0 and float(effect.age)>=float(effect.expires):_dispose(effect)
	minion_shake.advance(delta)
	# Main camera requests from all owners are sampled once by game, afterwards.

func _record_materials(effect: Dictionary):
	for materials in effect.state.get("materials",{}).values():
		for mat in materials:
			if not is_instance_valid(mat):continue
			var key: String=mat.get_meta("source_key","")
			effect.observed_materials[key]={"source_key":key,"shader":mat.get_meta("source_base_shader_path",mat.shader.resource_path) if mat is ShaderMaterial else "StandardMaterial3D","compatibility":mat.get_meta("compatibility","")}

func _audit(effect: Dictionary) -> Dictionary:
	var particles: Array=[]
	for player in effect.particles.values():particles.append(player.node.get_audit())
	return {"serial":effect.serial,"owner_serial":effect.owner_serial,"root_key":effect.root_key,"route_id":effect.route_id,"age":effect.age,"expires":effect.expires,"source_event":effect.source_event,"events":effect.events.duplicate(true),"unsupported":effect.unsupported.duplicate(),"observed_materials":effect.observed_materials.values(),"particles":particles,"trails":effect.trails.get_audit() if effect.has("trails") else {},"components":effect.components.get_audit() if effect.has("components") else {},"rendertexture":effect.rendertexture.get_audit() if effect.has("rendertexture") and is_instance_valid(effect.rendertexture) else {}}

func _dispose(effect: Dictionary):
	var profile_started:int=Time.get_ticks_usec() if game!=null and bool(game.get("profile_frame_stages")) else -1
	# Retirement must reach both rendered worlds before the RT textures are freed.
	# queue_free alone leaves the independent transmission mirror visible until
	# its next sync, which can sample a released ViewportTexture on this frame.
	if is_instance_valid(effect.container):
		effect.container.visible=false
		var retiring:Array=[effect.container]
		while not retiring.is_empty():
			var node:Node=retiring.pop_back()
			if node is SubViewport:continue
			if node is GeometryInstance3D and is_instance_valid(game.native_transmission):
				var mirror=game.native_transmission.mirrors.get(node.get_instance_id())
				if is_instance_valid(mirror):mirror.visible=false
			retiring.append_array(node.get_children())
	if effect.has("hit_unit") and str(effect.hit_unit.key)==str(effect.hit_unit_key):game.native_combat._clear_pose(effect.hit_unit)
	if effect.has("trails"):effect.trails.dispose()
	if effect.has("components"):effect.components.dispose(float(effect.age))
	history.append(_audit(effect));if history.size()>96:history.pop_front()
	if effect.has("rendertexture") and is_instance_valid(effect.rendertexture):effect.rendertexture.dispose();effect.rendertexture.queue_free()
	if is_instance_valid(effect.container):effect.container.queue_free()
	effects.erase(effect)
	if profile_started>=0:_profile_effect_row(effect,"dispose",profile_started,{})

func cancel_all():
	for effect in effects.duplicate():_dispose(effect)
	camera_offset=Vector2.ZERO;active_camera_shake={};minion_shake.cancel_all()

func get_audit() -> Dictionary:
	var active: Array=[]
	for effect in effects:active.append(_audit(effect))
	return {"active_count":effects.size(),"active":active,"history":history.duplicate(true),"untranslated_materials":assets.material_audit.duplicate(),"minion_shake":minion_shake.get_audit(),"source_routes":routes.keys(),"projection":("Source phone camera; raw source anchors/paths, missing placements fail closed" if SourceProjection.from_game(game)!=null else "Original local transforms under fixed 15-degree board registration; not recovered camera")}

# Opt-in CPU stage records; callers own draining this array.
func _profile_effect_stage(stages:Dictionary,label:String,started:int)->int:
	var now:=Time.get_ticks_usec()
	stages[label]=now-started
	return now

func _profile_effect_row(effect:Dictionary,operation:String,started:int,stages:Dictionary)->void:
	var cost:=Time.get_ticks_usec()-started
	if cost<=5000:return
	profile_rows.append({"frame":Engine.get_process_frames(),"operation":operation,"source_key":effect.get("root_key",""),"route":effect.get("route_id",""),"serial":effect.get("serial",-1),"age":effect.get("age",0.0),"usec":cost,"stages":stages})
