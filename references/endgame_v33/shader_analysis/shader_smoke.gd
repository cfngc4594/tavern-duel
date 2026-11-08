extends SceneTree
func _initialize():
 var files=DirAccess.get_files_at("res://shaders")
 var n=0
 for f in files:
  if f.ends_with(".gdshader") and f.contains("endgame_"):
   var s=load("res://shaders/"+f)
   var m=ShaderMaterial.new();m.shader=s
   print(f, " uniforms=",s.get_shader_uniform_list().size());n+=1
 var module=load("res://scripts/native_endgame_materials.gd").new()
 print("ENDGAME_SHADER_SMOKE ",n," routes=",module.routes.size())
 quit()
