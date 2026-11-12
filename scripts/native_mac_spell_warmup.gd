extends RefCounted
## Draw production spell shaders while the loading canvas covers the board.
## Only the isolated effect player advances. No match or combat-player callbacks run.

const Effects = preload("res://scripts/native_combat_effects.gd")
const DamageSplat = preload("res://scripts/native_damage_splat.gd")
const RenderTexture = preload("res://scripts/native_combat_rendertexture.gd")
const PhoneBoardLayout = preload("res://scripts/source_phone_board_layout.gd")
const ENABLED_SETTING := "render_quality/macos_spell_shader_warmup"
const COIN_SETTING := "render_quality/macos_played_coin_warmup"
const HELLFIRE_SETTING := "render_quality/macos_opponent_hellfire_warmup"
const CORRUPTION_SETTING := "render_quality/macos_opponent_corruption_warmup"
const LIFE_TAP_SETTING := "render_quality/macos_life_tap_warmup"
const FIREBALL := "CS2_029"
const COIN := "GAME_005"
const HELLFIRE := "CS2_062"
const CORRUPTION := "CS2_063"
const LIFE_TAP := "CS2_056"
const FIREBALL_SAMPLES := [
	["birth", 0.04],
	["charging", 0.2],
	["launch", 0.03],
	["flight", 0.18],
	["impact", 0.03],
	["impact_particles", 0.17],
	["impact_tail", 0.5],
	["missile_tail", 0.22],
	["late_impact_tail", 0.43],
	["hero_damage", 0.0],
	["hero_hover", 0.0],
]
const COIN_SAMPLES := [
	["played_coin_launch", 0.0],
	["played_coin_particles", 0.025],
	["played_coin_rise", 0.155],
	["played_coin_fade", 0.54],
]
const HELLFIRE_SAMPLES := [
	["opponent_hellfire_launch", 0.0],
	["opponent_hellfire_first_sample", 0.025],
	["opponent_hellfire_particles", 0.125],
	["opponent_hellfire_impact", 0.215],
	["opponent_hellfire_tail", 0.65],
]
const CORRUPTION_SAMPLES := [
	["opponent_corruption_birth", 0.0],
	["opponent_corruption_first_sample", 0.027],
	["opponent_corruption_charge", 0.17],
	["opponent_corruption_launch", 0.027],
	["opponent_corruption_flight", 0.22],
	["opponent_corruption_impact", 0.025],
	["opponent_corruption_impact_particles", 0.245],
]
const LIFE_TAP_SAMPLES := [
	["opponent_life_tap_impact", 0.0],
	["opponent_life_tap_first_sample", 0.025],
	["opponent_life_tap_particles", 0.125],
]

var wall_usec := 0
var completed_batches := 0
var _started_usec := -1
var _next_sample := 0
var _finished := false
var _draw_callback := Callable()
var _player: Node
var _damage_preview: Node
var _hero_hover_staged := false
var _spell: Dictionary = {}
var _shaders: Dictionary = {}
var _samples: Array = []
var _cards: Array[String] = []
var _offscreen_sequence_before_preview := -1
var _corruption_position: Vector3

static func enabled() -> bool:
	if not OS.has_feature("macos") or DisplayServer.get_name() == "headless":return false
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":return false
	var args := OS.get_cmdline_user_args()
	return not args.has("--mac-skip-spell-warmup") and (_fireball_enabled(args) or _coin_enabled(args) or _hellfire_enabled(args) or _corruption_enabled(args) or _life_tap_enabled(args))

static func _fireball_enabled(args: PackedStringArray) -> bool:
	return args.has("--mac-spell-warmup") or bool(ProjectSettings.get_setting(ENABLED_SETTING, false))

static func _coin_enabled(args: PackedStringArray) -> bool:
	return not args.has("--mac-skip-played-coin-warmup") and (args.has("--mac-played-coin-warmup") or bool(ProjectSettings.get_setting(COIN_SETTING, false)))

