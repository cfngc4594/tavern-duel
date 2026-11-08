extends Node
## Recovered build-37 combat presentation; 5834 rules remain in game/rules.
## Scene registration and the Unity native solver are explicit compatibility layers.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const Assets = preload("res://scripts/native_combat_assets.gd")
const Curves = preload("res://scripts/native_summon_curves.gd")
const READY_SECONDS = 0.5333333611488342
const FINISH_SECONDS = 0.5333333611488342
const FINISH_CALLBACK = 0.5166666507720947
const PROJECTION_SCALE = 0.78 * 0.9
var game: Node
var assets = Assets.new()
var instances: Array = []
var history: Array = []
var prepared: Dictionary = {}
var prepared_spell: Dictionary = {}
var cancelled_poses: Array=[]
var serial := 0
var clock_seconds := 0.0
var controller: Dictionary = {}
var camera_offset := Vector2.ZERO
var visual_rng := RandomNumberGenerator.new()
var effect_player: Node

func setup(owner_game: Node):
	game=owner_game;assets.setup(game.native_card_renderer);visual_rng.seed=320837
	for object in assets.objects.values():
		if object.get("class_name","")=="AttackSpellController":controller=object.data;break
	if ResourceLoader.exists("res://scripts/native_combat_effects.gd"):
		effect_player=load("res://scripts/native_archer_effect.gd").new();add_child(effect_player);effect_player.setup(game,assets)

func prepare_attack(unit: Dictionary):
	if not prepared.is_empty() and prepared.unit.id==unit.id:return
	cancel_prepared()
	for entry in cancelled_poses.duplicate():
		if int(entry.unit.id)==int(unit.id):_clear_pose(entry.unit);cancelled_poses.erase(entry)
	prepared={"unit":unit,"key":unit.key,"age":0.0}
	_reset_legacy(unit)
	_pose(unit,"AllyInPlay_ReadyAttack",0.0)

func cancel_prepared(instant: bool=false):
	if prepared.is_empty():return
	if instant:_clear_pose(prepared.unit)
	else:
		cancelled_poses.append({"unit":prepared.unit,"key":prepared.key,"age":0.0})
		_pose(prepared.unit,"AllyInPlay_FinishAttack",0.0)
		if is_instance_valid(effect_player):effect_player.attack_cancel(prepared.unit)
	prepared={}

func begin_attack(unit: Dictionary,target: Dictionary,on_contact: Callable,on_finished: Callable) -> int:
	var ready_age:=0.0
	if not prepared.is_empty() and prepared.unit.id==unit.id:ready_age=minf(READY_SECONDS,float(prepared.age))
	prepared={}
	serial+=1
	var entry: Dictionary={"serial":serial,"kind":"attack","key":unit.key,"unit":unit,"target":target.duplicate(),"age":0.0,"ready_age":ready_age,"launch_time":READY_SECONDS-ready_age,"contact_time":READY_SECONDS-ready_age+float(controller.m_AllyInfo.m_MoveToTargetDuration),"stage":"ready","origin":unit.pos,"contact":target.pos,"hit":false,"finished":false,"events":[],"on_contact":on_contact,"on_finished":on_finished,"compatibility":[]}
	var projection=SourceProjection.from_game(game)
	if projection!=null:
		var origin=projection.resolve_anchor(unit);var destination=projection.resolve_anchor(target)
		if not origin.is_empty() and not destination.is_empty():
			entry.source_origin=origin.position;entry.source_contact=destination.position
	entry.contact=_contact_position(unit,target,entry)
	entry.finish_time=float(entry.contact_time)+maxf(FINISH_SECONDS,1.0)
	_reset_legacy(unit);unit.animating=true
	instances.append(entry)
	_emit(entry,"ready",0.0)
	_pose(unit,"AllyInPlay_ReadyAttack",ready_age)
	return serial

func _reset_legacy(unit: Dictionary):
	unit.scale=1.0;unit.lift=0.0;unit.rotation=0.0
	# Native local curves own the whole actor, not the old hand-written lift/scale.
	unit.erase("native_combat_position");unit.erase("native_combat_rotation");unit.erase("native_combat_scale")

func _clear_pose(unit: Dictionary):
	_reset_legacy(unit)

