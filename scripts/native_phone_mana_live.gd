extends Node3D
## ManaCrystal source state machine. Caller owns source identity and source pose.
const Particle=preload("res://scripts/native_combat_particles.gd")
const GEM="cab-69c88b234dfa427e02d1fcee9337ae34:-8487740772885620839"
const TEMP="cab-3563ba8b89db13ca6eb196aa111591f1:1211368574384928431"
const TEMP_PROPOSED="cab-3563ba8b89db13ca6eb196aa111591f1:-5472448365763917293"
var assets
var state:Dictionary={}
var spawn_state:Dictionary={}
var spawn_clip:=""
var destroy_state:Dictionary={}
var destroy_started:=-1.0
var finished:=false
var destroy_action_started:=-1.0
var shake_initial:=Vector3.ZERO
var shake_rng=RandomNumberGenerator.new()
var source_sound_events:Array=[]
var audio_results:Array=[]
var source_active:=true
var temporary:=false
var desired_state:=0
var visible_state:=0
var animation_target:=0
var clip:=""
var clip_time:=0.0
var clip_started:=0.0
var playing:=false
var birth_played:=false
var in_game:=true
var blockers:Array=[]
var particle_players:Dictionary={}
var particle_specs:Dictionary={}
var particle_started:Dictionary={}
var elapsed:=0.0
var event_index:=0
var event_routes:Dictionary={}
func setup(source_assets,is_temporary:bool=false,already_present:bool=false):
 assets=source_assets;temporary=is_temporary;in_game=not already_present
 shake_rng.seed=530579
 state=assets.instantiate(GEM,self);state.root.visible=true
 if temporary:
  _replace_material("",TEMP);_replace_material("Proposed_Quad",TEMP_PROPOSED)
 for key in state.particles:
  particle_specs[key]=state.particles[key]
 # A source animation callback table is required, never guess targets by names.
 var file="res://assets/native_phone_mana/event_routes.json"
 if FileAccess.file_exists(file):event_routes=JSON.parse_string(FileAccess.get_file_as_string(file))
 for reason in assets.strict_blockers:_block(reason)
func _block(reason:String):
 if not blockers.has(reason):blockers.append(reason)
func _replace_material(path:String,key:String):
 var node=state.paths.get(path)
 if node==null:_block("Missing source material target "+path);return
 var go=str(node.get_meta("source_key",""));var mat=assets.material(key)
 if mat==null:_block("Missing source material "+key);return
 state.renderers[go].set_surface_override_material(0,mat);state.materials[go]=[mat]
static func transition_name(from:int,to:int,temp:bool)->String:
 match Vector2i(from,to):
  Vector2i(0,1):return "ManaGemUsed"
  Vector2i(1,0):return "ManaGem_Restore"
  Vector2i(0,2):return "ManaGemProposed_Temp" if temp else "ManaGemProposed"
  Vector2i(2,0):return "ManaGemProposed_Cancel_Temp" if temp else "ManaGemProposed_Cancel"
  Vector2i(1,2):return "ManaGemUsed_Proposed"
  Vector2i(2,1):return "ManaGemProposed_Used"
 return ""
func request_state(value:int):
 if desired_state==3:return
 if value<0 or value>3:_block("Invalid source mana state");return
 desired_state=value
 if value==3:
  if not playing:_begin_destroy()
  return
 _update_transition()
func create():
 if playing or desired_state==3:return
 birth_played=true
 _play("ManaGemBirth_Temp" if temporary else "ManaGemBirth",0)
 var spawn_key="cab-69c88b234dfa427e02d1fcee9337ae34:"+("444880502752515993" if temporary else "-7390460722471725159")
 spawn_state=assets.instantiate(spawn_key,self);spawn_state.root.visible=true
 spawn_clip="mana_spawn_edit_temp" if temporary else "mana_spawn_edit"
 assets.sample_clip(spawn_state,spawn_clip,0.0)
 for reason in assets.strict_blockers:_block(reason)
 for event in assets.clips[spawn_clip].data.get("m_Events",[]):
  if str(event.functionName)=="PlayDefaultSound":
   source_sound_events.append(event.duplicate(true));_audio("temporary_mana_birth")
  else:_block("Unresolved spawn animation callback "+str(event.functionName))
func _update_transition():
 if playing or desired_state==3 or desired_state==visible_state:return
 if in_game and not birth_played:return
 _play(transition_name(visible_state,desired_state,temporary),desired_state)
func _play(name:String,target:int):
 if name=="" or not assets.clips.has(name):_block("Missing source mana clip "+name);return
 clip=name;clip_time=0.0;clip_started=elapsed;animation_target=target;event_index=0;playing=true
 _sample(0.0)
func advance(delta:float):
 elapsed+=maxf(delta,0.0)
 if playing:
  clip_time=minf(clip_time+maxf(delta,0.0),assets.clip_length(clip));_sample(clip_time)
  if clip_time>=assets.clip_length(clip):playing=false;visible_state=animation_target
 for key in particle_players:particle_players[key].seek(elapsed-float(particle_started[key]))
 if desired_state==3 and not playing and destroy_started<0.0:_begin_destroy()
 if destroy_started>=0.0 and not temporary and destroy_action_started<0.0:
  var age=elapsed-destroy_started
  assets.sample_clip(state,"ManaGemDestroy",minf(age,assets.clip_length("ManaGemDestroy")))
  var fade=1.0-clampf(age/0.5,0.0,1.0)
  var amount=Vector3(0.05000000074505806,0.10000000149011612,0.05000000074505806)*fade
  # Original iTween is world-space initial+independent Random.Range each frame.
  # Godot RNG/actual caller cadence is compatibility, not Unity RNG parity.
  var offset=Vector3(shake_rng.randf_range(-amount.x,amount.x),shake_rng.randf_range(-amount.y,amount.y),shake_rng.randf_range(-amount.z,amount.z))
  state.root.global_position=shake_initial+Vector3(offset.x,offset.y,-offset.z)
  if age>=0.5:_enter_destroy_action(destroy_started+0.5)
 if destroy_action_started>=0.0 and elapsed-destroy_action_started>=1.0:
  finished=true
  for player in particle_players.values():player.source_destroy()
 visible=blockers.is_empty() and not finished
 _update_transition()