static func _hellfire_enabled(args: PackedStringArray) -> bool:
	return not args.has("--mac-skip-opponent-hellfire-warmup") and (args.has("--mac-opponent-hellfire-warmup") or bool(ProjectSettings.get_setting(HELLFIRE_SETTING, false)))

static func _corruption_enabled(args: PackedStringArray) -> bool:
	return not args.has("--mac-skip-opponent-corruption-warmup") and (args.has("--mac-opponent-corruption-warmup") or bool(ProjectSettings.get_setting(CORRUPTION_SETTING, false)))

static func _life_tap_enabled(args: PackedStringArray) -> bool:
	return not args.has("--mac-skip-life-tap-warmup") and bool(ProjectSettings.get_setting(LIFE_TAP_SETTING, false))

func advance(game: Node) -> bool:
	if _finished:return true
	if _draw_callback.is_valid():return false
	if _started_usec < 0:
		if not _can_stage(game):return true
		var args := OS.get_cmdline_user_args()
		if _fireball_enabled(args):
			_samples.append_array(FIREBALL_SAMPLES)
			_cards.append(FIREBALL)
		if _coin_enabled(args):
			_samples.append_array(COIN_SAMPLES)
			_cards.append(COIN)
		if _hellfire_enabled(args):
			_samples.append_array(HELLFIRE_SAMPLES)
			_cards.append(HELLFIRE)
		if _corruption_enabled(args) and is_instance_valid(game.source_projection) and is_instance_valid(game.source_phone_layout):
			var row: Dictionary = game.source_phone_layout.source_items.get("friendly_play", {}).get("source_row", {})
			var slots := PhoneBoardLayout.normal_slots(row, 1) if not row.is_empty() else []
			if not slots.is_empty():
				_corruption_position = slots[0]
				_samples.append_array(CORRUPTION_SAMPLES)
				_cards.append(CORRUPTION)
		if _life_tap_enabled(args):
			_samples.append_array(LIFE_TAP_SAMPLES)
			_cards.append(LIFE_TAP)
		_started_usec = Time.get_ticks_usec()
		game.native_startup_timing.mark("spell_shader_warmup_begin", {"cards":_cards})
		_setup_player(game)
	if _next_sample == _samples.size() or not _can_stage(game):
		_release_staging()
		_finished = true
		wall_usec = Time.get_ticks_usec() - _started_usec
		game.native_startup_timing.mark("spell_shader_warmup_end", {"cards":_cards,"wall_usec":wall_usec,"batches":completed_batches,"shader_count":_shaders.size()})
		return true
	var sample: Array = _samples[_next_sample]
	_next_sample += 1
	var started := Time.get_ticks_usec()
	_stage_sample(game, sample[0], sample[1])
	# Launch can draw before the next transmission sync. Stage that color
	# frame separately, then advance particles and synchronize both views.
	if sample[0] != "played_coin_launch":game.native_transmission.sync()
	_draw_callback = _sample_drawn.bind(game, sample[0], started)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	_release_staging()
	_shaders.clear()

func _can_stage(game: Node) -> bool:
	return game.native_initial_loading and is_instance_valid(game.world_canvas) and not game.world_canvas.visible \
		and is_instance_valid(game.spatial_scene) and is_instance_valid(game.native_transmission) \
		and is_instance_valid(game.native_combat) and is_instance_valid(game.spatial_scene.camera)

func _setup_player(game: Node) -> void:
	_player = Effects.new()
	_player.name = "SpellShaderWarmup"
	_player.suppress_game_shake = true
	game.add_child(_player)
	_player.setup(game, game.native_combat.assets)
	var target := {"type":"hero","side":1,"pos":game.ENEMY_HERO}
	_spell = {"serial":1,"key":FIREBALL,"source":game.PLAYER_HERO,"side":0,"target":target}

