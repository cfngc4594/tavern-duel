extends Node
## Opt-in recorder for one seeded normal match using the production scene and clocks.
const SpellInput = preload("res://scripts/native_phone_spell_input.gd")
const CombatParticles = preload("res://scripts/native_combat_particles.gd")
## Android's Godot logger truncates individual messages at roughly 1000 bytes.
const BATCH_SIZE := 10
const DIAGNOSTIC_BATCH_SIZE := 8
const NATIVE_AB_RUN_PATH := "user://native-particle-ab-run.txt"
const SCENARIOS := ["idle", "opening-draw", "heavy-spell", "terminal"]
const MINION_COMBAT_SCENARIO := "minion-combat"
const SCENARIO_SUITE_PATH := "user://android-scenario-suite.txt"
const SCENARIO_TIMEOUT_USEC := 180_000_000
const MAX_RUN_USEC := 900_000_000
const MAX_SPIKES_PER_PHASE := 6
const MAX_EFFECT_SAMPLES_PER_PHASE := 12
const FX_EFFECT_PHASES := ["fireball_cold", "fireball_first", "fireball_repeat", "coin_cold", "coin_repeat", "fireblast_first", "fireblast_repeat"]
const ACTION_PAUSE := 0.45
const RESULT_HOLD_SECONDS := 2.5

var game
var first_side := 1
var seed_value := 5834
var game_usec := 0
var draw_started_usec := 0
var render_draw_usec := 0
var started_usec := 0
var previous_usec := 0
var frame := 0
var phase := "loading"
var action_pause := 0.0
var activity := ""
var result := ""
var rows: Array = []
var stage_sums := {}
var phase_spikes := {}
var profiling := false
var profile_fx_effects := false
var fx_effect_samples := {}
var output_path := ""
var output_lines := PackedStringArray()
var quit_when_done := false
var fx_benchmark: RefCounted
var native_particle_mode := "default"
var native_ab_run := -1
var scenario := ""
var scenario_run := -1
var scenario_error := ""
var scenario_driver: RefCounted
var scenario_particle_profile := false

func setup(host):
	game = host
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--android-match-profile":
			profiling = true
		elif arg == "--android-match-quit":
			quit_when_done = true
		elif arg.begins_with("--android-match-output="):
			output_path = arg.trim_prefix("--android-match-output=")
		elif arg == "--android-native-particles-ab":
			native_ab_run = int(FileAccess.get_file_as_string(NATIVE_AB_RUN_PATH)) if FileAccess.file_exists(NATIVE_AB_RUN_PATH) else 0
			CombatParticles.native_batch_enabled = native_ab_run % 2 == 1
			native_particle_mode = "native" if CombatParticles.native_batch_enabled else "reference"
		elif arg.begins_with("--android-match-seed="):
			var value: String = arg.trim_prefix("--android-match-seed=")
			if value.is_valid_int() and int(value) >= 0:
				seed_value = int(value)
	_configure_scenario(args)
	if scenario.is_empty() and scenario_error.is_empty() and "--android-fx-benchmark" in args:
		fx_benchmark = load("res://scripts/android_fx_benchmark.gd").new()
		fx_benchmark.setup(game, args)
		first_side = 0
		profile_fx_effects = "--android-fx-profile-effects" in args
		profiling = profiling or profile_fx_effects
	game.profile_frame_stages = profiling
	game.scripted_pointer = true
	CombatParticles.native_batch_calls = 0
	CombatParticles.native_batch_particles = 0
	CombatParticles.native_constant_batches = 0
	CombatParticles.native_trail_geometry_batches = 0
	CombatParticles.fast_particle_projection_skips = 0

