extends RefCounted
## One-shot fresh scene allocations. Never returns a previously played effect.
static var enabled:bool=true
const SkinSolver=preload("res://scripts/native_archer_skin.gd")
const ProjectionPolicy=preload("res://scripts/source_board_projection.gd")
var host:Node
var game:Node
var assets
var staging:Node3D
var roots:Array=[]
var ready:Dictionary={}
var pending:Dictionary={}
var hits:int=0
var misses:int=0
var refills:int=0
var steps:int=0
var prepare_usec:int=0
var stage_usec:Dictionary={"instantiate":0,"skin":0}
var stage_max_usec:Dictionary={"instantiate":0,"skin":0}
var step_rows:Array=[] # Bounded wall-clock markers for continuous-frame correlation.
var last_frame:int=-1
var idle_last_frame:int=-1
var idle_frames:int=0
var disposed:bool=false
static func available()->bool:
 return enabled and OS.get_name()=="Windows" and RenderingServer.get_current_rendering_method()=="forward_plus"
func setup(owner:Node,owner_game:Node,source_assets,routes:Dictionary):
 host=owner;game=owner_game;assets=source_assets
 for route in ["CS2_189/missile","CS2_189/impact"]:
  if routes.has(route):roots.append(str(routes[route].root_key))
 staging=Node3D.new();staging.name="PreparedArcherStaging"
 staging.visible=false;staging.process_mode=Node.PROCESS_MODE_DISABLED
 host.add_child(staging) # Outside spatial_scene's transmission/capture traversal.
func prepare_step()->bool:
 if disposed:return true
 var started:int=Time.get_ticks_usec()
 var step_frame:int=Engine.get_process_frames()
 var loading:bool=is_instance_valid(game) and bool(game.get("native_initial_loading"))
 var stage:String="skin" if not pending.is_empty() else "instantiate"
 if not pending.is_empty():
  var token:Dictionary=pending
  var state:Dictionary=token.state
  var old_renderers:Dictionary=state.renderers.duplicate()
  var old_materials:Dictionary=state.materials.duplicate()
  var skin=SkinSolver.new();skin.setup(assets,state)
  token.skin=skin
  for s in skin.skinned:s.instance.get_parent().remove_child(s.instance)
  state.renderers=old_renderers;state.materials=old_materials
  ready[token.root_key]=token;pending={};refills+=1
 else:
  var key:String=""
  for candidate in roots:
   if not ready.has(candidate):key=candidate;break
  if key.is_empty():return true
  var container=Node3D.new();staging.add_child(container)
  var projection=Node3D.new();container.add_child(projection)
  var reflected:bool=ProjectionPolicy.from_game(game)!=null
  projection.basis=ProjectionPolicy.REFLECTION if reflected else Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*(0.78*0.9)
  pending={"root_key":key,"container":container,"projection":projection,"state":assets.instantiate(key,projection),"reflected":reflected,"assets":assets}
  pending.state.root.visible=true
 var cost:int=Time.get_ticks_usec()-started
 step_rows.append({"stage":stage,"frame":step_frame,"started_usec":started,"cost_usec":cost,"loading":loading})
 if step_rows.size()>64:step_rows.pop_front()
 steps+=1;prepare_usec+=cost;stage_usec[stage]+=cost;stage_max_usec[stage]=maxi(stage_max_usec[stage],cost)
 return ready.size()==roots.size() and pending.is_empty()
func take(key:String)->Dictionary:
 if disposed or not roots.has(key):return {}
 if not ready.has(key):misses+=1;return {}
 var token:Dictionary=ready[key];ready.erase(key)
 if token.assets!=assets or bool(token.reflected)!=(ProjectionPolicy.from_game(game)!=null):
  _free_token(token);misses+=1;return {}
 hits+=1
 return token
func install(token:Dictionary,state:Dictionary):
 var skin=token.skin
 for s in skin.skinned:
  s.node.add_child(s.instance)
  var key:String=str(s.node.get_meta("source_key",""))
  state.renderers[key]=s.instance;state.materials[key]=s.materials
 # Final pose changed, but static source inputs/templates remain valid.
 for s in skin.skinned:
  if s.has("cache"):s.cache.last_matrices=PackedByteArray()
 skin._skin()
 token.erase("skin")
 return skin
func _refill_guards_clear()->bool:
 if not host.effects.is_empty() or not host.archer_shots.is_empty():return false
 if game.busy or game.native_initial_loading or game.drag_index>=0 or game.selected_unit>=0 or not game.pending_battlecry.is_empty():return false
 if is_instance_valid(game.native_summon) and not game.native_summon.instances.is_empty():return false
 if game.targeting_power:return false
 if is_instance_valid(game.native_combat) and (not game.native_combat.instances.is_empty() or not game.native_combat.prepared.is_empty() or not game.native_combat.prepared_spell.is_empty()):return false
 if is_instance_valid(game.native_death) and not game.native_death.active.is_empty():return false
 if is_instance_valid(game.native_damage):
  for entry in game.native_damage.entries.values():
   if bool(entry.get("active",false)):return false
 return true
func refill_if_idle():
 if disposed:return
 var frame:int=Engine.get_process_frames()
 if not _refill_guards_clear():
  idle_frames=0;idle_last_frame=-1
  return
 if frame==idle_last_frame:return
 idle_frames=mini(idle_frames+1,3) if frame==idle_last_frame+1 else 1
 idle_last_frame=frame
 # Let two complete quiet frames drain deferred frees/transmission changes.
 if idle_frames<=2 or frame==last_frame:return
 last_frame=frame;prepare_step()
func _free_token(token:Dictionary):
 if token.has("skin"):
  for s in token.skin.skinned:
   if is_instance_valid(s.instance) and s.instance.get_parent()==null:s.instance.free()
  token.erase("skin")
 if is_instance_valid(token.get("container")):token.container.free()
func dispose():
 if disposed:return
 disposed=true
 for token in ready.values():_free_token(token)
 ready.clear()
 if not pending.is_empty():_free_token(pending);pending={}
 if is_instance_valid(staging):staging.free()
 staging=null;host=null;game=null;assets=null
func audit()->Dictionary:
 var node_count:int=0;var detached:int=0;var mesh_bytes:int=0
 var tokens:Array=ready.values()
 if not pending.is_empty():tokens.append(pending)
 for token in tokens:
  var nodes:Array=[token.container]
  while not nodes.is_empty():
   var node:Node=nodes.pop_back();node_count+=1;nodes.append_array(node.get_children())
  if token.has("skin"):
   for s in token.skin.skinned:
    detached+=1
    for surface in range(s.mesh.get_surface_count()):mesh_bytes+=var_to_bytes(s.mesh.surface_get_arrays(surface)).size()
 return {"enabled":enabled,"ready":ready.size(),"pending":not pending.is_empty(),"capacity":roots.size(),"hits":hits,"misses":misses,"refills":refills,"steps":steps,"prepare_usec":prepare_usec,"step_rows":step_rows.duplicate(true),"stage_usec":stage_usec.duplicate(),"stage_max_usec":stage_max_usec.duplicate(),"nodes":node_count,"detached_nodes":detached,"owned_skin_array_bytes_estimate":mesh_bytes,"estimate_excludes_shared_assets_and_gpu_overhead":true,"disposed":disposed}