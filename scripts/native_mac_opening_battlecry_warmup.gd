extends RefCounted
## Submit first-use match effect shaders while loading.
## Small isolated targets reproduce their Compatibility light specializations.

const OpeningAssets = preload("res://scripts/source_opening_assets.gd")
const SourceManifest = preload("res://scripts/native_source_manifest.gd")
const Transmission = preload("res://scripts/native_combat_transmission.gd")
const SETTING := "render_quality/macos_opening_battlecry_warmup"
const FLAG := "--mac-opening-battlecry-warmup"
const SKIP_FLAG := "--mac-skip-opening-battlecry-warmup"
const EFFECTS_FLAG := "--mac-match-effects-warmup"
const SKIP_EFFECTS_FLAG := "--mac-skip-match-effects-warmup"
const EFFECTS_SETTING := "render_quality/macos_match_effects_warmup"
const VIEW_SIZE := Vector2i(64, 64)
const WELDLINE := "cab-3563ba8b89db13ca6eb196aa111591f1:-2139291312852994735"
const WELD_SPARK := "cab-3563ba8b89db13ca6eb196aa111591f1:-1010197123275176497"
const SUMMON_DUST := "cab-3563ba8b89db13ca6eb196aa111591f1:-2825523773836913966"
const ATTACK_SPLAT := "cab-3563ba8b89db13ca6eb196aa111591f1:2366413796736633013"
const DEATH_PORTRAIT := "cab-3563ba8b89db13ca6eb196aa111591f1:6737433705032255151"
const WARLOCK_SKULL := "cab-4fa5ae6b4d83b746ad8cfb40261b2af1:-7240466281421260143"

var _finished := false
var _batches: Array[String] = []
var _next_batch := 0
var _staging: Node
var _draw_callback := Callable()
var _views: Dictionary = {}
var _shaders: Array[Shader] = []

static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return OS.has_feature("macos") and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and (_opening_enabled(args) or _effects_enabled(args))

static func _opening_enabled(args: PackedStringArray) -> bool:
	return not args.has(SKIP_FLAG) and (args.has(FLAG) or bool(ProjectSettings.get_setting(SETTING, false)))

static func _effects_enabled(args: PackedStringArray) -> bool:
	return not args.has(SKIP_EFFECTS_FLAG) and (args.has(EFFECTS_FLAG) or bool(ProjectSettings.get_setting(EFFECTS_SETTING, false)))

