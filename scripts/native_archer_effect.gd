extends "res://scripts/native_combat_effects.gd"
## Source Arrow_Targeted_FX graph, meshes, textures and clips. Presentation only.
## Damage/death is committed by the caller at this missile's actual impact.
var archer_shots:Array=[]
var archer_serial:int=1000000
var archer_audio_owners:Dictionary={}
var archer_audio_scopes:Dictionary={}
var archer_audio_history:Array=[]

func setup(owner_game:Node,source_assets):
	super.setup(owner_game,source_assets)
	assets.objects=assets.objects.duplicate();routes=routes.duplicate()
	var extra:Dictionary=SourceDictionary.load_manifest("res://assets/original_combat_v32/archer/manifest.json")
	for key in extra.objects:
		assets.objects[key]=extra.objects[key]
		if extra.objects[key].type=="AnimationClip":
			assets.clips[key]=extra.objects[key]
	assets._prepare_render_order()
	var data:Dictionary=SourceDictionary.load_source_dictionary("res://assets/original_combat_v32/archer/routes.json")
	routes.merge(data.routes);cards.CS2_189=data.card

func play_archer(unit:Dictionary,target:Dictionary,audio_scope:String="",on_impact:Callable=Callable(),on_complete:Callable=Callable(),on_cancel:Callable=Callable())->int:

	archer_serial+=1
	archer_audio_owners[archer_serial]={"scope":audio_scope,"side":unit.side,"target":target.duplicate(true)}
	var entry:Dictionary={"key":"CS2_189","side":unit.side,"source":unit.pos,"target":target.duplicate(true),"serial":archer_serial,"age":0.0,"route":spell_route("CS2_189",target,unit.side)}
	entry.on_impact=on_impact;entry.on_complete=on_complete;entry.on_cancel=on_cancel
	spell_launch(entry)
	# SuperSpell.OnMissileSpellStateFinished (0x06014b24) starts the path
	# only after Birth completes. Reuse this instance's sampled FSM wait.
	var birth_end:float=0.0
	for schedule in entry.missile_effect.schedules:
		for step in schedule.data:
			if step.state_name=="ActionState":birth_end=float(step.at)
	entry.missile_effect.motion.begin=birth_end
	entry.route.impact_time+=birth_end
	archer_shots.append(entry)
	return archer_serial

func advance(delta:float):
	var remaining:float=maxf(delta,0.0)
	while remaining>0.0000001:
		var step:float=remaining
		for shot in archer_shots:step=minf(step,maxf(0.0,float(shot.route.impact_time)-float(shot.age)))
		super.advance(step)
		for shot in archer_shots:shot.age+=step
		remaining-=step
		for shot in archer_shots.duplicate():
			if float(shot.age)+0.0000001>=float(shot.route.impact_time):
				spell_impact(shot);archer_shots.erase(shot)

func _spawn(root_key:String,anchor:Vector2,route_id:String,owner_serial:int)->Dictionary:
	var effect:Dictionary=super._spawn(root_key,anchor,route_id,owner_serial)
	if route_id.begins_with("CS2_189/") and not game.headless:
		effect.archer_skin=preload("res://scripts/native_archer_skin.gd").new()
		effect.archer_skin.setup(assets,effect.state)
		# Source Awake is independent of the projection container visibility gate.
		for key in effect.state.particles:
			if bool(effect.state.particles[key].system.data.get("playOnAwake",false)) and not effect.particles.has(key):
				_particles(effect,key,0.0,false,true)
	return effect

func _action(effect:Dictionary,action:Dictionary,moment:float):
	if str(effect.route_id).begins_with("CS2_189/"):
		var params:Dictionary=action.params
		if action.class_name in ["AudioPlaythroughAction","AudioPlayRandomClipAction"]:
			_play_source_audio(effect,action,moment)
			return
		if action.class_name=="SetPosition":
			var key:String=_target_key(effect,action)
			var node=effect.state.get("nodes",{}).get(key)
			if is_instance_valid(node):
				# This source action uses self space and explicit x/y/z zero.
				node.position=Vector3(float(_value(effect,params.x,0.0)),float(_value(effect,params.y,0.0)),float(_value(effect,params.z,0.0)))
			return
		if action.class_name=="InvokeMethod" and str(_value(effect,params.methodName,""))=="StartShake":
			if not effect.has("archer_invocations"):effect.archer_invocations=[]
			effect.archer_invocations.append({"at":moment+float(_value(effect,params.delay,0.0)),"key":_target_key(effect,action)})
			return
	super._action(effect,action,moment)

