extends RefCounted
## Emote21 source route for the current bounded Mage/Warlock hero pool.
## Uses the existing original SoundManager router, including source category3.
const MANIFEST="res://assets/original_audio_v30/hand_full/runtime_extension.json"
var game
var extension:Dictionary={}
var scopes:Dictionary={}
var history:Array=[]
func setup(host):
 game=host;extension=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
func _router():
 if not is_instance_valid(game):return null
 var manager=game.get_node_or_null("/root/SoundManager")
 if not is_instance_valid(manager):return null
 var router=manager.get("original_audio")
 if not is_instance_valid(router):return null
 for key in extension.sound_defs:router.catalog.sound_defs[key]=extension.sound_defs[key]
 for key in extension.cards:
  if not router.catalog.cards.has(key):router.catalog.cards[key]={"card_id":key,"events":{}}
  router.catalog.cards[key].events.hand_full=extension.cards[key].events.hand_full
 return router
func play(entry:Dictionary)->Dictionary:
 var side:int=entry.side
 var hero_class:String=str(game.hero_classes[side])
 var key:String={"MAGE":"HERO_08","WARLOCK":"HERO_07"}.get(hero_class,"")
 var row:Dictionary={"event":"hand_full","emote_type":21,"ticket":entry.ticket,"side":side,"hero":key,"boundary":"source mill flight start, after draw-slot acquisition, one global turn gate"}
 var router=_router()
 if key=="":row.status="unrecovered_hero"
 elif not game.sound_enabled:row.status="game_sound_disabled"
 elif not is_instance_valid(router):row.status="router_unavailable"
 else:
  # CardSoundSpell.Play stops the previous same-source playback before replay.
  if scopes.has(key):router.stop_scope(scopes[key])
  var scope="hand-full:%d:%d"%[game.get_instance_id(),int(entry.ticket)]
  scopes[key]=scope
  row.request=router.play_event(key,"hand_full",{"scope_id":scope,"event_token":"emote21","source_side":side,"card_id":key})
  row.status="dispatched" if row.request.get("accepted",false) else row.request.get("reason","rejected")
  router.finish_scope(scope)
 history.append(row)
 while history.size()>128:history.pop_front()
 return row
func clear():
 var router=_router()
 if is_instance_valid(router):
  for scope in scopes.values():router.stop_scope(scope)
 scopes.clear()
