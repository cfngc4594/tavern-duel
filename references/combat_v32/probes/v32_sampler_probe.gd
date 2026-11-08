extends SceneTree
func _initialize():call_deferred('run')
func run():
 var a=preload('res://scripts/native_combat_assets.gd').new();a.setup();var checks=0;var failures=[];var records=[]
 var texture=a.load_texture('cab-3563ba8b89db13ca6eb196aa111591f1:5681093337556782924')
 var original=FileAccess.get_file_as_bytes('res://assets/original_combat_v32/mips/Default-Particle__5681093337556782924.rgba8-mips')
 checks+=2
 if texture.get_image().get_mipmap_count()!=6:failures.append('original seven levels')
 if texture.get_image().get_data()!=original:failures.append('mip bytes changed')
 for key in a.objects:
  if a.objects[key].type!='Material':continue
  var m=a.material(key);var names=[]
  if not m is ShaderMaterial:continue
  for spec in m.shader.get_shader_uniform_list():names.append(str(spec.name))
  var bindings=m.get_meta('source_sampler_bindings',{})
  for property in bindings:
   var d=bindings[property]
   if not names.has(property):continue
   var regex=RegEx.new();regex.compile('uniform\\s+sampler2D\\s+'+str(property)+'\\s*:[^;]*;')
   var declaration=regex.search(m.shader.code)
   checks+=1
   if declaration==null:failures.append(key+' missing sampler')
   elif int(d.wrap_u)==1 and not declaration.get_string().contains('repeat_disable'):failures.append(key+' clamp')
   if int(d.mip_count)>1:
    checks+=2
    if not declaration.get_string().contains('filter_linear_mipmap'):failures.append(key+' mip filtering')
    if not m.shader.code.contains('dFdx(source_uv)'):failures.append(key+' bilinear mip selection')
   records.append({'material':key,'property':property,'binding':d,'declaration':declaration.get_string() if declaration else ''})
 print('V32_SAMPLERS ',JSON.stringify({'checks':checks,'bindings':records.size(),'failures':failures}))
 FileAccess.open('/tmp/v32_sampler_probe.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failures':failures,'bindings':records},'  '))
 quit(0 if failures.is_empty() else 1)
