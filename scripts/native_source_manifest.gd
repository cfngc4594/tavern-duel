extends RefCounted
## Immutable source JSON only. Mesh JSON remains transient in geometry(), and
## nodes, materials, textures, clips indexes and runtime copies stay per owner.
static var _startup_timing
static var _manifests: Dictionary={}
static var _parse_counts: Dictionary={}
static var _content_hashes: Dictionary={}
static var _failures: Array=[]
static var _cache_hits: Array=[]
static var _dag_hits: Array=[]

static func _key(path: String) -> String:
	# Exported sparse packs reopen their backing entry by the original scheme.
	# globalize(res://) can strip it when exported resource_path is empty.
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	return ProjectSettings.localize_path(ProjectSettings.globalize_path(path).simplify_path())

static func _freeze(value) -> void:
	if value is Dictionary:
		for child in value.values():_freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value:_freeze(child)
		value.make_read_only()

static func load_manifest(path: String) -> Dictionary:
	var result=load_source_dictionary(path)
	if not result.get("objects") is Dictionary:
		_failures.append({"path":path,"reason":"source manifest missing objects"});return {}
	return result

static func _timed_body_load_source_dictionary(path: String) -> Dictionary:
	var key:=_key(path)
	if _manifests.has(key):return _manifests[key]
	var dag_path=key.trim_suffix(".json")+".runtime.dag.bin"
	if FileAccess.file_exists(dag_path):
		var source_digest=_stream_sha256(key)
		var expected_source=_read_digest(dag_path+".source_sha256")
		var expected_cache=_read_digest(dag_path+".sha256")
		if not source_digest.is_empty() and not expected_cache.is_empty() and source_digest==expected_source and _stream_sha256(dag_path)==expected_cache:
			var variant=_read_variant(dag_path)
			var decoded=decode_dag(variant.get("value")) if variant.ok else {}
			if not decoded.is_empty():
				_manifests[key]=decoded;_content_hashes[key]=source_digest;_dag_hits.append(key)
				return decoded
			_failures.append({"path":dag_path,"reason":"invalid exact DAG graph"})
		else:_failures.append({"path":dag_path,"reason":"exact DAG source or cache hash mismatch"})
	var cache_path=key.trim_suffix(".json")+".runtime.bin"
	var source_hash_path=key.trim_suffix(".json")+".runtime.sha256"
	if FileAccess.file_exists(cache_path) and FileAccess.file_exists(source_hash_path) and FileAccess.file_exists(cache_path+".sha256"):
		var source_digest=_stream_sha256(key)
		var expected_source=_read_digest(source_hash_path)
		var expected_cache=_read_digest(cache_path+".sha256")
		if not source_digest.is_empty() and not expected_cache.is_empty() and source_digest==expected_source and _stream_sha256(cache_path)==expected_cache:
			var variant=_read_variant(cache_path)
			var decoded=variant.get("value")
			if variant.ok and decoded is Dictionary:
				_freeze(decoded);_manifests[key]=decoded;_content_hashes[key]=source_digest;_cache_hits.append(key)
				return decoded
			_failures.append({"path":cache_path,"reason":"invalid precompiled source variant"})
	var read=_read_file(key,true)
	if not read.ok:return {}
	var bytes:PackedByteArray=read.bytes
	var parser:=JSON.new()
	_parse_counts[key]=int(_parse_counts.get(key,0))+1
	var error:=parser.parse(bytes.get_string_from_utf8())
	if error!=OK or not parser.data is Dictionary:
		_failures.append({"path":key,"reason":"invalid source manifest","error":error});return {}
	var parsed:Dictionary=parser.data
	_freeze(parsed)
	_content_hashes[key]=read.digest
	_manifests[key]=parsed
	return parsed

