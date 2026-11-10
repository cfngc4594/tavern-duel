extends SceneTree
## Full desktop board fixture. Real GPU only; never unmask the root window.
## -- --privacy-guard-test --board-source-bundle=<compiled bin> --parity-output=<json>
## Optional --cpu-only validates setup/actions without claiming rendered parity.
const Probe=preload("res://original_board/scripts/board_probe.gd")
const Store=preload("res://original_board/scripts/board_source_store.gd")
const Compiler=preload("res://original_board/scripts/board_source_compiler.gd")
const Policy=preload("res://scripts/source_board_camera_policy.gd")
const FIELDS=["door_interaction","window_lamp_interaction","arch_interactions","kite_interactions","pumpkin_interaction","bush_interactions","water_interactions"]
const SIZE=Vector2i(1600,900)
var pair: Array=[]
var rows: Array=[]
var reset_hashes: Dictionary={}
var reset_states: Dictionary={}
var guard
var failed=false
var cpu_only=false
var output=""
var cycle=0

func _initialize():call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if not ok:
  failed=true;push_error("BOARD_SOURCE_PARITY_FAIL "+message)
 return ok
func digest(bytes: PackedByteArray) -> String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()

func fixture(enabled: bool) -> Dictionary:
 Store.enabled=enabled
 var vp=SubViewport.new();vp.size=SIZE;vp.own_world_3d=true
 vp.msaa_3d=Viewport.MSAA_DISABLED;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 vp.audio_listener_enable_3d=true;vp.handle_input_locally=true;vp.gui_disable_input=true
 root.add_child(vp)
 var p=Probe.new();p.host_driven=true;p.interaction_audio_enabled=false;vp.add_child(p)
 check(p.build_complete and not p.phone_variant,"Desktop board build incomplete")
 check(p.audit.errors.is_empty(),"Board source errors: "+str(p.audit.errors))
 # Setup randomizes these RNGs. Replace only exogenous random inputs, using
 # each probe's own source ranges. Never copy mutable state between probes.
 for field_index in range(FIELDS.size()):
  var controller=p.get(FIELDS[field_index]);controller.rng.seed=572031+field_index
  if "systems" in controller:
   for sys in controller.systems.values():
    for gate_key in sys.gates:
     var split=gate_key.rsplit(":",true,1)
     var action=sys.states[split[0]].actions[int(split[1])]
     check(action["class"]=="MousePickRandomAction","Unexpected initial random gate")
     var high=int(action.params.RandomGateClicksMax);var low=mini(int(action.params.RandomGateClicksMin),high)
     sys.gates[gate_key].threshold=low if high<=low else controller.rng.randi_range(low,high-1)
  # Initial randomized audio choices are irrelevant to muted GPU parity.
  controller.events.clear()
 return {"viewport":vp,"probe":p}

func state_snapshot(p) -> Dictionary:
 var out={"elapsed":p.elapsed_seconds,"nodes":{},"renderers":{},"controllers":{},"particles":[]}
 for key in p.source_nodes:
  var n=p.source_nodes[key];out.nodes[key]=[n.transform,n.visible]
 for key in p.renderer_nodes:
  var r=p.renderer_nodes[key];out.renderers[key]=[r.visible,r.mesh.get_surface_count()]
 for field in FIELDS:
  var c=p.get(field);var summary={"rng":c.rng.state,"events":c.events.duplicate(true)}
  if "state" in c:summary.state=c.state
  if "systems" in c:
   summary.systems={}
   for kind in c.systems:
    var sys=c.systems[kind];var selected={}
    for key in ["state","time","gates","variables","waits","pending","animation","rotation_speed","material_values"]:
     if sys.has(key):selected[key]=sys[key].duplicate(true) if sys[key] is Dictionary or sys[key] is Array else sys[key]
    summary.systems[kind]=selected
  out.controllers[field]=summary
 for key in p.water_particles.entries:
  var e=p.water_particles.entries[key];var instances=[]
  for item in e.instances:instances.append([item.age,item.solver.live_count,item.solver.emitted_count,item.solver.particles.duplicate(true)])
  out.particles.append([key,e.playing,e.play_calls,e.stop_calls,instances])
 return out