func _configure_scenario(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--android-scenario="):
			scenario = arg.trim_prefix("--android-scenario=")
			if not SCENARIOS.has(scenario) and scenario != MINION_COMBAT_SCENARIO:
				scenario_error = "invalid_scenario"
				return
	if "--android-scenario-suite" in args:
		if not scenario.is_empty():
			scenario_error = "conflicting_scenario_options"
			return
		scenario_run = 0
		if FileAccess.file_exists(SCENARIO_SUITE_PATH):
			var counter := FileAccess.get_file_as_string(SCENARIO_SUITE_PATH).strip_edges()
			if not counter.is_valid_int() or int(counter) < 0:
				scenario_error = "invalid_scenario_suite_counter"
				return
			scenario_run = int(counter)
		scenario = SCENARIOS[scenario_run % SCENARIOS.size()]
	if scenario.is_empty():
		return
	if "--android-fx-benchmark" in args or native_ab_run >= 0:
		scenario_error = "conflicting_benchmark_modes"
		return
	first_side = 0
	profiling = true
	match scenario:
		"idle":
			scenario_driver = load("res://scripts/android_scenario_idle.gd").new()
		"opening-draw":
			scenario_driver = load("res://scripts/android_scenario_opening.gd").new()
		MINION_COMBAT_SCENARIO:
			scenario_driver = load("res://scripts/android_scenario_minion_combat.gd").new()
		"heavy-spell", "terminal":
			fx_benchmark = load("res://scripts/android_fx_benchmark.gd").new()
			fx_benchmark.setup_scenario(game, scenario)
	if scenario_driver != null:
		scenario_driver.setup(game)
	if scenario == "heavy-spell":
		profile_fx_effects = true
		scenario_particle_profile = "--android-scenario-particle-profile" in args
		if scenario_particle_profile:
			CombatParticles.seek_rows.clear()
			CombatParticles.seek_source_totals.clear()
			CombatParticles.profile_seek = true

func _ready():
	started_usec = Time.get_ticks_usec()
	get_tree().process_frame.connect(_sample_previous_frame)
	if profiling:
		RenderingServer.frame_pre_draw.connect(_begin_render_draw)
		RenderingServer.frame_post_draw.connect(_end_render_draw)
	emit_record("MATCH_BENCH_BEGIN " + JSON.stringify({
		"schema": 1, "ticks_usec": started_usec, "seed": seed_value, "first_side": first_side,
		"benchmark": "scenario" if not scenario.is_empty() else ("fx" if fx_benchmark != null else "match"),
		"scenario": scenario, "scenario_run": scenario_run, "particle_profile": scenario_particle_profile,
		"arm": fx_benchmark.arm if fx_benchmark != null else "",
		"run_index": fx_benchmark.run_index if fx_benchmark != null else 0,
		"profile_stages": profiling, "profile_fx_effects": profile_fx_effects,
		"native_particle_mode": native_particle_mode,
		"native_ab_run": native_ab_run,
		"native_particle_available": ClassDB.class_exists(&"TavernParticleKernel"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"display": DisplayServer.get_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"resolution": str(get_window().size), "refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"columns": ["frame", "frame_usec", "game_usec", "draw_calls", "static_memory", "render_memory", "phase", "render_objects", "render_draw_usec"]
	}))

func emit_record(line: String) -> void:
	print(line)
	if not output_path.is_empty():
		output_lines.append(line)

func _begin_render_draw():
	draw_started_usec = Time.get_ticks_usec()

func _end_render_draw():
	if draw_started_usec > 0:
		render_draw_usec = Time.get_ticks_usec() - draw_started_usec
		draw_started_usec = 0

func _sample_previous_frame():
	var now := Time.get_ticks_usec()
	if previous_usec != 0:
		frame += 1
		var interval := now - previous_usec
		rows.append([
			frame, interval, game_usec,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), phase,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), render_draw_usec
		])
		render_draw_usec = 0
		if profiling:
			_collect_stages(interval)
		if profile_fx_effects:
			_collect_fx_effect_profile(interval)
		if rows.size() >= BATCH_SIZE:
			_flush_rows()
	previous_usec = now
	if not result.is_empty():
		_finish()

