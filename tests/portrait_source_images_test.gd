extends SceneTree
const Source=preload("res://scripts/portrait_source_images.gd")
const Mask=preload("res://scripts/portrait_circle_mask.gd")
const FIXTURES:String="res://tests/fixtures/portrait_source_images/"
var checks:int=0
var failures:int=0

class FileStub:
	extends RefCounted
	var open:bool=true
	var mode:String="ok"
	var position:int=0
	var error:int=OK
	func is_open()->bool:return open
	func get_error()->int:return error
	func get_length()->int:
		if mode=="closed_length":open=false
		if mode=="error_length":error=ERR_FILE_CANT_READ
		return 4
	func get_position()->int:return position
	func get_buffer(_length:int)->PackedByteArray:
		if mode=="closed_read":open=false
		if mode=="error_read":error=ERR_FILE_CANT_READ
		position=3 if mode=="bad_position" else 4
		return PackedByteArray([1,2]) if mode=="short" else PackedByteArray([1,2,3,4])

func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok:
		failures+=1;push_error(message)

func same_image(actual:Image,expected:Image,label:String):
	check(actual!=null and not actual.is_empty(),label+" nonempty")
	check(actual.get_size()==expected.get_size(),label+" dimensions")
	check(actual.get_format()==expected.get_format(),label+" native format")
	check(actual.has_mipmaps()==expected.has_mipmaps(),label+" mipmaps")
	check(actual.get_mipmap_count()==expected.get_mipmap_count(),label+" mipmap count")
	check(actual.get_data()==expected.get_data(),label+" every image byte")

func write_bytes(path:String,bytes:PackedByteArray):
	var file=FileAccess.open(path,FileAccess.WRITE)
	check(file!=null and file.is_open(),"fixture write opens")
	file.store_buffer(bytes);file.close()

func run():
	check(not Source.enabled,"candidate defaults OFF")
	check(Source.get_audit().policy_loads==0 and not Source.get_audit().policy_loaded,"no eager policy loading")
	var paths:Array=Source.default_portrait_paths()
	check(paths.size()==54,"54 unique production portrait paths")
	var manifest:Dictionary=Source.build_export_manifest(paths)
	check(manifest.entries.size()==54,"all production imports verified")
	check(JSON.stringify(manifest).to_utf8_buffer().size()<32768,"metadata only, no pixel bundle")
	check(Source.set_verified_manifest(JSON.parse_string(JSON.stringify(manifest))),"JSON numeric representation roundtrip")
	check(Source.try_load(paths[0])==null and Source.get_audit().hits==0,"disabled source path performs no loads")
	Source.enabled=true
	for path in paths:
		var actual:Image=Source.try_load(path) if OS.get_name()=="Windows" else Source._read_entry(path,manifest.entries[path],true)
		var reference:Image=(load(path) as Texture2D).get_image()
		same_image(actual,reference,"native "+path)
		actual.convert(Image.FORMAT_RGBA8);reference.convert(Image.FORMAT_RGBA8)
		same_image(actual,reference,"raw RGBA "+path)
		Mask.apply(actual);Mask.apply(reference)
		same_image(actual,reference,"cropped RGBA "+path)
	if OS.get_name()=="Windows":
		var audit=Source.get_audit()
		check(audit.hits==54 and audit.fallbacks==0 and audit.errors==0,"all direct source hits, no fallback")
		check(audit.policy_entries==54 and audit.policy_loads==1,"one metadata load")
		check(audit.bytes==9929457,"all source reads counted")
	for id in ["CS2_172","CS2_186","CS2_200"]:
		check(manifest.entries.has("res://assets/original_classic_v13/art/"+id+".webp"),"production WebP fallback "+id)
	test_alpha_fixtures()
	test_policy_and_changes(manifest)
	test_bad_manifests(manifest,paths[0])
	test_io_failures()
	if OS.get_name()=="Windows":test_game_routes(manifest)
	Source.enabled=false;Source.reset_manifest();Source.reset_audit()
	if failures==0:print("PORTRAIT_SOURCE_IMAGES_PASS checks=",checks," unique=54 exact native/raw/cropped bytes; alpha/non-square/WebP; defaults; policy/source/integrity/I/O fallback; aliases/missing/reload")
	else:print("PORTRAIT_SOURCE_IMAGES_FAILED failures=",failures)
	quit(1 if failures else 0)

