extends Node
## Presentation adapter only: existing 5834 rule fields are observed, never set.
## Source Actor/SpellTable/TagVisualConfiguration→original status prefab FSM.
const Assets=preload("res://scripts/native_state_assets.gd")
var game: Node
var assets=Assets.new()
var effects: Node
var audio: Node
var routes: Dictionary={}
var actor_reuse: Dictionary={}
var live: Dictionary={}
var instances: Dictionary={}
var clearing:=false
var history: Array=[]
var serial:=0
var source_missing: Array=[]
var observed_corruption: Array=[]
var terminal_hero_deaths: Dictionary={}
const KEYWORD_DEATH_DELAY: float=0.30000001192092896

func setup(owner_game: Node):
 game=owner_game;assets.setup(game.native_card_renderer,"res://assets/original_status_v34/")
 actor_reuse=JSON.parse_string(FileAccess.get_file_as_string("res://references/status_v34/actor_reuse.json"))
 routes=JSON.parse_string(FileAccess.get_file_as_string("res://references/status_v34/runtime_routes.json")).get("routes",{})
 audio=preload("res://scripts/native_status_audio.gd").new();add_child(audio);audio.setup_status(game)
 effects=preload("res://scripts/native_status_effects.gd").new();add_child(effects);effects.setup_status(game,assets,self,routes)
 for route in ["frozen_minion/root","frozen_hero/root","sleep/root","taunt/root"]:
  if not routes.has(route):source_missing.append(route)

func can_reuse_actor(old_card: String,new_card: String) -> bool:
 if old_card==new_card:return true
 for mapping in actor_reuse.get("mappings",[]):
  if str(mapping.from_card_id)==old_card and str(mapping.to_card_id)==new_card:return bool(mapping.reuse_actor) and not bool(mapping.update_actor)
 return false

func _unit_visible(unit: Dictionary) -> bool:
 return not unit.get("dead",true) and int(unit.get("hp",0))>0 and not unit.get("hidden",false) and not unit.get("native_summon_hidden",false)

func _wants_sleep(unit: Dictionary) -> bool:
 # EntityBase.IsAsleep 0x060138CE: numTurnsInPlay==0, attacksThisTurn==0,
 # no Charge/Rush/modern exceptions. Frozen is NOT a suppression condition.
 # summoning_sick is this bounded 5834 engine's numTurnsInPlay==0 equivalent.
 return bool(unit.get("summoning_sick",false)) and int(unit.get("attacks_used",0))==0 and game.definitions[unit.key].get("keyword","")!="冲锋"

func desired_states() -> Dictionary:
 var desired: Dictionary={};observed_corruption=[]
 if game.game_over:return desired
 for board in game._presentation_boards():
  for unit in board:
   var subject: String="unit:%d"%int(unit.id)
   if bool(unit.get("corrupted",false)):observed_corruption.append({"id":unit.id,"side":unit.side,"key":unit.key,"rule_state":true,"marker":"No persistent source effect in CS2_063e; finite skull impact remains in combat"})
   if unit.get("dead",true) or int(unit.get("hp",0))<=0:
    # Original normal minion body death starts first. WaitAndPrepare then
    # invokes keyword Death at t0+0.3, not at HP=0 or snapshot disappearance.
    var death: Dictionary=game.native_damage.dying.get(int(unit.id),{})
    if not death.is_empty() and float(game.native_damage.clock_seconds)<float(death.start)+KEYWORD_DEATH_DELAY:
     for identity in live:
      var held: Dictionary=live[identity]
      if held.subject==subject and str(held.key)==str(unit.key):desired[identity]={"subject":subject,"status":held.status,"unit":unit,"side":int(unit.side),"key":str(unit.key),"pos":unit.pos,"shown":not unit.get("hidden",false) and not unit.get("native_summon_hidden",false),"keyword_death_due":float(death.start)+KEYWORD_DEATH_DELAY}
    continue
   if not _unit_visible(unit):
    # Actor.Hide→HideSpellTable→Spell.Hide gates visibility without a Death
    # event, disposal or re-Birth. Keep existing live spells and do not spawn
    # a first hidden spell. Hidden tag changes reconcile when shown again.
    for identity in live:
     var held: Dictionary=live[identity]
     if held.subject==subject and str(held.key)==str(unit.key):desired[identity]={"subject":subject,"status":held.status,"unit":unit,"side":int(unit.side),"key":str(unit.key),"pos":unit.pos,"shown":false}
    continue
   var states: Array=[]
   if bool(unit.get("frozen",false)):states.append("frozen_minion")
   if _wants_sleep(unit):states.append("sleep")
   if game.definitions[unit.key].get("keyword","")=="嘲讽":states.append("taunt")
   for state in states:desired[subject+":"+state]={"subject":subject,"status":state,"unit":unit,"side":int(unit.side),"key":str(unit.key),"pos":unit.pos,"shown":true}
 for side in range(2):
  if game.hero_frozen[side] and game.health[side]>0:
   desired["hero:%d:frozen_hero"%side]={"subject":"hero:%d"%side,"status":"frozen_hero","unit":{},"side":side,"key":"HERO_07" if game.hero_classes[side]=="WARLOCK" else "HERO_08","pos":game.PLAYER_HERO if side==0 else game.ENEMY_HERO}
 return desired

