extends Node
## Original ManaCrystalMgr list identities and deferred state requests.
## Rendering/audio adapters remain explicit; this is not a replacement game rule engine.
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const Rotation=preload("res://scripts/source_itween_rotation.gd")
const TEXT_POLICY="res://assets/native_phone_mana/source_text_policy.json"
const STEP=0.20000000298023224
var game
var renderer
var initialized:=false
var elapsed:=0.0
var last_frame:=-1
var last_event_serial:=0
var next_identity:=0
var permanent:Array=[]
var temporary:Array=[]
var pending:Array=[]
var retiring_records:Array=[]
var counter_motion:Dictionary={}
var text_policy:Dictionary={}
var queue_counts={"birth":0,"spend":0,"ready":0}
var previous_spent:=0
var normalize_permanent_pending:=false
var proposed_source=null
var blockers:Array=[]
var source_events:Array=[]
var audio_results:Array=[]
var audio_serial:=0
var propose_spell_state:=""
var sound_cursors:Dictionary={}
var last_snapshot:Dictionary={}
var input_snapshot:Dictionary={}
var hidden_crystal_poses:Dictionary={}
var last_values:Dictionary={}
var unported:Array=["Overload/game modes outside ordinary mana", "Original asynchronous prefab loader latency is not reproduced", "Device/GPU output not yet compared", "Hidden source GameObject animation/time-zero callback behavior uses the disclosed TEST compatibility clock, not verified Unity inactive-object parity"]
func setup(host,source_renderer):
 game=host;renderer=source_renderer
 text_policy=JSON.parse_string(FileAccess.get_file_as_string(TEXT_POLICY))
func _block(reason:String):
 if not blockers.has(reason):blockers.append(reason)
func reset():
 if renderer!=null:renderer.clear_live()
 initialized=false;elapsed=0.0;last_frame=-1;last_event_serial=0;next_identity=0
 permanent.clear();temporary.clear();pending.clear();retiring_records.clear();counter_motion.clear();queue_counts={"birth":0,"spend":0,"ready":0}
 previous_spent=0;normalize_permanent_pending=false;proposed_source=null;blockers.clear();source_events.clear();audio_results.clear();audio_serial=0;propose_spell_state="";sound_cursors.clear()
 last_snapshot={};input_snapshot={};last_values={};hidden_crystal_poses.clear()
func _event(kind:String,data:Dictionary={}):
 var row=data.duplicate(true);row.kind=kind;row.at=elapsed;source_events.append(row)
 if source_events.size()>256:source_events.pop_front()
 if kind=="source_manager_sound":
  var name={"m_SoundOnAddPath":"mana_add","m_SoundOnSpendPath":"mana_spend","m_SoundOnRefreshPath":"mana_refresh"}.get(str(data.get("field","")),"")
  if name=="":_block("Unbound original manager audio event");return
  var sound=get_node_or_null("/root/SoundManager")
  if sound==null:_block("Source manager audio adapter unavailable");return
  audio_serial+=1
  var result=sound.play_phone_source_audio(name,{"scope_id":"phone-mana-manager:%s:%s"%[get_instance_id(),audio_serial],"source_side":0})
  audio_results.append({"event":name,"at":elapsed,"result":result})
  if audio_results.size()>128:audio_results.pop_front()
func _new_record(is_temporary:bool,loaded:bool,state:int=0)->Dictionary:
 next_identity+=1
 return {"id":next_identity,"temporary":is_temporary,"loaded":loaded,"state":state,"slot":-1,"player":null,"removal_pending":false}
func _read_state()->Dictionary:
 if game==null or game.get("flow")==null:
  _block("Mana controller requires explicit flow.temporary_mana");return {}
 var temp=int(game.flow.temporary_mana[0]);var maximum=int(game.max_mana);var available=int(game.mana)
 if temp<0 or maximum<0 or available<temp:
  _block("Inconsistent source permanent/temporary mana counts");return {}
 return {"permanent":maximum,"temporary":temp,"spent":maximum-clampi(available-temp,0,maximum),"available":available,"enemy_available":int(game.enemy_mana),"enemy_permanent":int(game.enemy_max_mana)}