func test_alpha_fixtures():
	var paths:Array=[FIXTURES+"rgba8_transparent.png",FIXTURES+"rgba8_opaque.png",FIXTURES+"rgb8_non_square.webp",FIXTURES+"l8_unsupported.png"]
	var manifest:Dictionary=Source.build_export_manifest(paths)
	check(manifest.entries.size()==3,"verified RGB/RGBA only; L8 safely unsupported")
	check(not manifest.entries.has(paths[3]),"unknown native format is not allowlisted")
	for path in paths.slice(0,3):
		var direct:Image=Source._read_entry(path,manifest.entries[path],true)
		var reference:Image=(load(path) as Texture2D).get_image()
		check(direct.get_size()==Vector2i(13,9),"non-square dimensions retained")
		same_image(direct,reference,"fixture native "+path)
		direct.convert(Image.FORMAT_RGBA8);reference.convert(Image.FORMAT_RGBA8)
		same_image(direct,reference,"fixture raw "+path)
		Mask.apply(direct);Mask.apply(reference)
		same_image(direct,reference,"fixture cropped "+path)
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(paths[0])
	var before:Image=Source._decode(bytes,"png",false)
	var after:Image=Source._decode(bytes,"png",true)
	check(before.get_data()!=after.get_data(),"transparent fixture actually exercises fix_alpha_edges")
	check(after.detect_alpha()!=Image.ALPHA_NONE,"fixture has real partial/zero alpha")

func test_policy_and_changes(manifest:Dictionary):
	var original:String=manifest.entries.keys()[0]
	var path:String="res://build/portrait_source_policy_fixture.png"
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(original)
	write_bytes(path,bytes)
	var config:=ConfigFile.new();check(config.load(original+".import")==OK,"read known policy")
	config.set_value("deps","source_file",path)
	check(config.save(path+".import")==OK,"write isolated policy fixture")
	var valid_text:String=FileAccess.get_file_as_string(path+".import")
	var policy:Dictionary=Source.read_import_policy(path)
	check(not policy.is_empty(),"copied known policy accepted")
	var entry:Dictionary=manifest.entries[original].duplicate(true)
	entry.import_sha256=policy.import_sha256
	check(Source._read_entry(path,entry,true)!=null,"isolated source accepted")
	for key in Source.PARAMS:
		config.clear();config.parse(valid_text)
		var value:Variant=Source.PARAMS[key]
		if value is bool:value=not value
		elif value is String:value="unreviewed"
		else:value+=1
		config.set_value("params",key,value);config.save(path+".import")
		check(Source.read_import_policy(path).is_empty(),"reject altered policy "+key)
		check(Source._read_entry(path,entry,true)==null,"fallback for altered policy "+key)
	config.clear();config.parse(valid_text);config.set_value("params","unreviewed/future_flag",false);config.save(path+".import")
	check(Source.read_import_policy(path).is_empty(),"unknown future flag rejected")
	config.clear();config.parse(valid_text);config.erase_section_key("params","mipmaps/generate");config.save(path+".import")
	check(Source.read_import_policy(path).is_empty(),"missing known flag rejected")
	config.clear();config.parse(valid_text);config.set_value("params","process/fix_alpha_border",false);config.save(path+".import")
	check(not Source.read_import_policy(path).is_empty(),"explicit fix-alpha false policy reviewed")
	check(Source._read_entry(path,entry,true)==null,"changed alpha policy invalidates old manifest")
	config.clear();config.parse(valid_text);config.set_value("remap","metadata",{"vram_texture":true});config.save(path+".import")
	check(Source.read_import_policy(path).is_empty(),"VRAM import rejected")
	config.clear();config.parse(valid_text);config.set_value("remap","importer","image");config.save(path+".import")
	check(Source.read_import_policy(path).is_empty(),"unreviewed importer rejected")
	write_bytes(path+".import",valid_text.to_utf8_buffer())
	var changed:PackedByteArray=bytes.duplicate();changed[changed.size()-1]^=1
	write_bytes(path,changed)
	check(Source._read_entry(path,entry,true)==null,"same-size changed source checksum rejected")
	write_bytes(path,bytes.slice(0,bytes.size()-1))
	check(Source._read_entry(path,entry,true)==null,"short/truncated source size rejected")
	write_bytes(path,PackedByteArray())
	check(Source._read_entry(path,entry,true)==null,"empty/corrupt source rejected")
	write_bytes(path,bytes)
	check(Source._read_entry(path,entry,false)!=null,"pack path does not need import policy")
	write_bytes(path+".import",PackedByteArray())
	check(Source._read_entry(path,entry,true)==null,"source path rejects missing/corrupt import metadata")
	check(Source._read_entry(path,entry,false)!=null,"exported path independent of import files")
	var wrong:Dictionary=entry.duplicate(true);wrong.image_sha256="0".repeat(64)
	check(Source._read_entry(path,wrong,false)==null,"wrong processed-image hash rejected")
	wrong=entry.duplicate(true);wrong.width+=1
	check(Source._read_entry(path,wrong,false)==null,"wrong dimensions rejected")
	wrong=entry.duplicate(true);wrong.format=Image.FORMAT_RGBA8
	check(Source._read_entry(path,wrong,false)==null,"wrong native format rejected")
	check(Source._read_entry(path+"missing",entry,false)==null,"missing source rejected")
	check(DirAccess.remove_absolute(path)==OK,"remove isolated temporary source")
	check(DirAccess.remove_absolute(path+".import")==OK,"remove isolated temporary policy")

