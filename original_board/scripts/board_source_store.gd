@tool
extends RefCounted
## Only immutable CPU data is shared. Each read returns caller-owned data/Image.
## Export regenerates the sealed bundle from content-hashed dependencies. Local
## opt-in callers must compile/validate current sources before choosing a path.
## Source edits require recompilation + clear_cache(); no per-match filesystem
## polling or source hashing is hidden in this loading optimization.
const BUNDLE_PATH='res://original_board/generated/desktop_source.bin'
const SCHEMA=1
const MAX_BUNDLE_BYTES=134217728
static var enabled=false
static var bundle_path=BUNDLE_PATH
static var _cache={}
static var _attempted_path=''
static var _stats={'loads':0,'json_hits':0,'image_hits':0,'raw_json_reads':0,'raw_image_reads':0,'misses':0,'serialized_payload_bytes':0,'image_bytes':0,'json_entries':0,'image_entries':0,'generation':'','error':''}
var _snapshot={}
static func _digest(bytes:PackedByteArray)->String:
 var ctx=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(bytes)
 return ctx.finish().hex_encode()
static func clear_cache(reset_statistics:bool=true):
 # Old probes keep their snapshot; future probes acquire the new generation.
 _cache={};_attempted_path=''
 if reset_statistics:
  for key in _stats:_stats[key]='' if key in ['generation','error'] else 0
static func get_audit()->Dictionary:
 var result=_stats.duplicate();result.enabled=enabled;result.bundle_path=bundle_path
 return result
static func _load_bundle():
 if _attempted_path==bundle_path:return
 _cache={};_attempted_path=bundle_path
 for key in ['serialized_payload_bytes','image_bytes','json_entries','image_entries']:_stats[key]=0
 _stats.generation='';_stats.error=''
 var file=FileAccess.open(bundle_path,FileAccess.READ)
 if file==null:
  _stats.error='Board bundle unavailable; raw source fallback';return
 var size=file.get_length()
 if size<=0 or size>MAX_BUNDLE_BYTES:
  _stats.error='Board bundle size invalid; raw source fallback';return
 var bytes=file.get_buffer(size);file.close()
 var result=_decode(bytes)
 if not result.ok:
  _stats.error=result.error+'; raw source fallback';return
 var decoded=result.data;var manifest=decoded.manifest
 _cache=decoded;_stats.loads+=1;_stats.serialized_payload_bytes=result.payload_bytes
 for key in ['image_bytes','json_entries','image_entries','generation']:_stats[key]=manifest.get(key,_stats[key])
static func _decode(bytes:PackedByteArray)->Dictionary:
 if bytes.is_empty() or bytes.size()>MAX_BUNDLE_BYTES:return {'ok':false,'error':'Board bundle size invalid'}
 var envelope=bytes_to_var(bytes)
 if not envelope is Dictionary or envelope.get('magic','')!='TAVERN_BOARD_SOURCE' or envelope.get('schema',-1)!=SCHEMA or not envelope.get('payload') is PackedByteArray:
  return {'ok':false,'error':'Board bundle header invalid'}
 var payload:PackedByteArray=envelope.payload
 if _digest(payload)!=envelope.get('sha256',''):
  return {'ok':false,'error':'Board bundle digest mismatch'}
 var decoded=bytes_to_var(payload)
 if not decoded is Dictionary or not decoded.get('manifest') is Dictionary or not decoded.get('json') is Dictionary or not decoded.get('images') is Dictionary:
  return {'ok':false,'error':'Board bundle structure invalid'}
 var manifest:Dictionary=decoded.manifest
 if manifest.get('schema',-1)!=SCHEMA or int(manifest.get('json_entries',-1))!=decoded.json.size() or int(manifest.get('image_entries',-1))!=decoded.images.size() or str(manifest.get('generation','')).length()!=64 or not manifest.get('dependencies') is Dictionary:
  return {'ok':false,'error':'Board bundle manifest invalid'}
 for path in decoded.json:
  if not path is String or not decoded.json[path] is Dictionary or not manifest.dependencies.has(path):return {'ok':false,'error':'Board bundle JSON entry invalid'}
 var image_bytes=0
 for path in decoded.images:
  var row=decoded.images[path]
  if not path is String or not row is Dictionary or not manifest.dependencies.has(path):return {'ok':false,'error':'Board bundle image entry invalid'}
  if int(row.get('width',0))<=0 or int(row.get('height',0))<=0 or not row.get('pixels') is PackedByteArray or int(row.get('format',-1))<0 or int(row.get('format',-1))>=Image.FORMAT_MAX or not row.get('mipmaps') is bool:return {'ok':false,'error':'Board bundle image metadata invalid'}
  # PNG decoder outputs uncompressed 8-bit channels without mipmaps. This
  # arithmetic checks each payload without allocating another full-size Image.
  var channels={Image.FORMAT_L8:1,Image.FORMAT_LA8:2,Image.FORMAT_RGB8:3,Image.FORMAT_RGBA8:4}
  if not row.width is int or not row.height is int or row.width>32768 or row.height>32768 or row.mipmaps or not channels.has(row.format):return {'ok':false,'error':'Board bundle PNG layout invalid'}
  if row.pixels.size()!=row.width*row.height*int(channels[row.format]):return {'ok':false,'error':'Board bundle PNG byte count invalid'}
  image_bytes+=row.pixels.size()
 if image_bytes!=int(manifest.get('image_bytes',-1)):return {'ok':false,'error':'Board bundle image size invalid'}
 return {'ok':true,'error':'','data':decoded,'payload_bytes':payload.size()}
static func validate_bytes(bytes:PackedByteArray)->Dictionary:
 # Packaging verification. Does not populate the gameplay cache or diagnostics.
 var result=_decode(bytes)
 return {'ok':result.ok,'error':result.error,'manifest':result.data.manifest.duplicate(true) if result.ok else {}}
func open_for_probe(desktop:bool):
 _snapshot={}
 # Packaged phone/mobile and actual phone board always retain the reference path.
 if not enabled or not desktop or OS.has_feature('android') or OS.has_feature('ios'):return
 _load_bundle();_snapshot=_cache
func read_json(path:String):
 if _snapshot.get('json',{}).has(path):
  _stats.json_hits+=1
  return _snapshot.json[path].duplicate(true)
 if not _snapshot.is_empty():_stats.misses+=1
 return raw_json(path)
func read_image(path:String)->Image:
 if _snapshot.get('images',{}).has(path):
  var row=_snapshot.images[path]
  _stats.image_hits+=1
  return Image.create_from_data(row.width,row.height,row.mipmaps,row.format,row.pixels)
 if not _snapshot.is_empty():_stats.misses+=1
 return raw_image(path)
static func raw_json(path:String):
 _stats.raw_json_reads+=1
 return JSON.parse_string(FileAccess.get_file_as_string(path))
static func raw_image(path:String)->Image:
 _stats.raw_image_reads+=1
 if not FileAccess.file_exists(path):return null
 var image=Image.new()
 if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
 return image
static func json_for(probe,path:String):
 if probe!=null and probe.has_method('read_source_json'):return probe.read_source_json(path)
 return raw_json(path)
static func image_for(probe,path:String)->Image:
 if probe!=null and probe.has_method('read_source_image'):return probe.read_source_image(path)
 return raw_image(path)
