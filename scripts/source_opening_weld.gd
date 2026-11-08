extends Node
const Audio=preload("res://scripts/source_opening_audio.gd")
## Original HeroWeld.DoAnim0x06015267 and DestroyWhenFinished0x0601526c.
## Authored hierarchy/clip/events; explicit Godot particle/light compatibility.
const Assets=preload("res://scripts/source_opening_assets.gd")
const Manifest=preload("res://scripts/native_source_manifest.gd")
const Curves=preload("res://scripts/native_summon_curves.gd")
const Particles=preload("res://scripts/native_combat_particles.gd")
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const PREFIX="cab-69c88b234dfa427e02d1fcee9337ae34:"
const ROOT=PREFIX+"-6011637508256998738"
const DESTROY_SECONDS:float=5.0
signal audio_requested(side:int)
var game
var assets
var world:Node3D
var states:Array=[]
var active:=false
var last_age:float=-1.0
var play_source_audio:bool=true
var rng:=RandomNumberGenerator.new()
var audit:Dictionary={"limitations":["Godot source ParticleSystem solver, not Unity RNG/integration parity","Godot OmniLight attenuation/color-space compatibility; unlit source shaders do not consume dynamic lights"],"suppressed_renderers":[],"audio":"Original decoded full weld WAV, volume1, one independent player per hero; audio_requested informational unless play_source_audio=false"}

func setup(host,source_assets,parent_world:Node3D)->void:
	game=host;world=parent_world;rng.randomize()
	assets=Assets.new();assets.setup(source_assets.renderer)
	assets.objects=assets.objects.duplicate()
	var weld:Dictionary=Manifest.load_manifest("res://assets/original_opening/weld.json")
	assets.objects.merge(weld.objects,true)
	assets.mesh_color_channels=assets.mesh_color_channels.duplicate()
	# Original mesh channel3 format2 (UNorm8), stream0 offset28 dimension4.
	assets.mesh_color_channels["cab-66e7137de3b79380e05eb711ae004556:-6718253660262085907"]={"normalization_divisor":255.0}
	assets._prepare_render_order()
	for key in weld.objects:
		var record:Dictionary=weld.objects[key]
		if record.type=="AnimationClip":assets.clips[record.name]=record;assets.clips[key]=record

func begin(source_positions:Array=[])->void:
	clear()
	var positions:Array=source_positions.duplicate()
	if positions.is_empty():
		for side in range(2):
			var entry:Dictionary=game.spatial_scene.phone_board_actors.actors.get("hero:"+str(side),{})
			if entry.is_empty():
				audit.limitations.append("Missing hero:"+str(side)+" source pose; weld not instantiated")
				return
			positions.append(SourceProjection.render_to_source(entry.actor.root.global_position))
	for side in range(positions.size()):
		var state:Dictionary=assets.instantiate_opening(ROOT,world,false)
		state.root.position=positions[side];state.root.visible=true
		state["lights"]={};state["weld_players"]={};state["blocked"]={}
		for key in state.nodes:
			var light:Dictionary=assets.component(key,"Light")
			if light.is_empty():continue
			var node:=OmniLight3D.new();state.nodes[key].add_child(node)
			node.light_color=Curves.color(light.data.m_Color)
			node.light_energy=float(light.data.m_Intensity);node.omni_range=float(light.data.m_Range)
			node.shadow_enabled=false;node.visible=true
			node.set_meta("source_light",light.key);node.set_meta("source_culling_mask",light.data.m_CullingMask.m_Bits)
			state.lights[key]=node
		for key in state.materials:
			for material in state.materials[key]:
				if material!=null and str(material.get_meta("compatibility","")).begins_with("Untranslated"):
					state.blocked[key]=true;audit.suppressed_renderers.append(key)
		states.append(state)
		if play_source_audio and Audio.permitted(game):
			var path:String="res://assets/original_opening/audio/hero_weld_FX_GameStart_HeroCoin_EmblemSear_FULL.wav"
			if ResourceLoader.exists(path):
				var audio:=AudioStreamPlayer.new();audio.bus=&"SFX";state.root.add_child(audio)
				audio.stream=load(path);audio.volume_db=0.0;audio.play()
				state["audio"]=audio
			else:audit.limitations.append("Exact hero weld WAV missing")
		audio_requested.emit(side)
	active=true;last_age=-1.0
	advance(0.0)

