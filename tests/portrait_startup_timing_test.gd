extends SceneTree
const Mask=preload("res://scripts/portrait_circle_mask.gd")
const STAGES=["exists_us","load_us","get_image_us","missing_image_us","convert_rgba8_us","duplicate_us","raw_texture_create_us","circle_mask_us","cropped_texture_create_us"]
var checks:int=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  push_error(message)
  quit(1)
  assert(ok,message)
func image_digest(image:Image)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
 hash.update(image.get_data())
 return hash.finish().hex_encode()
func same_image(actual:Image,expected:Image,label:String):
 check(actual!=null and not actual.is_empty(),label+" nonempty")
 check(actual.get_size()==expected.get_size(),label+" dimensions")
 check(actual.get_format()==expected.get_format(),label+" format")
 check(actual.has_mipmaps()==expected.has_mipmaps(),label+" mipmaps")
 check(actual.get_mipmap_count()==expected.get_mipmap_count(),label+" mipmap count")
 check(image_digest(actual)==image_digest(expected),label+" exact image bytes")
func portrait_ids()->Array:
 # Read the actual call site's list, then use the same public expansion API.
 var source=FileAccess.get_file_as_string("res://scripts/game.gd")
 var function=source.get_slice("func _load_portraits():",1).get_slice("\nfunc ",0)
 var ids:Array=JSON.parse_string(function.get_slice("var ids = ",1).get_slice("\n",0))
 ids.append_array(preload("res://scripts/classic_flow_cards.gd").extra_portrait_ids())
 return ids
func run():
 var Game=load("res://scripts/game.gd")
 var ids=portrait_ids()
 var off=Game.new();off.native_startup_timing.enabled=false
 off._load_portraits()
 check(off.native_startup_timing.records.is_empty(),"disabled instrumentation emits no records")
 check(off.portraits.size()==ids.size() and off.raw_portraits.size()==ids.size(),"all indexed slots retained")
 var unique:Dictionary={}
 var source_layout:Dictionary={}
 var missing:Array=[]
 for i in ids.size():
  var id:String=ids[i]
  if unique.has(id):
   var first:int=unique[id]
   check(off.raw_portraits[i]==off.raw_portraits[first],"disabled duplicate raw alias "+id)
   check(off.portraits[i]==off.portraits[first],"disabled duplicate cropped alias "+id)
   if missing.has(first):missing.append(i)
   continue
  unique[id]=i
  var path:String="res://assets/original_classic_v13/art/"+id+".png"
  if not ResourceLoader.exists(path):path="res://assets/original_classic_v13/art/"+id+".webp"
  var expected:Image
  if ResourceLoader.exists(path):expected=(load(path) as Texture2D).get_image()
  else:
   missing.append(i);expected=Image.create(256,256,false,Image.FORMAT_RGBA8);expected.fill(Color("302739"))
  source_layout[id]={"format":expected.get_format(),"has_mipmaps":expected.has_mipmaps(),"mipmap_count":expected.get_mipmap_count()}
  expected.convert(Image.FORMAT_RGBA8)
  same_image(off.raw_portraits[i].get_image(),expected,"disabled raw "+id)
  Mask.apply(expected)
  same_image(off.portraits[i].get_image(),expected,"disabled cropped "+id)
 check(off.missing_portrait_indices==missing,"disabled missing slot indices")
 # Hold one source texture so a known ResourceLoader cache hit is exercised.
 var cached_path:String="res://assets/original_classic_v13/art/HERO_08.png"
 var cached_texture:Texture2D=load(cached_path)
 check(cached_texture!=null and ResourceLoader.has_cached(cached_path),"source cache fixture")
 var on=Game.new();on.native_startup_timing.enabled=true
 on.native_startup_timing.origin_us=Time.get_ticks_usec()
 on._load_portraits()
 check(on.missing_portrait_indices==off.missing_portrait_indices,"enabled missing slots unchanged")
 check(on.raw_portraits.size()==ids.size() and on.portraits.size()==ids.size(),"enabled indexed slots unchanged")
 for i in ids.size():
  var first:int=unique[ids[i]]
  if first!=i:
   check(on.raw_portraits[i]==on.raw_portraits[first],"enabled duplicate raw alias")
   check(on.portraits[i]==on.portraits[first],"enabled duplicate cropped alias")
  else:
   same_image(on.raw_portraits[i].get_image(),off.raw_portraits[i].get_image(),"enabled raw "+ids[i])
   same_image(on.portraits[i].get_image(),off.portraits[i].get_image(),"enabled cropped "+ids[i])
 var rows:Dictionary={};var summary:Dictionary={}
 for row in on.native_startup_timing.records:
  if row.event=="portrait_source_cpu":
   check(not rows.has(row.id),"one record per unique ID")
   rows[row.id]=row
   var first:int=unique[row.id]
   var raw:Image=on.raw_portraits[first].get_image()
   check(row.width==raw.get_width() and row.height==raw.get_height(),"record dimensions")
   check(row.source_format==source_layout[row.id].format,"record source format")
   check(row.source_has_mipmaps==source_layout[row.id].has_mipmaps and row.source_mipmap_count==source_layout[row.id].mipmap_count,"record source mipmaps")
   check(row.output_format==Image.FORMAT_RGBA8,"record output format")
   check(row.output_has_mipmaps==raw.has_mipmaps() and row.output_mipmap_count==raw.get_mipmap_count(),"record mipmaps")
   check(row.missing==missing.has(first),"record missing state")
   check(row.slot_count==ids.count(row.id) and row.dedup_cache_hits==ids.count(row.id)-1,"record duplicate counts")
   check(row.exists_queries==2,"preserve both original existence checks")
   for stage in STAGES:check(row.has(stage) and row[stage]>=0,"nonnegative stage "+stage)
  elif row.event=="portraits_source_summary":summary=row
  else:check(false,"unexpected diagnostic event")
 check(rows.size()==unique.size(),"all unique source records")
 check(rows.HERO_08.resource_cache_hit,"known source cache hit recorded")
 for id in ["CS2_172","CS2_186","CS2_200"]:
  check(rows[id].path.ends_with(".webp") and not rows[id].missing,"existing WebP fallback "+id)
 check(summary.slots==ids.size() and summary.unique_ids==unique.size(),"summary slot/unique totals")
 check(summary.dedup_cache_hits==ids.size()-unique.size(),"summary duplicate count")
 check(summary.missing_slots==missing.size(),"summary missing count")
 check(on.native_startup_timing.records.back().event=="portraits_source_summary","summary follows source records")
 # A second invocation must clear outputs and report fresh counts, not accumulate.
 on.native_startup_timing.records.clear();on._load_portraits()
 check(on.native_startup_timing.records.size()==unique.size()+1,"repeat invocation fresh records")
 check(on.portraits.size()==ids.size() and on.raw_portraits.size()==ids.size(),"repeat invocation resets slots")
 check(on.missing_portrait_indices==missing,"repeat invocation resets missing slots")
 off.free();on.free()
 test_missing_fixture()
 print("PORTRAIT_STARTUP_TIMING_PASS checks=",checks," slots=",ids.size()," unique_ids=",unique.size()," exact raw/cropped bytes, aliasing, flag-off silence, stage metadata, cache hit, repeat invocation")
 quit()