func _collect_fx_effect_profile(interval: int) -> void:
	if not is_instance_valid(game.native_combat) or not is_instance_valid(game.native_combat.effect_player):
		return
	var effect_rows: Array = game.native_combat.effect_player.profile_rows
	if effect_rows.is_empty():
		return
	if phase in FX_EFFECT_PHASES:
		if not fx_effect_samples.has(phase):
			fx_effect_samples[phase] = []
		var samples: Array = fx_effect_samples[phase]
		for row in effect_rows:
			# The archer wrapper also records inclusive timings around these calls.
			# Keep the underlying work so it occupies the bounded sample once.
			if row.operation not in ["sample", "spawn", "dispose"]:
				continue
			if samples.size() == MAX_EFFECT_SAMPLES_PER_PHASE and row.usec <= samples.back().usec:
				continue
			row.benchmark_frame = frame
			row.frame_usec = interval
			row.render_draw_usec = rows.back()[8]
			samples.append(row)
			samples.sort_custom(func(a, b): return a.usec > b.usec)
			if samples.size() > MAX_EFFECT_SAMPLES_PER_PHASE:
				samples.pop_back()
	effect_rows.clear()

func _collect_stages(interval: int):
	if not stage_sums.has(phase):
		stage_sums[phase] = {}
		phase_spikes[phase] = []
	var stages: Dictionary = stage_sums[phase]
	var frame_stages: Dictionary = game.last_frame_stages
	if scenario_particle_profile:
		frame_stages = frame_stages.duplicate()
		_add_scenario_particle_stages(frame_stages)
	for label in frame_stages:
		var value: int = frame_stages[label]
		if not stages.has(label):
			stages[label] = [0, 0, 0]
		var totals: Array = stages[label]
		totals[0] += 1
		totals[1] += value
		totals[2] = maxi(totals[2], value)
	if interval < 25_000:
		return
	var spikes: Array = phase_spikes[phase]
	if spikes.size() == MAX_SPIKES_PER_PHASE and interval <= int(spikes.back().frame_usec):
		return
	spikes.append({"frame": frame, "frame_usec": interval, "game_usec": game_usec, "stages": frame_stages.duplicate()})
	spikes.sort_custom(func(a, b): return a.frame_usec > b.frame_usec)
	if spikes.size() > MAX_SPIKES_PER_PHASE:
		spikes.pop_back()

func _add_scenario_particle_stages(stages: Dictionary) -> void:
	var seek_rows := CombatParticles.seek_rows
	if phase in FX_EFFECT_PHASES and not seek_rows.is_empty():
		var state_usec := 0
		var geometry_usec := 0
		var upload_usec := 0
		for row in seek_rows:
			var loop_state_usec := int(row.get("state_usec", 0))
			state_usec += int(row.get("worker_usec", 0)) + loop_state_usec
			geometry_usec += maxi(0, int(row.get("loop_usec", 0)) - loop_state_usec)
			upload_usec += int(row.upload_usec)
		# Nested breakdown of the combat stage, excluding inclusive subemitter time.
		stages["particle_state"] = state_usec
		stages["particle_geometry_loop"] = geometry_usec
		stages["particle_mesh_upload"] = upload_usec
	seek_rows.clear()

func _flush_rows():
	if rows.is_empty():
		return
	var payload := JSON.stringify(rows)
	if payload.to_utf8_buffer().size() > 875:
		for row in rows:
			emit_record("MATCH_BENCH_FRAME " + JSON.stringify([row]))
	else:
		emit_record("MATCH_BENCH_FRAME " + payload)
	rows.clear()

