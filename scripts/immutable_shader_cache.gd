extends RefCounted
## Main-thread-only immutable Shader cache; never Material/Texture/effect ownership.
## Callers must not mutate returned shader code or set default texture parameters.
static var enabled:bool=true
const CAPACITY:int=64
static var _shaders:Dictionary={}
static var _lru:Array[String]=[]
static var hits:int=0
static var misses:int=0
static var creation_usec:int=0
static var _source_bytes:int=0
static var _path_shaders:Dictionary={}
static var _path_lru:Array[String]=[]
static var path_hits:int=0
static var path_misses:int=0
static var path_load_usec:int=0
static var _path_source_bytes:int=0

static func get_or_create(code:String)->Shader:
 if enabled and _shaders.has(code):
  hits+=1
  _lru.erase(code);_lru.append(code)
  return _shaders[code]
 misses+=1
 var started:=Time.get_ticks_usec()
 var shader:=Shader.new()
 shader.code=code
 creation_usec+=Time.get_ticks_usec()-started
 if not enabled:return shader
 while _lru.size()>=CAPACITY:
  var oldest:String=_lru.pop_front()
  _source_bytes-=oldest.to_utf8_buffer().size()
  _shaders.erase(oldest)
 _shaders[code]=shader;_lru.append(code)
 _source_bytes+=code.to_utf8_buffer().size()
 return shader

# Preserve the ResourceLoader object and resource_path, not a code reconstruction.
static func load_shader(path:String)->Shader:
 if enabled and _path_shaders.has(path):
  path_hits+=1
  _path_lru.erase(path);_path_lru.append(path)
  return _path_shaders[path]
 path_misses+=1
 var started:=Time.get_ticks_usec()
 var shader:Shader=load(path) as Shader
 path_load_usec+=Time.get_ticks_usec()-started
 if not enabled or shader==null:return shader
 while _path_lru.size()>=CAPACITY:
  var oldest:String=_path_lru.pop_front()
  _path_source_bytes-=_path_shaders[oldest].code.to_utf8_buffer().size()
  _path_shaders.erase(oldest)
 _path_shaders[path]=shader;_path_lru.append(path)
 _path_source_bytes+=shader.code.to_utf8_buffer().size()
 return shader

static func clear(reset_stats:bool=true)->void:
 _shaders.clear();_lru.clear();_source_bytes=0
 _path_shaders.clear();_path_lru.clear();_path_source_bytes=0
 if reset_stats:hits=0;misses=0;creation_usec=0;path_hits=0;path_misses=0;path_load_usec=0

static func audit()->Dictionary:
 return {"enabled":enabled,"capacity":CAPACITY,"hits":hits,"misses":misses,"creation_usec":creation_usec,"retained":_shaders.size(),"source_bytes":_source_bytes,"path_hits":path_hits,"path_misses":path_misses,"path_load_usec":path_load_usec,"path_retained":_path_shaders.size(),"path_source_bytes":_path_source_bytes}
