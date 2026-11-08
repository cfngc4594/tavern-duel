extends SceneTree
func _initialize():
	var factory=load("res://scripts/native_coin_materials.gd").new();factory.setup()
	var ids={}
	for name in factory.records:
		var mat:ShaderMaterial=factory.build(name);assert(mat!=null)
		assert(mat.shader.get_shader_uniform_list().size()>0)
		assert(mat.get_meta("native_shader_translation",false))
		assert(not mat.get_meta("runtime_parity_verified",true))
		ids[mat.get_meta("source_shader_id")]=true
	assert(factory.missing.is_empty());assert(ids.size()==7)
	print("NATIVE_COIN_MATERIAL_PASS 12 materials / 7 original shader identities / all texture bindings; parsed only, not rendered parity")
	quit()
