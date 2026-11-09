extends Node
## Source-driven 37.0 generic summon actor/effect player; rule state stays in game.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const SourceRotation=preload("res://scripts/source_itween_rotation.gd")
const Assets=preload("res://scripts/native_summon_assets.gd")
const Curves=preload("res://scripts/native_summon_curves.gd")
const Particles=preload("res://scripts/native_summon_particles.gd")
const PROJECTION_SCALE=0.78*0.9
var game: Node
var assets=Assets.new()
var instances: Array=[]
var history: Array=[]
var transformations: Array=[]
var serial:=0
var source_clock:=0.0
var camera_rng:=RandomNumberGenerator.new()
var highlight_rng:=RandomNumberGenerator.new()
var camera_offset:=Vector2.ZERO
var source_routes: Dictionary={}
var hand_bindings: Dictionary={}
var camera_requests:Dictionary={}

func setup(owner_game: Node):
	game=owner_game;assets.setup(game.native_card_renderer);camera_rng.seed=310831;highlight_rng.seed=311831
	source_routes=JSON.parse_string(FileAccess.get_file_as_string("res://references/summon_v31/runtime_routes.json")).routes
	for label in source_routes:
		var root_key:String=str(source_routes[label].get("root_key",""))
		for step in source_routes[label].get("state_enter_schedule",[]):
			for action in step.get("actions",[]):
				var params:Dictionary=action.get("params",{})
				if str(action.get("class_name",""))!="InvokeMethod" or str(params.get("behaviour",""))!="CameraShaker" or str(params.get("methodName",""))!="StartShake":continue
				for component in assets.objects.values():
					if str(component.get("class_name",""))=="CameraShaker" and str(component.get("refs",{}).get(".m_GameObject",""))==root_key:
						camera_requests[label]={"time":float(step.get("at_seconds_nominal",0.0))+float(params.get("delay",0.0)),"source":component.data,"component_key":component.key}
	hand_bindings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/original_summon_v31/data/ordinary_hand_texture_highlight_bindings.json"))

func route_for(unit: Dictionary,route: String="hand") -> Dictionary:
	var d: Dictionary=game.definitions[unit.key]
	var tier: String="large" if int(d.cost)>=7 else ("medium" if int(d.cost)>=4 else "small")
	var enemy:=int(unit.side)==1
	var out_label: String="" if route=="token" else ("hand_out_hidden" if enemy else "hand_out_"+tier)
	var in_label: String=("spawn_opponent" if enemy else "spawn_friendly") if route=="token" else ("play_in_opponent" if enemy else "play_in_"+tier)
	var out_name: String=assets.objects[assets.manifest.root_labels[out_label]].name if out_label!="" else ""
	var in_name: String=assets.objects[assets.manifest.root_labels[in_label]].name
	var actor_clip: String="" if route=="token" else ("AllyInPlaySpawn_Med" if not enemy and tier!="small" else "AllyInPlaySpawn")
	var actor_type: int=(31 if enemy else 26) if route=="token" else ({"small":42,"medium":68,"large":69}[tier] if enemy else {"small":2,"medium":24,"large":25}[tier])
	return {"route":route,"out_name":out_name,"in_name":in_name,"out_label":out_label,"in_label":in_label,"out_duration":float(source_routes[out_label].finished_seconds_nominal) if out_label!="" else 0.0,"in_duration":float(source_routes[in_label].finished_seconds_nominal),"in_clip":"AllyInPlay_SummonMinionGlowFadeIn" if route=="token" else "","tail_duration":assets.clip_length("AllyInPlay_SummonMinionGlowFadeOut") if route=="token" else ((3.5999999046325684 if tier=="large" else 2.5) if not enemy and tier!="small" else 2.0),"actor_clip":actor_clip,"actor_type":actor_type,"tier":"generated" if route=="token" else tier}

func _prefab(name: String) -> String:
	for key in assets.objects:
		if assets.objects[key].type=="GameObject" and str(assets.objects[key].name)==name:return key
	return ""