func test_missing_fixture():
 # Compile the actual production method in a minimal host, replacing only its
 # source-ID fixture. No real asset is renamed, removed, or overwritten.
 var source=FileAccess.get_file_as_string("res://scripts/game.gd")
 var function="func _load_portraits():"+source.get_slice("func _load_portraits():",1).get_slice("\nfunc ",0)
 var ids_line="\tvar ids = "+function.get_slice("\tvar ids = ",1).get_slice("\n",0)
 function=function.replace(ids_line,'\tvar ids = ["__missing_portrait_timing_fixture__","__missing_portrait_timing_fixture__"]')
 function=function.replace('\tids.append_array(preload("res://scripts/classic_flow_cards.gd").extra_portrait_ids())\n',"")
 var script=GDScript.new()
 script.source_code='extends RefCounted\nvar portraits:Array=[]\nvar raw_portraits:Array=[]\nvar missing_portrait_indices:Array=[]\nvar native_startup_timing=preload("res://scripts/native_startup_timing.gd").new()\n'+function
 check(script.reload()==OK,"missing fixture compiles production method")
 var off=script.new();var on=script.new()
 off.native_startup_timing.enabled=false;on.native_startup_timing.enabled=true
 off._load_portraits();on._load_portraits()
 check(off.native_startup_timing.records.is_empty(),"missing fixture flag-off silence")
 check(off.missing_portrait_indices==[0,1] and on.missing_portrait_indices==[0,1],"missing duplicate slot indices")
 check(off.raw_portraits[0]==off.raw_portraits[1] and on.raw_portraits[0]==on.raw_portraits[1],"missing duplicate raw aliases")
 check(off.portraits[0]==off.portraits[1] and on.portraits[0]==on.portraits[1],"missing duplicate cropped aliases")
 var expected=Image.create(256,256,false,Image.FORMAT_RGBA8);expected.fill(Color("302739"))
 same_image(off.raw_portraits[0].get_image(),expected,"missing raw fallback")
 same_image(on.raw_portraits[0].get_image(),expected,"missing timed raw fallback")
 Mask.apply(expected)
 same_image(off.portraits[0].get_image(),expected,"missing cropped fallback")
 same_image(on.portraits[0].get_image(),expected,"missing timed cropped fallback")
 check(on.native_startup_timing.records.size()==2,"missing fixture one source and summary")
 var row=on.native_startup_timing.records[0]
 check(row.missing and row.path.ends_with(".webp") and not row.resource_cache_hit,"missing fallback record")
 check(row.slot_count==2 and row.dedup_cache_hits==1,"missing duplicate counts")
 check(row.load_us==0 and row.get_image_us==0 and row.missing_image_us>=0,"missing load/get_image not executed")
 check(row.width==256 and row.height==256 and row.source_format==Image.FORMAT_RGBA8,"missing fallback metadata")
 var summary=on.native_startup_timing.records[1]
 check(summary.unique_ids==1 and summary.slots==2 and summary.missing_ids==1 and summary.missing_slots==2,"missing summary")
