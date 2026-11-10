@tool
extends RefCounted
## Experimental CPU source-image acquisition. No texture or image is cached.
## Windows-only, opt-in, and fail-closed: callers retain load(path).get_image().
## The allowlist is generated in a separate preparation/export process, never in
## a timed game process. Ordinary exports need not contain this optional file.
const MANIFEST_PATH:String="res://assets/portrait_source_policy.json"
const SCHEMA_VERSION:int=1
const POLICY_VERSION:String="godot-4.7.1-lossless-rgb-rgba-fix-alpha-v1"
const ENGINE_HASH:String="a13da4feb8d8aefc283c3763d33a2f170a18d541"
const PARAMS:Dictionary={
	"compress/mode":0,"compress/high_quality":false,"compress/lossy_quality":0.7,
	"compress/uastc_level":0,"compress/rdo_quality_loss":0.0,"compress/hdr_compression":1,
	"compress/normal_map":0,"compress/channel_pack":0,"mipmaps/generate":false,
	"mipmaps/limit":-1,"roughness/mode":0,"roughness/src_normal":"",
	"process/channel_remap/red":0,"process/channel_remap/green":1,
	"process/channel_remap/blue":2,"process/channel_remap/alpha":3,
	"process/premult_alpha":false,"process/normal_map_invert_y":false,
	"process/hdr_as_srgb":false,"process/hdr_clamp_exposure":false,
	"process/size_limit":0,"detect_3d/compress_to":1}
static var enabled:bool=false
static var _manifest_checked:bool=false
static var _manifest:Dictionary={}
static var _hits:int=0
static var _fallbacks:int=0
static var _bytes:int=0
static var _errors:int=0
static var _policy_loads:int=0

static func get_audit()->Dictionary:
	return {"enabled":enabled,"policy_loaded":not _manifest.is_empty(),"hits":_hits,
		"fallbacks":_fallbacks,"bytes":_bytes,"errors":_errors,"policy_loads":_policy_loads,
		"policy_entries":_manifest.get("entries",{}).size()}

static func reset_audit()->void:
	_hits=0;_fallbacks=0;_bytes=0;_errors=0

static func default_portrait_paths()->Array:
	# Preparation/export only: read the one authoritative production ID list.
	# Do not instantiate Game (which would preload unrelated game resources).
	var source:String=FileAccess.get_file_as_string("res://scripts/game.gd")
	var method:String=source.get_slice("func _load_portraits():",1).get_slice("\nfunc ",0)
	var parser:=JSON.new()
	if parser.parse(method.get_slice("var ids = ",1).get_slice("\n",0))!=OK or not parser.data is Array:return []
	var ids:Array=parser.data
	ids.append_array(preload("res://scripts/classic_flow_cards.gd").extra_portrait_ids())
	var paths:Array=[]
	for id in ids:
		var path:String="res://assets/original_classic_v13/art/"+str(id)+".png"
		if not ResourceLoader.exists(path):path="res://assets/original_classic_v13/art/"+str(id)+".webp"
		if not paths.has(path):paths.append(path)
	return paths

