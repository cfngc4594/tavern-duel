extends SceneTree
func _initialize():
 var shader=load("res://shaders/native_coin_reflection.gdshader")
 assert(shader!=null)
 var uniforms={}
 for uniform in shader.get_shader_uniform_list():uniforms[uniform.name]=true
 for name in ["_MainTex","_SpecTex","_ReflTex","_MainTex_ST","_ReflectionIntensity","_ReflectionRotation","_LightingBlend","_UnityTimeX","_GodotToSourceWorld"]:assert(uniforms.has(name))
 print("COIN_REFLECTION_SHADER_PASS: shader parser and original named parameters; no rendered parity assertion")
 quit()