func _pose(unit: Dictionary,clip_name: String,time: float):
	if not assets.clips.has(clip_name):return
	var data: Dictionary=assets.clips[clip_name].data
	unit.native_combat_position=Curves.vector_curve(data.m_PositionCurves[0].curve,time) if not data.m_PositionCurves.is_empty() else Vector3.ZERO
	unit.native_combat_rotation=Curves.quaternion_curve(data.m_RotationCurves[0].curve,time) if not data.m_RotationCurves.is_empty() else Quaternion.IDENTITY
	unit.native_combat_scale=Curves.vector_curve(data.m_ScaleCurves[0].curve,time,Vector3.ONE) if not data.m_ScaleCurves.is_empty() else Vector3.ONE
	unit.scale=1.0;unit.lift=0.0

func _contact_position(unit: Dictionary,target: Dictionary,entry: Dictionary) -> Vector2:
	# Recovered controller uses its source Renderer.bounds. This compatibility
	# registration applies the same ray/AABB operation to the actual Godot actor.
	if game.headless or not is_instance_valid(game.spatial_scene):
		entry.compatibility.append("Headless contact registration has no rendered bounds; controller zero-offset branch")
		return target.pos
	game.spatial_scene.sync_from_game()
	if not game.spatial_scene.pieces.has(unit.id):return target.pos
	var actor: Dictionary=game.spatial_scene.pieces[unit.id].actor
	var bounds:=AABB();var first:=true
	for mesh in actor.renderers.values():
		if not is_instance_valid(mesh) or mesh.mesh==null:continue
		var box: AABB=mesh.global_transform*mesh.mesh.get_aabb()
		bounds=box;first=false;break
	if first:return target.pos
	var projection=SourceProjection.from_game(game)
	var source_world: Vector3
	var target_world: Vector3
	if projection!=null:
		if not entry.has("source_origin") or not entry.has("source_contact"):return target.pos
		source_world=SourceProjection.source_to_render(entry.source_origin);target_world=SourceProjection.source_to_render(entry.source_contact)
	else:
		source_world=game.spatial_scene.screen_to_world(unit.pos);target_world=game.spatial_scene.screen_to_world(target.pos)
	var center:=bounds.get_center()
	var direction: Vector3=(target_world-source_world).normalized()
	var intersection=bounds.intersects_ray(center+direction*1000.0,-direction)
	if intersection==null:return target.pos
	var offset: Vector3=(center-intersection)*(0.5-float(controller.m_SourceImpactOffset))*2.0
	entry.source_bounds={"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]}
	if projection!=null:
		entry.source_contact+=SourceProjection.render_to_source(offset)
		return projection.source_to_screen(entry.source_contact)
	return target.pos+Vector2(offset.x,-offset.y)*100.0

func advance(delta: float):
	var dt:=maxf(0.0,delta);clock_seconds+=dt;camera_offset=Vector2.ZERO
	if not prepared_spell.is_empty():prepared_spell.age+=dt
	if not prepared.is_empty():
		if prepared.unit.dead or str(prepared.unit.key)!=str(prepared.key):cancel_prepared()
		else:
			prepared.age+=dt;_pose(prepared.unit,"AllyInPlay_ReadyAttack",minf(READY_SECONDS,float(prepared.age)))
	for entry in cancelled_poses.duplicate():
		entry.age+=dt
		if str(entry.unit.key)!=str(entry.key) or bool(entry.unit.dead) or float(entry.age)>=FINISH_SECONDS:
			_clear_pose(entry.unit);cancelled_poses.erase(entry)
		else:_pose(entry.unit,"AllyInPlay_FinishAttack",entry.age)
	for entry in instances.duplicate():
		entry.age+=dt
		if entry.kind=="attack":_advance_attack(entry)
		elif entry.kind=="missile_replay":_advance_missile_replay(entry)
		else:_advance_spell(entry)
	if is_instance_valid(effect_player):
		effect_player.advance(dt);camera_offset+=effect_player.camera_offset

func _advance_attack(entry: Dictionary):
	var unit: Dictionary=entry.unit
	if str(unit.key)!=str(entry.key):_cancel(entry,"actor_replaced");return
	if not entry.hit and (bool(unit.dead) or int(unit.hp)<=0):_cancel(entry,"attacker_died_before_contact");return
	if not entry.hit and not game._valid_character(entry.target):_cancel(entry,"target_removed_before_contact");return
	if not game.allies.has(unit) and not game.enemies.has(unit):_cancel(entry,"actor_removed");return
	var age: float=entry.age
	if age<float(entry.launch_time):
		_pose(unit,"AllyInPlay_ReadyAttack",age+float(entry.ready_age));return
	if entry.stage=="ready":
		entry.stage="lunge";_emit(entry,"launch",entry.launch_time);game._event("attack_lunge")
		if game.sound_enabled:get_node("/root/SoundManager").play_original_event("@attack","launch",{"scope_id":game._next_audio_scope("attack_launch"),"card_id":unit.key,"unit_id":unit.id})
		if is_instance_valid(effect_player):effect_player.attack_launch(entry)
	if age<float(entry.contact_time):
		var t:=clampf((age-float(entry.launch_time))/float(controller.m_AllyInfo.m_MoveToTargetDuration),0.0,1.0)
		unit.pos=entry.origin.lerp(entry.contact,t)
		_source_attack_position(entry,false,t)
		_pose(unit,"AllyInPlay_ReadyAttack",READY_SECONDS)
		return
	if not entry.hit:
		entry.hit=true;entry.stage="return";unit.pos=entry.contact
		_source_attack_position(entry,false,1.0)
		_emit(entry,"contact",entry.contact_time)
		if is_instance_valid(effect_player):effect_player.attack_impact(entry)
		if entry.on_contact.is_valid():entry.on_contact.call()
	var returning:=age-float(entry.contact_time)
	# ZonePlay m_transitionTime=1, default iTween easeOutExpo. Source controller
	# calls Zone.UpdateLayout; game-specific overrides are not recovered.
	var t:=clampf(returning/1.0,0.0,1.0)
	unit.pos=entry.contact.lerp(unit.target,1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*t))
	_source_attack_position(entry,true,1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*t))
	_pose(unit,"AllyInPlay_FinishAttack",returning)
	if returning>=FINISH_CALLBACK and not entry.finished:
		entry.finished=true;_emit(entry,"spell_finished",float(entry.contact_time)+FINISH_CALLBACK)
	if age>=float(entry.finish_time):
		unit.pos=unit.target;unit.animating=false;_clear_pose(unit)
		game._event("attack_return");_emit(entry,"return_finished",entry.finish_time)
		if entry.on_finished.is_valid():entry.on_finished.call()
		_dispose(entry)