func begin(unit: Dictionary,source: Dictionary={},route: String="hand",on_settle: Callable=Callable()) -> int:
	assets.renderer=game.native_card_renderer
	for previous in instances.duplicate():
		if int(previous.unit.id)==int(unit.id):_cancel_entry(previous,"replaced_actor")
	serial+=1
	var config:=route_for(unit,route)
	var entry: Dictionary={"serial":serial,"unit":unit,"key":unit.key,"side":unit.side,"source":source.duplicate(),"config":config,"age":0.0,"stage":"out" if route=="hand" else "in","settled":false,"events":[],"on_settle":on_settle,"out":{},"in":{},"hand":{},"container":null,"particles":[],"visual_missing":[],"detached":[],"frozen_origin":null,"origin":source.get("pos",Vector2(800,45)),"source_clock_start":source_clock,"schedule_cursors":{},"clip_players":{},"particle_players":{},"observed_materials":{},"crossfades":[],"out_cleaned":false}
	if SourceProjection.from_game(game)!=null and route=="hand":
		# Card.GetTransitionDelay consumes the pending delay once. ZonePlay
		# passes that same delay to ScaleTo, RotateTo and MoveTo.
		entry.source_transition_delay=float(unit.get("source_transition_delay",0.0))
		unit.source_transition_delay=0.0
	if route=="hand":
		unit.animating=true;unit.hidden=true
		# Remove the retired Tween entry scale; source Spawn has no scale track.
		unit.scale=1.0
	else:unit.native_summon_hidden=true
	unit.summon_shadow=true
	instances.append(entry)
	if not game.headless:_build_visual(entry)
	if route=="hand":
		_emit(entry,"out_start",0.0);game._audio_hand_actor(unit,false);game._event("summon_lift")
		game._card_audio(unit.key,"play",{"scope_id":"unit:"+str(unit.id),"event_token":"summon","unit_id":unit.id})
	else:
		_emit(entry,"in_start",0.0)
		game._audio_actor(unit.id,unit.key,int(config.actor_type))
		game._card_audio(unit.key,"play",{"scope_id":"unit:"+str(unit.id),"event_token":"summon","unit_id":unit.id,"summoned":true})
	_sample(entry)
	return serial

func _build_visual(entry: Dictionary):
	game.spatial_scene.sync_from_game()
	var container:=Node3D.new();container.name="OriginalSummon_%d"%entry.serial;game.spatial_scene.add_child(container);entry.container=container
	var projection:=Node3D.new();projection.name="BoardProjectionCompatibility";container.add_child(projection)
	projection.basis=Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*PROJECTION_SCALE
	var source_projection=SourceProjection.from_game(game)
	if source_projection!=null:projection.basis=SourceProjection.REFLECTION
	entry.projection=projection
	if entry.config.route=="hand":
		if int(entry.side)==1:
			entry.hand=assets.instantiate(assets.manifest.root_labels.hidden_actor,projection)
			# Source HighlightState.Setup disables the renderer before state selection.
			for go_key in entry.hand.renderers:
				if str(assets.objects[go_key].name)=="Highlight_Card_Plane":entry.hand.renderers[go_key].visible=false
		else:
			entry.hand=game.native_card_renderer.clone_world_hand(entry.key);projection.add_child(entry.hand.root)
			_attach_hand_highlight(entry)
		if source_projection!=null and not entry.hand.is_empty():
			# Actor.SetCard0x060127f5: Card owns world TRS; Actor and RootObject
			# start at identity before the original AllyInHandDeath local curves.
			entry.hand.root.transform=Transform3D.IDENTITY
			var body:Node3D=entry.hand.paths.get("RootObject")
			if is_instance_valid(body):body.transform=Transform3D.IDENTITY
		var key: String=assets.manifest.root_labels.get(entry.config.out_label,"")
		if key!="":entry.out=assets.instantiate(key,entry.hand.root)
		else:entry.visual_missing.append(entry.config.out_name)
	var key: String=assets.manifest.root_labels.get(entry.config.in_label,"")
	if key!="":entry["in"]=assets.instantiate(key,game.spatial_scene.pieces[entry.unit.id].actor.root);entry["in"].root.visible=entry.config.route=="token"
	else:entry.visual_missing.append(entry.config.in_name)

