extends Node
## Source end-game presentation only. Historical rule results and RNG stay owned
## by the existing game. Source Time.timeScale is a local presentation clock.
const BASE="res://assets/original_endgame_v33/"
var game: Node
var assets
var effects: Node
var audio: Node
var screen: Node
var match_generation:=1
var frame_id:=0
var clock_seconds:=0.0
var scaled_seconds:=0.0
var source_time_scale:=1.0
var saved_time_scale:=1.0
var camera_offset:=Vector2.ZERO
var state: String="idle"
var result: Dictionary={}
var history: Array=[]
var request_count:=0
var activation_count:=0
var source_roots: Array=[]
var source_ready:=false
var hero_body_visible: Array=[true,true]
var hero_details_visible: Array=[true,true]
var finished_heroes: Dictionary={}
var pending_screen:=false
var blockers: Array=[]
var seen_hero_deaths: Dictionary={}
var pending_hero_voice: Dictionary={}
var death_voice_history: Array=[]

func setup(owner_game: Node):
 game=owner_game
 if not FileAccess.file_exists(BASE+"manifest.json") or not FileAccess.file_exists("res://references/endgame_v33/runtime_routes.json"):
  blockers.append("Original end-game source manifest/routes unavailable");return
 assets=load("res://scripts/native_endgame_assets.gd").new();assets.setup(game.native_card_renderer)
 var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://references/endgame_v33/runtime_routes.json")).routes
 source_ready=["endgame_win/root","endgame_lose/root","endgame_draw_opponent/root"].all(func(id):return routes.has(id) and assets.objects.has(str(routes[id].root_key)))
 effects=load("res://scripts/native_endgame_effects.gd").new();add_child(effects);effects.setup_endgame(game,assets,self,routes)
 audio=load("res://scripts/native_endgame_audio.gd").new();add_child(audio);audio.setup(game)
 # Screen module is independently restored; the hero sample can run before it.
 if FileAccess.file_exists("res://references/endgame_v33/screen_ready.json") and ResourceLoader.exists("res://scripts/native_endgame_screen.gd"):
  screen=load("res://scripts/native_endgame_screen.gd").new();add_child(screen);screen.setup(game,assets)
  screen.source_event.connect(_on_screen_source_event);screen.closed.connect(_on_screen_closed)
 else:blockers.append("Original result screen module pending; hero source effects available")

func request(snapshot: Dictionary) -> bool:
 request_count+=1
 if state!="idle":
  history.append({"event":"duplicate_terminal_request_ignored","generation":match_generation,"at":clock_seconds});return false
 result=snapshot.duplicate(true);activation_count+=1
 state="waiting_source" if not source_ready else "heroes"
 history.append({"event":"terminal_result_accepted","generation":match_generation,"at":clock_seconds,"outcome":result.outcome,"dead_sides":result.dead_sides.duplicate()})
 if source_ready:_activate_heroes()
 return true

func _activate_heroes():
 saved_time_scale=source_time_scale
 var hero_ids: Dictionary={0:result.hero_cards[0],1:result.hero_cards[1]}
 audio.begin("endgame:"+str(match_generation),str(result.outcome),result.dead_sides,hero_ids)
 if not pending_hero_voice.is_empty():
  audio.trigger("hero_death",pending_hero_voice)
  history.append({"event":"hero_activation_stage","stage":"selected_character_vo_dispatched","order":history.size(),"side":pending_hero_voice.side,"generation":match_generation,"frame":frame_id,"at":clock_seconds,"timing_scope":"local dispatch call returned; not audible onset or original server packet time"})
  death_voice_history.append({"event":"selected_hero_voice_dispatched","side":pending_hero_voice.side,"card_id":pending_hero_voice.card_id,"gate":"offline terminal presentation handoff after atomic replay","wall_time":clock_seconds})
  pending_hero_voice={}
 # This voice is CardDef.DeathEffect, not the hero body spell's own sound.
 # DeathSpellController dispatches selected character VO before the ZONE
 # handoff; Check_HeroToGraveyard dispatches keyword Death immediately.
 # BlowUpHero's separate PLAYSTATE path also retires keywords before body.
 # Their original packet spacing is unavailable in this atomic local handoff.
 if is_instance_valid(game.native_status):
  for side in result.dead_sides:
   game.native_status.hero_graveyard_handoff(int(side))
   history.append({"event":"hero_activation_stage","stage":"keyword_death_handoff_dispatched","order":history.size(),"side":int(side),"generation":match_generation,"frame":frame_id,"at":clock_seconds,"timing_scope":"local dispatch call returned; not original server packet time"})
 var dispatch: Array=[]
 match str(result.outcome):
  "win":dispatch=[{"side":1,"kind":"win","spell_type":37}]
  "lose":dispatch=[{"side":0,"kind":"lose","spell_type":38}]
  "tie":dispatch=[{"side":1,"kind":"draw_opponent","spell_type":39},{"side":0,"kind":"lose","spell_type":38}]
 for item in dispatch:
  var side: int=item.side;finished_heroes[side]=false
  var route: String="endgame_"+str(item.kind)+"/root"
  var anchor: Vector2=game.PLAYER_HERO if side==0 else game.ENEMY_HERO
  var effect: Dictionary=effects._spawn_route(route,anchor,"Action",match_generation,{"key":item.kind,"side":side,"source":anchor,"target":{"type":"hero","side":side,"pos":anchor}})
  history.append({"event":"hero_activation_stage","stage":"hero_body_dispatched","order":history.size(),"side":side,"generation":match_generation,"frame":frame_id,"at":clock_seconds,"timing_scope":"local dispatch call returned; not original server packet time"})
  source_roots.append({"side":side,"spell_type":item.spell_type,"route":route,"root":effect.get("root_key",""),"serial":effect.get("serial",-1)})