func advance(game: Node) -> bool:
	if _finished:
		return true
	if _draw_callback.is_valid():
		return false
	if not game.native_initial_loading or game.world_canvas.visible:
		_finished = true
		return true
	if _batches.is_empty():
		var args := OS.get_cmdline_user_args()
		if _opening_enabled(args):
			_batches.append("opening_battlecry")
		if _effects_enabled(args):
			_batches.append("match_combat")
			if game.flow.mode == "normal" and not game.flow.visuals.prepared_coin_assets.is_empty():
				_batches.append("match_opening_coin")
	if _next_batch == _batches.size():
		_finished = true
		return true

	var batch := _batches[_next_batch]
	_next_batch += 1
	var started_usec := Time.get_ticks_usec()
	game.native_startup_timing.mark(batch + "_shader_warmup_begin")
	_staging = Node.new()
	_staging.name = "MatchShaderWarmup"
	game.add_child(_staging)
	match batch:
		"opening_battlecry": _stage_opening_battlecry(game)
		"match_combat": _stage_combat(game)
		"match_opening_coin": _stage_opening_coin(game)
	_draw_callback = _drawn.bind(game, batch, started_usec)
	RenderingServer.frame_post_draw.connect(_draw_callback, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	return false

func _stage_opening_battlecry(game: Node) -> void:
	if game.flow.mode == "normal":
		var assets := OpeningAssets.new()
		assets.base_path = OpeningAssets.OPENING_BASE
		assets.objects = SourceManifest.load_manifest(OpeningAssets.OPENING_BASE + "weld.json").objects
		assets._prepare_render_order()
		_stage(&"weldline", assets.material(WELDLINE) as ShaderMaterial, Viewport.MSAA_2X, false, true)
		if _views.has(&"weldline"):
			_stage_weld_color(_views[&"weldline"][0], assets.material(WELD_SPARK) as ShaderMaterial)
	var board: Viewport = game.spatial_scene.get_viewport()
	_stage(&"summon_dust", game.native_summon.assets.material(SUMMON_DUST) as ShaderMaterial,
		board.msaa_3d, true)

func _stage_combat(game: Node) -> void:
	var board: Viewport = game.spatial_scene.get_viewport()
	var combat_assets = game.native_combat.assets
	_stage(&"attack_splat", combat_assets.material(ATTACK_SPLAT) as ShaderMaterial, board.msaa_3d, true)
	_stage(&"warlock_skull", combat_assets.material(WARLOCK_SKULL) as ShaderMaterial, board.msaa_3d, true, true)
	var death_assets = game.native_death.assets
	var death_material: ShaderMaterial = death_assets.material(DEATH_PORTRAIT) as ShaderMaterial
	if death_material != null:
		# The live death route binds a card portrait after building its material.
		# These portraits share the same trilinear sampler and mip bias.
		var portrait: Texture2D = death_assets.load_texture(death_assets.portrait_by_card.get("CS2_182", ""))
		death_assets.endgame_textures.bind_source_sampler(death_material, "_MainTex", portrait, death_assets)
		_stage(&"death_portrait", death_material, board.msaa_3d, true)

func _stage_opening_coin(game: Node) -> void:
	var materials = game.flow.visuals.prepared_coin_assets.materials
	_stage(&"coin_fresnel", materials.build("FX_GlowCoin"), Viewport.MSAA_2X)
	_stage(&"coin_reflection", materials.build("MulliganCoinDrop1-mat_coin"), Viewport.MSAA_2X)

func cancel() -> void:
	_finished = true
	if _draw_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_draw_callback):
		RenderingServer.frame_post_draw.disconnect(_draw_callback)
	_draw_callback = Callable()
	_release_staging()

func _release_staging() -> void:
	if is_instance_valid(_staging):
		_staging.queue_free()
	_staging = null
	_views.clear()

func _stage(label: StringName, material: ShaderMaterial, msaa: Viewport.MSAA, directional := false, omni := false) -> void:
	if material == null:
		return
	_shaders.append(material.shader)
	var color_view := SubViewport.new()
	color_view.size = VIEW_SIZE
	color_view.own_world_3d = true
	color_view.transparent_bg = true
	color_view.msaa_3d = msaa
	color_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_staging.add_child(color_view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0, 4)
	color_view.add_child(camera)
	camera.current = true
	if directional:
		color_view.add_child(DirectionalLight3D.new())
	if omni:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0, 1)
		light.omni_range = 4.0
		color_view.add_child(light)
	_stage_quad(color_view, material)
	var transmission := Transmission.new()
	_staging.add_child(transmission)
	transmission.setup(color_view)
	transmission.transmission_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_views[label] = [color_view, transmission.transmission_view]

func _stage_weld_color(color_view: SubViewport, spark: ShaderMaterial) -> void:
	# The first weld light also specializes its additive sparks and nearby
	# unshaded text. These two programs are used only on the color pass.
	if spark != null:
		_shaders.append(spark.shader)
		_stage_quad(color_view, spark)
	var label := Label3D.new()
	label.text = "A"
	label.shaded = false
	label.double_sided = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	color_view.add_child(label)

func _stage_quad(view: SubViewport, material: ShaderMaterial) -> void:
	var proxy := MeshInstance3D.new()
	proxy.mesh = QuadMesh.new()
	proxy.material_override = material
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(proxy)

func _drawn(game: Node, batch: String, started_usec: int) -> void:
	_draw_callback = Callable()
	if _finished or not is_instance_valid(game):
		return
	var draw_calls := {}
	for label in _views:
		var passes: Array = []
		for view: SubViewport in _views[label]:
			passes.append(view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		draw_calls[label] = passes
	game.native_startup_timing.mark(batch + "_shader_warmup_end", {
		"wall_usec": Time.get_ticks_usec() - started_usec,
		"color_transmission_draw_calls": draw_calls,
	})
	_release_staging()