func _attach_hand_highlight(entry: Dictionary):
	# The source HighlightState starts disabled. Only a verified hand interaction
	# state supplied by the actual submission path may enable this renderer.
	var actor_state: int=int(entry.source.get("source_actor_state",1))
	var spec: Dictionary=hand_bindings.hand_highlight
	var parent: Node3D=entry.hand.paths.get(spec.relative_path)
	if not is_instance_valid(parent):return
	var states: Array=spec.highlight_state_component.data.m_HighlightStates
	var material_key: String=""
	for i in range(states.size()):
		if int(states[i].m_StateType)==actor_state:
			material_key=spec.highlight_state_component.refs.get(".m_HighlightStates[%d].m_Material"%i,"");break
	if material_key=="":return
	var mat: Material=assets.material(material_key,assets.load_texture(spec.ordinary_static_mask_candidate.texture_key))
	if not mat is ShaderMaterial:return
	mat.set_shader_parameter("_Seed",highlight_rng.randf())
	mat.set_shader_parameter("_Intensity",1.0)
	mat.render_priority=50
	var mesh:=MeshInstance3D.new();mesh.mesh=assets.geometry(spec.mesh_key);mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
	entry.hand.renderers[spec.go_key]=mesh;entry.hand.materials[spec.go_key]=[mat];entry.hand.nodes[spec.go_key]=parent
	entry.hand_highlight_material=mat
	_emit(entry,"source_hand_highlight_state_"+str(actor_state),0.0)

func advance(delta: float):
	source_clock+=maxf(delta,0.0);camera_offset=Vector2.ZERO
	for entry in instances.duplicate():
		if str(entry.unit.key)!=str(entry.key):
			_cancel_entry(entry,"transformed_actor");continue
		entry.age+=maxf(delta,0.0)
		var config: Dictionary=entry.config
		var out_duration: float=config.out_duration
		if entry.stage=="out" and float(entry.age)>=out_duration:
			entry.stage="in";_emit(entry,"out_finished",out_duration);_emit(entry,"in_start",out_duration)
			game._event("summon_transform");game._event("summon_reveal")
			entry.unit.hidden=false;entry.unit.pos=entry.unit.target
			game._audio_hand_actor(entry.unit,true)
			if not entry.hand.is_empty():
				for renderer in entry.hand.renderers.values():renderer.visible=false
				if int(entry.side)==0 and config.tier!="small":entry.out.root.visible=false
			if not entry["in"].is_empty():entry["in"].root.visible=true
		var in_time: float=float(entry.age)-out_duration
		var camera_request:Dictionary=camera_requests.get(config.in_label,{})
		if entry.stage!="out" and not camera_request.is_empty() and in_time>=float(camera_request.time) and not _has_event(entry,"camera_shake"):
			_emit(entry,"camera_shake",out_duration+float(camera_request.time))
			# Source InvokeMethod delay and exact CameraShaker component: both
			# medium and large source routes participate in the same arbitration.
			var source:Dictionary=camera_request.source
			game.camera_shake.request_curve(Curves.vec(source.m_Amount),source.m_IntensityCurve,float(source.get("m_HoldAtSec",0.0)) if bool(source.get("m_Hold",false)) else null,bool(source.get("m_IsOverride",false)),"summon:"+str(config.in_label)+":CameraShaker.StartShake")
		if not entry.settled and in_time>=float(config.in_duration):_settle(entry)
		_sample(entry)
		if entry.settled and in_time>=float(config.in_duration)+float(config.tail_duration):
			_emit(entry,"tail_reset",out_duration+float(config.in_duration)+float(config.tail_duration));_dispose(entry);instances.erase(entry)