func _event_targets(event_name:String)->String:
	if event_name.ends_with("andChilds3"):return PREFIX+"5638255445322783406"
	if event_name.ends_with("andChilds2"):return PREFIX+"-2404861325214328146"
	if event_name.ends_with("andChilds"):return PREFIX+"-4481128936512857426"
	return ""

func _particle_event(state:Dictionary,event_name:String,event_age:float)->void:
	var target:Node3D=state.nodes.get(_event_targets(event_name))
	if target==null:return
	for key in state.particles:
		var spec:Dictionary=state.particles[key]
		if spec.node!=target and not target.is_ancestor_of(spec.node):continue
		if event_name.begins_with("Stop"):
			if state.weld_players.has(key):
				var row:Dictionary=state.weld_players[key]
				row.node.stop_emitting(maxf(0.0,event_age-float(row.start)))
			continue
		if state.weld_players.has(key):continue
		if spec.renderer.is_empty():continue
		var player=Particles.new();var copy:Dictionary=spec.duplicate()
		copy.autoplay=true;copy.source_scope_root=world;copy.compatibility_basis=world.global_basis
		player.setup(copy,assets,world,rng.randi())
		state.weld_players[key]={"node":player,"start":event_age}

func _sample(state:Dictionary,age:float)->void:
	assets.sample_clip(state,"HeroWeldIn",age)
	# Common clip sampler handles intensity but not color-channel Light curves.
	for track in assets.clips.HeroWeldIn.data.get("m_FloatCurves",[]):
		if int(track.classID)!=108 or not str(track.attribute).begins_with("m_Color."):continue
		var target:Node3D=state.paths.get(str(track.path))
		if target==null:continue
		var key:String=target.get_meta("source_key","")
		if not state.lights.has(key):continue
		var color:Color=state.lights[key].light_color
		var channel:int=["r","g","b","a"].find(str(track.attribute).get_slice(".",1))
		if channel>=0:color[channel]=Curves.scalar_keys(track.curve.m_Curve,age)
		state.lights[key].light_color=color
	for materials in state.materials.values():
		for material in materials:
			if material is ShaderMaterial:material.set_shader_parameter("_UnityTimeX",float(game.elapsed)/20.0)
	for key in state.blocked:
		if state.renderers.has(key):state.renderers[key].visible=false

func advance(age:float)->void:
	if not active:return
	if age>=DESTROY_SECONDS:clear();return
	age=maxf(0.0,age)
	if age<last_age:
		audit.limitations.append("Weld seek backwards unsupported; call begin again")
		return
	for state in states:
		for event in assets.clips.HeroWeldIn.data.get("m_Events",[]):
			var time:float=float(event.time)
			if time>last_age and time<=age:
				_sample(state,time)
				_particle_event(state,str(event.functionName),time)
		_sample(state,age)
		for row in state.weld_players.values():
			row.node.seek(maxf(0.0,age-float(row.start)))
			if row.node.material is ShaderMaterial:row.node.material.set_shader_parameter("_UnityTimeX",float(game.elapsed)/20.0)
	last_age=age

func clear()->void:
	for state in states:
		if state.has("audio") and is_instance_valid(state.audio):
			Audio.stop_tree(state.audio)
		for light in state.get("lights",{}).values():
			if is_instance_valid(light):light.visible=false
		for row in state.get("weld_players",{}).values():
			if is_instance_valid(row.node):row.node.queue_free()
		if is_instance_valid(state.root):state.root.queue_free()
	states.clear();active=false;last_age=-1.0