func sync_from_game(delta: float=0.0):
 if game.game_over:_sync_terminal(maxf(delta,0.0));return
 var current_keys: Dictionary={}
 for board in game._presentation_boards():
  for unit in board:current_keys["unit:%d"%int(unit.id)]=str(unit.key)
 # Current ordinary Polymorph changes CardDef on the same source Actor. Do not
 # convert a cardID change into owner destruction or restart unchanged sleep.
 for identity in instances.keys():
  var entry: Dictionary=instances[identity]
  var next_key: String=str(current_keys.get(entry.subject,entry.key))
  if next_key!=str(entry.key) and can_reuse_actor(str(entry.key),next_key):
   history.append({"event":"same_actor_carddef_update","identity":identity,"from":entry.key,"to":next_key,"serial":entry.effect.serial,"time":game.indicator_time})
   entry.key=next_key;entry.effect.context.key=next_key
 # Actor ownership outlives a status Death/None, but not actual Actor release.
 for identity in instances.keys():
  var stored: Dictionary=instances[identity]
  if str(stored.subject).begins_with("unit:"):
   if not current_keys.has(stored.subject) or str(current_keys[stored.subject])!=str(stored.key):
    if live.has(identity):_retire(identity,"owner_released",true)
    else:effects.release_instance(stored.effect)
 var desired: Dictionary=desired_states()
 for identity in live.keys():
  var current: Dictionary=live[identity]
  if not desired.has(identity) or current.key!=desired[identity].key:
   var replaced: bool=current_keys.has(current.subject) and str(current_keys[current.subject])!=str(current.key)
   var is_unit: bool=str(current.subject).begins_with("unit:")
   var death: Dictionary=game.native_damage.dying.get(int(str(current.subject).get_slice(":",1)),{}) if is_unit else {}
   var owner_released: bool=is_unit and not current_keys.has(current.subject)
   var reason: String="actor_replaced" if replaced else ("owner_released" if owner_released else ("actor_death" if not death.is_empty() else "state_removed"))
   var moment: float=float(current.effect.age)
   if reason=="actor_death":
    var due: float=float(death.start)+KEYWORD_DEATH_DELAY
    moment+=clampf(delta-(float(game.native_damage.clock_seconds)-due),0.0,maxf(delta,0.0))
    current.effect.keyword_death={"body_origin":float(death.start),"due":due,"delay":KEYWORD_DEATH_DELAY,"dispatch_clock":float(game.native_damage.clock_seconds)}
   _retire(identity,reason,replaced or owner_released,moment)
 for identity in desired:
  var item: Dictionary=desired[identity]
  if not live.has(identity):_begin(identity,item)
  if live.has(identity):
   var entry: Dictionary=live[identity]
   entry.pos=item.pos;entry.shown=bool(item.get("shown",true))
   if not item.unit.is_empty():entry.effect.follow_unit=item.unit
   entry.effect.anchor=item.pos
 effects.advance(maxf(delta,0.0));effects.sync_projection()

func _begin(identity: String,item: Dictionary):
 var route_id: String=item.status+"/root"
 if not routes.has(route_id):return
 var reused: bool=instances.has(identity)
 var effect: Dictionary={}
 var context: Dictionary={"key":item.key,"side":item.side,"source":item.pos,"target":{"type":"unit","unit":item.unit,"pos":item.pos} if not item.unit.is_empty() else {"type":"hero","side":item.side,"pos":item.pos}}
 if reused:
  effect=instances[identity].effect
  effect.context=context;effect.cached_none=false
  if is_instance_valid(effect.container):effect.container.visible=bool(item.get("shown",true))
  effects._start_event(effect,"Birth",float(effect.age))
 else:
  serial+=1
  effect=effects._spawn_route(route_id,item.pos,"Birth",serial,context)
 if effect.is_empty():return
 effect.subject=item.subject;effect.status_name=item.status;effect.identity=identity
 if not item.unit.is_empty():effect.follow_unit=item.unit
 var entry: Dictionary={"subject":item.subject,"status":item.status,"key":item.key,"side":item.side,"pos":item.pos,"effect":effect,"shown":bool(item.get("shown",true))}
 live[identity]=entry;instances[identity]=entry
 history.append({"event":"birth_reused" if reused else "birth","identity":identity,"serial":effect.serial,"card_id":item.key,"source_root":effect.root_key,"time":game.indicator_time})
 _trim_history()

