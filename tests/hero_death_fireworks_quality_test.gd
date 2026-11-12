extends SceneTree

const ARM_SETTING := "render_quality/android_fx_benchmark_arm"
const SKIP_SETTING := "render_quality/android_skip_hero_death_fireworks"
const SMOKE := "cab-69c88b234dfa427e02d1fcee9337ae34:-2684664198738008316"

var game: Node

func _initialize():
	call_deferred("run")

func run():
	game = load("res://main.tscn").instantiate()
	game.startup_mode = "practice"
	root.add_child(game)
	game.set_process(false)
	game.sound_enabled = false
	await process_frame
	game.flow.finish_opening()

	var effects: Node = game.native_endgame.effects
	ProjectSettings.set_setting(SKIP_SETTING, true)
	for arm in ["reference", "candidate", "spell", "endgame", "no_bloom"]:
		ProjectSettings.set_setting(ARM_SETTING, arm)
		assert(not effects._skip_victory_fireworks())
	ProjectSettings.set_setting(ARM_SETTING, "")
	assert(effects._skip_victory_fireworks() == OS.has_feature("android"))
	ProjectSettings.set_setting(SKIP_SETTING, false)
	assert(not effects._skip_victory_fireworks())

	game.headless = false
	game._setup_spatial_presentation()
	game.spatial_scene.sync_from_game()
	var full: Dictionary = await _play("candidate", [24, -2])
	var lite: Dictionary = await _play("candidate_hero_lite", [24, -2])
	assert(full.events == lite.events)
	assert(full.outcome == "win" and full.result_frame == lite.result_frame)
	assert(full.smoke_seed == lite.smoke_seed and lite.smoke_seed >= 0)
	assert(lite.omitted == full.fireworks and lite.omitted.size() == 3)
	assert(lite.fireworks.is_empty() and full.omitted.is_empty())

	game.headless = true
	for health in [[-2, 24], [0, 0]]:
		full = await _play("candidate", health)
		lite = await _play("candidate_hero_lite", health)
		assert(full == lite and lite.omitted.is_empty())
	game.free()
	print("HERO_DEATH_FIREWORKS_QUALITY_PASS victory omits only three fireworks, preserves smoke seed and result timing; defeat and tie retain their traces")
	quit()

func _play(arm: String, health: Array) -> Dictionary:
	ProjectSettings.set_setting(ARM_SETTING, arm)
	var terminal: Node = game.native_endgame
	terminal.clear()
	await process_frame
	terminal.effects.serial = 0
	terminal.effects.visual_rng.seed = 320947
	game.game_over = false
	game.health = health.duplicate()
	game._check_victory()
	for frame in range(240):
		terminal.advance(0.05)
		if terminal.state == "result":break
	assert(terminal.state == "result")
	var trace := {"outcome":terminal.result.outcome,"result_frame":terminal.frame_id,"events":[],"omitted":[],"fireworks":[],"smoke_seed":-1}
	for effect in terminal.effects.effects:
		if effect.particles.has(SMOKE):trace.smoke_seed = effect.particles[SMOKE].node.instance_seed
		for event in effect.events:
			if event.event == "decorative_firework_omitted":
				trace.omitted.append(event.source_key)
			elif event.event == "particle_play" and terminal.effects.VICTORY_FIREWORKS.has(event.source_key):
				trace.fireworks.append(event.source_key)
			else:
				trace.events.append(event)
	return trace