func _sample(entry: Dictionary):
	var unit: Dictionary=entry.unit
	var age: float=entry.age
	var cfg: Dictionary=entry.config
	var source_projection=SourceProjection.from_game(game)
	var source_pose:Dictionary={}
	if source_projection!=null:
		source_pose=_source_card_pose(entry,source_projection)
		if source_pose.is_empty():
			var missing="Phone summon requires complete source Card poses and explicit source Euler endpoints"
			if not entry.visual_missing.has(missing):entry.visual_missing.append(missing)
		elif cfg.route=="hand" and not bool(entry.get("source_card_tween_complete",false)):
			# Actor replacement does not replace the Card parent. Keep the same
			# original 1-second world TRS through both out and in actor stages.
			unit.source_world_position=source_pose.position
			unit.source_world_scale=source_pose.scale
			unit.source_world_rotation=source_pose.basis.get_rotation_quaternion()
			unit.source_world_euler=source_pose.euler
			unit.pos=source_projection.source_to_screen(source_pose.position)
			if age>=1.0+float(entry.get("source_transition_delay",0.0)):
				entry.source_card_tween_complete=true
	if entry.stage!="out" and cfg.route=="hand" and assets.clips.has(cfg.actor_clip) and age<float(cfg.out_duration)+assets.clip_length(cfg.actor_clip):
		var data: Dictionary=assets.clips[cfg.actor_clip].data
		var local_time:=maxf(0.0,age-float(cfg.out_duration))
		unit.native_summon_position=Curves.vector_curve(data.m_PositionCurves[0].curve,local_time) if not data.m_PositionCurves.is_empty() else Vector3.ZERO
		unit.native_summon_rotation=Curves.quaternion_curve(data.m_RotationCurves[0].curve,local_time) if not data.m_RotationCurves.is_empty() else Quaternion.IDENTITY
		if source_projection==null:unit.pos=unit.target
		if source_projection!=null:
			unit.lift=0.0 # Source actor height stays 3D; never add the legacy screen lift.
		else:unit.lift=(float(unit.native_summon_position.y)*sin(PI/12.0)+float(unit.native_summon_position.z)*cos(PI/12.0))*PROJECTION_SCALE*100.0
	elif entry.settled:
		unit.erase("native_summon_position");unit.erase("native_summon_rotation");unit.lift=0.0

	if not game.headless and game.spatial_scene.pieces.has(unit.id):
		var actor: Node3D=game.spatial_scene.pieces[unit.id].actor.root
		actor.position=unit.get("native_summon_position",Vector3.ZERO);actor.quaternion=unit.get("native_summon_rotation",Quaternion.IDENTITY)
	if is_instance_valid(entry.container):
		# Card-parent slot interpolation is independent of Actor local source curves.
		# Source ZonePlay default m_transitionTime=1.0 and iTween default
		# easeOutExpo. Destination/projection are this board's registration.
		var t:=clampf(age/1.0,0.0,1.0)
		var position: Vector2=entry.origin.lerp(unit.target,1.0 if t>=1.0 else 1.0-pow(2.0,-10.0*t)) if cfg.route=="hand" else unit.target
		if source_projection!=null:
			var valid:=not source_pose.is_empty()
			entry.container.visible=valid
			if valid:
				var source_position:Vector3=source_pose.position
				if entry.frozen_origin!=null:
					if not entry.has("source_frozen_origin"):entry.source_frozen_origin=source_position
					source_position=entry.source_frozen_origin
				entry.container.position=SourceProjection.source_to_render(source_position)
				if cfg.route=="hand":
					entry.projection.basis=SourceProjection.REFLECTION*source_pose.basis*Basis.from_scale(source_pose.scale)
		else:entry.container.position=game.spatial_scene.screen_to_world((entry.frozen_origin if entry.frozen_origin!=null else position)+game.shake_offset)
		if cfg.route=="hand" and not entry.out_cleaned:
			if int(entry.side)==1:
				var t_hidden:=clampf(age/0.4000000059604645,0.0,1.0)
				entry.hand.root.position=Vector3(0,6.0*(1.0-pow(1.0-t_hidden,2)),0)
			else:assets.sample_clip(entry.hand,"AllyInHandDeath",age)


		for state in [entry.hand,entry.out,entry["in"]]:
			for mats in state.get("materials",{}).values():
				for mat in mats:
					if mat is ShaderMaterial:
						mat.set_shader_parameter("_UnityTimeX",source_clock*0.05)
						mat.set_shader_parameter("_ShaderTime",fmod(source_clock*0.05,65535.0))
		if entry.has("hand_highlight_material"):
			entry.hand_highlight_material.set_shader_parameter("_Intensity",maxf(0.0,1.0-age))

	_run_schedule(entry,str(cfg.out_label),age,0.0,"out")
	if entry.stage!="out":_run_schedule(entry,str(cfg.in_label),age-float(cfg.out_duration),float(cfg.out_duration),"in")

	for player in entry.clip_players.values():
		var clip_time:=maxf(0.0,age-float(player.start))
		assets.sample_clip(player.state,player.clip,clip_time,player.path)
		if float(player.get("crossfade",0.0))>0.0 and clip_time<float(player.crossfade):
			var previous: Dictionary=player.get("previous",{})
			assets.sample_float_crossfade(player.state,player.clip,clip_time,player.path,previous,age-float(previous.get("start",age)),clip_time/float(player.crossfade),player.initial_pose)
	for player in entry.particle_players.values():player.node.seek(age-float(player.start))
	_collect_material_usage(entry)