func update(snapshot:Dictionary,delta:float,counter_values:Dictionary={},frame_id:int=-1):
 if renderer==null or not snapshot.get("ready",false):return
 input_snapshot=snapshot
 if frame_id<0:frame_id=Engine.get_process_frames()
 var fresh_frame=frame_id!=last_frame
 if fresh_frame:
  elapsed+=maxf(delta,0.0);last_frame=frame_id
  # Advance objects that existed before this frame. Newly delivered Birth starts at0.
  renderer.advance_live(maxf(delta,0.0))
 var current=_read_state()
 if current.is_empty():return
 var layout=game.get("source_phone_layout")
 var events:Array=layout.mana_events if layout!=null else []
 if not initialized:
  for i in int(current.permanent):permanent.append(_new_record(false,true,1 if i<int(current.spent) else 0))
  for _i in int(current.temporary):temporary.append(_new_record(true,true))
  previous_spent=int(current.spent)
  if not events.is_empty():last_event_serial=int(events.back().serial)
  initialized=true
 else:
  var reported_spent:=0
  for event in events:
   var serial=int(event.serial)
   if serial<=last_event_serial:continue
   if serial!=last_event_serial+1:_block("Mana event history gap; explicit reset/prime required")
   last_event_serial=serial
   if int(event.side)!=0:continue # Opponent has only the source counter, no friendly gem row.
   var temp_used=int(event.get("temporary_used",-1));var ordinary=int(event.get("permanent_used",-1))
   if temp_used<0 or ordinary<0 or temp_used+ordinary!=int(event.cost):
    _block("Invalid temporary-first mana spend event");continue
   _request_removal(true,temp_used)
   _queue_many("spend",ordinary)
   reported_spent+=ordinary
   _event("spend_event",{"serial":serial,"temporary_used":temp_used,"permanent_used":ordinary})
  _reconcile_count(false,int(current.permanent))
  _reconcile_count(true,int(current.temporary))
  var difference=int(current.spent)-previous_spent-reported_spent
  if difference>0:_queue_many("spend",difference)
  elif difference<0:_queue_many("ready",-difference)
  previous_spent=int(current.spent)
 _run_pending(frame_id)
 _normalize_permanent()
 _bind_slots()
 _capture_sounds()
 var display=_display_snapshot(snapshot)
 _update_counter(fresh_frame,maxf(delta,0.0))
 var values=_counter_values(current,counter_values)
 last_snapshot=display;last_values=values
 renderer.sync(display,values)
func _queue_many(kind:String,count:int):
 if count<=0:return
 if kind=="spend":_event("source_manager_sound",{"field":"m_SoundOnSpendPath","call":"ManaCrystalMgr.SpendManaCrystals"})
 for _i in count:
  queue_counts[kind]+=1
  var wait=(int(queue_counts[kind])-1 if kind=="spend" else int(queue_counts[kind]))*STEP
  pending.append({"kind":kind,"at":elapsed+wait,"after_frame":last_frame})
func _effective_count(rows:Array)->int:
 var count:=0
 for row in rows:
  if not row.removal_pending:count+=1
 return count
func _reconcile_count(is_temporary:bool,wanted:int):
 var rows:Array=temporary if is_temporary else permanent
 var difference=wanted-_effective_count(rows)
 if difference<0:_request_removal(is_temporary,-difference)
 for _i in maxi(0,difference):
  var row=_new_record(is_temporary,false);rows.append(row)
  queue_counts.birth+=1
  pending.append({"kind":"birth","record":row,"at":elapsed+int(queue_counts.birth)*STEP,"after_frame":last_frame})
func _request_removal(is_temporary:bool,count:int):
 var rows:Array=temporary if is_temporary else permanent
 for _i in count:
  var record:Dictionary={}
  var indices=range(rows.size()-1,-1,-1) if is_temporary else range(rows.size())
  for index in indices:
   if not rows[index].removal_pending:record=rows[index];break
  if record.is_empty():_block("Source mana destroy exceeds the live source list");return
  record.removal_pending=true
  # Destroy waits for all resource prefab loads, but not their Birth animations.
  pending.append({"kind":"destroy","record":record,"at":elapsed,"after_frame":last_frame-1})
func _loading()->bool:
 for row in permanent+temporary:
  if not row.loaded:return true
 return false