func black_root() -> bool:
 if not check(guard.runtime_evidence().active,"Privacy guard inactive"):return false
 var image=root.get_texture().get_image()
 if not check(image!=null and not image.is_empty(),"Missing root privacy frame"):return false
 image.convert(Image.FORMAT_RGBA8);var bytes=image.get_data()
 for i in range(0,bytes.size(),4):
  if bytes[i]!=0 or bytes[i+1]!=0 or bytes[i+2]!=0 or bytes[i+3]!=255:return check(false,"Nonblack root privacy pixel "+str(i))
 return true

func capture(label: String) -> bool:
 var a=state_snapshot(pair[0].probe);var b=state_snapshot(pair[1].probe)
 if not check(a==b,label+": independent CPU states differ"):return false
 var row={"cycle":cycle,"phase":label,"source_seconds":pair[0].probe.elapsed_seconds,"live_particles":0,"state_sha256":digest(var_to_bytes(a))}
 if cycle==0:reset_states[label]=row.state_sha256
 elif not check(reset_states.get(label)==row.state_sha256,label+": repeated lifecycle CPU state differs"):return false
 for e in pair[0].probe.water_particles.entries.values():
  for item in e.instances:row.live_particles+=item.solver.live_count
 if not cpu_only:
  for frame in range(3):
   await process_frame
   await RenderingServer.frame_post_draw
   if not black_root():return false
  var ai=pair[0].viewport.get_texture().get_image();var bi=pair[1].viewport.get_texture().get_image()
  if not check(ai!=null and bi!=null and not ai.is_empty() and not bi.is_empty(),label+": missing board pixels"):return false
  if not check(ai.get_size()==SIZE and bi.get_size()==SIZE and ai.get_format()==bi.get_format(),label+": board dimensions/format differ"):return false
  var ab=ai.get_data();var bb=bi.get_data();row.baseline_sha256=digest(ab);row.bundle_sha256=digest(bb)
  if ab!=bb:
   if not output.is_empty():
    ai.save_png(output.get_basename()+"_baseline_mismatch.png");bi.save_png(output.get_basename()+"_bundle_mismatch.png")
   rows.append(row);return check(false,label+": exact GPU bytes differ; no tolerance applied")
  var rgba: Image=ai.duplicate();rgba.convert(Image.FORMAT_RGBA8);var data=rgba.get_data();var nonblack=0
  for i in range(0,data.size(),4):
   if data[i]!=0 or data[i+1]!=0 or data[i+2]!=0:nonblack+=1
  if not check(nonblack>0,label+": board image is all black"):return false
  row.nonblack_pixels=nonblack;row.width=SIZE.x;row.height=SIZE.y
  if cycle==0:reset_hashes[label]=row.baseline_sha256
  elif not check(reset_hashes.get(label)==row.baseline_sha256,label+": repeated lifecycle is not pixel-deterministic"):return false
 rows.append(row)
 print("BOARD_SOURCE_PARITY_PHASE ",JSON.stringify(row))
 return true

func advance(steps: int):
 for step in range(steps):
  for f in pair:f.probe.advance_host(0.05)
func click(field: String,kind: String=""):
 for f in pair:
  var c=f.probe.get(field)
  if kind.is_empty():
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=c.target_screen()
   check(c.handle_input(event),"Source click missed "+field)
  else:check(c.click_kind(kind),"Source click rejected "+field+"/"+kind)