func _source_attack_position(entry:Dictionary,returning:bool,t:float):
	var projection=SourceProjection.from_game(game)
	if projection==null:return
	if not entry.has("source_origin") or not entry.has("source_contact"):
		projection.block("Attack source anchors unavailable");return
	var destination=projection.unit_target(entry.unit) if returning else {"position":entry.source_contact}
	if destination.is_empty():return
	entry.unit.source_world_position=(entry.source_contact if returning else entry.source_origin).lerp(destination.position,t)
	entry.unit.pos=projection.source_to_screen(entry.unit.source_world_position)

func supports_spell(key: String) -> bool:
	return is_instance_valid(effect_player) and effect_player.supports_spell(key)

func prepare_spell(key: String,source: Vector2,side: int=0):
	if not prepared_spell.is_empty() and str(prepared_spell.key)==key and int(prepared_spell.side)==side:return
	cancel_prepared_spell()
	if not effect_player.routes.has(key+"/start"):return
	serial+=1
	prepared_spell={"serial":serial,"key":key,"source":source,"target":{},"side":side,"age":0.0,"ready_time":effect_player.start_ready_time(key)}
	prepared_spell.effect=effect_player.prepare_spell_start(prepared_spell)

func cancel_prepared_spell(instant: bool=false):
	if prepared_spell.is_empty():return
	effect_player.cancel_spell_start(prepared_spell.get("effect",{}),instant)
	prepared_spell={}

func _take_prepared_spell(key: String,source: Vector2,side: int) -> Dictionary:
	if prepared_spell.is_empty() or str(prepared_spell.key)!=key or int(prepared_spell.side)!=side:prepare_spell(key,source,side)
	var preparation: Dictionary=prepared_spell
	prepared_spell={}
	return preparation