func _stage_sample(game: Node, stage: String, age: float) -> void:
	match stage:
		"birth", "opponent_corruption_birth":
			if stage == "opponent_corruption_birth":_prepare_corruption(game)
			_spell.start_effect = _player.prepare_spell_start(_spell)
			_spell.route = _player.spell_route(_spell.key, _spell.target, _spell.side)
		"launch", "opponent_corruption_launch":
			var ready: float = _player.start_ready_time(_spell.key)
			_player.advance(maxf(0.0, ready - float(_spell.start_effect.get("age", 0.0))))
			_spell.start_action_time = ready
			_player.spell_launch(_spell)
		"impact", "opponent_corruption_impact":
			var missile: Dictionary = _spell.get("missile_effect", {})
			_player.advance(maxf(0.0, float(_spell.route.impact_time) - float(missile.get("age", 0.0))))
			_player.spell_impact(_spell)
		"hero_damage":
			_stage_hero_damage(game)
			return
		"hero_hover":
			if is_instance_valid(game.native_highlight):
				_hero_hover_staged = game.native_highlight.stage_enemy_hero_hover_warmup()
			return
		"played_coin_launch":
			_offscreen_sequence_before_preview = RenderTexture.offscreen_sequence
			_spell = {"serial":1,"key":COIN,"source":game.PLAYER_HERO,"side":0,"target":{}}
			_spell.route = _player.spell_route(COIN, _spell.target, _spell.side)
			_player.spell_launch(_spell)
			return
		"opponent_hellfire_launch":
			_player.cancel_all()
			_restore_offscreen_sequence()
			_spell = {"serial":1,"key":HELLFIRE,"source":game.ENEMY_HERO,"side":1,"target":{}}
			_spell.route = _player.spell_route(HELLFIRE, _spell.target, _spell.side)
			# The AI launches before the frame's normal transmission sync.
			# Draw the real initial pose before advancing the effect clock.
			_player.spell_launch(_spell)
			return
		"opponent_life_tap_impact":
			_player.cancel_all()
			_restore_offscreen_sequence()
			_offscreen_sequence_before_preview = RenderTexture.offscreen_sequence
			var target := {"type":"hero","side":1,"pos":game.ENEMY_HERO}
			_spell = {"serial":1,"key":LIFE_TAP,"source":Vector2(948,196),"side":1,"target":target}
			_spell.route = _player.spell_route(LIFE_TAP, target, _spell.side)
			# The AI dispatches Life Tap after the frame's effect clock advance.
			_player.spell_impact(_spell)
			return
	_player.advance(age)

func _prepare_corruption(game: Node) -> void:
	_player.cancel_all()
	_restore_offscreen_sequence()
	# A one-minion friendly row gives the same target pose as the first real
	# Corruption. Only the position is used by this effect; no actor is added.
	var screen_position: Vector2 = game.source_projection.source_to_screen(_corruption_position)
	var target := {"type":"unit","pos":screen_position,"unit":{"side":0,"source_world_position":_corruption_position}}
	_spell = {"serial":1,"key":CORRUPTION,"source":game.ENEMY_HERO,"side":1,"target":target}

func _stage_hero_damage(game: Node) -> void:
	if not is_instance_valid(game.native_damage):return
	var live: Node = game.native_damage
	_damage_preview = DamageSplat.new()
	_damage_preview.name = "HeroDamageShaderWarmup"
	_damage_preview.game = game
	_damage_preview.assets = live.assets
	_damage_preview.glyph_bundle = live.glyph_bundle
	_damage_preview.reflected_shaders = live.reflected_shaders
	game.add_child(_damage_preview)
	_damage_preview.present({"target_id":"hero:1","target_type":"hero","side":1,"amount":6})
	# The real presentation yields once at scale zero, then exposes its meshes.
	_damage_preview.sync()
	_damage_preview.advance(1.0 / 60.0)
	_damage_preview.sync()