func _process(delta: float):
	if not scenario_error.is_empty():
		result = scenario_error
		return
	var timeout_usec := MAX_RUN_USEC if scenario.is_empty() else SCENARIO_TIMEOUT_USEC
	if Time.get_ticks_usec() - started_usec > timeout_usec:
		result = "timeout"
		return
	if game.native_initial_loading:
		phase = "loading"
		if not game.native_loading_error.is_empty():
			result = "loading_failed"
		return
	if scenario_driver != null:
		scenario_driver.advance(self)
		return
	if fx_benchmark != null:
		fx_benchmark.advance(self)
		return
	if game.game_over:
		phase = "endgame"
		if game.native_endgame.state in ["waiting_source", "waiting_screen"]:
			result = game.native_endgame.state
		elif is_instance_valid(game.native_endgame.screen) and game.native_endgame.screen.age >= RESULT_HOLD_SECONDS:
			result = "completed"
		return
	if game.flow.phase != "playing":
		phase = "opening_" + game.flow.phase
		if game.flow.phase == "mulligan" and game.flow.phase_time >= 0.5:
			_confirm_mulligan()
		return

	action_pause = maxf(0.0, action_pause - delta)
	if not game.player_turn:
		phase = "opponent_" + _opponent_activity()
		activity = ""
		return
	phase = "player_" + (activity if game.busy and not activity.is_empty() else "idle")
	if game.busy or action_pause > 0.0 or not game.flow.accepts_actions():
		return
	if not game.pending_battlecry.is_empty():
		var target := _battlecry_target()
		var start := Time.get_ticks_usec()
		game.pointer = target
		game._resolve_target(target)
		if not game.pending_battlecry.is_empty():
			result = "battlecry_target_rejected"
		_mark_action("battlecry", "CS2_189", start)
		return
	if game.cards.any(func(card): return card.get("drawing", false) or card.get("returning", false)):
		phase = "player_draw"
		return
	if _play_card() or _attack() or _hero_power():
		return
	var start := Time.get_ticks_usec()
	game.end_turn()
	_mark_action("end_turn", "", start)

func _confirm_mulligan():
	var start := Time.get_ticks_usec()
	for i in game.flow.opening_hand.size():
		if game.definitions[game.flow.opening_hand[i]].cost >= 4:
			game.flow.toggle_mulligan(i)
	game.flow.confirm_mulligan()
	_mark_action("mulligan", "", start, false)

func _opponent_activity() -> String:
	if not game.native_summon.instances.is_empty():
		return "summon"
	for instance in game.native_combat.instances:
		return "attack" if instance.kind == "attack" else "spell"
	return "resolve" if game.busy else "idle"

func _play_card() -> bool:
	var play_position: Vector2 = game.PLAY_RECT.get_center()
	if game._phone_hand_enabled():
		play_position = game.source_phone_layout.snapshot.items.friendly_play.center
	var best_index := -1
	var best_priority := -1
	var best_position := play_position
	var best_action := ""
	for i in game.cards.size():
		var key: String = game.cards[i].key
		var definition: Dictionary = game.definitions[key]
		if int(definition.cost) > int(game.mana):
			continue
		var position := play_position
		var action := "minion" if definition.kind == "minion" else "spell"
		var priority := int(definition.cost) * 10
		if definition.kind == "minion":
			if game.allies.size() >= 7 or not game._source_play_contains(position):
				continue
			if key == "CS2_189":
				priority += 24
		else:
			if key == "GAME_005":
				if game.mana >= 10 or not game.cards.any(func(card): return int(game.definitions[card.key].cost) == int(game.mana) + 1):
					continue
				priority = 1000
			elif key == "CS2_027" and game.allies.size() >= 7:
				continue
			elif key in ["CS2_025", "CS2_026", "CS2_032"] and game.enemies.is_empty():
				continue
			if game.rules.needs_target(key):
				var target: Dictionary = game.rules.ai_target(key, 0)
				if target.is_empty():
					continue
				position = target.pos
				var screen_target: Dictionary = game.target_at(position, 1)
				if not game.rules.legal_target(key, screen_target, 0):
					continue
				if screen_target.type == "hero" and int(definition.get("damage", 0)) >= int(game.health[1]):
					priority += 100
			elif game._phone_hand_enabled() and not SpellInput.over_playfield(game.source_projection, position):
				continue
		if priority > best_priority:
			best_index = i
			best_priority = priority
			best_position = position
			best_action = action
	if best_index < 0:
		return false
	var key: String = game.cards[best_index].key
	var start := Time.get_ticks_usec()
	game.pointer = best_position
	if not game.play_card(best_index, best_position, game.allies.size()):
		result = "play_card_rejected"
	_mark_action("battlecry_aim" if not game.pending_battlecry.is_empty() else best_action, key, start)
	return true