static func get_audit() -> Dictionary:
	return {"cached_paths":_manifests.keys(),"parse_counts":_parse_counts.duplicate(),"source_sha256":_content_hashes.duplicate(),"failures":_failures.duplicate(true),"precompiled_cache_hits":_cache_hits.duplicate(),"exact_dag_cache_hits":_dag_hits.duplicate(),"scope":"Recursively read-only source dictionaries only; all mutable runtime objects and geometry JSON remain owner-local"}

## FileAccess can be non-null but closed after a sparse-pack backing open fails.
## Never call length/position/get_var on such a handle. No partial digest is valid.
static func _io_failure(path:String,reason:String,details:Dictionary={}) -> Dictionary:
	var failure={"path":path,"reason":reason}
	failure.merge(details)
	_failures.append(failure)
	push_error("Source data I/O failed: "+JSON.stringify(failure))
	return {"ok":false,"digest":"","bytes":PackedByteArray()}

static func _checked_open(path:String):
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:
		_io_failure(path,"open returned null",{"error":FileAccess.get_open_error()});return null
	if not file.is_open():
		_io_failure(path,"open returned closed handle");return null
	return file

static func _timed_body__read_file(path:String,collect:bool=false) -> Dictionary:
	var file=_checked_open(path)
	if file==null:return {"ok":false,"digest":"","bytes":PackedByteArray()}
	var result=_consume_stream(file,path,collect)
	if file.is_open():file.close()
	return result

## File-like parameter permits deterministic failing/short-read QA, without
## weakening the real FileAccess path. Length is captured once, not a moving bound.
static func _consume_stream(file,path:String,collect:bool=false) -> Dictionary:
	if file==null or not file.is_open():return _io_failure(path,"stream is not open")
	var length:int=file.get_length()
	if not file.is_open():return _io_failure(path,"stream closed while reading length")
	var initial_error:int=file.get_error()
	if length<0 or initial_error!=OK:return _io_failure(path,"invalid stream length",{"length":length,"error":initial_error})
	var position:int=file.get_position()
	if position!=0:return _io_failure(path,"invalid initial stream position",{"position":position,"length":length})
	var hash=HashingContext.new()
	var hash_error:int=hash.start(HashingContext.HASH_SHA256)
	if hash_error!=OK:return _io_failure(path,"hash start failed",{"error":hash_error})
	var bytes:=PackedByteArray()
	while position<length:
		if not file.is_open():return _io_failure(path,"stream closed during read",{"position":position,"length":length})
		var requested:int=mini(1048576,length-position)
		var chunk:PackedByteArray=file.get_buffer(requested)
		var error:int=file.get_error()
		if not file.is_open():return _io_failure(path,"stream closed after read",{"position":position,"requested":requested,"read":chunk.size(),"error":error})
		var after:int=file.get_position()
		if chunk.is_empty() or after<=position or after-position!=chunk.size() or chunk.size()>requested or after>length:
			return _io_failure(path,"read did not make valid progress",{"position":position,"after":after,"length":length,"requested":requested,"read":chunk.size(),"error":error})
		if error!=OK:return _io_failure(path,"read failed",{"position":position,"after":after,"length":length,"requested":requested,"read":chunk.size(),"error":error})
		hash_error=hash.update(chunk)
		if hash_error!=OK:return _io_failure(path,"hash update failed",{"position":position,"error":hash_error})
		if collect:bytes.append_array(chunk)
		position=after
	var finished:PackedByteArray=hash.finish()
	if finished.size()!=32:return _io_failure(path,"hash finish failed",{"digest_bytes":finished.size()})
	return {"ok":true,"digest":finished.hex_encode(),"bytes":bytes}

static func _stream_sha256(path:String)->String:
	return _read_file(path).digest

static func _read_digest(path:String)->String:
	var result=_read_file(path,true)
	if not result.ok:return ""
	var value:String=result.bytes.get_string_from_utf8().strip_edges()
	if value.length()!=64:
		_io_failure(path,"invalid SHA256 sidecar length");return ""
	for character in value:
		if not character in "0123456789abcdef":
			_io_failure(path,"invalid SHA256 sidecar characters");return ""
	return value

