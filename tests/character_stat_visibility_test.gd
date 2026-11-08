extends SceneTree

const Renderer=preload("res://scripts/native_card_renderer.gd")
var failures:Array[String]=[]

func check(value:bool,message:String):
	if not value:failures.append(message)

func _initialize():
	var renderer=Renderer.new()
	renderer.profiles={"hero_in_play":{"labels":[]},"minion_in_play":{"labels":[]}}
	var attack=Node3D.new()
	var health=MeshInstance3D.new()
	health.mesh=QuadMesh.new()
	var material=ShaderMaterial.new()
	var shader=Shader.new();shader.code="shader_type spatial; uniform vec4 text_tint;"
	material.shader=shader;health.mesh.surface_set_material(0,material)
	var state={"source_profile":"hero_in_play","paths":{"RootObject/DecorationRoot/AttackObject":attack},"stats":{},"stat_nodes":{"health":health}}
	renderer.update_world_character_stats(state,{"atk":0,"hp":30})
	check(not attack.visible,"zero hero attack gem must be hidden")
	check(material.get_shader_parameter("text_tint")==Color.WHITE,"full health white")
	renderer.update_world_character_stats(state,{"atk":2,"hp":29})
	check(attack.visible,"nonzero hero attack gem must be restored")
	check(material.get_shader_parameter("text_tint")==Color.RED,"damaged hero red on desktop")
	renderer.update_world_character_stats(state,{"atk":0,"hp":30})
	check(not attack.visible,"hero gem hidden again after attack expires")
	check(material.get_shader_parameter("text_tint")==Color.WHITE,"healed hero returns white")
	state.source_profile="minion_in_play";attack.visible=true
	renderer.update_world_minion_stats(state,0,3,4,2)
	check(attack.visible,"zero-attack minion gem must not be hidden")
	check(material.get_shader_parameter("text_tint")==Color.RED,"damage takes priority over buff")
	renderer.update_world_minion_stats(state,0,4,4,2)
	check(material.get_shader_parameter("text_tint")==Color.GREEN,"healthy buff green")
	renderer.update_world_minion_stats(state,0,4,5,2)
	check(material.get_shader_parameter("text_tint")==Color.RED,"same displayed hp updates color when max changes")
	renderer.update_world_minion_stats(state,0,2,2,2)
	check(material.get_shader_parameter("text_tint")==Color.WHITE,"normal minion white")
	check(Renderer.health_stat_color(29,30,30,true).is_equal_approx(Color(1,50.0/255.0,50.0/255.0)),"source phone red")
	attack.free();health.free();renderer.free()
	for message in failures:push_error(message)
	print("character_stat_visibility_test failures=",failures.size())
	if failures.is_empty():print("CHARACTER_STAT_VISIBILITY_PASS")
	quit(0 if failures.is_empty() else 1)