func _source_card_pose(entry:Dictionary,source_projection)->Dictionary:
	var unit:Dictionary=entry.unit
	var destination:Dictionary=source_projection.unit_target(unit)
	if destination.is_empty():return {}
	if entry.config.route!="hand":return {"position":destination.position}
	var origin:Dictionary=source_projection.resolve_anchor(entry.source)
	if origin.is_empty():return {}
	if not origin.has("scale") or not origin.has("rotation") or not unit.has("source_world_target_scale") or not unit.has("source_world_target_rotation"):
		source_projection.block("Phone summon needs complete source Card scale and rotation")
		return {}
	# Do not reconstruct Unity's Euler aliases from a quaternion. The hand and
	# recovered ZonePlay contract supply the exact source Euler endpoints.
	var start=entry.source.get("source_world_euler")
	var finish=unit.get("source_world_target_euler")
	if not start is Vector3 or not finish is Vector3:
		source_projection.block("Phone summon has no explicit source Euler endpoints")
		return {}
	if not SourceRotation.matches_rotation(start,origin.rotation) or not SourceRotation.matches_rotation(finish,unit.source_world_target_rotation):
		source_projection.block("Phone summon Euler endpoint disagrees with its source quaternion")
		return {}
	# ZonePlay::.ctor m_transitionTime=1.0; UpdateLayout supplies no ease override.
	var blend:=SourceRotation.ease_out_expo_progress(float(entry.age),1.0,float(entry.get("source_transition_delay",0.0)))
	var angles:=SourceRotation.interpolate(start,finish,blend)
	return {"position":origin.position.lerp(destination.position,blend),"scale":origin.scale.lerp(unit.source_world_target_scale,blend),"euler":angles,"basis":SourceRotation.source_basis(angles)}

func _settle(entry: Dictionary):
	entry.settled=true;entry.stage="tail"
	var u: Dictionary=entry.unit
	var time: float=float(entry.config.out_duration)+float(entry.config.in_duration)
	_emit(entry,"in_finished",time);_emit(entry,"particle_play",time)
	if entry.config.route=="hand":u.hidden=false;u.pos=u.target;u.lift=0.0;u.scale=1.0;u.animating=false
	u.erase("native_summon_hidden");u.summon_shadow=false;u.erase("native_summon_position");u.erase("native_summon_rotation")
	game._event("summon_contact");game._event("summon_settled")
	if entry.config.route=="hand":
		# Preserve the historical cosmetic RNG contract without using it for FX.
		for _i in range(142):game.rng.randf()
	if not game.headless and game.spatial_scene.pieces.has(u.id):
		var actor: Node3D=game.spatial_scene.pieces[u.id].actor.root
		actor.position=Vector3.ZERO;actor.quaternion=Quaternion.IDENTITY
		entry.frozen_origin=u.target
		if SourceProjection.from_game(game)!=null and u.has("source_world_target"):entry.source_frozen_origin=u.source_world_target

	if entry.on_settle.is_valid():entry.on_settle.call()