func _sample_drawn(game: Node, stage: String, started: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(_player) or not is_instance_valid(game):return
	var capture_views := 0
	var capture_draw_calls := 0
	for effect in _player.effects:
		if is_instance_valid(effect.container):
			var draws := _retain_drawn_shaders(effect.container)
			capture_views += draws.x
			capture_draw_calls += draws.y
	if is_instance_valid(_damage_preview):
		for entry in _damage_preview.entries.values():
			if is_instance_valid(entry.hero_proxy):_retain_drawn_shaders(entry.hero_proxy)
	if _hero_hover_staged:
		var highlight: Node = game.native_highlight.renderer
		var pipeline: Dictionary = highlight.gpu_pipelines.get("hero:1", {})
		if is_instance_valid(pipeline.get("root")):
			var draws := _retain_drawn_shaders(pipeline.root)
			capture_views += draws.x
			capture_draw_calls += draws.y
		var entry: Dictionary = highlight.entries.get("hero:1", {})
		if is_instance_valid(entry.get("mesh")):_retain_drawn_shaders(entry.mesh)
	completed_batches += 1
	game.native_startup_timing.mark("spell_shader_warmup_batch_drawn", {
		"stage":stage,"wall_usec":Time.get_ticks_usec()-started,"effects":_player.effects.size(),
		"capture_views":capture_views,"capture_draw_calls":capture_draw_calls,"shader_count":_shaders.size(),
		"hero_damage":is_instance_valid(_damage_preview),"hero_hover":_hero_hover_staged,
		"color_draw_calls":game.spatial_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"transmission_draw_calls":game.native_transmission.transmission_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
	})
	if stage == "late_impact_tail":
		_spell.clear()
		_player.cancel_all()
		game.native_transmission.sync()
	elif is_instance_valid(_damage_preview):
		_release_damage_preview()
		game.native_transmission.sync()
	elif _hero_hover_staged:
		game.native_highlight.hide_enemy_hero_hover_warmup()
		_hero_hover_staged = false
		game.native_transmission.sync()

func _retain_drawn_shaders(root: Node) -> Vector2i:
	# Generated sampler/capture variants use weak lookup tables. Keep their actual
	# Shader resources alive after removing the temporary meshes and render targets.
	var draws := Vector2i.ZERO
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is SubViewport and node.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			draws.x += 1
			draws.y += node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			draws.y += node.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			continue
		if node is MeshInstance3D and node.mesh != null:
			for surface in range(node.mesh.get_surface_count()):
				_retain_material(node.get_active_material(surface))
		elif node is CanvasItem:
			_retain_material(node.material)
	return draws

func _retain_material(material: Material) -> void:
	if material is ShaderMaterial and is_instance_valid(material.shader):
		_shaders[material.shader.get_instance_id()] = material.shader

func _release_staging() -> void:
	_spell.clear()
	_release_damage_preview()
	if not is_instance_valid(_player):
		_restore_offscreen_sequence()
		return
	var game: Node = _player.game
	if _hero_hover_staged and is_instance_valid(game) and is_instance_valid(game.native_highlight):
		game.native_highlight.hide_enemy_hero_hover_warmup()
	_hero_hover_staged = false
	_player.cancel_all()
	_restore_offscreen_sequence()
	_player.queue_free()
	_player = null
	if is_instance_valid(game) and game.is_inside_tree() and is_instance_valid(game.native_transmission):
		game.native_transmission.sync()

func _restore_offscreen_sequence() -> void:
	if _offscreen_sequence_before_preview < 0:return
	RenderTexture.offscreen_sequence = _offscreen_sequence_before_preview
	_offscreen_sequence_before_preview = -1

func _release_damage_preview() -> void:
	if not is_instance_valid(_damage_preview):return
	_damage_preview.clear()
	_damage_preview.queue_free()
	_damage_preview = null