func test_bad_manifests(manifest:Dictionary,path:String):
	for field in ["schema_version","policy_version","engine_hash","entries"]:
		var bad:Dictionary=manifest.duplicate(true);bad.erase(field)
		check(not Source.set_verified_manifest(bad),"incomplete manifest rejected "+field)
		check(Source.try_load(path)==null,"missing manifest safely falls back")
	var bad:Dictionary=manifest.duplicate(true);bad.policy_version="unknown"
	check(not Source.set_verified_manifest(bad),"unknown policy version rejected")
	bad=manifest.duplicate(true);bad.engine_hash="different-engine"
	check(not Source.set_verified_manifest(bad),"other engine rejected")
	bad=manifest.duplicate(true);bad.entries[path].fix_alpha_edges=1
	check(not Source.set_verified_manifest(bad),"invalid policy types rejected")
	bad=manifest.duplicate(true);bad.entries[path].width=1.5
	check(not Source.set_verified_manifest(bad),"fractional dimensions rejected")
	bad=manifest.duplicate(true);bad.entries[path].source_sha256="not a checksum"
	check(not Source.set_verified_manifest(bad),"invalid checksum rejected")
	bad=manifest.duplicate(true);bad.extra="unknown"
	check(not Source.set_verified_manifest(bad),"unknown manifest keys rejected")
	check(Source.set_verified_manifest(manifest),"valid policy restored")
	manifest.entries[path].source_bytes+=1
	check(Source.try_load(path)!=null if OS.get_name()=="Windows" else true,"installed metadata cannot alias caller mutations")
	manifest.entries[path].source_bytes-=1

func test_io_failures():
	check(Source._consume_file(null,4).is_empty(),"null handle rejected")
	var closed=FileStub.new();closed.open=false
	check(Source._consume_file(closed,4).is_empty(),"non-null closed handle rejected")
	for mode in ["closed_length","error_length","closed_read","error_read","short","bad_position"]:
		var file=FileStub.new();file.mode=mode
		check(Source._consume_file(file,4).is_empty(),"read failure rejected "+mode)
	var seeked=FileStub.new();seeked.position=1
	check(Source._consume_file(seeked,4).is_empty(),"wrong initial position rejected")
	check(Source._consume_file(FileStub.new(),3).is_empty(),"size bound enforced")
	check(Source._consume_file(FileStub.new(),4,3).is_empty(),"manifest size enforced")
	check(Source._consume_file(FileStub.new(),4,4)==PackedByteArray([1,2,3,4]),"complete read accepted")

