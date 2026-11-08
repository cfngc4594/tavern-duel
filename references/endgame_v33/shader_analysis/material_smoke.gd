extends SceneTree
func _initialize():call_deferred("run")
func run():
 var assets=load("res://scripts/native_endgame_assets.gd").new();assets.setup()
 var builder=load("res://scripts/native_endgame_materials.gd").new()
 var n=0
 for k in assets.objects:
  var r=assets.objects[k]
  if r.type!="Material" or not builder.routes.has(str(r.get("refs",{}).get(".m_Shader",""))):continue
  var m=assets.material(k)
  assert(m!=null and m is ShaderMaterial)
  assert(m.get_meta("source_key")==k)
  print(r.name," ",m.shader.resource_path," uniforms=",m.shader.get_shader_uniform_list().size());n+=1
 print("ENDGAME_MATERIAL_SMOKE ",n)
 assets=null;builder=null
 quit()
