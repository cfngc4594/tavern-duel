extends SceneTree
const Policy=preload("res://scripts/render_resolution_policy.gd")
func _initialize():call_deferred("run")
func run():
	var failed:=0
	var cases=[[Vector2i(1600,900),Vector2i(1600,900)],[Vector2i(1920,1080),Vector2i(1920,1080)],[Vector2i(2400,1080),Vector2i(1920,1080)],[Vector2i(2560,1440),Vector2i(2560,1440)],[Vector2i(1280,720),Vector2i(1280,720)],[Vector2i(2048,1536),Vector2i(2048,1152)]]
	for row in cases:
		var actual=Policy.target_size(row[0]);print("SIZE ",row[0]," -> ",actual)
		if actual!=row[1]:failed+=1
		for point in [Vector2.ZERO,Vector2(800,450),Vector2(1600,900),Vector2(352,171)]:
			var mapped=Policy.logical_to_target(point,actual)
			if not (mapped*Policy.target_to_logical_scale(actual)).is_equal_approx(point):failed+=1
	if Policy.target_size(Vector2i(3840,2160),1.5)!=Vector2i(2400,1350):failed+=1
	for path in ["res://scripts/game.gd","res://scripts/original_board_bridge.gd","res://scripts/native_endgame_background.gd","res://scripts/native_combat_screen_effects.gd"]:
		var script=load(path)
		if script==null or not script.can_instantiate():failed+=1
		print("LOAD ",path," ",script!=null and script.can_instantiate())
	print("RESOLUTION_TEST_FAILURES=",failed);quit(failed)