func _sample(seconds:float):
 assets.sample_clip(state,clip,seconds)
 if not spawn_state.is_empty() and clip in ["ManaGemBirth","ManaGemBirth_Temp"]:assets.sample_clip(spawn_state,spawn_clip,minf(seconds,assets.clip_length(spawn_clip)))
 var events:Array=assets.clips[clip].data.get("m_Events",[])
 while event_index<events.size() and float(events[event_index].time)<=seconds:
  _event(events[event_index]);event_index+=1
 # class88 curves address the legacy disabled emitters in this prefab. They
 # are retained but must not be retargeted to the new systems without evidence.
 # Missing legacy Point light tracks are no-ops, as no Light component exists.
func _event(event:Dictionary):
 var name=str(event.functionName)
 if not event_routes.has(name):_block("Unresolved source mana callback "+name);return
 for operation in event_routes[name]:
  var key=str(operation.target)
  if not particle_specs.has(key):_block("Source callback target absent "+key);continue
  var event_time=clip_started+float(event.time)
  if operation.action=="play":_start_particle(key,event_time)
  elif operation.action=="stop" and particle_players.has(key):particle_players[key].stop_emitting(event_time-float(particle_started[key]))
func _start_particle(key:String,at:float):
 # Called only for a verified source Play event. Independent compatibility RNG.
 if particle_players.has(key):
  _block("Source ParticleSystem.Play resume semantics not yet ported");return
 var spec:Dictionary=particle_specs[key].duplicate();spec.autoplay=true
 var player=Particle.new();player.setup(spec,assets,self,83011+particle_players.size())
 particle_players[key]=player;particle_started[key]=at
 player.seek(maxf(0.0,elapsed-at))
 for reason in player.unsupported:_block("Mana particle "+key+": "+str(reason))
func audit()->Dictionary:
 return {"ready":blockers.is_empty(),"desired_state":desired_state,"visible_state":visible_state,"clip":clip,"clip_time":clip_time,"playing":playing,"source_active":source_active,"hidden_animation_compatibility":"Hidden gem/spawn are not rendered; source clip clock continues and initial audio event stays immediate. Unity Legacy Animation inactive isPlaying/time-zero event equivalence is unverified." if not source_active else "","birth_played":birth_played,"blockers":blockers.duplicate(),"particles":particle_players.size(),"finished":finished,"destroy_started":destroy_started,"destroy_action_started":destroy_action_started,"sound_events":source_sound_events.duplicate(true),"audio_results":audio_results.duplicate(true)}

func _begin_destroy():
 destroy_started=elapsed
 if not temporary:
  _audio("normal_mana_destroy")
  shake_initial=state.root.global_position
  assets.sample_clip(state,"ManaGemDestroy",0.0)
  return
 _enter_destroy_action(elapsed)
func _enter_destroy_action(at:float):
 destroy_action_started=at
 if temporary:_audio("temporary_mana_destroy")
 var source_id="809484295395645337" if temporary else "-5725931659908507751"
 destroy_state=assets.instantiate("cab-69c88b234dfa427e02d1fcee9337ae34:"+source_id,self)
 destroy_state.root.visible=true;state.root.visible=false
 for key in destroy_state.particles:particle_specs[key]=destroy_state.particles[key]
 var ids=["2520266025434781593","4622594020881176473"] if temporary else ["-1162864041860622439","-5898140158092077159","669536401333655449","7132199635193599897"]
 for id in ids:
  var key="cab-69c88b234dfa427e02d1fcee9337ae34:"+id
  if particle_specs.has(key):_start_particle(key,at)
  else:_block("Missing original destroy particle "+key)
 for reason in assets.strict_blockers:_block(reason)
 source_sound_events.append({"source":("Temp_ManaDestroy/State 3/AudioPlayClipAction" if temporary else "ManaDestroy/State 3/AudioPlaythroughAction"),"at":at})

func prime_state(value:int)->bool:
 # Only initial registration of an already existing source object. This is not
 # a runtime transition and must never be used to skip a live Birth/animation.
 if in_game or playing or elapsed>0.0 or not value in [0,1,2]:return false
 desired_state=value;visible_state=value
 if value!=0:
  var name=transition_name(0,value,temporary)
  assets.sample_clip(state,name,assets.clip_length(name))
 return true

func _audio(event:String):
 var sound=get_node_or_null("/root/SoundManager")
 if sound==null:audio_results.append({"accepted":false,"event":event,"reason":"sound_manager_unavailable"});return
 var context={"scope_id":"native-mana:"+str(get_instance_id())+":"+event,"event_token":event,"source_side":0}
 var result=sound.play_original_event("@mana","destroy",context) if event=="normal_mana_destroy" else sound.play_phone_source_audio(event,context)
 if event=="normal_mana_destroy" and result.get("accepted",false):sound.original_audio.finish_scope(context.scope_id)
 result.event=event;audio_results.append(result)

func set_source_active(value:bool):
 # Source ManaCrystal.Hide/Show toggles Gem and the selected Spawn only. The
 # ManaCrystal root and destroy sibling stay active, retaining identity/lifetime.
 source_active=value
 if not state.is_empty():state.root.visible=value and destroy_action_started<0.0
 if not spawn_state.is_empty():spawn_state.root.visible=value