func _battlecry_target() -> Vector2:
	for unit in game.enemies:
		if not unit.dead and int(unit.hp) == 1 and not game.target_at(unit.pos, 1).is_empty():
			return unit.pos
	return game.ENEMY_HERO

func _attack() -> bool:
	for unit in game.allies:
		if not game.can_attack(unit):
			continue
		var target := {"type": "hero", "side": 1, "pos": game.ENEMY_HERO}
		for enemy in game.enemies:
			if not enemy.dead and game.definitions[enemy.key].keyword == "嘲讽":
				target = {"type": "unit", "unit": enemy, "pos": enemy.pos}
				break
		if not game.legal_attack(unit, target):
			continue
		var start := Time.get_ticks_usec()
		game.pointer = target.pos
		if not game.attack(unit, target):
			result = "attack_rejected"
		_mark_action("attack", unit.key, start)
		return true
	return false

func _hero_power() -> bool:
	if game.power_used or game.mana < 2:
		return false
	var start := Time.get_ticks_usec()
	game.pointer = game.ENEMY_HERO
	game.targeting_power = true
	game._begin_spell_audio_preview("CS2_034")
	game._resolve_target(game.pointer)
	if not game.power_used:
		result = "hero_power_rejected"
	_mark_action("hero_power", "CS2_034", start)
	return true

func _mark_action(name: String, card: String, started: int, mark_phase: bool = true):
	action_pause = ACTION_PAUSE
	if mark_phase:
		activity = name
		phase = "player_" + activity
	emit_record("MATCH_BENCH_EVENT " + JSON.stringify({
		"frame": frame + 1, "ticks_usec": started, "action": name, "card": card,
		"action_usec": Time.get_ticks_usec() - started, "turn": game.turn
	}))