func begin_spell(key: String,source: Vector2,target: Dictionary,side: int,on_hit: Callable,on_finished: Callable,on_visual_impact: Callable=Callable(),on_launch: Callable=Callable()) -> int:
	var preparation:=_take_prepared_spell(key,source,side)
	serial+=1
	var route: Dictionary=effect_player.spell_route(key,target,side)
	var delay: float=maxf(0.0,float(preparation.get("ready_time",0.0))-float(preparation.get("age",0.0)))
	for field in ["impact_time","hit_time","finished_time"]:route[field]=float(route[field])+delay
	route.launch_delay=delay;route.prepared_age=float(preparation.get("age",0.0))
	var entry: Dictionary={"serial":serial,"kind":"spell","key":key,"source":source,"target":target.duplicate(),"side":side,"age":0.0,"stage":"ready","route":route,"hit":false,"finished":false,"events":[],"on_contact":on_hit,"on_finished":on_finished,"on_visual_impact":on_visual_impact,"on_launch":on_launch,"start_effect":preparation.get("effect",{}),"start_action_time":float(preparation.get("age",0.0))+delay,"compatibility":[]}
	instances.append(entry);_emit(entry,"ready",0.0)
	_advance_spell(entry)
	return serial

func begin_missile_replay(key: String,source: Vector2,side: int,steps: Array,audio_scope: String,on_finished: Callable,on_launch: Callable=Callable()) -> int:
	var preparation:=_take_prepared_spell(key,source,side)
	serial+=1
	var entry: Dictionary={"serial":serial,"kind":"missile_replay","key":key,"source":source,"target":{},"side":side,"age":0.0,"stage":"launch","hit":false,"finished":false,"events":[],"on_finished":on_finished,"compatibility":["Rules resolved atomically once; visible health, deaths and generated units replay recorded snapshots"],"shots":[],"route":{},"scope":audio_scope}
	entry.start_effect=preparation.get("effect",{});entry.on_launch=on_launch
	var launch: float=maxf(0.0,float(preparation.get("ready_time",0.0))-float(preparation.get("age",0.0)))
	entry.launch_delay=launch;entry.start_action_time=float(preparation.get("age",0.0))+launch
	for i in range(steps.size()):
		var target: Dictionary=steps[i].target
		var route: Dictionary=effect_player.spell_route(key,target,side)
		entry.shots.append({"index":i,"launch":launch,"arrival":launch+float(route.flight),"contact":launch+float(route.hit_time),"target":target,"route":route,"launched":false,"arrived":false,"hit":false,"serial":serial,"key":key,"side":side,"source":source})
		launch+=float(route.flight)
	entry.finish_time=float(entry.shots[-1].contact) if not entry.shots.is_empty() else 0.0
	entry.route={"finished_time":entry.finish_time,"shots":steps.size(),"launch_delay":entry.launch_delay,"prepared_age":float(preparation.get("age",0.0))}
	instances.append(entry);_advance_missile_replay(entry)
	return serial

func _advance_missile_replay(entry: Dictionary):
	for shot in entry.shots:
		var scope: String=entry.scope if int(shot.index)==0 else entry.scope+":missile:"+str(shot.index)
		if not shot.launched and float(entry.age)>=float(shot.launch):
			shot.launched=true
			if int(shot.index)==0:
				if entry.on_launch.is_valid():entry.on_launch.call()
				shot.start_effect=entry.start_effect;shot.start_action_time=entry.start_action_time
				shot.defer_start_death=entry.shots.size()>1;effect_player.spell_launch(shot)
				entry.start_effect=shot.get("start_effect",{})
			else:
				shot.missile_effect=effect_player._launch_missile(shot,shot.target,float(shot.route.flight))
				game._spell_audio(entry.key,"launch",scope,{"event_token":"launch:"+str(shot.index),"skip_spawn_delay":true})
			if int(shot.index)==entry.shots.size()-1:
				game._spell_audio(entry.key,"release",entry.scope)
				if entry.has("start_effect") and effect_player.effects.has(entry.start_effect):effect_player._start_event(entry.start_effect,"Death",entry.start_effect.age)
			_emit(entry,"missile_launch_"+str(shot.index),shot.launch)
		if not shot.arrived and float(entry.age)>=float(shot.arrival):
			shot.arrived=true;effect_player.spell_impact(shot)
			game._audio_hit_targets(entry.key,scope,[shot.target]);_emit(entry,"missile_arrival_"+str(shot.index),shot.arrival)
		if not shot.hit and float(entry.age)>=float(shot.contact):
			shot.hit=true;game.combat_replay.show_step(int(shot.index));_emit(entry,"visible_damage_"+str(shot.index),shot.contact)
			var deaths: Array=game.combat_replay.audio.get("deaths",[]).filter(func(d):return int(d.damage_index)==int(shot.index))
			game._audio_flush_deaths(deaths,{})
			game._finish_spell_scope(scope)
	if float(entry.age)>=float(entry.finish_time):
		entry.finished=true;entry.stage="finished";_emit(entry,"finished",entry.finish_time)
		if entry.on_finished.is_valid():entry.on_finished.call()
		_dispose(entry)

