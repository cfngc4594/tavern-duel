extends SceneTree
## Resource-only queue regression. Does not play effects or assert GPU warmup.
const Preparer=preload("res://scripts/effect_material_preparer.gd")
const Source=preload("res://scripts/native_source_manifest.gd")
const CombatAssets=preload("res://scripts/native_combat_assets.gd")
const DeathAssets=preload("res://scripts/native_death_assets.gd")
class Host extends Node:
 var assets
 var effect_player
 var routes:Dictionary={}
 var instances:Array=[]
 var serial:int=0
 var source_clock:float=0.0
 var highlight_rng=RandomNumberGenerator.new()
class MockGame extends Node:
 var native_combat
 var native_summon
 var native_damage
 var native_card_renderer
 var native_death
 var rng=RandomNumberGenerator.new()
class NullAssets extends RefCounted:
 func material(_key:String)->Material:return null
var failed:=false
func require(ok:bool,label:String):
 if not ok:failed=true;push_error("EFFECT_PREP_FAIL "+label)
func _initialize():call_deferred("run")
func run():
 Preparer.summon_enabled=false
 Preparer.extended=false
 var game=MockGame.new();root.add_child(game)
 game.native_combat=Host.new();game.add_child(game.native_combat)
 game.native_combat.effect_player=Host.new();game.native_combat.add_child(game.native_combat.effect_player)
 game.native_death=Host.new();game.add_child(game.native_death)
 var combat=CombatAssets.new();combat.setup()
 combat.objects=combat.objects.duplicate()
 var extra:Dictionary=Source.load_manifest("res://assets/original_combat_v32/archer/manifest.json")
 combat.objects.merge(extra.objects,true);combat._prepare_render_order()
 game.native_combat.assets=combat;game.native_death.assets=DeathAssets.new();game.native_death.assets.setup()
 game.native_combat.effect_player.routes=Source.load_source_dictionary("res://assets/original_combat_v32/archer/routes.json").routes
 game.native_damage=preload("res://scripts/native_damage_splat.gd").new()
 game.add_child(game.native_damage);game.native_damage.setup(game)
 game.native_summon=Host.new();game.add_child(game.native_summon)
 game.native_summon.assets=preload("res://scripts/native_summon_assets.gd").new()
 game.native_summon.assets.setup()
 game.native_summon.highlight_rng.seed=9876
 game.rng.seed=12345
 var before_rng:int=game.rng.state;var before_nodes:int=game.get_child_count()
 var prep=Preparer.new();prep.setup(game)
 require(prep.total==41,"33 source materials plus 8 selected capture jobs")
 var calls:=0
 while not prep.done and calls<100:
  var before:int=prep.cursor;prep.advance();calls+=1
  require(prep.cursor==before+1,"one queued job per advance")
 require(prep.done and calls==41,"bounded completion")
 require(prep.prepared_sources==33,"selected source material count")
 require(prep.prepared_captures==8 and prep.skipped_captures.is_empty(),"8 capture materials prepared")
 require(prep.warnings.is_empty(),"actual source roots/resources available")
 require(game.rng.state==before_rng and game.get_child_count()==before_nodes,"no gameplay RNG or effect nodes")
 require(prep._jobs.is_empty() and prep._capture_sources.is_empty(),"temporary source ownership released")
 var cursor:int=prep.cursor;prep.advance();require(prep.cursor==cursor,"done queue is idempotent")
 # Expanded queue uses 7 reachable damage prefab materials (not 5 legacy font
 # material records) and 2 real UberText material configurations.
 Preparer.extended=true
 var expanded=Preparer.new();expanded.setup(game)
 var temporary:WeakRef=weakref(expanded._transmission)
 require(expanded.total==50,"extended 40 sources + 8 capture + 2 glyph tasks")
 require(expanded._transmission.get_child_count()==0 and not expanded._transmission.is_inside_tree(),"no transmission viewport or scene")
 var damage=game.native_damage
 var before_damage:Array=[damage.serial,damage.clock_seconds,damage.entries.duplicate(true),damage.events.duplicate(true),damage.history.duplicate(true),damage.dying.duplicate(true)]
 var observed_shader:Shader
 var baseline_connections:int=0
 for job in expanded._jobs:
  if job.kind=="glyph":
   var glyph:ShaderMaterial=damage._make_text_material(job.spec)
   observed_shader=glyph.shader
   baseline_connections=observed_shader.changed.get_connections().size()
   require(observed_shader.code.contains("cull_back"),"glyph retains original culling")
   break
 var expanded_calls:=0
 while not expanded.done and expanded_calls<100:
  var before:int=expanded.cursor;expanded.advance();expanded_calls+=1
  require(expanded.cursor==before+1,"extended one task per advance")
 require(expanded.done and expanded_calls==50,"extended bounded completion")
 require(expanded.prepared_sources==40 and expanded.prepared_glyphs==2 and expanded.prepared_captures==8,"extended source/glyph/capture counts")
 require(expanded.prepared_transmissions==42,"transmission sources and glyphs only")
 require(expanded.warnings.is_empty(),"extended actual assets available")
 require(temporary.get_ref()==null and expanded._transmission==null,"temporary transmission freed")
 require(observed_shader.changed.get_connections().size()==baseline_connections,"temporary shader observers disconnected")
 require(game.rng.state==before_rng and game.get_child_count()==before_nodes,"extended no RNG or scene mutation")
 require(before_damage==[damage.serial,damage.clock_seconds,damage.entries,damage.events,damage.history,damage.dying],"damage presentation state unchanged")
 require(not damage.reflected_shaders.is_empty(),"actual owner retains reflected shader variants")
 var expanded_cursor:int=expanded.cursor;expanded.advance()
 require(expanded.cursor==expanded_cursor,"extended done idempotent")
 # Summon adds only reachable effect materials, never actors or highlight draws.
 Preparer.summon_enabled=true
 var summon_rng:int=game.native_summon.highlight_rng.state
 var summon_prep=Preparer.new();summon_prep.setup(game)
 require(summon_prep.summon_tasks==19 and summon_prep.total==69,"19 summon material tasks")
 var summon_calls:int=0
 while not summon_prep.done and summon_calls<100:
  var before:int=summon_prep.cursor;summon_prep.advance();summon_calls+=1
  require(summon_prep.cursor==before+1,"summon one job per advance")
 require(summon_prep.done and summon_prep.prepared_sources==59 and summon_prep.prepared_transmissions==61,"summon source/transmission totals")
 require(game.native_summon.highlight_rng.state==summon_rng and game.rng.state==before_rng,"summon RNG unchanged")
 require(game.native_summon.serial==0 and game.native_summon.source_clock==0.0 and game.native_summon.instances.is_empty(),"summon state unchanged")
 require(game.get_child_count()==before_nodes,"summon creates no scene nodes")
 print("EFFECT_MATERIAL_PREPARER_SUMMON_AUDIT ",JSON.stringify(summon_prep.audit()))
 Preparer.summon_enabled=false
 # Aborting mid-queue must release the detached Transmission node immediately.
 var interrupted=Preparer.new();interrupted.setup(game)
 var interrupted_node:WeakRef=weakref(interrupted._transmission)
 interrupted.advance()
 var interrupted_cursor:int=interrupted.cursor
 interrupted.dispose()
 require(interrupted.done and interrupted.cursor==interrupted_cursor,"dispose stops queue without pretending completion")
 require(interrupted_node.get_ref()==null and interrupted._jobs.is_empty() and interrupted._capture_sources.is_empty(),"mid-queue disposal releases node and resources")
 var disposed_audit:Dictionary=interrupted.audit()
 interrupted.dispose();interrupted.advance()
 require(interrupted.audit()==disposed_audit,"dispose and advance after disposal are idempotent")
 print("EFFECT_MATERIAL_PREPARER_EXTENDED_AUDIT ",JSON.stringify(expanded.audit()))
 Preparer.extended=false
 # A missing selected object is reported and other queue work still completes.
 var original_manifest:Dictionary=combat.manifest
 combat.manifest=original_manifest.duplicate()
 combat.manifest.root_labels=original_manifest.root_labels.duplicate()
 combat.manifest.root_labels.attack_friendly="missing_preparation_record"
 var missing=Preparer.new();missing.setup(game)
 var missing_calls:=0
 while not missing.done and missing_calls<100:missing.advance();missing_calls+=1
 require(missing.done and not missing.warnings.is_empty(),"missing object fails open")
 combat.manifest=original_manifest
 # Failed optional preparation must consume jobs, release ownership and not hang.
 var fail_open=Preparer.new();var nulls=NullAssets.new()
 fail_open._started_usec=Time.get_ticks_usec();fail_open.total=2
 for key in ["missing_a","missing_b"]:
  fail_open._jobs.append({"assets":nulls,"key":key,"identity":key,"kind":"source","capture_needed":false})
 fail_open.advance();require(not fail_open.done and fail_open.cursor==1,"null first item consumed")
 fail_open.advance();require(fail_open.done and fail_open.cursor==2 and fail_open.warnings.size()==2,"null jobs fail open")
 print("EFFECT_MATERIAL_PREPARER_AUDIT ",JSON.stringify(prep.audit()))
 game.free()
 if not failed:print("EFFECT_MATERIAL_PREPARER_PASS bounded 41 jobs, one per advance, no RNG/nodes, null fail-open")
 quit(1 if failed else 0)