func _run_pending(frame:int):
 for operation in pending.duplicate():
  if elapsed+0.00000001<float(operation.at) or frame<=int(operation.after_frame):continue
  var kind:String=operation.kind
  if kind=="destroy" and _loading():continue
  if kind=="birth":
   operation.record.loaded=true;queue_counts.birth-=1
   if not operation.record.temporary:normalize_permanent_pending=true
   _bind_slots()
   _event("source_manager_sound",{"field":"m_SoundOnAddPath","identity":operation.record.id,"call":"LoadCrystalCallback"})
  elif kind=="destroy":
   var row:Dictionary=operation.record
   if row.slot>=0:renderer.set_live_state(row.slot,3)
   retiring_records.append(row)
   _event("destroy",{"identity":row.id,"temporary":row.temporary})
   var rows:Array=temporary if row.temporary else permanent
   rows.erase(row)
   if not row.temporary:normalize_permanent_pending=true
   _bind_slots()
  else:
   var indices=range(permanent.size()) if kind=="spend" else range(permanent.size()-1,-1,-1)
   var selected:Dictionary={}
   for index in indices:
    var row:Dictionary=permanent[index]
    if not row.loaded or row.removal_pending:continue
    if (kind=="spend" and int(row.state)!=1) or (kind=="ready" and int(row.state)==1):selected=row;break
   if not selected.is_empty():
    _request_state(selected,1 if kind=="spend" else 0)
    if kind=="ready":_event("source_manager_sound",{"field":"m_SoundOnRefreshPath","identity":selected.id,"call":"WaitThenReadyManaCrystal"})
   elif kind=="spend":_block("Source spend queue found no available ordinary crystal")
   queue_counts[kind]-=1
  pending.erase(operation)
func _normalize_permanent():
 if not normalize_permanent_pending or _loading() or int(queue_counts.ready)>0 or int(queue_counts.spend)>0:return
 # Original UpdatePermanentCrystalStates0x06005b71 runs after ordinary
 # add/destroy and all queued loads/ready/spend finish. Removal of list[0]
 # may remove a used crystal; the remaining first RESOURCES_USED must be used.
 for i in permanent.size():
  var value=1 if i<previous_spent else 0
  if int(permanent[i].state)!=value:_request_state(permanent[i],value)
 normalize_permanent_pending=false
func _display_records()->Array:
 var result:Array=[]
 for i in range(permanent.size()-1,-1,-1):
  if permanent[i].loaded:result.append(permanent[i])
 for row in temporary:
  if row.loaded:result.append(row)
 return result
func _bind_slots():
 var rows=_display_records();var mapping:Dictionary={}
 var options=_source_options()
 var source=Layout.recovered_mana_items(options).friendly_mana
 var parent_pose=_source_parent_pose(options)
 for i in rows.size():
  if rows[i].slot>=0:mapping[int(rows[i].slot)]=i
 if not mapping.is_empty() and not renderer.remap_live(mapping):_block("Source mana live identity remap failed");return
 for i in rows.size():
  var row:Dictionary=rows[i];row.slot=i
  var pose:Transform3D
  if i<source.crystals.size():
   pose=source.crystals[i].source_pose
   row.source_local_pose=parent_pose.affine_inverse()*pose
  else:
   if not row.has("source_local_pose"):row.source_local_pose=_source_initial_local_pose()
   pose=parent_pose*row.source_local_pose
  if row.player==null:
   # Existing objects are primed without a fabricated Birth. Only asynchronous
   # new objects get PlayCreateAnimation after the original source queue delay.
   var already_present=not row.has("birth_requested") and not _is_birth_record(row)
   row.player=renderer.begin_live(i,bool(row.temporary),already_present,int(row.state),pose,i>=10)
   row.birth_requested=not already_present
  renderer.set_live_pose(i,pose)
  renderer.set_live_hidden(i,i>=10)
func _is_birth_record(row:Dictionary)->bool:
 for operation in pending:
  if operation.kind=="birth" and int(operation.record.id)==int(row.id):return true
 return false
func _request_state(row:Dictionary,value:int):
 if int(row.state)==3:return
 row.state=value
 if row.slot>=0:renderer.set_live_state(int(row.slot),value)
