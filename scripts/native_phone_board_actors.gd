extends Node3D
## Original hero/power Actor hierarchies in one source-world reflection.
## Source shader failures stay hidden and auditable rather than using 2D fallbacks.
var game
var actors:Dictionary={}
var blockers:Array=[]
var last_advanced_frame:=-1
func setup(host):
 game=host;basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
func _make(key:String,side:int,kind:String)->Dictionary:
 var renderer=game.native_card_renderer
 var art=(0 if side==0 else 56) if kind=="hero" else (21 if side==0 else 57)
 var definition={"hp":game.health[side],"atk":0} if kind=="hero" else {"cost":2}
 var state=renderer.build_world_hero(key,definition,game.raw_portraits[art]) if kind=="hero" else renderer.build_world_hero_power(key,definition,game.raw_portraits[art])
 var card=Node3D.new();card.name="Source"+key;add_child(card);card.add_child(state.root)
 return {"root":card,"actor":state}
func sync():
 blockers.clear()
 var frame=Engine.get_process_frames()
 var advance=frame!=last_advanced_frame
 var delta=float(game.get("source_visual_delta")) if game.get("source_visual_delta")!=null else 0.0
 last_advanced_frame=frame
 if game.source_projection==null:return
 for side in range(2):
  for kind in ["hero","power"]:
   var key=kind+":"+str(side)
   if not actors.has(key):actors[key]=_make(key,side,kind)
   var entry=actors[key];var state:Dictionary=entry.actor
   if not state.materials_ready:
    entry.root.visible=false;blockers.append({"actor":key,"unresolved":state.unresolved_materials});continue
   var source_key=("friendly_" if side==0 else "opposing_")+kind
   var item:Dictionary=game.source_phone_layout.snapshot.items[source_key]
   entry.root.transform=item.source_pose
   entry.root.visible=not is_instance_valid(game.native_endgame) or game.native_endgame.hero_body_visible[side]
   if kind=="hero":game.native_card_renderer.update_world_character_stats(state,{"hp":game.health[side],"atk":0})
   else:
    var exhausted=bool(game.get("power_used")) if side==0 else bool(game.flow.enemy_power_used)
    # OnActorChanged -> ActivateStateSpells also plays Restore on initial false.
    game.native_card_renderer.set_world_power_exhausted(state,exhausted,true)
    if advance:game.native_card_renderer.advance_world_power_animation(state,delta)