func _advance_spell(entry: Dictionary):
	if entry.stage=="ready":
		if float(entry.age)<float(entry.route.launch_delay):return
		entry.stage="launch";_emit(entry,"launch",entry.route.launch_delay)
		if entry.on_launch.is_valid():entry.on_launch.call()
		effect_player.spell_launch(entry)
	if not bool(entry.get("impact_started",false)) and float(entry.age)>=float(entry.route.impact_time):
		entry.impact_started=true;effect_player.spell_impact(entry)
		if entry.get("on_visual_impact",Callable()).is_valid():entry.on_visual_impact.call()
	if not entry.hit and float(entry.age)>=float(entry.route.hit_time):
		entry.hit=true;entry.stage="impact";_emit(entry,"contact",entry.route.hit_time)
		if entry.on_contact.is_valid():entry.on_contact.call()
	if float(entry.age)>=float(entry.route.finished_time):
		entry.finished=true;entry.stage="finished";_emit(entry,"finished",entry.route.finished_time)
		if entry.on_finished.is_valid():entry.on_finished.call()
		_dispose(entry)

func _cancel(entry: Dictionary,reason: String):
	if entry.kind=="attack":
		_clear_pose(entry.unit);entry.unit.pos=entry.unit.target;entry.unit.animating=false
		if entry.unit.has("source_world_target"):entry.unit.source_world_position=entry.unit.source_world_target
	entry.cancel_reason=reason;_emit(entry,"cancelled",entry.age)
	if reason!="match_reset" and entry.on_finished.is_valid():entry.on_finished.call()
	_dispose(entry)

func cancel_all():
	cancel_prepared_spell(true)
	cancel_prepared(true)
	for entry in cancelled_poses:_clear_pose(entry.unit)
	cancelled_poses.clear()
	for entry in instances.duplicate():_cancel(entry,"match_reset")
	if is_instance_valid(effect_player):effect_player.cancel_all()
	camera_offset=Vector2.ZERO

func _emit(entry: Dictionary,event: String,time: float):
	entry.events.append({"event":event,"source_time":time,"observed_age":entry.age})

func _dispose(entry: Dictionary):
	history.append(_audit(entry));if history.size()>64:history.pop_front()
	instances.erase(entry)

func _audit(entry: Dictionary) -> Dictionary:
	var out: Dictionary={"serial":entry.serial,"kind":entry.kind,"card":entry.key,"age":entry.age,"stage":entry.stage,"events":entry.events.duplicate(true),"compatibility":entry.compatibility.duplicate(),"cancel_reason":entry.get("cancel_reason","")}
	if entry.kind=="attack":out.merge({"unit_id":entry.unit.id,"ready_age":entry.ready_age,"launch_time":entry.launch_time,"contact_time":entry.contact_time,"finish_time":entry.finish_time,"source_bounds":entry.get("source_bounds",{})})
	else:out.route=entry.route.duplicate(true)
	return out

func get_audit() -> Dictionary:
	var active: Array=[]
	for entry in instances:active.append(_audit(entry))
	return {"active":active,"history":history.duplicate(true),"active_count":instances.size(),"cancel_pose_count":cancelled_poses.size(),"prepared_unit":prepared.get("unit",{}).get("id",-1),"prepared_age":prepared.get("age",0.0),"prepared_spell":str(prepared_spell.get("key","")),"prepared_spell_age":float(prepared_spell.get("age",0.0)),"effects":effect_player.get_audit() if is_instance_valid(effect_player) else {},"replay":game.combat_replay.get_audit(),"source_build":assets.manifest.get("build",""),"native_pixel_equivalence":false,"screen_effects":game.native_screen_effects.get_audit() if is_instance_valid(game.native_screen_effects) else {}}