func test_game_routes(manifest:Dictionary):
	var Game=load("res://scripts/game.gd")
	Source.enabled=false;Source.reset_manifest();Source.reset_audit()
	var off=Game.new();off._load_portraits()
	check(not Source.get_audit().policy_loaded and Source.get_audit().policy_loads==0,"flag-off game never loads policy")
	Source.enabled=true;check(Source.set_verified_manifest(manifest),"install game policy");Source.reset_audit()
	var on=Game.new();on.native_startup_timing.enabled=true;on._load_portraits()
	check(on.portraits.size()==58 and on.raw_portraits.size()==58,"all 58 ordered slots retained")
	check(on.missing_portrait_indices==off.missing_portrait_indices,"missing slots preserved")
	for i in 58:
		same_image(on.raw_portraits[i].get_image(),off.raw_portraits[i].get_image(),"game raw slot "+str(i))
		same_image(on.portraits[i].get_image(),off.portraits[i].get_image(),"game cropped slot "+str(i))
		check(on.raw_portraits[i]!=off.raw_portraits[i],"no global ImageTexture reuse")
		for j in i:
			check((on.raw_portraits[i]==on.raw_portraits[j])==(off.raw_portraits[i]==off.raw_portraits[j]),"raw dedup alias graph")
			check((on.portraits[i]==on.portraits[j])==(off.portraits[i]==off.portraits[j]),"cropped dedup alias graph")
	var audit:Dictionary=Source.get_audit()
	check(audit.hits==54 and audit.fallbacks==0 and audit.errors==0 and audit.policy_loads==1,"game exactly 54 source decodes and one manifest")
	for row in on.native_startup_timing.records:
		if row.event=="portrait_source_cpu":
			check(row.source_image_hit and row.source_image_us>=0,"source timing covers full acquisition")
			check(row.load_us==0 and row.get_image_us==0,"temporary imported Texture2D bypassed")
	var first_texture:ImageTexture=on.raw_portraits[0]
	Source.reset_audit();on._load_portraits()
	check(on.raw_portraits[0]!=first_texture,"repeat invocation creates owner-local texture")
	check(Source.get_audit().hits==54 and Source.get_audit().policy_loads==1,"repeat invocation decodes afresh without reloading metadata")
	var bad:Dictionary=manifest.duplicate(true)
	bad.entries["res://assets/original_classic_v13/art/HERO_08.png"].source_sha256="0".repeat(64)
	Source.set_verified_manifest(bad);Source.reset_audit();on._load_portraits()
	check(Source.get_audit().hits==53 and Source.get_audit().fallbacks==1 and Source.get_audit().errors==1,"checksum failure uses original resource fallback")
	same_image(on.raw_portraits[0].get_image(),off.raw_portraits[0].get_image(),"failed source raw fallback")
	same_image(on.portraits[0].get_image(),off.portraits[0].get_image(),"failed source cropped fallback")
	off.free();on.free()
	test_missing_game_fixture()

func test_missing_game_fixture():
	var source:String=FileAccess.get_file_as_string("res://scripts/game.gd")
	var method:String="func _load_portraits():"+source.get_slice("func _load_portraits():",1).get_slice("\nfunc ",0)
	var ids_line:String="\tvar ids = "+method.get_slice("\tvar ids = ",1).get_slice("\n",0)
	method=method.replace(ids_line,'\tvar ids = ["__missing_portrait_source_fixture__","__missing_portrait_source_fixture__"]')
	method=method.replace('\tids.append_array(preload("res://scripts/classic_flow_cards.gd").extra_portrait_ids())\n',"")
	var script:=GDScript.new()
	script.source_code='extends RefCounted\nvar portraits:Array=[]\nvar raw_portraits:Array=[]\nvar missing_portrait_indices:Array=[]\nvar native_startup_timing=preload("res://scripts/native_startup_timing.gd").new()\n'+method
	check(script.reload()==OK,"missing fixture uses production method")
	Source.reset_audit()
	var game=script.new();game._load_portraits()
	check(game.missing_portrait_indices==[0,1],"missing duplicate indices retained")
	check(game.raw_portraits[0]==game.raw_portraits[1] and game.portraits[0]==game.portraits[1],"missing fallback aliases retained")
	check(Source.get_audit().hits==0 and Source.get_audit().fallbacks==0,"missing resource is never sent to source decoder")
	var expected:=Image.create(256,256,false,Image.FORMAT_RGBA8);expected.fill(Color("302739"))
	same_image(game.raw_portraits[0].get_image(),expected,"missing placeholder raw")
	Mask.apply(expected);same_image(game.portraits[0].get_image(),expected,"missing placeholder cropped")