func exercise() -> bool:
 if not await capture("initial"):return false
 advance(10)
 if not await capture("ambient_clock"):return false
 click("door_interaction");advance(5)
 if not await capture("door_opening"):return false
 advance(80);click("door_interaction");advance(5)
 if not await capture("door_closing"):return false
 click("window_lamp_interaction");advance(5)
 if not await capture("window_material_swap"):return false
 advance(80);click("window_lamp_interaction");advance(5)
 if not await capture("window_restore"):return false
 for field in ["arch_interactions","water_interactions","kite_interactions","pumpkin_interaction","bush_interactions"]:
  for press in range(8):
   for kind in pair[0].probe.get(field).systems:click(field,kind)
   advance(5)
   if not await capture(field+"_press_"+str(press)):return false
   advance(35)
 # Explicit source-emitter exercise also covers emitters not triggered by this
 # finite click sequence. No emitter count/quality/workload is reduced.
 for f in pair:
  for key in f.probe.water_particles.entries:f.probe.water_particles.set_playing(key,true)
 advance(10)
 if not await capture("all_source_emitters_playing"):return false
 if not check(rows[-1].live_particles>0,"Particle fixture emitted no living geometry"):return false
 for f in pair:
  for key in f.probe.water_particles.entries:f.probe.water_particles.set_playing(key,false)
 advance(5)
 if not await capture("source_particle_stop_tails"):return false
 advance(120)
 return await capture("settled")

func run():
 for arg in OS.get_cmdline_user_args():
  if arg=="--cpu-only":cpu_only=true
  if arg.begins_with("--board-source-bundle="):Store.bundle_path=arg.trim_prefix("--board-source-bundle=")
  if arg.begins_with("--parity-output="):output=arg.trim_prefix("--parity-output=")
 guard=root.get_node_or_null("PrivacyTestGuard")
 if not check(guard!=null and guard.runtime_evidence().active,"Requires active --privacy-guard-test"):finish();return
 if not check(cpu_only or DisplayServer.get_name()!="headless","Real graphical renderer required for GPU proof"):finish();return
 if not check(not Policy.is_phone(),"Desktop board required"):finish();return
 if not check(FileAccess.file_exists(Store.bundle_path),"Compiled bundle missing: "+Store.bundle_path):finish();return
 var validated=Store.validate_bytes(FileAccess.get_file_as_bytes(Store.bundle_path))
 if not check(validated.ok and Compiler.validate_sources(validated.get("manifest",{})),"Bundle invalid or source hashes stale; rebuild with compiler"):finish();return
 root.unfocusable=true;Store.clear_cache()
 for iteration in range(2):
  cycle=iteration
  pair=[fixture(false),fixture(true)]
  for field in ["meshes","materials","textures"]:
   var left=pair[0].probe.get(field);var right=pair[1].probe.get(field)
   check(left.keys()==right.keys(),"Source resource keys differ: "+field)
   for key in left:
    if left[key]!=null:check(left[key]!=right.get(key),"Mutable resource shared between probes: "+field+"/"+str(key))
    else:check(right.get(key)==null,"Unsupported resource omission differs: "+field+"/"+str(key))
  var stats=Store.get_audit()
  if not check(stats.loads==1 and stats.json_hits>0 and stats.image_hits>0 and stats.misses==0 and stats.error.is_empty(),"Bundle not used cleanly: "+str(stats)):break
  if failed or not await exercise():break
  for f in pair:f.probe.close_probe();f.viewport.queue_free()
  pair.clear();await process_frame;await process_frame
 finish()

func finish():
 var report={"passed":not failed,"gpu_pixels_verified":not cpu_only and not failed,"cpu_only":cpu_only,"cycles":cycle+1,"phases":rows,"store":Store.get_audit(),"scope":"Two full desktop source-board lifecycles, independent mutable resources, fixed 0.05 source clock, seeded source-range click gates. Exact GPU bytes, no tolerance; not original-client or whole-game parity."}
 if guard!=null:report.environment=guard.runtime_evidence()
 if not output.is_empty():
  var file=FileAccess.open(output,FileAccess.WRITE)
  if file==null:check(false,"Cannot write report "+output)
  else:file.store_string(JSON.stringify(report,"  "));file.close()
 for f in pair:f.probe.close_probe();f.viewport.queue_free()
 Store.enabled=false
 print("BOARD_SOURCE_",("CPU" if cpu_only else "RENDER"),"_PARITY_",("FAIL" if failed else "PASS")," phases=",rows.size())
 quit(1 if failed else 0)
