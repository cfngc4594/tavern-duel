extends RefCounted
## Optional, bounded loading-screen preparation. Never creates/plays an effect.
static var enabled:bool=true
static var extended:bool=true
static var summon_enabled:bool=true
const Transmission=preload("res://scripts/native_combat_transmission.gd")
const CaptureMaterials=preload("res://scripts/native_combat_capture_materials.gd")
const ATTACK_ROOTS=["attack_friendly","attack_opponent","attack_impact_small","attack_impact_medium","attack_impact_large","attack_impact_mega"]
var done:bool=false
var error:String=""
var warnings:Array=[]
var cursor:int=0
var total:int=0
var prepared_sources:int=0
var prepared_glyphs:int=0
var prepared_transmissions:int=0
var transmission_cpu_usec:int=0
var _extended:bool=false
var _summon_enabled:bool=false
var summon_tasks:int=0
var _transmission:Node
var _damage:Node
var prepared_captures:int=0
var skipped_captures:Array=[]
var setup_usec:int=0
var item_cpu_usec:int=0
var max_item_usec:int=0
var _started_usec:int=0
var _finished_usec:int=0
var _jobs:Array=[]
var _capture_sources:Dictionary={}
var _capture_factory=CaptureMaterials.new()

func setup(game:Node)->void:
 _started_usec=Time.get_ticks_usec()
 _extended=extended
 _summon_enabled=summon_enabled
 if _extended or _summon_enabled:_transmission=Transmission.new()
 if not is_instance_valid(game.native_combat) or not is_instance_valid(game.native_death):
  _warn("Effect material preparation requires initialized combat/death assets.")
  _finish();return
 var combat=game.native_combat.assets
 var roots:Array=[]
 for label in ATTACK_ROOTS:
  var key:String=str(combat.manifest.get("root_labels",{}).get(label,""))
  if key.is_empty():_warn("Missing attack material preparation root: "+label);continue
  roots.append(key)
 # Only the known supported Archer routes, not every spell in the manifest.
 for route in ["CS2_189/missile","CS2_189/impact"]:
  if game.native_combat.effect_player.routes.has(route):
   roots.append(str(game.native_combat.effect_player.routes[route].root_key))
 _queue_scope(combat,roots,"combat",true)
 var death=game.native_death.assets
 var death_roots:Array=[]
 for label in ["minion_death","minion_death_splat"]:
  var key:String=str(death.manifest.get("root_labels",{}).get(label,""))
  if key.is_empty():_warn("Missing death material preparation root: "+label);continue
  death_roots.append(key)
 _queue_scope(death,death_roots,"death",false)
 if _extended:
  if is_instance_valid(game.native_damage):
   _damage=game.native_damage
   var damage_roots:Array=[]
   for label in ["minion_damage_splat","hero_damage_splat"]:
    var key:String=str(_damage.assets.manifest.get("root_labels",{}).get(label,""))
    if key.is_empty():_warn("Missing damage preparation root: "+label);continue
    damage_roots.append(key)
   var selected:Dictionary=_collect(_damage.assets,damage_roots)
   _queue_scope(_damage.assets,damage_roots,"damage",false)
   var glyph_keys:Array=[]
   for key in _damage.assets.objects:
    var record:Dictionary=_damage.assets.objects[key]
    if record.get("class_name","")=="UberText" and selected.nodes.has(str(record.get("refs",{}).get(".m_GameObject",""))):glyph_keys.append(key)
   glyph_keys.sort()
   for key in glyph_keys:_jobs.append({"kind":"glyph","key":key,"spec":_damage.assets.objects[key].data})
  else:_warn("Extended preparation requires initialized damage assets.")
 if _summon_enabled:
  if is_instance_valid(game.native_summon):
   var summon=game.native_summon.assets
   var summon_roots:Array=[]
   for label in summon.manifest.get("root_labels",{}):
    if str(label).begins_with("hand_out_") or str(label).begins_with("play_in_") or str(label).begins_with("spawn_"):
     summon_roots.append(str(summon.manifest.root_labels[label]))
   var before:int=_jobs.size()
   _queue_scope(summon,summon_roots,"summon",false)
   summon_tasks=_jobs.size()-before
  else:_warn("Summon preparation requires initialized summon assets.")
 total=_jobs.size();setup_usec=Time.get_ticks_usec()-_started_usec
 if total==0:_finish()

func _collect(assets,roots:Array)->Dictionary:
 var nodes:Dictionary={};var materials:Dictionary={};var pending:Array=roots.duplicate()
 while not pending.is_empty():
  var key:String=str(pending.pop_back())
  if nodes.has(key):continue
  var go:Dictionary=assets.objects.get(key,{})
  if go.is_empty():_warn("Missing effect preparation object: "+key);continue
  nodes[key]=true
  for component_key in go.get("refs",{}).values():
   var component:Dictionary=assets.objects.get(component_key,{})
   for target in component.get("refs",{}).values():
    if assets.objects.get(target,{}).get("type","")=="Material":materials[target]=true
   if component.get("type","")=="Transform":
    for field in component.get("refs",{}):
     if str(field).begins_with(".m_Children["):
      var child:Dictionary=assets.objects.get(component.refs[field],{})
      var child_go:String=str(child.get("refs",{}).get(".m_GameObject",""))
      if not child_go.is_empty():pending.append(child_go)
 return {"nodes":nodes,"materials":materials}