func _retire(identity: String,reason: String,instant: bool=false,moment: float=-1.0):
 var entry: Dictionary=live[identity];var effect: Dictionary=entry.effect
 if instant:effects.release_instance(effect)
 else:
  # The source spell remains attached during a Death tail while its original
  # Actor still exists; follow its pose until disposal instead of detaching.
  var followed: Dictionary=effect.get("follow_unit",{})
  if not followed.is_empty() and game.unit_by_id(int(followed.id)).is_empty():
   var retained: Dictionary=game.native_damage.dying.get(int(followed.id),{})
   if retained.is_empty():effect.erase("follow_unit")
   else:effect.follow_unit=retained.unit
  var event_age: float=float(effect.age) if moment<0.0 else moment
  # Preserve any earlier action in this frame before changing the FSM event.
  var previous_age: float=effect.age
  effect.age=event_age;effects._run_schedules(effect)
  effects._start_event(effect,"Death",event_age);effect.age=previous_age
 history.append({"event":"clear" if instant else "death","identity":identity,"reason":reason,"time":game.indicator_time})
 live.erase(identity);_trim_history()

func _trim_history():
 while history.size()>128:history.pop_front()

func clear(reason: String="clear"):
 clearing=true
 for identity in live.keys():_retire(identity,reason,true)
 if is_instance_valid(effects):effects.cancel_all()
 instances.clear();terminal_hero_deaths.clear();clearing=false
 observed_corruption=[]
 if is_instance_valid(audio):audio.clear()

func has_native_state(unit_id: int,state: String) -> bool:
 return live.has("unit:%d:%s"%[unit_id,state])

func get_audit() -> Dictionary:
 var rows: Array=[]
 for identity in live:
  var entry: Dictionary=live[identity]
  rows.append({"identity":identity,"subject":entry.subject,"status":entry.status,"card_id":entry.key,"side":entry.side,"source_root":entry.effect.root_key,"source_event":entry.effect.source_event,"age":entry.effect.age,"visual_available":not entry.effect.state.is_empty(),"shown":entry.get("shown",true),"keyword_death":entry.effect.get("keyword_death",{})})
 return {"active":rows,"active_count":rows.size(),"cached_instance_count":instances.size(),"cached_serials":instances.values().map(func(entry):return {"identity":entry.effect.identity,"serial":entry.effect.serial,"source_event":entry.effect.source_event,"cached_none":entry.effect.get("cached_none",false)}),"live_ids":live.keys(),"history":history.duplicate(true),"source_missing":source_missing.duplicate(),"effects":effects.get_audit() if is_instance_valid(effects) else {},"audio":audio.get_audit() if is_instance_valid(audio) else {},"corruption":observed_corruption.duplicate(true),"terminal_hero_deaths":terminal_hero_deaths.duplicate(true),"deathrattle":{"reachable":false,"reason":"No deathrattle card in 27 collectibles plus coin/sheep/mirror; legacy EX1_556 excluded"},"actor_reuse":actor_reuse.duplicate(true),"rules_mutated":false,"projection":"Original source local transforms under existing actor/15-degree board registration"}

func hero_graveyard_handoff(side: int):
 if terminal_hero_deaths.has(side):return
 var identity: String="hero:%d:frozen_hero"%side
 var record: Dictionary={"side":side,"source":"Card.Check_HeroToGraveyard 0x06012e28 IL001b oldActor.DoCardDeathVisuals","keyword_delay":0.0,"handoff":"local visible terminal origin; original zone and PLAYSTATE server-event spacing is unavailable","had_frozen_instance":live.has(identity),"clock":game.native_endgame.scaled_seconds if is_instance_valid(game.native_endgame) else 0.0}
 terminal_hero_deaths[side]=record
 if not live.has(identity):return
 var entry: Dictionary=live[identity]
 entry.effect.keyword_death=record.duplicate(true)
 _retire(identity,"hero_graveyard",false,float(entry.effect.age))
 history.append({"event":"hero_keyword_death_immediate","identity":identity,"source":record.source,"keyword_delay":0.0,"time":game.indicator_time})
 _trim_history()

func _sync_terminal(delta: float):
 # Preserve only an existing dead hero's frozen spell until its visible zone
 # handoff, then run the source Death tail. Other status ownership keeps v34's
 # terminal cleanup, so this narrow bridge never leaves minion indicators alive.
 for identity in instances.keys():
  var entry: Dictionary=instances[identity]
  var keep: bool=entry.status=="frozen_hero" and int(game.health[int(entry.side)])<=0
  if keep:continue
  if live.has(identity):_retire(identity,"game_over",true)
  else:effects.release_instance(entry.effect)
 effects.advance(delta);effects.sync_projection()
 for identity in instances.keys():
  var entry: Dictionary=instances[identity]
  if bool(entry.effect.get("cached_none",false)) and terminal_hero_deaths.has(int(entry.side)):
   effects.release_instance(entry.effect)
