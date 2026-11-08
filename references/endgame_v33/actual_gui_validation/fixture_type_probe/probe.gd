extends SceneTree
func _initialize():
 var runtime=[{"side":1,"spell_type":37}]
 var parsed=JSON.parse_string('[{"side":1,"spell_type":37}]')
 var report={"runtime_types":[typeof(runtime[0].side),typeof(runtime[0].spell_type)],"json_types":[typeof(parsed[0].side),typeof(parsed[0].spell_type)],"array_equality":runtime==parsed,"dictionary_equality":runtime[0]==parsed[0],"scalar_equality":runtime[0].side==parsed[0].side,"scalar_normalized_equality":int(runtime[0].side)==int(parsed[0].side)}
 print(JSON.stringify(report));FileAccess.open('res://result.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '));quit()
