extends SceneTree
const Archer=preload("res://scripts/native_archer_effect.gd")
const Assets=preload("res://scripts/native_combat_assets.gd")
class PreparedArcher extends Archer:
 var use_pool:bool=false
 func _take_prepared_scene(key:String)->Dictionary:
  return get_prepared_pool().take(key) if use_pool else {}
var failed:bool=false
func check(ok:bool,label:String):
 if not ok:failed=true;push_error("ARCHER_PREPARED_FAIL "+label)
func compare(a:Dictionary,b:Dictionary,label:String):
 check(var_to_bytes(a.events)==var_to_bytes(b.events),label+" events")
 check(a.particles.keys()==b.particles.keys(),label+" particle keys")
 for key in a.particles:
  var x=a.particles[key].node;var y=b.particles[key].node
  check(x.rng.state==y.rng.state and x.emitted_count==y.emitted_count,label+" RNG/count "+key)
  check(var_to_bytes(x.particles)==var_to_bytes(y.particles),label+" particle bytes "+key)
 for key in a.state.renderers:
  if not b.state.renderers.has(key):check(false,label+" renderer missing");continue
  var x=a.state.renderers[key];var y=b.state.renderers[key]
  if not x is MeshInstance3D or not y is MeshInstance3D:continue
  check(x.visible==y.visible,label+" visibility")
  if x.mesh==null or y.mesh==null:continue
  check(x.mesh.get_surface_count()==y.mesh.get_surface_count(),label+" surface count")
  for surface in range(x.mesh.get_surface_count()):
   check(var_to_bytes(x.mesh.surface_get_arrays(surface))==var_to_bytes(y.mesh.surface_get_arrays(surface)),label+" mesh "+key)
 if a.has("rendertexture"):
  var x:Dictionary=a.rendertexture.get_audit();var y:Dictionary=b.rendertexture.get_audit()
  x.erase("shared_capture_shader_cache");y.erase("shared_capture_shader_cache")
  check(var_to_bytes(x)==var_to_bytes(y),label+" RTT audit")
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.headless=false;game._setup_spatial_presentation()
 var fresh=PreparedArcher.new();var prepared=PreparedArcher.new()
 for fx in [fresh,prepared]:
  game.add_child(fx)
  var assets=Assets.new();assets.setup(game.native_card_renderer);fx.setup(game,assets)
 prepared.use_pool=true
 var pool=prepared.get_prepared_pool()
 var rng_before:int=game.rng.state
 var serial_before:int=prepared.serial;var archer_before:int=prepared.archer_serial
 for i in range(4):pool.prepare_step()
 check(pool.ready.size()==2 and pool.pending.is_empty(),"bounded loading inventory")
 check(game.rng.state==rng_before and prepared.serial==serial_before and prepared.archer_serial==archer_before and prepared.effects.is_empty() and prepared.archer_shots.is_empty(),"preparation no RNG/serial/events")
 check(not game.spatial_scene.is_ancestor_of(pool.staging),"outside spatial scan")
 for route in ["CS2_189/missile","CS2_189/impact"]:
  var context={"key":"CS2_189","side":0,"source":Vector2(800,800),"target":{"type":"hero","side":1,"pos":game.ENEMY_HERO}}
  var event:String="Birth" if route.ends_with("missile") else "Death"
  var a:Dictionary=fresh._spawn_route(route,game.ENEMY_HERO,event,123,context)
  var b:Dictionary=prepared._spawn_route(route,game.ENEMY_HERO,event,123,context)
  for frame in range(90):
   a.age=frame/60.0;b.age=frame/60.0;fresh.clock_seconds=a.age;prepared.clock_seconds=b.age
   fresh._sample(a);prepared._sample(b)
   if frame%10==0 or frame==89:compare(a,b,route+" "+str(frame))
  # Concurrent second instance exceeds capacity and must create fresh, not reuse.
  fresh._spawn_route(route,game.ENEMY_HERO,event,124,context)
  var fallback=prepared._spawn_route(route,game.ENEMY_HERO,event,124,context)
  check(fallback.state.root!=b.state.root,"empty fallback fresh instance")
 fresh.cancel_all();prepared.cancel_all();await process_frame
 check(pool.hits==2 and pool.misses==2,"one hit then one miss each route")
 for i in range(4):pool.prepare_step()
 check(pool.ready.size()==2 and pool.refills==4,"fresh inventory replenished")
 # Idle refills are real follow-up work, not a first-two-hits-only prewarm.
 var consumed:Dictionary=pool.take(pool.roots[0]);pool._free_token(consumed)
 var before_steps:int=pool.steps
 var old_busy:bool=game.busy;var old_loading:bool=game.native_initial_loading
 game.native_initial_loading=false;game.busy=true
 pool.refill_if_idle();check(pool.steps==before_steps,"busy suppresses refill")
 game.busy=false;game.drag_index=0
 pool.refill_if_idle();check(pool.steps==before_steps,"drag suppresses refill")
 game.drag_index=-1
 pool.refill_if_idle();check(pool.steps==before_steps,"first quiet frame waits")
 await process_frame
 pool.refill_if_idle();check(pool.steps==before_steps,"second quiet frame waits")
 game.busy=true;pool.refill_if_idle()
 check(pool.idle_frames==0,"busy resets quiet window even in same frame")
 game.busy=false
 pool.refill_if_idle();check(pool.steps==before_steps,"new first quiet frame waits")
 await process_frame
 pool.refill_if_idle();check(pool.steps==before_steps,"new second quiet frame waits")
 await process_frame
 pool.refill_if_idle();check(pool.steps==before_steps+1 and not pool.pending.is_empty(),"third quiet frame first stage")
 pool.refill_if_idle();check(pool.steps==before_steps+1,"one refill stage per frame")
 await process_frame
 pool.refill_if_idle();check(pool.steps==before_steps+2 and pool.ready.size()==2,"idle second stage replenishes")
 game.busy=old_busy;game.native_initial_loading=old_loading
 var staging_ref:WeakRef=weakref(pool.staging)
 pool.dispose();pool.dispose()
 check(staging_ref.get_ref()==null and pool.ready.is_empty() and pool.pending.is_empty(),"inventory cleanup")
 fresh.free();prepared.free();game.queue_free()
 if not failed:print("ARCHER_PREPARED_PASS real routes exact events/RNG/mesh/RTT; capacity fallback/refill/dispose")
 quit(1 if failed else 0)