func _run_schedule(entry: Dictionary,label: String,time: float,offset: float,state_name: String):
	if label=="" or not source_routes.has(label):return
	var schedule: Array=source_routes[label].state_enter_schedule
	var index: int=entry.schedule_cursors.get(label,0)
	var state: Dictionary=entry[state_name]
	while index<schedule.size() and time+0.000000001>=float(schedule[index].at_seconds_nominal):
		var moment: float=float(schedule[index].at_seconds_nominal)+offset
		for action in schedule[index].actions:
			var key: String=action.get("target_object_key","")
			var params: Dictionary=action.params
			var target: Node3D=state.get("nodes",{}).get(key)
			match str(action.class_name):
				"ActorSetVisibility":
					if state_name=="out":
						var shown: bool=bool(params.m_Visible)
						_emit(entry,"source_out_actor_shown" if shown else "source_out_actor_hidden",moment)
						for mesh in entry.hand.get("renderers",{}).values():
							if is_instance_valid(mesh):mesh.visible=shown
						if not bool(params.m_IgnoreSpells) and not entry.out.is_empty():entry.out.root.visible=shown
				"SetMaterialTexture":
					if hand_bindings.has(label) and key==str(hand_bindings[label].target_go_key):
						var texture=assets.load_texture(hand_bindings[label].texture_key)
						for mat in state.get("materials",{}).get(key,[]):
							if mat is ShaderMaterial:
								mat.set_shader_parameter("_MainTex",texture);mat.set_shader_parameter("_MainTexClamp",texture)
								mat.set_shader_parameter("_MainClamp",int(assets.objects[hand_bindings[label].texture_key].data.m_TextureSettings.m_WrapU)==1)
				"ActivateGameObject":
					if is_instance_valid(target):target.visible=bool(params.activate)
				"PlayAnimation","AnimationPlaythroughAction":
					if is_instance_valid(target):
						var path: String=str(state.root.get_path_to(target));if path==".":path=""
						var clip_name: String=params.get("animName",params.get("m_AnimName",""))
						var previous: Dictionary=entry.clip_players.get(state_name+key,{})
						var crossfade: float=float(params.get("m_CrossFadeSec",0.0))
						entry.clip_players[state_name+key]={"state":state,"path":path,"clip":clip_name,"start":moment,"crossfade":crossfade,"previous":previous,"initial_pose":assets.capture_float_pose(state,clip_name,path)}
						if crossfade>0.0:
							entry.crossfades.append({"clip":clip_name,"previous":previous.get("clip","source initial pose"),"start":moment,"duration":crossfade,"weight_model":"linear property blend; Unity native normalization not recovered"})
				"ParticlePlayAction":
					_emit(entry,"source_particle_play:"+key,moment)
					if state.get("particles",{}).has(key):
						var particle=Particles.new();particle.setup(state.particles[key],assets,entry.projection,int(entry.serial)*173+entry.particles.size())
						entry.particles.append(particle);entry.particle_players[state_name+key]={"node":particle,"start":moment}
				"ParticleStopAction":
					_emit(entry,"source_particle_stop:"+key,moment)
					if entry.particle_players.has(state_name+key):
						var player: Dictionary=entry.particle_players[state_name+key]
						if player.node.has_method("stop_emitting"):player.node.stop_emitting(moment-float(player.start))
				"SetParent":
					if is_instance_valid(target) and str(params.parent.get("path_id",""))=="0":
						target.reparent(entry.projection,bool(params.worldPositionStays));entry.detached.append(target)
		if state_name=="out" and str(schedule[index].state_name).to_lower().begins_with("none"):_release_out(entry,moment)
		index+=1
	entry.schedule_cursors[label]=index

func _release_out(entry: Dictionary,moment: float):
	if entry.out_cleaned:return
	entry.out_cleaned=true;_emit(entry,"out_actor_destroy",moment)
	for key in entry.clip_players.keys():
		if str(key).begins_with("out"):entry.clip_players.erase(key)
	if not entry.hand.is_empty() and is_instance_valid(entry.hand.root):
		entry.hand.root.visible=false;entry.hand.root.queue_free()
	entry.hand={};entry.out={}

func _collect_material_usage(entry: Dictionary):
	if game.headless:return
	var states: Array=[entry.hand,entry.out,entry["in"]]
	if game.spatial_scene.pieces.has(entry.unit.id):states.append(game.spatial_scene.pieces[entry.unit.id].actor)
	for state in states:
		for mesh in state.get("renderers",{}).values():
			if not is_instance_valid(mesh) or not mesh.is_visible_in_tree():continue
			if mesh.material_override!=null:_record_material(entry,mesh.material_override)
			else:
				for surface in range(mesh.mesh.get_surface_count()):_record_material(entry,mesh.get_surface_override_material(surface))
	for particle in entry.particles:
		if is_instance_valid(particle) and particle.mesh.get_surface_count()>0:_record_material(entry,particle.material)