func choose_death_voice(wave: Array,combat_pair: Array) -> int:
 # This is an audio-only copy of the local simultaneous death wave. The original
 # server PowerHistory task ordering is unavailable; no rule list is modified.
 var candidates: Array=wave.duplicate()
 var new_heroes: Array=[]
 for side in range(2):
  if game.health[side]>0 or seen_hero_deaths.has(side):continue
  seen_hero_deaths[side]=true;new_heroes.append(side)
  candidates.append({"unit":{"id":-1000-side,"key":"HERO_07" if game.hero_classes[side]=="WARLOCK" else "HERO_08","side":side},"hero":true})
 var selected: int=get_node("/root/SoundManager").original_audio.choose_death_index(candidates,combat_pair)
 var selected_id: int=-1
 if selected>=0:
  var chosen: Dictionary=candidates[selected];selected_id=int(chosen.unit.id)
  if chosen.get("hero",false):pending_hero_voice={"side":chosen.unit.side,"card_id":chosen.unit.key}
 if not new_heroes.is_empty():
  death_voice_history.append({"event":"death_wave_selection","hero_sides":new_heroes,"candidate_ids":candidates.map(func(c):return c.unit.id),"selected_id":selected_id,"selected_hero":selected>=0 and candidates[selected].get("hero",false),"source":"Shared original DeathSpellController selector; local audio-only wave adapter"})
 return selected_id

func observe_unprocessed_hero_death():
 for side in range(2):
  if game.health[side]<=0 and not seen_hero_deaths.has(side):
   choose_death_voice([],[]);return

func visual_time_scale() -> float:return source_time_scale

func advance(delta: float):
 frame_id+=1
 var wall: float=maxf(delta,0.0);clock_seconds+=wall
 var scaled: float=wall*source_time_scale;scaled_seconds+=scaled
 if is_instance_valid(effects):
  effects.advance(scaled);camera_offset=effects.camera_offset
  # GameEntity.HideOtherElements starts after ActivateSpellForDestroyedHero,
  # and waits .5 scaled seconds. It hides details, never the portrait root.
  for effect in effects.effects:
   var side: int=int(effect.context.side)
   if hero_details_visible[side] and float(effect.age)>=.5:
    hero_details_visible[side]=false
    history.append({"event":"hero_details_hidden","side":side,"source_scaled_age":effect.age,"wall_time":clock_seconds,"source":"GameEntity.HideOtherElements06005568 WaitForSeconds(.5)"})
 if pending_screen:
  pending_screen=false;_show_result()
 if is_instance_valid(screen):screen.advance(scaled)

func sync():
 if is_instance_valid(effects):effects.sync_projection()
 if is_instance_valid(screen):screen.sync()

func set_source_time_scale(effect: Dictionary,value: float):
 source_time_scale=value
 effect.last_time_scale=value

func set_hero_body_visible(side: int,visible: bool,moment: float):
 hero_body_visible[side]=visible
 history.append({"event":"hero_root_visibility","side":side,"visible":visible,"source_scaled_age":moment,"wall_time":clock_seconds})