func _sample(effect:Dictionary):
	for call in effect.get("archer_invocations",[]).duplicate():
		if float(effect.age)>=float(call.at):
			_animation_event(effect,{"key":call.key,"clip":"InvokeMethod"},{"functionName":"StartShake"},float(call.at))
			effect.archer_invocations.erase(call)
	super._sample(effect)
	if effect.has("archer_skin"):effect.archer_skin._skin()

func cancel_all():
	for shot in archer_shots:
		var cancel:Callable=shot.get("on_cancel",Callable())
		if cancel.is_valid():cancel.call()
	archer_shots.clear()
	for scope in archer_audio_scopes:get_node("/root/SoundManager").original_audio.stop_scope(scope)
	archer_audio_scopes.clear();archer_audio_owners.clear()
	super.cancel_all()

func _play_source_audio(effect:Dictionary,action:Dictionary,moment:float):
	var owner:Dictionary=archer_audio_owners.get(effect.owner_serial,{})
	if str(owner.get("scope","")).is_empty():return
	var stage:String=str(effect.route_id).get_slice("/",1)
	var state_name:String=""
	for event in effect.events:
		if event.event=="state_enter":state_name=str(event.state)
	var event_name:String="launch" if stage=="missile" else "hit"
	var scope:String=str(owner.scope)+(":missile" if stage=="missile" else ":impact:0")
	var target:Dictionary=owner.target
	var options:Dictionary={"source_fsm_state":state_name,"source_fsm_action_index":int(action.index),"stage_filter":[stage],"skip_spawn_delay":true,"source_side":owner.side,"event_token":state_name+":"+str(action.index),"target_position":target.get("pos",Vector2.ZERO),"target_id":int(target.unit.id) if target.get("type","")=="unit" else -1-int(target.get("side",0))}
	# The actual source FSM action has just executed. Do not re-sample its waits
	# or repeat the prefab's spawn-frame delay. Keep the original action-local delay.
	var request:Dictionary=game._spell_audio("CS2_189",event_name,scope,options)
	archer_audio_scopes[scope]=effect.owner_serial
	archer_audio_history.append({"owner_serial":effect.owner_serial,"route":effect.route_id,"state":state_name,"action_index":action.index,"local_visual_time":moment,"visual_clock":clock_seconds,"request":request})
	if archer_audio_history.size()>96:archer_audio_history.pop_front()
	get_node("/root/SoundManager").original_audio.finish_scope(scope)

func _dispose(effect:Dictionary):
	var owner:int=int(effect.owner_serial)
	super._dispose(effect)
	if not archer_audio_owners.has(owner):return
	for active in effects:
		if int(active.owner_serial)==owner:return
	for shot in archer_shots:
		if int(shot.serial)==owner:return
	archer_audio_owners.erase(owner)
	for scope in archer_audio_scopes.keys():
		if int(archer_audio_scopes[scope])==owner:archer_audio_scopes.erase(scope)

func retain_death_audio(owner:int,deaths:Array):
	if archer_audio_owners.has(owner):
		archer_audio_owners[owner].death_audio=deaths.duplicate(true)
		archer_audio_owners[owner].death_audio_consumed=false

func spell_impact(entry:Dictionary):
	# Remove before calling: re-entry or cancellation cannot commit damage twice.
	var commit:Callable=entry.get("on_impact",Callable())
	entry.erase("on_impact");entry.erase("on_cancel")
	if commit.is_valid():commit.call()
	super.spell_impact(entry)
	if str(entry.get("key",""))!="CS2_189":return
	var owner:Dictionary=archer_audio_owners.get(entry.serial,{})
	if not owner.is_empty() and not bool(owner.get("death_audio_consumed",false)):
		owner.death_audio_consumed=true
		var deaths:Array=owner.get("death_audio",[])
		owner.erase("death_audio")
		if not deaths.is_empty():
			game._audio_flush_deaths(deaths,{},{})
			archer_audio_history.append({"event":"observed_death_audio_flushed","owner_serial":entry.serial,"count":deaths.size(),"visual_clock":clock_seconds})
	var complete:Callable=entry.get("on_complete",Callable())
	entry.erase("on_complete")
	if complete.is_valid():complete.call()