func _record_material(entry: Dictionary,mat: Material):
	if not is_instance_valid(mat):return
	var key: String=mat.get_meta("source_key","")
	var shader_path: String=mat.shader.resource_path if mat is ShaderMaterial else "StandardMaterial3D"
	var record: Dictionary=assets.objects.get(key,{})
	var identity: String=key if key!="" else shader_path+":"+str(mat.get_meta("original_shader_id",""))
	if not entry.observed_materials.has(identity):
		entry.observed_materials[identity]={"source_key":key,"name":record.get("name","existing original card shader"),"source_shader":record.get("refs",{}).get(".m_Shader",mat.get_meta("original_shader_id","")),"production_shader":shader_path,"compatibility":mat.get_meta("compatibility","translated source formula; scene/backend compatibility"),"first_observed_age":entry.age}

func _has_event(entry: Dictionary,name: String) -> bool:
	return entry.events.any(func(event):return event.event==name)
func _emit(entry: Dictionary,name: String,time: float):
	entry.events.append({"event":name,"source_time":time,"observed_age":entry.age,"frame":Engine.get_process_frames()})
func _dispose(entry: Dictionary):
	history.append(_entry_audit(entry));if history.size()>32:history.pop_front()
	if not entry["in"].is_empty() and is_instance_valid(entry["in"].root):entry["in"].root.queue_free()
	if is_instance_valid(entry.container):entry.container.queue_free()
func actor_transformed(unit: Dictionary,old_key: String,dedicated_effect: String=""):
	for entry in instances.duplicate():
		if int(entry.unit.id)==int(unit.id):_cancel_entry(entry,"transformed_actor")
	transformations.append({"unit_id":unit.id,"from":old_key,"to":unit.key,"route":"same_entity_play_to_play","standard_spawn":false,"dedicated_transform_fx":dedicated_effect if dedicated_effect!="" else "not migrated; existing spell impact retained","source_clock":source_clock})
	if transformations.size()>32:transformations.pop_front()

func _cancel_entry(entry: Dictionary,reason: String):
	if entry.config.route=="hand" and str(entry.unit.key)==str(entry.key):entry.unit.hidden=false;entry.unit.animating=false;entry.unit.lift=0.0;entry.unit.scale=1.0
	entry.unit.erase("native_summon_hidden");entry.unit.erase("native_summon_position");entry.unit.erase("native_summon_rotation")
	_emit(entry,"cancelled",entry.age);entry.cancel_reason=reason;_dispose(entry);instances.erase(entry)
func cancel_unit(id:int):
	for entry in instances.duplicate():
		if int(entry.unit.id)==id:_cancel_entry(entry,"provisional_cancel")

func cancel_all():
	for entry in instances.duplicate():_cancel_entry(entry,"reset")
	camera_offset=Vector2.ZERO
func _entry_audit(entry: Dictionary) -> Dictionary:
	var result: Dictionary={"serial":entry.serial,"unit_id":entry.unit.id,"card":entry.key,"side":entry.side,"stage":entry.stage,"age":entry.age,"settled":entry.settled,"route":entry.config.duplicate(true),"events":entry.events.duplicate(true),"visual_missing":entry.visual_missing.duplicate(),"particles":[],"observed_materials":entry.observed_materials.values(),"crossfades":entry.crossfades.duplicate(true),"out_cleaned":entry.out_cleaned,"cancel_reason":entry.get("cancel_reason",""),"selected_hand_highlight_state":int(entry.source.get("source_actor_state",1)),"hand_highlight_state_basis":entry.source.get("source_actor_state_basis","none supplied; original setup disabled")}
	for particle in entry.particles:result.particles.append(particle.get_audit())
	return result
func get_audit() -> Dictionary:
	var active: Array=[]
	for entry in instances:active.append(_entry_audit(entry))
	return {"source_build":assets.manifest.get("build",""),"active":active,"history":history.duplicate(true),"active_count":instances.size(),"transformations":transformations.duplicate(true),"projection":("Source phone camera; raw source Card/Actor hierarchy, explicit anchors" if SourceProjection.from_game(game)!=null else "Godot fixed board orthographic registration, 15 degree compatibility view; not recovered original camera"),"clip_sampling":"original keys, tangents and source FSM waits; no baked animation","untranslated_materials":assets.material_audit.duplicate(),"native_pixel_equivalence":false}