func assign_actor_portrait(effect: Dictionary,root_key: String,moment: float):
 var side: int=effect.context.side
 var label: String="guldan_portrait" if str(result.hero_cards[side])=="HERO_07" else "jaina_portrait"
 var texture_key: String=assets.manifest.root_labels[label]
 var texture: Texture2D=assets.load_texture(texture_key)
 var count:=0
 if not game.headless:
  for key in effects._descendants(root_key):
   var node: Node3D=effect.state.nodes.get(key)
   if not is_instance_valid(node) or not node.is_visible_in_tree():continue
   count+=assets.bind_hero_portrait(effect.state.materials.get(key,[]),texture)
 history.append({"event":"source_assign_portrait","side":side,"texture":texture_key,"materials":count,"source_scaled_age":moment})

func on_source_audio_action(effect: Dictionary,action: Dictionary,moment: float):
 if str(action.class_name)!="AudioPlaythroughAction":return
 var kind: String=str(effect.context.key)
 if kind=="draw_opponent":kind="draw"
 var phase: String=str(effect.get("current_state","")).replace("State ","state")
 audio.trigger(kind+"_"+phase,{"side":effect.context.side})

func on_source_callback(effect: Dictionary,callback: Dictionary,moment: float):
 if str(callback.event)!="OnSpellFinished" or str(effect.source_event)!="Action":return
 finished_heroes[int(effect.context.side)]=true
 history.append({"event":"hero_spell_finished","side":effect.context.side,"route":effect.route_id,"source_scaled_age":moment,"wall_time":clock_seconds})
 pending_screen=not finished_heroes.is_empty() and finished_heroes.values().all(func(done):return done)

func _show_result():
 # GameEntity.ShowEndGameScreenAfterEffects restores the saved Mgr scale before
 # EndGameScreen.Show. It does not destroy the hero spell or its particle tails.
 source_time_scale=saved_time_scale
 if is_instance_valid(screen):
  state="result";screen.show(result)
 else:state="waiting_screen"
 history.append({"event":"all_hero_spells_finished","wall_time":clock_seconds,"scaled_time":scaled_seconds,"restored_scale":source_time_scale})

func _on_screen_source_event(event: String):
 if not is_instance_valid(audio):return
 if event=="Action":audio.screen_show()
 elif event=="Death":audio.screen_close()

func request_continue() -> bool:
 if state!="result" or not is_instance_valid(screen) or not screen.can_close():return false
 if not screen.close():return false
 state="closing"
 history.append({"event":"source_screen_close_requested","wall_time":clock_seconds})
 return true

func _on_screen_closed():
 if state=="closing":call_deferred("_restart_after_close",match_generation)

func _restart_after_close(generation: int):
 if generation==match_generation and state=="closing":game.restart_match()

func clear(restore_bgm: bool=true):
 if is_instance_valid(effects):effects.cancel_all()
 if is_instance_valid(screen):screen.clear()
 if is_instance_valid(audio):audio.clear(restore_bgm)
 match_generation+=1;frame_id=0;clock_seconds=0.0;scaled_seconds=0.0
 state="idle";result.clear();request_count=0;activation_count=0;source_roots.clear();history.clear()
 source_time_scale=1.0;saved_time_scale=1.0;camera_offset=Vector2.ZERO
 hero_body_visible=[true,true];hero_details_visible=[true,true];finished_heroes.clear();pending_screen=false
 seen_hero_deaths.clear();pending_hero_voice={};death_voice_history.clear()

func get_audit() -> Dictionary:
 return {"match_generation":match_generation,"state":state,"outcome":result.get("outcome",""),"winner_side":result.get("winner_side",-1),"dead_sides":result.get("dead_sides",[]).duplicate(),"result":result.duplicate(true),"requests":request_count,"activations":activation_count,"source_ready":source_ready,"source_roots":source_roots.duplicate(true),"history":history.duplicate(true),"death_voice_history":death_voice_history.duplicate(true),"blockers":blockers.duplicate(),"wall_time":clock_seconds,"scaled_time":scaled_seconds,"time_scale":source_time_scale,"hero_body_visible":hero_body_visible.duplicate(),"hero_details_visible":hero_details_visible.duplicate(),"effects":effects.get_audit() if is_instance_valid(effects) else {},"audio":audio.get_audit() if is_instance_valid(audio) else {},"screen":screen.get_audit() if is_instance_valid(screen) else {},"compatibility":["Original local geometry under existing fixed board/camera registration","TimeScale is applied to migrated presentation, never to historical rule resolution","Simultaneous tie scripts use deterministic enemy-before-friendly order; native Unity same-priority Update order is not recoverable from CIL","No account XP, rewards, pets, or premium hero overrides are invented","Hero VO uses one shared local death-wave selection then the terminal presentation handoff; original server task ordering and its timing relative to PLAYSTATE are not available"]}