func propose(entity_id,cost:int):
 if entity_id==null or not initialized:return
 proposed_source=entity_id
 if cost<=0:return # Original records the source first, then returns.
 propose_spell_state="Idle State"
 _event("propose_usage_spell",{"state":1,"source_identity":str(entity_id),"source_fsm_path":["Birth State","Idle State"],"visual_audio_actions":0})
 var count:=0
 for i in range(temporary.size()-1,-1,-1):
  var row:Dictionary=temporary[i]
  if not row.loaded or row.removal_pending:continue
  if int(row.state)==1:_block("Original manager found an invalid spent temporary crystal");continue
  _request_state(row,2 if count<cost else 0)
  if count<cost:count+=1
 for row in permanent:
  if not row.loaded or row.removal_pending or int(row.state)==1:continue
  _request_state(row,2 if count<cost else 0)
  if count<cost:count+=1
func cancel_proposal(entity_id):
 if entity_id==null or proposed_source!=entity_id:return
 proposed_source=null
 propose_spell_state="None State"
 _event("propose_usage_spell",{"state":5,"source_identity":str(entity_id),"source_fsm_path":["Death State","None State"],"visual_audio_actions":0})
 for row in temporary:
  if int(row.state)==2:_request_state(row,0)
 for i in range(permanent.size()-1,-1,-1):
  if int(permanent[i].state)==2:_request_state(permanent[i],0)
func _display_snapshot(snapshot:Dictionary)->Dictionary:
 var result=snapshot.duplicate();result.items=snapshot.items.duplicate()
 var friendly:Dictionary=snapshot.items.friendly_mana.duplicate()
 var options=_source_options()
 # Reuse the one recovered source layout function for the loaded source lists;
 # logical counts may already include prefabs still in the original .2s queue.
 var source=Layout.recovered_mana_items(options).friendly_mana
 friendly.crystals=source.crystals;result.items.friendly_mana=friendly
 var parent_pose=_source_parent_pose(options)
 hidden_crystal_poses.clear()
 var rows=_display_records()
 for i in rows.size():
  var row:Dictionary=rows[i]
  if i<source.crystals.size():
   row.source_local_pose=parent_pose.affine_inverse()*source.crystals[i].source_pose
  else:
   if not row.has("source_local_pose"):row.source_local_pose=_source_initial_local_pose()
   hidden_crystal_poses[i]=parent_pose*row.source_local_pose
 return result
func _source_options()->Dictionary:
 var count_permanent:=0;var count_temporary:=0
 for row in permanent:
  if row.loaded:count_permanent+=1
 for row in temporary:
  if row.loaded:count_temporary+=1
 var canvas:Vector2=input_snapshot.canvas_size
 var options={"aspect":canvas.x/canvas.y,"permanent_mana_count":count_permanent,"temporary_mana_count":count_temporary}
 var layout=game.get("source_phone_layout")
 if layout!=null and not layout.mana_tray.is_empty():options.mana_tray_position=layout.mana_tray.position
 return options
func _source_initial_local_pose()->Transform3D:
 var interaction=Layout.source_json(Layout.INTERACTION_PATH)
 var gem:Dictionary=interaction.mana["ManaGemBone:7409025516337681387"]
 var q:Array=gem.local_rotation;var scale_value:Vector3=Layout.vector(gem.local_scale)
 var basis=Basis(Quaternion(q[0],q[1],q[2],q[3]))
 # Original LoadCrystalCallback copies bone LOCAL rotation/scale but sets
 # LOCAL position to zero, before UpdateLayout optionally places visible gems.
 return Transform3D(Basis(basis.x*scale_value.x,basis.y*scale_value.y,basis.z*scale_value.z),Vector3.ZERO)
func _source_parent_pose(options:Dictionary)->Transform3D:
 var interaction=Layout.source_json(Layout.INTERACTION_PATH)
 var gem:Dictionary=interaction.mana["ManaGemBone:7409025516337681387"]
 var local=_source_initial_local_pose();local.origin=Layout.vector(gem.local_position)
 var parent_pose:Transform3D=Layout.matrix(gem.world_matrix)*local.affine_inverse()
 var position:Vector3=options.get("mana_tray_position",Layout.vector(interaction.mana.tray_animation.shown))
 parent_pose.origin+=position-Layout.vector(interaction.mana.tray_animation.shown)
 return parent_pose