static func _timed_body__read_variant(path:String)->Dictionary:
	var file=_checked_open(path)
	if file==null:return {"ok":false}
	var result=_consume_variant(file,path)
	if file.is_open():file.close()
	return result

static func _consume_variant(file,path:String)->Dictionary:
	if file==null or not file.is_open():
		_io_failure(path,"variant stream is not open");return {"ok":false}
	var length:int=file.get_length()
	if not file.is_open():
		_io_failure(path,"variant stream closed while reading length");return {"ok":false}
	var error:int=file.get_error()
	if length<4 or error!=OK:
		_io_failure(path,"invalid variant stream length",{"length":length,"error":error});return {"ok":false}
	if file.get_position()!=0:
		_io_failure(path,"invalid initial variant position");return {"ok":false}
	var value=file.get_var(false) # Never instantiate encoded Objects.
	if not file.is_open():
		_io_failure(path,"variant stream closed during read");return {"ok":false}
	error=file.get_error()
	var position:int=file.get_position()
	if error!=OK or position!=length:
		_io_failure(path,"variant read failed or incomplete",{"error":error,"position":position,"length":length});return {"ok":false}
	return {"ok":true,"value":value}

## Ordered, typed Variant DAG. Every reference points strictly backward, which
## rules out cycles. Shared containers are immutable before becoming reachable.
static func _timed_body_decode_dag(encoded) -> Dictionary:
	if not encoded is Dictionary or encoded.get("format")!="exact-variant-dag-v1":return {}
	var records=encoded.get("nodes")
	var root_id=encoded.get("root")
	if not records is Array or not root_id is int or root_id<0 or root_id>=records.size():return {}
	var values:Array=[]
	for id in records.size():
		var record=records[id]
		if not record is Array or record.size()!=2 or not record[0] is int:return {}
		var tag:int=record[0]
		var payload=record[1]
		if tag==0:
			if typeof(payload) not in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING]:return {}
			values.append(payload)
		elif tag==1 or tag==2:
			if not payload is PackedInt32Array:return {}
			for ref in payload:
				if ref<0 or ref>=id:return {}
			if tag==1:
				var array:Array=[]
				for ref in payload:array.append(values[ref])
				array.make_read_only();values.append(array)
			else:
				if payload.size()%2!=0:return {}
				var dict:Dictionary={}
				for offset in range(0,payload.size(),2):
					var key=values[payload[offset]]
					if not key is String or dict.has(key):return {}
					dict[key]=values[payload[offset+1]]
				dict.make_read_only();values.append(dict)
		else:return {}
	var result=values[root_id]
	if not result is Dictionary:return {}
	return result

## Opt-in instrumentation only: same I/O, hashes, decoding and cache policy.
static func _timer():
	if _startup_timing==null:
		_startup_timing=preload("res://scripts/native_startup_timing.gd").new()
		_startup_timing.configure()
	return _startup_timing

static func load_source_dictionary(path:String)->Dictionary:
	var timer=_timer()
	if timer.enabled:timer.mark("manifest_request",{"key":_key(path),"already_cached":_manifests.has(_key(path))})
	timer.begin("manifest_load",path)
	var result=_timed_body_load_source_dictionary(path)
	timer.end("manifest_load",path)
	return result

static func _read_file(path:String,collect:bool=false)->Dictionary:
	var timer=_timer()
	var stage="manifest_collect_and_hash" if collect else "manifest_stream_hash"
	timer.begin(stage,path)
	var result=_timed_body__read_file(path,collect)
	timer.end(stage,path)
	return result

static func _read_variant(path:String)->Dictionary:
	var timer=_timer()
	timer.begin("manifest_variant_read",path)
	var result=_timed_body__read_variant(path)
	timer.end("manifest_variant_read",path)
	return result

static func decode_dag(encoded)->Dictionary:
	var timer=_timer()
	timer.begin("manifest_dag_decode")
	var result=_timed_body_decode_dag(encoded)
	timer.end("manifest_dag_decode")
	return result