func _queue_scope(assets,roots:Array,scope:String,include_capture:bool)->void:
 var selected:Dictionary=_collect(assets,roots)
 var capture_keys:Dictionary={}
 if include_capture:
  # Match RenderTexture.setup ownership/source selection without instantiating it.
  for record in assets.objects.values():
   var kind:String=str(record.get("class_name",""))
   if kind not in ["RenderToTexture","OffScreenRenderFX"]:continue
   var owner:String=str(record.get("refs",{}).get(".m_GameObject",""))
   if not selected.nodes.has(owner):continue
   var field:String=".ObjectToRender" if kind=="OffScreenRenderFX" else ".m_ObjectToRender"
   var source:String=str(record.refs.get(field,owner))
   if not selected.nodes.has(source):continue
   var captured:Dictionary=_collect(assets,[source])
   capture_keys.merge(captured.materials)
 var keys:Array=selected.materials.keys();keys.sort()
 for key in keys:
  _jobs.append({"assets":assets,"key":key,"identity":scope+":"+str(key),"kind":"source","capture_needed":capture_keys.has(key),"scope":scope})
 var captures:Array=capture_keys.keys();captures.sort()
 for key in captures:
  for kind in ["color","alpha"]:
   _jobs.append({"assets":assets,"key":key,"identity":scope+":"+str(key),"kind":kind})

func advance()->bool:
 if done:return true
 var started:int=Time.get_ticks_usec()
 var job:Dictionary=_jobs[cursor]
 if job.kind=="glyph":
  if _damage.glyph_bundle.is_empty():_warn("Missing damage glyph bundle: "+str(job.key))
  else:
   var material:Material=_damage._make_text_material(job.spec)
   if material==null:_warn("Damage glyph material returned null: "+str(job.key))
   else:
    prepared_glyphs+=1
    _prepare_transmission(material)
 elif job.kind=="source":
  var material:Material=job.assets.material(job.key)
  if material==null:_warn("Effect material preparation returned null: "+str(job.key))
  else:
   prepared_sources+=1
   if _extended or (_summon_enabled and job.get("scope","")=="summon"):
    if job.get("scope","")=="damage":_damage._compensate_reflected_culling(material)
    _prepare_transmission(material)
   if job.capture_needed:_capture_sources[job.identity]=material
 else:
  var source:Material=_capture_sources.get(job.identity)
  var capture:Material=null
  if source is ShaderMaterial:
   capture=_capture_factory.color_material(source) if job.kind=="color" else _capture_factory.alpha_material(source)
  if capture==null:
   # A missing optional translated capture formula is a bounded skip, not a hang.
   skipped_captures.append({"key":job.key,"kind":job.kind,"reason":"No compatible capture formula/pass"})
  else:prepared_captures+=1
 cursor+=1
 var elapsed:int=Time.get_ticks_usec()-started
 item_cpu_usec+=elapsed;max_item_usec=maxi(max_item_usec,elapsed)
 if cursor>=total:_finish()
 return done

func _prepare_transmission(material:Material)->void:
 # Every source has its final shader before its single transmission call.
 var started:int=Time.get_ticks_usec()
 var variant:Material=_transmission.transmission_material(material)
 if variant==null:_warn("Transmission preparation returned null.")
 else:prepared_transmissions+=1
 transmission_cpu_usec+=Time.get_ticks_usec()-started

func _warn(message:String)->void:
 error=message
 if not warnings.has(message):
  warnings.append(message)
  push_warning(message)

func dispose()->void:
 # May be called on loading failure or scene exit before the queue completes.
 if done:return
 _finish()

func _finish()->void:
 done=true;_finished_usec=Time.get_ticks_usec()
 _capture_factory.clear();_capture_sources.clear();_jobs.clear()
 if is_instance_valid(_transmission):
  # This node never entered the tree: explicitly disconnect its observers.
  _transmission._exit_tree()
  _transmission.free()
 _transmission=null;_damage=null

func progress()->int:
 return cursor

func audit()->Dictionary:
 return {"enabled":enabled,"extended":_extended,"summon_enabled":_summon_enabled,"summon_tasks":summon_tasks,"prepared_glyphs":prepared_glyphs,"prepared_transmissions":prepared_transmissions,"transmission_cpu_usec":transmission_cpu_usec,"done":done,"error":error,"warnings":warnings.duplicate(),"completed":cursor,"total":total,"prepared_sources":prepared_sources,"prepared_captures":prepared_captures,"skipped_captures":skipped_captures.duplicate(true),"setup_usec":setup_usec,"item_cpu_usec":item_cpu_usec,"max_item_usec":max_item_usec,"wall_usec":(_finished_usec if done else Time.get_ticks_usec())-_started_usec}
