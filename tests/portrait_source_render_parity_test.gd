extends SceneTree
## Actual production portrait loader, exact GPU pixels. Not a timing fixture.
const Source=preload("res://scripts/portrait_source_images.gd")
const SIZE=Vector2i(1600,900)
var failed=false
var output=""
var rows:Array=[]
var guard
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->bool:
 if not ok:failed=true;push_error("PORTRAIT_SOURCE_PARITY_FAIL "+message)
 return ok
func fixture(candidate:bool)->Dictionary:
 Source.enabled=candidate
 var Game=load("res://scripts/game.gd")
 var game=Game.new();game.native_startup_timing.enabled=false;game._load_portraits()
 var viewport=SubViewport.new();viewport.size=SIZE;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var background=ColorRect.new();background.size=SIZE;background.color=Color(0.17,0.3,0.43,1);viewport.add_child(background)
 var textures:Array=game.raw_portraits+game.portraits
 for i in textures.size():
  var rect=TextureRect.new();rect.position=Vector2((i%12)*132+2,(i/12)*88+2);rect.size=Vector2(128,84)
  rect.texture=textures[i];rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  rect.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;viewport.add_child(rect)
 return {"game":game,"viewport":viewport,"textures":textures.size()}
func black_root()->bool:
 if not check(guard.runtime_evidence().active,"Privacy guard inactive"):return false
 var image=root.get_texture().get_image()
 if not check(image!=null and not image.is_empty(),"Missing protected root image"):return false
 image.convert(Image.FORMAT_RGBA8);var bytes=image.get_data()
 for i in range(0,bytes.size(),4):
  if bytes[i]!=0 or bytes[i+1]!=0 or bytes[i+2]!=0 or bytes[i+3]!=255:return check(false,"Root privacy pixel not opaque black")
 return true
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--parity-output="):output=arg.trim_prefix("--parity-output=")
 guard=root.get_node_or_null("PrivacyTestGuard")
 if not check(guard!=null and guard.runtime_evidence().active,"Requires active privacy guard") or not check(DisplayServer.get_name()!="headless","Requires real GPU"):finish();return
 root.unfocusable=true
 var policy=Source.build_export_manifest(Source.default_portrait_paths())
 if not check(not policy.entries.is_empty() and Source.set_verified_manifest(policy),"Verified source policy"):finish();return
 for cycle in range(2):
  Source.reset_audit()
  var reference=fixture(false);var candidate=fixture(true)
  check(reference.textures==116 and reference.textures==candidate.textures,"All 58 raw and 58 cropped slots rendered")
  var audit=Source.get_audit()
  check(audit.hits==policy.entries.size() and audit.fallbacks==0 and audit.errors==0,"All source images acquired without fallback")
  for i in range(3):
   await process_frame;await RenderingServer.frame_post_draw
   if not black_root():break
  var a:Image=reference.viewport.get_texture().get_image();var b:Image=candidate.viewport.get_texture().get_image()
  check(a!=null and b!=null and not a.is_empty() and a.get_size()==SIZE and a.get_format()==b.get_format(),"Rendered layout")
  if not failed:
   var ab=a.get_data();var bb=b.get_data()
   check(ab==bb,"Exact GPU bytes differ; no tolerance")
   var rgba=a.duplicate();rgba.convert(Image.FORMAT_RGBA8);var data=rgba.get_data();var varying=0
   for i in range(4,data.size(),4):
    if data[i]!=data[0] or data[i+1]!=data[1] or data[i+2]!=data[2]:varying+=1
   check(varying>100000,"Portrait atlas has no real visible content")
   rows.append({"cycle":cycle,"size":str(SIZE),"textures":reference.textures,"baseline_sha256":Source.sha256(ab),"candidate_sha256":Source.sha256(bb),"varying_pixels":varying,"audit":audit})
  for f in [reference,candidate]:f.game.free();f.viewport.queue_free()
  await process_frame;await process_frame
  if failed:break
 finish()
func finish():
 Source.enabled=false
 var report={"passed":not failed,"gpu_pixels_verified":not failed and rows.size()==2,"cycles":rows,"scope":"Production raw/cropped portrait textures rendered at identical layout, two fresh lifecycles; exact GPU bytes. Root remains black. Not whole-game parity or timing."}
 if not output.is_empty():
  var file=FileAccess.open(output,FileAccess.WRITE)
  if file==null:check(false,"Report path unavailable")
  else:file.store_string(JSON.stringify(report,"  "));file.close()
 print("PORTRAIT_SOURCE_RENDER_PARITY_",("FAIL" if failed else "PASS")," ",JSON.stringify(report))
 quit(1 if failed else 0)