func _counter_values(current:Dictionary,overrides:Dictionary)->Dictionary:
 var values={"available":str(current.available),"permanent":str(current.permanent),"hidden_crystal_poses":hidden_crystal_poses.duplicate()}
 for side in ["friendly","opposing"]:
  var available=int(current.available if side=="friendly" else current.enemy_available)
  var maximum=int(current.permanent if side=="friendly" else current.enemy_permanent)
  var key=side+"_counter"
  if maximum>=10:values[key]=str(available) # ManaCounter.OnlyShowCurrentResourceText phone branch.
  elif overrides.has(key):values[key]=str(overrides[key])
  elif text_policy.get("GAMEPLAY_MANA_COUNTER","")=="{0}/{1}":values[key]=str(available)+"/"+str(maximum)
  else:_block("Missing verified GAMEPLAY_MANA_COUNTER localized value for "+side)
 var layout=game.get("source_phone_layout")
 if layout!=null and not layout.mana_tray.is_empty():values.mana_tray_position=layout.mana_tray.position
 if not counter_motion.is_empty():
  values.counter_flip_times={"friendly":counter_motion.time}
  values.friendly_counter_alpha=counter_motion.alpha
 if overrides.has("counter_flip_times"):values.counter_flip_times=overrides.counter_flip_times
 return values
func _update_counter(fresh_frame:bool,delta:float):
 var layout=game.get("source_phone_layout")
 if layout==null or layout.mana_tray.is_empty():return
 var shown=bool(layout.mana_tray.shown)
 var duration:float=renderer.assets.clip_length("Resource_Large_phone_Flip")
 if duration<=0.0:_block("Missing source phone counter flip clip");return
 if counter_motion.is_empty():
  # Prime an already-present tray without replaying a fabricated show event.
  counter_motion={"shown":shown,"time":duration if shown else 0.0,"duration":duration,"alpha":0.0 if shown else 1.0,"alpha_from":0.0 if shown else 1.0,"alpha_age":1.0}
 if fresh_frame:
  counter_motion.time=clampf(float(counter_motion.time)+(delta if counter_motion.shown else -delta),0.0,duration)
  counter_motion.alpha_age+=delta
  var blend=Rotation.ease_out_expo_progress(counter_motion.alpha_age,0.10000000149011612)
  counter_motion.alpha=lerpf(float(counter_motion.alpha_from),0.0 if counter_motion.shown else 1.0,blend)
 if shown!=bool(counter_motion.shown):
  counter_motion.shown=shown;counter_motion.alpha_from=counter_motion.alpha;counter_motion.alpha_age=0.0
  if not shown and float(counter_motion.time)==0.0:counter_motion.time=duration
  _event("phone_counter_flip",{"shown":shown,"speed":1 if shown else -1,"source":"ManaCrystalMgr.ShowPhoneManaTray/HidePhoneManaTray"})
func _capture_sounds():
 for row in permanent+temporary+retiring_records:
  if not is_instance_valid(row.player):continue
  var events:Array=row.player.source_sound_events
  var cursor=int(sound_cursors.get(row.id,0))
  for i in range(cursor,events.size()):_event("source_actor_sound",{"identity":row.id,"event":events[i]})
  sound_cursors[row.id]=events.size()
 for row in retiring_records.duplicate():
  if not is_instance_valid(row.player):retiring_records.erase(row)
func audit()->Dictionary:
 var state=[]
 for row in permanent+temporary:state.append({"identity":row.id,"temporary":row.temporary,"loaded":row.loaded,"slot":row.slot,"state":row.state,"removal_pending":row.removal_pending})
 return {"initialized":initialized,"ready":initialized and blockers.is_empty(),"runtime_complete":false,"blockers":blockers.duplicate(),"unported":unported.duplicate(),"source_lists":state,"queued":pending.size(),"events":source_events.duplicate(true),"propose_spell_state":propose_spell_state,"audio_results":audio_results.duplicate(true),"last_mana_event_serial":last_event_serial,"clock":elapsed,"identity_note":"Local presentation identities, not original server entity IDs"}