static func sha256(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	return hash.finish().hex_encode()

static func _engine_supported()->bool:
	return Engine.get_version_info().get("hash","")==ENGINE_HASH

static func _supported_path(path:String)->bool:
	return path.begins_with("res://") and path.get_extension() in ["png","webp"]

static func _hash_valid(value:Variant)->bool:
	if not value is String or value.length()!=64:return false
	for character in value:
		if not character in "0123456789abcdef":return false
	return true

static func _integer_in(value:Variant,minimum:int,maximum:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=minimum and value<=maximum

static func _entry_valid(entry:Variant)->bool:
	if not entry is Dictionary or entry.size()!=8:return false
	return _hash_valid(entry.get("source_sha256")) and _hash_valid(entry.get("import_sha256")) \
		and _hash_valid(entry.get("image_sha256")) and entry.get("fix_alpha_edges") is bool \
		and _integer_in(entry.get("source_bytes"),1,67108864) \
		and _integer_in(entry.get("width"),1,16383) and _integer_in(entry.get("height"),1,16383) \
		and _integer_in(entry.get("format"),Image.FORMAT_RGB8,Image.FORMAT_RGBA8)

static func _manifest_valid(manifest:Dictionary)->bool:
	if manifest.size()!=4 or manifest.get("schema_version")!=SCHEMA_VERSION \
		or manifest.get("policy_version")!=POLICY_VERSION or manifest.get("engine_hash")!=ENGINE_HASH \
		or not manifest.get("entries") is Dictionary:return false
	for path in manifest.entries:
		if not path is String or not _supported_path(path) or not _entry_valid(manifest.entries[path]):return false
	return true

static func set_verified_manifest(manifest:Dictionary)->bool:
	# Only metadata is retained. Replacing/clearing it cannot retain any images.
	_manifest_checked=true;_manifest={}
	if not _engine_supported() or not _manifest_valid(manifest):return false
	_manifest=manifest.duplicate(true)
	_policy_loads+=1
	return true

static func reset_manifest()->void:
	_manifest={};_manifest_checked=false;_policy_loads=0

static func _read_bytes(path:String,maximum:int,expected_length:int=-1)->PackedByteArray:
	if not FileAccess.file_exists(path):return PackedByteArray()
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or not file.is_open():return PackedByteArray()
	var bytes:PackedByteArray=_consume_file(file,maximum,expected_length)
	if file.is_open():file.close()
	return bytes

static func _consume_file(file,maximum:int,expected_length:int=-1)->PackedByteArray:
	# A sparse-pack backing failure can produce a non-null, already closed file.
	if file==null or not file.is_open():return PackedByteArray()
	var length:int=file.get_length()
	if not file.is_open() or file.get_error()!=OK or length<=0 or length>maximum \
		or (expected_length>=0 and length!=expected_length):return PackedByteArray()
	if file.get_position()!=0 or not file.is_open() or file.get_error()!=OK:return PackedByteArray()
	var bytes:PackedByteArray=file.get_buffer(length)
	if not file.is_open() or file.get_error()!=OK or bytes.size()!=length:return PackedByteArray()
	if file.get_position()!=length or not file.is_open() or file.get_error()!=OK:return PackedByteArray()
	return bytes

static func _ensure_manifest()->void:
	if _manifest_checked:return
	_manifest_checked=true
	if not FileAccess.file_exists(MANIFEST_PATH):return
	var parser:=JSON.new()
	if parser.parse(_read_bytes(MANIFEST_PATH,1048576).get_string_from_utf8())!=OK or not parser.data is Dictionary:return
	set_verified_manifest(parser.data)

static func read_import_policy(path:String)->Dictionary:
	# Reject unknown keys and every unreviewed preprocessing/compression policy.
	# Pinned source: resource_importer_texture.cpp import/_save_ctex and
	# modules/webp/webp_common.cpp (lossless uses config.exact=1).
	if not _engine_supported() or not _supported_path(path) or not FileAccess.file_exists(path+".import"):return {}
	var bytes:PackedByteArray=_read_bytes(path+".import",1048576)
	var config:=ConfigFile.new()
	if config.parse(bytes.get_string_from_utf8())!=OK:return {}
	var sections:PackedStringArray=config.get_sections();sections.sort()
	if sections!=PackedStringArray(["deps","params","remap"]):return {}
	var remap_keys:PackedStringArray=config.get_section_keys("remap");remap_keys.sort()
	if remap_keys!=PackedStringArray(["importer","metadata","path","type","uid"]):return {}
	if config.get_value("remap","importer",null)!="texture" or config.get_value("remap","type",null)!="CompressedTexture2D":return {}
	var metadata:Variant=config.get_value("remap","metadata",null)
	if not metadata is Dictionary or metadata.size()!=1 or metadata.get("vram_texture")!=false:return {}
	var dest:Variant=config.get_value("remap","path",null)
	if not dest is String or not dest.begins_with("res://.godot/imported/") or not dest.ends_with(".ctex"):return {}
	var deps_keys:PackedStringArray=config.get_section_keys("deps");deps_keys.sort()
	if deps_keys!=PackedStringArray(["dest_files","source_file"]):return {}
	if config.get_value("deps","source_file",null)!=path or config.get_value("deps","dest_files",null)!=[dest]:return {}
	var keys:PackedStringArray=config.get_section_keys("params")
	if keys.size()!=PARAMS.size()+1:return {}
	for key in PARAMS:
		if not config.has_section_key("params",key):return {}
		var value:Variant=config.get_value("params",key,null)
		if typeof(value)!=typeof(PARAMS[key]) or value!=PARAMS[key]:return {}
	if not config.has_section_key("params","process/fix_alpha_border"):return {}
	var fix:Variant=config.get_value("params","process/fix_alpha_border",null)
	if not fix is bool:return {}
	return {"fix_alpha_edges":fix,"import_sha256":sha256(bytes)}

static func _decode(bytes:PackedByteArray,extension:String,fix_alpha_edges:bool)->Image:
	var image:=Image.new()
	var error:Error=ERR_FILE_UNRECOGNIZED
	if extension=="png":error=image.load_png_from_buffer(bytes)
	elif extension=="webp":error=image.load_webp_from_buffer(bytes)
	if error!=OK or image.is_empty() or image.has_mipmaps() \
		or not image.get_format() in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8] \
		or image.get_width()>16383 or image.get_height()>16383:return null
	# This is the importer's exact operation, before game.gd's RGBA conversion.
	# In particular, transparent pixels are not assumed to be black or opaque.
	if fix_alpha_edges:image.fix_alpha_edges()
	return image

static func try_load(path:String)->Image:
	if not enabled:return null
	if OS.get_name()!="Windows" or not _engine_supported():
		_fallbacks+=1;return null
	_ensure_manifest()
	if _manifest.is_empty() or not _manifest.entries.has(path):
		_fallbacks+=1;return null
	var image:Image=_read_entry(path,_manifest.entries[path],OS.has_feature("editor"))
	if image==null:
		_fallbacks+=1;_errors+=1
	else:_hits+=1
	return image

static func _read_entry(path:String,entry:Dictionary,check_import:bool)->Image:
	if not _entry_valid(entry) or not _supported_path(path) or not FileAccess.file_exists(path):return null
	# Source-tree runs also reject changed import settings. Exported packs do not
	# depend on .import files: their policy was verified afresh during export.
	if check_import:
		var policy:Dictionary=read_import_policy(path)
		if policy.is_empty() or policy.import_sha256!=entry.import_sha256 \
			or policy.fix_alpha_edges!=entry.fix_alpha_edges:return null
	var bytes:PackedByteArray=_read_bytes(path,67108864,int(entry.source_bytes))
	_bytes+=bytes.size()
	if bytes.size()!=int(entry.source_bytes) or sha256(bytes)!=entry.source_sha256:return null
	var image:Image=_decode(bytes,path.get_extension(),entry.fix_alpha_edges)
	if image==null or image.get_width()!=int(entry.width) or image.get_height()!=int(entry.height) \
		or image.get_format()!=int(entry.format) or sha256(image.get_data())!=entry.image_sha256:return null
	return image

static func build_export_manifest(paths:Array)->Dictionary:
	# Run ONLY in an untimed preparation/export process. Each eligible source is
	# compared to the real imported texture, including native format and all bytes.
	var manifest:Dictionary={"schema_version":SCHEMA_VERSION,"policy_version":POLICY_VERSION,
		"engine_hash":ENGINE_HASH,"entries":{}}
	if not _engine_supported():return manifest
	for path in paths:
		if not path is String or manifest.entries.has(path):continue
		var policy:Dictionary=read_import_policy(path)
		if policy.is_empty() or not FileAccess.file_exists(path) or not ResourceLoader.exists(path):continue
		var bytes:PackedByteArray=_read_bytes(path,67108864)
		if bytes.is_empty() or bytes.size()>67108864:continue
		var image:Image=_decode(bytes,path.get_extension(),policy.fix_alpha_edges)
		if image==null:continue
		var texture:Texture2D=ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if texture==null:continue
		var reference:Image=texture.get_image();texture=null
		if reference==null or reference.get_size()!=image.get_size() or reference.get_format()!=image.get_format() \
			or reference.has_mipmaps() or reference.get_data()!=image.get_data():continue
		# Reject concurrent changes while preparing the allowlist.
		if sha256(_read_bytes(path,67108864))!=sha256(bytes) \
			or read_import_policy(path)!=policy:continue
		manifest.entries[path]={"source_bytes":bytes.size(),"source_sha256":sha256(bytes),
			"import_sha256":policy.import_sha256,"fix_alpha_edges":policy.fix_alpha_edges,
			"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),
			"image_sha256":sha256(image.get_data())}
	return manifest
