extends SceneTree
## CPU resource/material parity, not rendered-pixel or GPU performance validation.
const Cache=preload("res://scripts/immutable_shader_cache.gd")
const CombatAssets=preload("res://scripts/native_combat_assets.gd")
const DeathAssets=preload("res://scripts/native_death_assets.gd")
const Captures=preload("res://scripts/native_combat_capture_materials.gd")
var failed:=false
var material_pairs:=0
var capture_pairs:=0
var isolated_uniforms:=0

func _initialize():call_deferred("run")
func require(ok:bool,label:String):
 if not ok:failed=true;push_error("SHADER_PATH_MATERIAL_FAIL "+label)

func uniform_names(shader:Shader)->Array[String]:
 # Avoid ShaderMaterial property-list reflection: it can rewrite legacy Color
 # overrides for unhinted vec4 uniforms. Equal code also proves equal defaults.
 var names:Array[String]=[]
 var expression:=RegEx.new()
 expression.compile("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)")
 for found in expression.search_all(shader.code):names.append(found.get_string(1))
 return names

func snapshot(material:ShaderMaterial)->Dictionary:
 var uniforms:Dictionary={}
 for name in uniform_names(material.shader):uniforms[name]=material.get_shader_parameter(name)
 var meta:Dictionary={}
 for name in material.get_meta_list():meta[name]=material.get_meta(name)
 return {"code":material.shader.code,"path":material.shader.resource_path,"uniforms":uniforms,"meta":meta,"priority":material.render_priority}

func compare(a:ShaderMaterial,b:ShaderMaterial,label:String):
 require(a!=b,label+" independent Material instances")
 require(snapshot(a)==snapshot(b),label+" shader code/path, overrides, defaults and metadata")
 # Sharing immutable Shader is intended; uniforms must remain material-local.
 for name in uniform_names(a.shader):
  var value=a.get_shader_parameter(name)
  var changed
  if value is float:changed=value+0.123
  elif value is int:changed=value+1
  elif value is Color:changed=Color(0.123,0.234,0.345,0.456)
  elif value is Vector4:changed=value+Vector4(0.1,0.2,0.3,0.4)
  elif value is Vector3:changed=value+Vector3(0.1,0.2,0.3)
  else:continue
  var before=b.get_shader_parameter(name)
  a.set_shader_parameter(name,changed)
  require(b.get_shader_parameter(name)==before,label+" uniform mutation isolated: "+name)
  a.set_shader_parameter(name,value)
  isolated_uniforms+=1
  break
 var before_a:=snapshot(a);var before_b:=snapshot(b)
 Cache.clear()
 require(snapshot(a)==before_a and snapshot(b)==before_b,label+" cache clear preserves live material state")

func exercise(assets,key:String,label:String,with_capture:bool):
 Cache.enabled=false
 var a:Material=assets.material(key)
 Cache.enabled=true
 var b:Material=assets.material(key)
 var c:Material=assets.material(key)
 if not require_shader_pair(a,b,label):return
 var aa:=a as ShaderMaterial
 var bb:=b as ShaderMaterial
 compare(aa,bb,label)
 require(c is ShaderMaterial and c!=a and c!=b,label+" third creation remains independent")
 if c is ShaderMaterial:require(snapshot(bb)==snapshot(c as ShaderMaterial),label+" repeat creation parity")
 material_pairs+=1
 if not with_capture:return
 for kind in ["color","alpha"]:
  Cache.enabled=false
  var old_factory=Captures.new()
  var old:Material=old_factory.color_material(a) if kind=="color" else old_factory.alpha_material(a)
  Cache.enabled=true
  var new_factory=Captures.new()
  var current:Material=new_factory.color_material(b) if kind=="color" else new_factory.alpha_material(b)
  require((old==null)==(current==null),label+" capture support parity "+kind)
  if old is ShaderMaterial and current is ShaderMaterial:
   compare(old as ShaderMaterial,current as ShaderMaterial,label+" capture "+kind)
   capture_pairs+=1

func require_shader_pair(a:Material,b:Material,label:String)->bool:
 var ok:bool=a is ShaderMaterial and b is ShaderMaterial
 require(ok,label+" routed source remains ShaderMaterial")
 return ok

func run():
 var original_enabled:bool=Cache.enabled
 Cache.clear()
 var combat=CombatAssets.new();combat.setup()
 # Common recovered combat shaders with actual capture formula files.
 var wanted:Array[String]=["-666151408197827071","1610204260223125505","4454903573088140019","-230275896195282385","240134070624251049"]
 var covered:Dictionary={}
 for key in combat.objects:
  var record:Dictionary=combat.objects[key]
  if str(record.get("type",""))!="Material":continue
  var shader_id:String=str(record.get("refs",{}).get(".m_Shader","")).get_slice(":",1)
  if not shader_id in wanted or covered.has(shader_id):continue
  exercise(combat,str(key),"combat "+str(key),true)
  covered[shader_id]=true
 require(covered.size()>=3,"at least three distinct real combat shader families")
 var death=DeathAssets.new();death.setup()
 var death_covered:Dictionary={}
 for key in death.objects:
  var record:Dictionary=death.objects[key]
  if str(record.get("type",""))!="Material":continue
  var shader_key:String=str(record.get("refs",{}).get(".m_Shader",""))
  if death_covered.has(shader_key) or not death.death_materials.routes.has(shader_key):continue
  exercise(death,str(key),"death "+str(key),false)
  death_covered[shader_key]=true
  if death_covered.size()>=4:break
 require(death_covered.size()>=2,"at least two real death shader families")
 require(capture_pairs>=2,"real color and alpha capture paths exercised")
 require(isolated_uniforms>0,"material-local uniform mutation exercised")
 Cache.clear();Cache.enabled=original_enabled
 if not failed:print("SHADER_PATH_MATERIAL_PASS pairs=",material_pairs," captures=",capture_pairs," isolated_uniforms=",isolated_uniforms)
 quit(1 if failed else 0)