func _finish():
	get_tree().process_frame.disconnect(_sample_previous_frame)
	if profiling:
		RenderingServer.frame_pre_draw.disconnect(_begin_render_draw)
		RenderingServer.frame_post_draw.disconnect(_end_render_draw)
	set_process(false)
	if scenario_driver != null and scenario_driver.has_method("finish"):
		scenario_driver.finish()
	game.profile_frame_stages = false
	if scenario_particle_profile:
		CombatParticles.profile_seek = false
		CombatParticles.seek_rows.clear()
		CombatParticles.seek_source_totals.clear()
	_flush_rows()
	var diagnostics := PackedStringArray()
	if fx_benchmark != null:
		for audit in fx_benchmark.terminal_audits:
			diagnostics.append("MATCH_BENCH_FX_CASE " + JSON.stringify(audit))
	if not scenario.is_empty():
		var cases: Array = []
		if scenario_driver != null:
			cases = scenario_driver.case_results
		elif fx_benchmark != null:
			cases = fx_benchmark.case_results
		for entry in cases:
			diagnostics.append("MATCH_BENCH_SCENARIO_CASE " + JSON.stringify(entry))
	for label in fx_effect_samples:
		for row in fx_effect_samples[label]:
			diagnostics.append("MATCH_BENCH_FX_EFFECT " + JSON.stringify({"phase": label, "sample": row}))
	for label in stage_sums:
		for chunk in _diagnostic_chunks(stage_sums[label]):
			diagnostics.append("MATCH_BENCH_STAGES " + JSON.stringify({"phase": label, "columns": ["samples", "sum_usec", "max_usec"], "stages": chunk}))
		for spike in phase_spikes[label]:
			for chunk in _diagnostic_chunks(spike.stages):
				var sample: Dictionary = spike.duplicate()
				sample.stages = chunk
				diagnostics.append("MATCH_BENCH_SPIKES " + JSON.stringify({"phase": label, "sample": sample}))
	var events := {}
	for event in game.event_trace:
		var label: String = event.event
		events[label] = int(events.get(label, 0)) + 1
	for chunk in _diagnostic_chunks(events):
		diagnostics.append("MATCH_BENCH_COUNTS " + JSON.stringify({"events": chunk}))
	var probe = game.original_board_bridge.probe
	var baked_meshes := 0
	var ambient_density := 1.0
	if is_instance_valid(probe):
		baked_meshes = int(probe.audit.board_variant.get("baked_meshes", 0))
		if is_instance_valid(probe.water_particles):ambient_density = float(probe.water_particles.get("ambient_particle_density"))
	var finish_payload := {
		"status": result, "completed": result == "completed", "ticks_usec": Time.get_ticks_usec(),
		"frames": frame, "health": game.health, "turn": game.turn, "turns_by_side": game.side_turn,
		"endgame": game.native_endgame.state, "outcome": game.native_endgame.result.get("outcome", ""),
		"board_baked_meshes": baked_meshes, "scenery_target": str(game.board_render_target_size),
		"spatial_msaa": int(game.spatial_view.msaa_3d) if is_instance_valid(game.spatial_view) else -1,
		"ambient_density": ambient_density,
		"victory_trail_density": ProjectSettings.get_setting_with_override("render_quality/victory_trail_density")
	}
	finish_payload["native_particles"] = {
		"batches": CombatParticles.native_batch_calls, "particles": CombatParticles.native_batch_particles,
		"constant_batches": CombatParticles.native_constant_batches,
		"trail_geometry_batches": CombatParticles.native_trail_geometry_batches,
		"projection_skips": CombatParticles.fast_particle_projection_skips,
	}
	if not scenario.is_empty():
		finish_payload.merge({"benchmark": "scenario", "scenario": scenario, "scenario_run": scenario_run})
	elif fx_benchmark != null:
		finish_payload.merge({"benchmark": "fx", "arm": fx_benchmark.arm, "run_index": fx_benchmark.run_index, "case_results": fx_benchmark.case_results})
	var hero_warmup = game.native_endgame_hero_warmup
	if hero_warmup != null:
		finish_payload["hero_warmup"] = {"wall_usec": hero_warmup.wall_usec, "batches": hero_warmup.completed_batches}
	var spell_warmup = game.native_mac_spell_warmup
	if spell_warmup != null:
		finish_payload["spell_warmup"] = {"wall_usec": spell_warmup.wall_usec, "batches": spell_warmup.completed_batches}
	# Drain diagnostics outside the measured interval. Hundreds of messages in
	# a single frame can exceed Android's logging quota even at safe line sizes.
	for index in diagnostics.size():
		if index % 8 == 0:
			await get_tree().process_frame
		emit_record(diagnostics[index])
	if fx_benchmark != null and result == "completed" and not fx_benchmark.finish():
		result = "fx_arm_counter_write_failed"
		finish_payload.status = result
		finish_payload.completed = false
	if native_ab_run >= 0 and result == "completed":
		var next_arm := FileAccess.open(NATIVE_AB_RUN_PATH, FileAccess.WRITE)
		if next_arm == null:
			result = "native_ab_counter_write_failed"
			finish_payload.status = result
			finish_payload.completed = false
		else:
			next_arm.store_string(str(native_ab_run + 1))
			next_arm.close()
	if scenario_run >= 0 and result == "completed" and not _advance_scenario_suite():
		result = "scenario_suite_counter_write_failed"
		finish_payload.status = result
		finish_payload.completed = false
	emit_record("MATCH_BENCH_END " + JSON.stringify(finish_payload))
	if not output_path.is_empty():
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			push_error("Could not open Android match capture: " + output_path)
		else:
			output.store_string("\n".join(output_lines) + "\n")
			output.close()
		output_lines.clear()
	if quit_when_done:
		get_tree().quit(0 if result == "completed" else 1)

func _advance_scenario_suite() -> bool:
	var counter := FileAccess.open(SCENARIO_SUITE_PATH, FileAccess.WRITE)
	if counter == null:
		return false
	counter.store_string(str(scenario_run + 1))
	counter.flush()
	return counter.get_error() == OK

func _diagnostic_chunks(values: Dictionary) -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	var chunk := {}
	for key in values:
		chunk[key] = values[key]
		if chunk.size() >= DIAGNOSTIC_BATCH_SIZE:
			chunks.append(chunk)
			chunk = {}
	if not chunk.is_empty():
		chunks.append(chunk)
	return chunks
