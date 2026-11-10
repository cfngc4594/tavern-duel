@tool
extends RefCounted
## Build-time only. Exact JSON Variants and original decoded PNG bytes.
## Never call this compiler from a gameplay frame.
const SCHEMA=1
const BASE='res://original_board/assets/'
var _json={}
var _images={}
var _hashes={}
var _error=''
static func digest(bytes:PackedByteArray)->String:
 var ctx=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(bytes)
 return ctx.finish().hex_encode()
func _read(path:String)->PackedByteArray:
 if not FileAccess.file_exists(path):
  _error='Missing board source '+path;return PackedByteArray()
 var bytes=FileAccess.get_file_as_bytes(path)
 _hashes[path]=digest(bytes)
 return bytes
func _add_json(path:String)->Dictionary:
 if _json.has(path):return _json[path]
 var bytes=_read(path)
 var parser=JSON.new()
 if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:
  _error='Invalid board JSON '+path;return {}
 _json[path]=parser.data
 return parser.data
func _add_image(path:String):
 if _images.has(path):return
 var image=Image.new()
 if image.load_png_from_buffer(_read(path))!=OK or image.is_empty():
  _error='Invalid board PNG '+path;return
 if image.has_mipmaps() or image.get_format() not in [Image.FORMAT_L8,Image.FORMAT_LA8,Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:
  _error='Unsupported original PNG format '+path;return
 _images[path]={'width':image.get_width(),'height':image.get_height(),'format':image.get_format(),'mipmaps':image.has_mipmaps(),'pixels':image.get_data()}
func _add_textures(data:Dictionary):
 for row in data.get('textures',{}).values():_add_image(str(row.file))
func _build()->Dictionary:
 var scene=_add_json(BASE+'scene.json')
 if scene.is_empty():return {'ok':false,'bytes':PackedByteArray(),'manifest':{},'error':_error}
 _add_json('res://original_board/references/minimum_scene_config.json')
 for row in scene.meshes.values():_add_json(str(row.file))
 _add_textures(scene)
 var door=_add_json(BASE+'door/door.json')
 for row in door.get('clips',{}).values():_add_json(BASE+'door/'+str(row.raw_file))
 if not door.has('listener_transform'):_add_json('res://original_board/references/board_cameras_source.json')
 _add_json(BASE+'window_lamp/window.json')
 for name in ['gong','lamp']:_add_json(BASE+'arch/'+name+'.json')
 var kite=_add_json(BASE+'kite/kite.json')
 _add_json(str(kite.get('mesh_file','')));_add_textures(kite)
 for name in ['kite_fsm','pole_fsm']:_add_json(BASE+'kite/'+name+'.json')
 var particles=_add_json(BASE+'water_particles/source.json')
 for row in particles.get('materials',{}).values():_add_image(str(row.texture))
 var farm=['pumpkin1','pumpkin2','pumpkin3']
 for i in range(1,11):farm.append('BushFlower%02d'%i)
 farm.append('BushFlower011')
 for name in farm:
  var data=_add_json(BASE+'farm/'+name+'.json')
  # Include source mesh swaps even when no initial state happens to request one.
  for obj in data.get('objects',{}).values():
   if obj.get('type','')=='Mesh' and obj.get('files',{}).has('mesh'):_add_json(BASE+'farm/'+str(obj.files.mesh))
 for name in ['mill_wheel','silo']:_add_json(BASE+'water/'+name+'.json')
 if not _error.is_empty():return {'ok':false,'bytes':PackedByteArray(),'manifest':{},'error':_error}
 var image_bytes=0
 for row in _images.values():image_bytes+=row.pixels.size()
 # Compiler identity participates even when the source asset set is unchanged.
 _read('res://original_board/scripts/board_source_compiler.gd')
 var generation=digest(var_to_bytes(_hashes))
 var manifest={'schema':SCHEMA,'generation':generation,'dependencies':_hashes,'json_entries':_json.size(),'image_entries':_images.size(),'image_bytes':image_bytes}
 var payload=var_to_bytes({'manifest':manifest,'json':_json,'images':_images})
 # SHA256 catches truncation/corruption before bytes_to_var. No object decoding.
 var bytes=var_to_bytes({'magic':'TAVERN_BOARD_SOURCE','schema':SCHEMA,'sha256':digest(payload),'payload':payload})
 return {'ok':true,'bytes':bytes,'manifest':manifest,'error':''}
static func compile()->Dictionary:
 return load('res://original_board/scripts/board_source_compiler.gd').new()._build()
static func validate_sources(manifest:Dictionary)->bool:
 # Build/test boundary only, not a per-match poll or runtime warm-up.
 if int(manifest.get('schema',-1))!=SCHEMA:return false
 for path in manifest.get('dependencies',{}):
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=manifest.dependencies[path]:return false
 return not manifest.get('dependencies',{}).is_empty()
