extends SceneTree
const Cache=preload("res://scripts/immutable_shader_cache.gd")
const CODE="shader_type spatial; uniform sampler2D tex; void fragment(){ ALBEDO=vec3(1.0); }"
var failed:=false
func _initialize():call_deferred("run")
func require(ok:bool,label:String):
 if not ok:failed=true;push_error(label)
func run():
 var old_enabled:bool=Cache.enabled
 Cache.clear();Cache.enabled=false
 var a:Shader=Cache.get_or_create(CODE)
 var b:Shader=Cache.get_or_create(CODE)
 require(a!=b and a.code==CODE and b.code==CODE,"disabled creates independent exact code shaders")
 require(Cache.audit().retained==0,"disabled retains no shader")
 Cache.clear();Cache.enabled=true
 a=Cache.get_or_create(CODE);b=Cache.get_or_create(CODE)
 require(a==b and a.code==CODE,"enabled exact code identity")
 var other:Shader=Cache.get_or_create(CODE+"\n// distinct")
 require(other!=a and other.code==CODE+"\n// distinct","different source never aliases")
 require(Cache.audit().hits==1 and Cache.audit().misses==2,"hit miss accounting")
 require(Cache.audit().source_bytes==CODE.to_utf8_buffer().size()+(CODE+"\n// distinct").to_utf8_buffer().size(),"UTF8 retained source byte accounting")
 # Material owns shader and texture, but retaining the shader must not own either.
 var material:ShaderMaterial=ShaderMaterial.new();material.shader=a
 var texture:ImageTexture=ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
 material.set_shader_parameter("tex",texture)
 var material_ref:WeakRef=weakref(material);var texture_ref:WeakRef=weakref(texture)
 material=null;texture=null
 require(material_ref.get_ref()==null and texture_ref.get_ref()==null,"no retained material or uniform texture")
 require(Cache.get_or_create(CODE)==a,"shader remains retained after material release")
 Cache.clear()
 var first:Shader=Cache.get_or_create(CODE+"\n// 0")
 var second:Shader=Cache.get_or_create(CODE+"\n// 1")
 for i in range(2,Cache.CAPACITY):Cache.get_or_create(CODE+"\n// "+str(i))
 require(Cache.audit().retained==Cache.CAPACITY,"bounded fill")
 require(Cache.get_or_create(CODE+"\n// 0")==first,"touch promotes oldest")
 Cache.get_or_create(CODE+"\n// overflow")
 require(Cache.get_or_create(CODE+"\n// 0")==first,"recent entry survives eviction")
 require(Cache.get_or_create(CODE+"\n// 1")!=second,"least recently used entry evicted")
 require(Cache.audit().retained==Cache.CAPACITY,"capacity maintained after replacement")
 var retained:Shader=Cache.get_or_create(CODE+"\n// lifetime")
 var retained_ref:WeakRef=weakref(retained);retained=null
 require(retained_ref.get_ref()!=null,"strong shader retention")
 Cache.clear()
 require(retained_ref.get_ref()==null,"clear releases sole cache-owned shader")
 require(Cache.audit().retained==0 and Cache.audit().source_bytes==0,"clear resets retained accounting")
 require(Cache.audit().creation_usec>=0,"creation timing available")
 exercise_paths()
 Cache.enabled=old_enabled
 print("IMMUTABLE_SHADER_CACHE ","FAIL" if failed else "PASS"," exact code, identity, LRU capacity, ownership, accounting")
 quit(1 if failed else 0)

func exercise_paths():
 Cache.clear();Cache.enabled=false
 var path:String="res://shaders/native_summon_scroll.gdshader"
 var original:Shader=load(path)
 var uncached:Shader=Cache.load_shader(path)
 require(uncached==original and uncached.resource_path==path,"disabled path preserves ResourceLoader identity and path")
 require(Cache.audit().path_retained==0,"disabled path retains nothing")
 Cache.clear();Cache.enabled=true
 var cached:Shader=Cache.load_shader(path)
 require(cached==original and cached.resource_path==path,"enabled path preserves original object/path")
 require(Cache.load_shader(path)==cached and Cache.audit().path_hits==1,"exact path hit")
 require(Cache.audit().path_source_bytes==cached.code.to_utf8_buffer().size(),"path code byte accounting")
 var files:PackedStringArray=DirAccess.get_files_at("res://shaders")
 files.sort()
 var paths:Array[String]=[]
 for file in files:
  if file.ends_with(".gdshader"):paths.append("res://shaders/"+file)
 require(paths.size()>Cache.CAPACITY,"enough existing source shaders for capacity test")
 if paths.size()<=Cache.CAPACITY:return
 Cache.clear()
 for i in Cache.CAPACITY:Cache.load_shader(paths[i])
 Cache.load_shader(paths[0])
 Cache.load_shader(paths[Cache.CAPACITY])
 require(Cache.audit().path_retained==Cache.CAPACITY,"path cache bounded independently")
 require(Cache._path_shaders.has(paths[0]) and not Cache._path_shaders.has(paths[1]),"path LRU evicts untouched oldest")
 for key in Cache._path_shaders:
  require(Cache._path_shaders[key] is Shader and Cache._path_shaders[key].resource_path==key,"path values contain only original Shaders")
 Cache.clear()
 require(Cache.audit().path_retained==0 and Cache.audit().path_source_bytes==0,"clear drops path retention")