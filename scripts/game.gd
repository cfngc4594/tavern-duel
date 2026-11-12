extends Node2D
## Personal, non-commercial fan prototype. Classic card rules pinned to 1.0.0.5834.
## Original game audio retains Blizzard copyright; unavailable character lines remain silent.
## All gameplay and rendering run in Godot, with a 1600 x 900 logical canvas.

const W = 1600.0
const H = 900.0
const CARD_SIZE = Vector2(156, 232)
const FRIEND_Y = 496.0
const ENEMY_Y = 340.0
var PLAYER_HERO = Vector2(800, 684)
var ENEMY_HERO = Vector2(800, 158)
const GOLD = Color("caa56a")
const INK = Color("33251b")
const CREAM = Color("f5e4bd")
const BLUE = Color("58d6ff")
const GREEN = Color("8eff87")
const RED = Color("ff6250")

const CARD_FACE_SCALE = Vector2(0.975, 0.938)
const CARD_FACE_OFFSET = Vector2(0, -7.192)
@export var startup_mode = "normal"
var flow
var rules
var native_history_events = preload("res://scripts/native_history_events.gd").new()
var hero_classes = ["MAGE", "WARLOCK"]
var game_tied = false
var font: Font
var title_font: Font
var stat_font: Font
var background: Texture2D
var face_render_mode = false
var face_render_key = ""
var draw_target: CanvasItem = self
var world_canvas: Node2D
var fixed_canvas: Node2D
var source_phone_name_banners
var fixed_layer: CanvasLayer
var screen_pointer=Vector2(800,500)
var camera_shake=preload("res://scripts/native_camera_shake.gd").new()
var spatial_post: Node2D
var native_transmission: Node
var native_screen_effects: Node
var spatial_view: SubViewport
var spatial_scene: Node3D
var native_rope_host:Node
var card_face_textures: Dictionary = {}
var native_card_renderer: Node = null
var native_turn_banner: Node = null
var native_turn_ui: Node = null
var native_summon: Node = null
var combat_replay = preload("res://scripts/native_combat_replay.gd").new()
var native_combat: Node = null
var native_damage: Node = null
var native_death: Node = null
var native_endgame: Node = null
var native_targeting: Node = null
var native_status: Node = null
var native_highlight: Node = null
# Retired renderers live through consumer rebinding and a complete render boundary.
var retired_native_renderers: Array = []
var native_cost_cache: Dictionary = {}
var native_definition_cache: Dictionary = {}
var raw_portraits: Array[Texture2D] = []
var masked_portraits: Dictionary = {}
var missing_portrait_indices: Array[int] = []
var unit_frames: Array[Texture2D] = []
var card_surface: Texture2D
var classic_ui: Dictionary = {}
var reference_fixture = false
var reference_secret = false
var reference_hand_costs: Dictionary = {}
var cards: Array = []
var allies: Array = []
var enemies: Array = []
var deck: Array = []
var enemy_deck: Array = []
var enemy_hand: Array = []
var definitions: Dictionary = {}
var health = [30, 30]
var mana = 4
var max_mana = 4
var enemy_mana = 4
var enemy_max_mana = 4
var turn = 1
var player_turn = true
var busy = false
var won = false
var game_over = false
var power_used = false
var elapsed = 0.0
# Cosmetic clock uses the full delta, independently of the physics safety clamp.
var indicator_time = 0.0
var pointer = Vector2(800, 500)
var hover_card = -1
var hover_unit = -1
var drag_index = -1
var selected_unit = -1
var targeting_power = false
var drag_start = Vector2.ZERO
var drag_pos = Vector2.ZERO
var drag_velocity = Vector2.ZERO
var source_held_motion = preload("res://scripts/native_held_motion.gd").new()
# Touch is an explicit input route, not desktop mouse emulation.
var touch_input_active: bool = OS.has_feature("android") or OS.has_feature("ios")
var active_touch_index: int = -1
var touch_press_window_pos := Vector2.ZERO
var pressed_card = -1
var mouse_down = false
var press_pos = Vector2.ZERO
var press_screen_pos = Vector2.ZERO
var unit_uid = 1
var source_card_uid=1
var particles: Array = []
var floats: Array = []
var ripples: Array = []
var bolts: Array = []
var recent_log: Array = []
var board_sprite: Sprite2D
var banner = "你的回合"
var banner_sub = "施展法术，指挥随从，点亮酒馆。"
var banner_time = 1.5
var toast = ""
var toast_time = 0.0
var shake = 0.0
var shake_offset = Vector2.ZERO # Compatibility field: never per-object camera motion.
var turn_clock = 75.0
var sound_enabled = true:
	set(value):
		sound_enabled = value
		if is_inside_tree(): SoundManager.set_sfx_enabled(value)
var help_visible = false
var settings_visible = false
var ai_timer = 0.0
var ai_step = 0
var hover_corner = -1
var corner_pulse = [0.0, 0.0, 0.0, 0.0]
var hit_flash = [0.0, 0.0]
var rng = RandomNumberGenerator.new()
var demo_mode = false
var demo_step = 0
var demo_clock = 0.0
var capture_mode = false
var state_out = ""
var last_state_write = 0.0
var opening = 1.0
var last_hover = -2
var tutorial_hint = true
var ambient_glints: Array = []
var headless = false
var staged_cards: Array = []
var release_fx: Node2D
var impacts: Array = []
var death_ghosts: Array = []
var event_trace: Array = []
var button_travel = 0.0
var pending_battlecry: Dictionary = {}
var death_queue: Array = []
var fatigue = [0, 0]
var hero_frozen = [false, false]
var side_turn = [1, 0]
var hero_thaw_turn = [0, 0]
# Presentation-only audio identity; these never enter the rule RNG or card values.
var _audio_action_sequence = 0
var _audio_selected_attack_id = -1
var _audio_combat_pair: Array = []
var _audio_spell_preview: Dictionary = {}
var _audio_resolution: Dictionary = {}
var _audio_scope_sides: Dictionary = {}

# Interaction state is separate from committed gameplay state. Preview never pays costs.
enum Interaction { IDLE, CARD_HELD, SPELL_AIM, PLACEMENT_PREVIEW, ATTACK_AIM, POWER_AIM, BATTLECRY_AIM }
var interaction_state = Interaction.IDLE
var tracked_drag = -1
var spell_aim_latched = false
var spell_anchor = Vector2.ZERO
var preview_index = -1
var preview_position = Vector2.ZERO
var target_feedback: Dictionary = {}
var rejections: Array = []
var demo_caption = ""
var scripted_pointer = false
const PLAY_RECT = Rect2(300, 420, 1000, 200)
var POWER_POS = Vector2(948, 690)

var native_startup_timing=preload("res://scripts/native_startup_timing.gd").new()
var native_card_loader=preload("res://scripts/native_card_load_queue.gd").new()
var native_load_guard=preload("res://scripts/native_load_guard.gd").new()
var native_loading_error=""
var native_loading_error_layer:CanvasLayer
var native_initial_loading=false
var native_scene_warmup_pending := false
var native_scene_warmup_complete := false
const EndgameHeroWarmup = preload("res://scripts/native_endgame_hero_warmup.gd")
var native_endgame_hero_warmup: EndgameHeroWarmup
const MacSpellWarmup = preload("res://scripts/native_mac_spell_warmup.gd")
var native_mac_spell_warmup: MacSpellWarmup
const MacCoinWarmup = preload("res://scripts/native_mac_coin_warmup.gd")
var native_mac_coin_warmup: MacCoinWarmup
var native_banner_pending=false
var native_initial_sounds:Array=[]
var native_load_frames=0
var native_last_load_frame=-1
var original_board_bridge
var source_projection
var source_visual_delta:=0.0
var profile_frame_stages: bool=false
var last_frame_stages: Dictionary={}
var android_match_benchmark: Node
var source_mana_controller
var source_mana_proposal_id=-1
var source_phone_layout
var native_phone_hand
var source_logic_opposing_hand
var board_gesture=false
const RenderResolution = preload("res://scripts/render_resolution_policy.gd")
var render_target_size := Vector2i(1600,900)
var presentation_size := Vector2(1600,900)
var presentation_offset := Vector2.ZERO
var board_render_target_size := Vector2i(1600,900)

func _refresh_render_resolution():
	var output:Vector2i=get_window().size
	var canvas:Vector2=get_viewport_rect().size
	if canvas.x<1600.0 or canvas.y<900.0:canvas=RenderResolution.canvas_size(output)
	var max_scale := float(ProjectSettings.get_setting_with_override("render_quality/offscreen_max_scale"))
	var target:Vector2i=RenderResolution.target_size(output,max_scale)
	var board_target:Vector2i=RenderResolution.scenery_size(canvas,target)
	if target==render_target_size and canvas.is_equal_approx(presentation_size) and board_target==board_render_target_size:return
	render_target_size=target;presentation_size=canvas;presentation_offset=(canvas-Vector2(1600,900))*0.5
	board_render_target_size=board_target
	if is_instance_valid(world_canvas):world_canvas.position=presentation_offset+camera_shake.screen_offset
	if is_instance_valid(fixed_canvas):fixed_canvas.position=presentation_offset
	if is_instance_valid(source_phone_layout):source_phone_layout.refresh();source_projection=source_phone_layout.context
	if is_instance_valid(spatial_view):spatial_view.size=board_target if source_projection!=null else target
	if is_instance_valid(original_board_bridge):original_board_bridge.set_render_size(board_target)
	if is_instance_valid(native_endgame) and is_instance_valid(native_endgame.screen):
		var effect=native_endgame.screen.background_effect
		if is_instance_valid(effect):effect.refresh_layout()

func get_render_resolution_audit() -> Dictionary:
	return {"logical_size":[1600,900],"canvas_size":[presentation_size.x,presentation_size.y],"content_offset":[presentation_offset.x,presentation_offset.y],"window_size":[get_window().size.x,get_window().size.y],"offscreen_size":[render_target_size.x,render_target_size.y],"scenery_size":[board_render_target_size.x,board_render_target_size.y],"policy":"Compatibility expanded mobile canvas; centered gameplay, wider original scenery, density/pixel-budget bounded targets"}


func _ready():
	if face_render_mode: return
	add_to_group("audio_shutdown_participants")
	native_startup_timing.configure()
	native_startup_timing.watch_game(self)
	native_startup_timing.begin("ready_cpu")
	_refresh_render_resolution()
	native_startup_timing.begin("phone_layout_cpu")
	source_phone_layout=preload("res://scripts/source_phone_layout_controller.gd").new();add_child(source_phone_layout);source_phone_layout.setup(self)
	native_startup_timing.end("phone_layout_cpu")
	source_projection=source_phone_layout.context
	native_phone_hand=preload("res://scripts/native_phone_hand.gd").new();native_phone_hand.setup(self)
	# Explicit adapter setting, not a claim about the original server feature flag.
	native_phone_hand.mini_hand_play_enabled=bool(ProjectSettings.get_setting("native_mobile/mini_hand_play_enabled",true))
	get_window().size_changed.connect(_refresh_render_resolution)
	native_initial_loading=DisplayServer.get_name()!="headless"
	flow=preload("res://scripts/classic_match_flow.gd").new()
	flow.game=self
	rules=preload("res://scripts/dual_class_rules.gd").new()
	rules.game=self
	flow.visuals=preload("res://scripts/classic_flow_visuals.gd").new()
	flow.visuals.game=self
	flow.audio=preload("res://scripts/classic_flow_audio.gd").new()
	add_child(flow.audio)
	_setup_presentation_canvases()
	world_canvas.visible=not native_initial_loading
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	font = load("res://assets/native_cards/OriginalCards/Fonts/BlizzardGlobal__2407746389514081280.ttf")
	title_font = load("res://assets/title.ttf")
	stat_font = load("res://assets/original_classic_v14/Belwe-Bold-official-web.ttf")
	rng.seed = 8372
	headless = DisplayServer.get_name() == "headless"
	original_board_bridge=load("res://scripts/original_board_bridge.gd").new()
	add_child(original_board_bridge)
	native_startup_timing.begin("board_setup_cpu")
	original_board_bridge.setup(self)
	native_startup_timing.end("board_setup_cpu")
	board_sprite=Sprite2D.new();board_sprite.name="LiveOriginalBoard"
	board_sprite.texture=original_board_bridge.get_texture()
	board_sprite.position=Vector2(800,450);board_sprite.z_index=-100
	board_sprite.scale=presentation_size/Vector2(board_render_target_size)
	world_canvas.add_child(board_sprite)
	native_startup_timing.begin("portraits_cpu")
	_load_portraits()
	native_startup_timing.end("portraits_cpu")
	card_surface = load("res://assets/original_classic_v13/ui/frame-minion-neutral.png")
	for key in ["frame-minion-neutral","frame-spell-mage","name-banner-minion","name-banner-spell","cost-mana","attack-minion","health","armor","race-banner","frame-spell-priest","frame-spell-neutral","frame-minion-hunter","rarity-minion-common","elite-minion"]:
		classic_ui[key] = load("res://assets/original_classic_v13/ui/"+key+".png")
	for key in ["inplay_minion","inplay_minion_taunt","inplay_minion_hide_stats","hero_frame","hero_power","hero_power_exhausted","mana_crystal","secret_hunter","hearthstone-cursor","hearthstone-click","hearthstone-grab","reference-history-137s"]:
		classic_ui[key] = load("res://assets/original_classic_v14/"+key+".png")
	for key in ["frame-minion-mage","frame-minion-warlock","frame-spell-warlock"]:
		var path="res://assets/original_classic_v13/ui/"+key+".png"
		if ResourceLoader.exists(path): classic_ui[key]=load(path)
	classic_ui["cardback"] = load("res://assets/original_classic_v13/cardback_classic.png")
	native_startup_timing.begin("definitions_cpu")
	_define_cards()
	native_startup_timing.end("definitions_cpu")
	for i in range(35):
		ambient_glints.append({"p": Vector2(rng.randf_range(180, 1420), rng.randf_range(120, 860)), "phase": rng.randf_range(0, TAU), "speed": rng.randf_range(0.25, 0.65)})
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": demo_mode = true
		if arg == "--capture": capture_mode = true
		if arg == "--practice": startup_mode="practice"
		if arg == "--normal": startup_mode="normal"
		if arg.begins_with("--state="): state_out = arg.substr(8)
	if OS.get_cmdline_user_args().has("--android-match-benchmark"):
		android_match_benchmark=load("res://scripts/android_match_benchmark.gd").new()
		android_match_benchmark.setup(self)
		add_child(android_match_benchmark)
		if OS.get_cmdline_user_args().has("--android-fx-viewport-profile"):
			var viewport_profile=load("res://scripts/android_fx_viewport_profile.gd").new()
			viewport_profile.game=self
			add_child(viewport_profile)
	if headless: sound_enabled = false
	else: Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	SoundManager.set_sfx_enabled(sound_enabled)
	native_startup_timing.begin("turn_ui_cpu")
	if not headless:
		native_turn_banner=load("res://scripts/native_turn_banner.gd").new();add_child(native_turn_banner);native_turn_banner.setup(self)
		native_turn_ui=load("res://scripts/native_turn_ui.gd").new();add_child(native_turn_ui);native_turn_ui.setup(self)
	native_startup_timing.end("turn_ui_cpu")
	native_startup_timing.begin("start_match_cpu")
	if android_match_benchmark!=null:
		start_match("normal",android_match_benchmark.first_side,android_match_benchmark.seed_value)
	else:
		start_match(startup_mode)
	native_startup_timing.end("start_match_cpu")
	native_startup_timing.begin("spatial_setup_cpu")
	if not headless: _setup_spatial_presentation()
	native_startup_timing.end("spatial_setup_cpu")
	native_startup_timing.begin("effects_setup_cpu")
	native_summon=load("res://scripts/native_summon_player.gd").new()
	add_child(native_summon)
	native_summon.setup(self)
	native_combat=load("res://scripts/native_combat_player.gd").new();add_child(native_combat);native_combat.setup(self);combat_replay.setup(self)
	native_damage=load("res://scripts/native_damage_splat.gd").new();add_child(native_damage);native_damage.setup(self)
	native_death=load("res://scripts/native_death.gd").new();add_child(native_death);native_death.setup(self)
	native_endgame=load("res://scripts/native_endgame.gd").new();add_child(native_endgame);native_endgame.setup(self)
	native_targeting=load("res://scripts/native_targeting.gd").new();add_child(native_targeting);native_targeting.setup(self)
	native_status=load("res://scripts/native_status.gd").new();add_child(native_status);native_status.setup(self)
	native_highlight=load("res://scripts/native_highlight.gd").new();add_child(native_highlight);native_highlight.setup(self)
	if not headless:
		native_screen_effects=load("res://scripts/native_combat_screen_effects.gd").new();add_child(native_screen_effects);native_screen_effects.setup(self,native_combat.assets)

	if bool(ProjectSettings.get_setting("native_rope/enabled",false)):
		native_rope_host=preload("res://source_rope/src/game_rope_host.gd").new();add_child(native_rope_host);native_rope_host.setup(self)
	native_startup_timing.end("effects_setup_cpu")
	native_startup_timing.end("ready_cpu")
	native_startup_timing.mark("ready_return",{"loading":native_initial_loading,"cards":definitions.size()})

func shutdown_presentation_audio():
	# WM_CLOSE/explicit shutdown only. Keep this scene and its audio sinks in
	# the tree while AudioServer releases real playback ownership.
	set_process(false);set_process_input(false);set_process_unhandled_input(false)
	if is_instance_valid(spatial_scene) and is_instance_valid(spatial_scene.phone_burn_renderer):
		await spatial_scene.phone_burn_renderer.shutdown()
	if is_instance_valid(native_rope_host):await native_rope_host.shutdown()

func _exit_tree():
	if native_mac_spell_warmup != null:native_mac_spell_warmup.cancel()
	if native_mac_coin_warmup != null:native_mac_coin_warmup.cancel()
	if face_render_mode: return
	native_startup_timing.stop_watching()
	if is_instance_valid(original_board_bridge):original_board_bridge.close()
	camera_shake.clear()
	if is_instance_valid(native_targeting):native_targeting.clear("exit_tree")
	if is_instance_valid(native_status):native_status.clear("exit_tree")
	if is_instance_valid(native_highlight):native_highlight.clear("exit_tree")
	if is_instance_valid(native_endgame):native_endgame.clear(false)
	if is_instance_valid(native_screen_effects):native_screen_effects.dispose()
	if flow!=null and is_instance_valid(flow.audio): flow.audio.stop()
	if is_instance_valid(SoundManager): SoundManager.stop_all_sfx()
	if get_tree()!=null:
		for tween in get_tree().get_processed_tweens(): tween.kill()

func _ensure_card_face_textures():
	if headless: return
	# Rebuild when normal-match definitions replace practice definitions.
	var changed=false
	for key in card_face_textures:
		if definitions.has(key) and native_definition_cache.get(key,"")!=JSON.stringify(definitions[key]):changed=true
	if changed:
		if is_instance_valid(native_card_renderer):
			retired_native_renderers.append({"renderer":native_card_renderer,"frames":4})
		native_card_renderer=null;card_face_textures.clear();native_cost_cache.clear();native_definition_cache.clear();native_card_loader.reset()
	if not is_instance_valid(native_card_renderer):
		native_card_renderer=load("res://scripts/native_card_renderer.gd").new()
		add_child(native_card_renderer)
		native_card_renderer.card_texture_ready.connect(_on_card_texture_ready)
	var missing:Array=[]
	for key in definitions:
		if not card_face_textures.has(key):missing.append(key)
	native_card_loader.enqueue(missing)
	if native_card_loader.has_pending():
		if not native_initial_loading:
			native_load_guard.reset()
			native_scene_warmup_pending=false
			native_scene_warmup_complete=false
		native_initial_loading=true
		if is_instance_valid(world_canvas):world_canvas.visible=false
		if is_instance_valid(native_turn_banner) and native_turn_banner.timeline.running:
			native_turn_banner.cancel_original();native_banner_pending=true
		_advance_native_card_load()

func _build_one_native_card(key:String):
	if not definitions.has(key):return
	native_startup_timing.begin("card_build_cpu",key)
	native_startup_timing.begin("card_until_queue_release_wall",key)
	var definition:Dictionary=definitions[key]
	native_definition_cache[key]=JSON.stringify(definition)
	card_face_textures[key]=native_card_renderer.build_card(key,definition,raw_portraits[definition.art])
	var cost=int(reference_hand_costs.get(key,definition.cost))
	native_card_renderer.update_cost(key,cost);native_cost_cache[key]=cost
	native_startup_timing.end("card_build_cpu",key)

func _native_card_complete(key:String)->bool:
	if not is_instance_valid(native_card_renderer) or not native_card_renderer.cards.has(key):return false
	var state:Dictionary=native_card_renderer.cards[key]
	var cache=native_card_renderer.texture_cache_controller
	var complete=bool(state.get("rt_cache_baked",false)) and not bool(state.get("rt_cache_dirty",true)) and native_card_renderer.pending_freezes.is_empty() and is_instance_valid(cache) and not cache.draw_pending and retired_native_renderers.is_empty()
	if complete:
		native_startup_timing.once("card_bake_clean_observed",key)
		if native_card_loader.clean_frames==1:native_startup_timing.end("card_until_queue_release_wall",key)
	return complete

func _advance_native_card_load():
	if not retired_native_renderers.is_empty():return
	var frame=Engine.get_process_frames()
	if native_last_load_frame==frame:return
	native_last_load_frame=frame
	var previous_active:String=native_card_loader.active
	if is_instance_valid(native_card_renderer):native_card_loader.tick(_native_card_complete,_build_one_native_card)
	if not previous_active.is_empty() and previous_active!=native_card_loader.active:
		native_startup_timing.mark("card_queue_released",{"key":previous_active})
	if not native_card_loader.has_pending():native_startup_timing.once("card_queue_empty")

func _show_native_turn_banner():
	if native_initial_loading:
		native_banner_pending=true;return
	if is_instance_valid(native_turn_banner):native_turn_banner.show_original()

func _native_loading_problem()->String:
	if not is_instance_valid(source_phone_layout):return "手机界面布局未能创建。"
	if not source_phone_layout.enabled or source_projection==null or not source_projection.is_enabled():return "手机界面布局未就绪，无法开始对局。"
	if not source_phone_layout.blockers.is_empty():return "手机界面布局校验失败："+str(source_phone_layout.blockers)
	if definitions.is_empty():return "卡牌集合为空，无法开始对局。"
	if not is_instance_valid(native_card_renderer):return "卡面渲染器未能创建。"
	var cache=native_card_renderer.texture_cache_controller
	if not is_instance_valid(cache):return "卡面缓存未能创建。"
	if not cache.enabled or not cache.auto_bake:return "卡面缓存或自动烘焙已停用，无法完成加载。"
	if not cache.errors.is_empty():return "卡面烘焙失败，详情已写入运行日志。"
	if not is_instance_valid(original_board_bridge):return "棋盘加载器未能创建。"
	return ""

func _fail_native_loading(message:String):
	if not native_loading_error.is_empty():return
	native_startup_timing.mark("loading_failed",{"message":message})
	native_loading_error=message
	if native_mac_spell_warmup != null:native_mac_spell_warmup.cancel()
	if native_mac_coin_warmup != null:native_mac_coin_warmup.cancel()
	if is_instance_valid(native_turn_banner):native_turn_banner.cancel_shader_warmup()
	native_banner_pending=false;native_initial_sounds.clear()
	if is_instance_valid(native_turn_banner):native_turn_banner.cancel_original()
	if is_instance_valid(world_canvas):world_canvas.visible=false
	if is_instance_valid(native_card_renderer):native_card_renderer.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(original_board_bridge):original_board_bridge.close()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	native_loading_error_layer=CanvasLayer.new();native_loading_error_layer.layer=100;add_child(native_loading_error_layer)
	var panel=ColorRect.new();panel.color=Color(0.055,0.055,0.065,1);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);native_loading_error_layer.add_child(panel)
	var label=Label.new();label.text="加载未完成\n\n"+message+"\n\n对局尚未开始。按 Esc 退出。";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if font!=null:label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",24);panel.add_child(label)
	push_error("Native loading failed: "+message)

func _advance_initial_loading(dt:float):
	if not native_loading_error.is_empty():return
	var progress=JSON.stringify([native_card_loader.built.size(),native_card_loader.active,native_card_loader.pending.size(),original_board_bridge.generation if is_instance_valid(original_board_bridge) else -1])
	var error=native_load_guard.check(Time.get_ticks_msec(),progress,_native_loading_problem())
	if not error.is_empty():_fail_native_loading(error);return
	native_load_frames+=1
	# Loading is not player turn time; do not charge wall-clock catch-up on release.
	if flow!=null:flow.clock_last_ms=Time.get_ticks_msec()
	_retire_native_renderers();_advance_native_card_load()
	var had_board_probe:=false
	if is_instance_valid(original_board_bridge):
		had_board_probe=is_instance_valid(original_board_bridge.probe)
		var board_advance_start:int=Time.get_ticks_usec() if native_startup_timing.enabled else 0
		original_board_bridge.advance(dt)
		if is_instance_valid(original_board_bridge.probe):native_startup_timing.once("board_probe_ready_observed",str(original_board_bridge.generation),{"created_this_advance":not had_board_probe,"advance_cpu_ms":(Time.get_ticks_usec()-board_advance_start)/1000.0 if native_startup_timing.enabled else 0.0})
	if native_card_loader.has_pending() or not is_instance_valid(original_board_bridge) or not is_instance_valid(original_board_bridge.probe):return
	if flow.mode=="normal" and flow.visuals.prepared_coin_assets.is_empty():
		# Let the board build and card render targets settle before preparing the
		# coin. No coin viewport or animation is created until opening deal.
		if not had_board_probe:return
		native_startup_timing.begin("coin_static_prepare_cpu")
		flow.visuals.prepare_source_coin_assets()
		native_startup_timing.end("coin_static_prepare_cpu")
	if not native_scene_warmup_complete:
		if not native_scene_warmup_pending:
			# The board and spatial targets render independently of the hidden
			# canvas. Let their first draw finish before advancing match clocks.
			native_scene_warmup_pending=true
			native_startup_timing.begin("scene_first_draw_wall")
			if is_instance_valid(spatial_scene):spatial_scene.sync_from_game()
			if is_instance_valid(native_transmission):native_transmission.sync()
			RenderingServer.frame_post_draw.connect(_finish_scene_warmup,CONNECT_ONE_SHOT)
		return
	if native_endgame_hero_warmup==null and EndgameHeroWarmup.enabled():
		native_endgame_hero_warmup=EndgameHeroWarmup.new()
	if native_endgame_hero_warmup!=null and not native_endgame_hero_warmup.advance(self):return
	if native_mac_spell_warmup == null and MacSpellWarmup.enabled():
		native_mac_spell_warmup = MacSpellWarmup.new()
	if native_mac_spell_warmup != null and not native_mac_spell_warmup.advance(self):return
	if native_mac_coin_warmup == null and MacCoinWarmup.enabled():
		native_mac_coin_warmup = MacCoinWarmup.new()
	if native_mac_coin_warmup != null and not native_mac_coin_warmup.advance(self):return
	if is_instance_valid(native_turn_banner) and not native_turn_banner.advance_shader_warmup(self):return
	native_startup_timing.begin("reveal_sync_cpu")
	native_initial_loading=false
	world_canvas.visible=true;world_canvas.queue_redraw()
	if native_banner_pending:
		native_banner_pending=false;_show_native_turn_banner()
	var sounds=native_initial_sounds.duplicate();native_initial_sounds.clear()
	for kind in sounds:play_sound(kind)
	native_startup_timing.end("reveal_sync_cpu")
	native_startup_timing.arm_frame_window("loading_gate_release",self)
	native_startup_timing.mark("loading_gate_released",{"world_visible":world_canvas.visible,"phase":str(flow.phase) if flow!=null else "","note":"CPU gate only; not proof of displayed frame or mulligan input readiness"})

func _finish_scene_warmup():
	native_scene_warmup_pending=false
	native_scene_warmup_complete=true
	native_startup_timing.end("scene_first_draw_wall")

func _on_card_texture_ready(key: String,texture: Texture2D,owner_renderer: Node):
	# A retired practice renderer may finish after normal mode has replaced it.
	if owner_renderer!=native_card_renderer:return
	native_startup_timing.once("card_texture_ready_signal",key)
	card_face_textures[key]=texture
	if is_instance_valid(native_transmission):native_transmission.sync()
	# Cache completion is asynchronous, including while game processing is paused.
	# Invalidate the actual display canvases, not only the now-empty game root.
	if is_instance_valid(world_canvas):world_canvas.queue_redraw()
	if is_instance_valid(spatial_post):spatial_post.queue_redraw()
	queue_redraw()

func _retire_native_renderers():
	for i in range(retired_native_renderers.size()-1,-1,-1):
		var entry=retired_native_renderers[i]
		entry.frames-=1
		if entry.frames<=0:
			if is_instance_valid(entry.renderer):entry.renderer.queue_free()
			retired_native_renderers.remove_at(i)

func _sync_native_card_costs():
	if not is_instance_valid(native_card_renderer):return
	for key in card_face_textures:
		# A previous mode may retain texture cache entries absent from current definitions.
		if not definitions.has(key):continue
		var cost=int(reference_hand_costs.get(key,definitions[key].cost))
		if native_cost_cache.get(key,-999)!=cost:
			native_card_renderer.update_cost(key,cost)
			native_cost_cache[key]=cost

func _setup_spatial_presentation():
	_ensure_card_face_textures()
	var composite_material:=ShaderMaterial.new()
	composite_material.shader=load("res://shaders/native_scene_composite.gdshader")
	world_canvas.material=composite_material
	spatial_view = SubViewport.new()
	spatial_view.name = "ClassicBoardSpatialObjects"
	spatial_view.size = board_render_target_size if source_projection!=null else render_target_size
	spatial_view.transparent_bg = true
	spatial_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(spatial_view)
	spatial_scene = load("res://scripts/classic_spatial.gd").new()
	spatial_view.add_child(spatial_scene)
	spatial_scene.setup(self, Vector2i(int(W), int(H)))
	native_transmission=load("res://scripts/native_combat_transmission.gd").new();add_child(native_transmission);native_transmission.setup(spatial_view,spatial_scene)
	var copy:=BackBufferCopy.new();copy.name="PreSpatialBackgroundCopy";copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;world_canvas.add_child(copy)
	spatial_post=Node2D.new();spatial_post.name="PostSpatialCanvas";spatial_post.material=native_transmission.make_composite_material();world_canvas.add_child(spatial_post)
	spatial_post.draw.connect(_draw_post_spatial)

func _load_portraits():
	masked_portraits.clear();raw_portraits.clear();missing_portrait_indices.clear()
	# Public original paintings; source and hashes are kept with the package.
	var ids = ["HERO_08","HERO_01","CS2_179","CS2_189","CS2_120","CS2_029","CS2_023","CS2_024","CS2_179","CS2_189","EX1_015","EX1_556","CS2_124","CS2_182","CS2_120","skele21","CS2_023","HERO_09","HERO_05","CS1h_001","DS1h_292","CS2_034","CS2_102","CS1_112","EX1_396","CS1_129","GAME_005","CS2_236","EX1_561","EX1_531","CS2_125","CS1_113","NEW1_034","CS2_172","CS2_200","CS2_186"]
	ids.append_array(preload("res://scripts/classic_flow_cards.gd").extra_portrait_ids())
	# Consumers only bind/draw these textures; no later texture updates occur.
	# Keep every indexed slot while sharing identical source-ID results.
	var by_id:Dictionary={}
	for id in ids:
		if by_id.has(id):
			var cached:Dictionary=by_id[id]
			if cached.missing:
				missing_portrait_indices.append(raw_portraits.size())
				push_warning("Missing original portrait: "+id)
			raw_portraits.append(cached.raw)
			continue
		var missing:=false
		var path = "res://assets/original_classic_v13/art/" + id + ".png"
		if not ResourceLoader.exists(path): path="res://assets/original_classic_v13/art/"+id+".webp"
		var cell: Image
		if ResourceLoader.exists(path): cell=(load(path) as Texture2D).get_image()
		else:
			missing=true
			missing_portrait_indices.append(raw_portraits.size())
			cell=Image.create(256,256,false,Image.FORMAT_RGBA8)
			cell.fill(Color("302739"))
			push_warning("Missing original portrait: "+id)

		cell.convert(Image.FORMAT_RGBA8)
		var raw := ImageTexture.create_from_image(cell)
		raw_portraits.append(raw)
		by_id[id]={"raw":raw,"missing":missing}

func _define_cards():
	# IDs and values are from HearthSim's archived client CardDefs, build 1.0.0.5834.
	definitions = {
		"CS2_179": {"name":"森金持盾卫士","cost":4,"atk":3,"hp":5,"art":8,"kind":"minion","keyword":"嘲讽","desc":["嘲讽"],"color":Color("749b94")},
		"CS2_189": {"name":"精灵弓箭手","cost":1,"atk":1,"hp":1,"art":9,"kind":"minion","keyword":"战吼","battlecry":"damage1","desc":["战吼：造成1点伤害。","可选择其他角色。"],"color":Color("92b272")},
		"EX1_015": {"name":"工程师学徒","cost":2,"atk":1,"hp":1,"art":10,"kind":"minion","keyword":"战吼","battlecry":"draw1","desc":["战吼：抽一张牌。"],"color":Color("d38eac")},
		"EX1_556": {"name":"麦田傀儡","cost":3,"atk":2,"hp":3,"art":11,"kind":"minion","keyword":"亡语","deathrattle":"skele21","desc":["亡语：召唤一个2/1的","损坏的傀儡。"],"color":Color("be995b")},
		"CS2_124": {"name":"狼骑兵","cost":3,"atk":3,"hp":1,"art":12,"kind":"minion","keyword":"冲锋","desc":["冲锋"],"color":Color("8ea4ac")},
		"CS2_182": {"name":"冰风雪人","cost":4,"atk":4,"hp":5,"art":13,"kind":"minion","keyword":"","desc":[],"color":Color("a8c9d7")},
		"CS2_120": {"name":"淡水鳄","race":"BEAST","race_name":"野兽","cost":2,"atk":2,"hp":3,"art":14,"kind":"minion","keyword":"","desc":[],"color":Color("73965d")},
		"skele21": {"name":"损坏的傀儡","cost":1,"atk":2,"hp":1,"art":15,"kind":"minion","keyword":"","token":true,"desc":[],"color":Color("ad865b")},
		"CS2_024": {"name":"寒冰箭","cost":2,"atk":0,"hp":0,"art":7,"kind":"spell","damage":3,"keyword":"冻结","desc":["造成3点伤害，并使","目标冻结。"],"color":Color("6aaedc")},
		"CS2_029": {"name":"火球术","cost":4,"atk":0,"hp":0,"art":5,"kind":"spell","damage":6,"keyword":"","desc":["造成6点伤害。"],"color":Color("e8894b")},
		"CS2_023": {"name":"奥术智慧","cost":3,"atk":0,"hp":0,"art":16,"kind":"spell","damage":0,"keyword":"","desc":["抽两张牌。"],"color":Color("9c79ce")}
	}
	if reference_fixture:
		# Fixture-only cards reconstruct the visible 2013 film state; not the playable 5834 pool.
		definitions.merge({
			"CS1_112":{"name":"Holy Nova","cost":5,"atk":0,"hp":0,"art":23,"kind":"spell","keyword":"","desc":["Deal 2 damage to all enemies.","Restore 2 Health to all friends."],"color":GOLD,"frame":"frame-spell-priest"},
			"EX1_396":{"name":"Mogu'shan Warden","cost":4,"atk":1,"hp":7,"art":24,"kind":"minion","keyword":"嘲讽","desc":["Taunt"],"color":GOLD},
			"CS1_129":{"name":"Inner Fire","cost":1,"atk":0,"hp":0,"art":25,"kind":"spell","keyword":"","desc":["Change a minion's Attack","to be equal to its Health."],"color":GOLD,"frame":"frame-spell-priest"},
			"GAME_005":{"name":"The Coin","cost":0,"atk":0,"hp":0,"art":26,"kind":"spell","keyword":"","desc":["Gain 1 Mana Crystal","this turn only."],"color":GOLD,"frame":"frame-spell-neutral"},
			"CS2_236":{"name":"Divine Spirit","cost":2,"atk":0,"hp":0,"art":27,"kind":"spell","keyword":"","desc":["Double a minion's Health."],"color":GOLD,"frame":"frame-spell-priest"},
			"EX1_561":{"name":"Alexstrasza","cost":9,"atk":8,"hp":8,"art":28,"kind":"minion","keyword":"","desc":["Battlecry: Set a hero's","remaining Health to 15."],"color":GOLD,"race_name":"Dragon"},
			"EX1_531":{"name":"Scavenging Hyena","cost":2,"atk":2,"hp":2,"art":29,"kind":"minion","keyword":"","desc":["Whenever a friendly Beast","dies, gain +2/+1."],"color":GOLD,"race_name":"Beast","frame":"frame-minion-hunter"},
			"CS2_125":{"name":"Ironfur Grizzly","cost":3,"atk":3,"hp":3,"art":30,"kind":"minion","keyword":"嘲讽","desc":["Taunt"],"color":GOLD,"race_name":"Beast"},
			"CS1_113":{"name":"Mind Control","cost":8,"atk":0,"hp":0,"art":31,"kind":"spell","keyword":"","desc":["Take control of an","enemy minion."],"color":GOLD,"frame":"frame-spell-priest"},
			"NEW1_034":{"name":"Huffer","cost":3,"atk":4,"hp":2,"art":32,"kind":"minion","keyword":"冲锋","desc":["Charge"],"color":GOLD,"race_name":"Beast","token":true}
		})
	for id in definitions: definitions[id].card_id=id

func start_match(mode: String = "practice", seat: int = -1, match_seed: int = -1):
	native_history_events.reset()
	if is_instance_valid(source_mana_controller):source_mana_controller.reset()
	source_mana_proposal_id=-1
	native_banner_pending=false;native_initial_sounds.clear()
	if mode=="menu":mode="normal" # v28 has no navigation menu.
	if flow!=null: flow.reset()
	if rules!=null: rules.reset()
	_define_cards()
	game_tied=false;help_visible=false;settings_visible=false
	SoundManager.stop_all_sfx()
	board_gesture=false
	if is_instance_valid(original_board_bridge):original_board_bridge.reset_for_match()
	_audio_action_sequence = 0; _audio_selected_attack_id = -1; _audio_combat_pair.clear(); _audio_spell_preview.clear(); _audio_resolution.clear(); _audio_scope_sides.clear()
	# Kill in-flight callbacks before replacing state: no old projectile may hit a new game.
	for tween in get_tree().get_processed_tweens(): tween.kill()
	indicator_time = 0.0
	won = false; ai_timer = 0.0; ai_step = 0; pressed_card = -1; mouse_down = false
	toast_time = 0; hit_flash = [0.0, 0.0]; shake = 0; last_hover = -1
	if is_instance_valid(native_summon):native_summon.cancel_all()
	if is_instance_valid(native_combat):native_combat.cancel_all()
	if is_instance_valid(native_screen_effects):native_screen_effects.clear()
	if is_instance_valid(native_death):native_death.clear()
	if is_instance_valid(native_damage):native_damage.clear()
	if is_instance_valid(native_targeting):native_targeting.clear("restart")
	if is_instance_valid(native_status):native_status.clear("restart")
	if is_instance_valid(native_highlight):native_highlight.clear("restart")
	if is_instance_valid(native_endgame):native_endgame.clear()
	camera_shake.clear();shake_offset=Vector2.ZERO
	if is_instance_valid(world_canvas):world_canvas.position=presentation_offset
	combat_replay.cancel()
	staged_cards.clear(); impacts.clear(); death_ghosts.clear(); event_trace.clear(); button_travel=0
	pending_battlecry.clear();death_queue.clear();fatigue=[0,0];hero_frozen=[false,false];side_turn=[1,0];hero_thaw_turn=[0,0]
	rejections.clear(); interaction_state=Interaction.IDLE;tracked_drag=-1;spell_aim_latched=false;preview_index=-1;target_feedback={}
	cards.clear(); allies.clear(); enemies.clear(); particles.clear(); floats.clear(); ripples.clear(); bolts.clear(); recent_log.clear()
	health = [30, 30]; mana = 4; max_mana = 4; enemy_mana = 4; enemy_max_mana = 4
	turn = 1; player_turn = true; busy = false; game_over = false; power_used = false
	drag_index = -1; selected_unit = -1; targeting_power = false; hover_card = -1; opening = 1.0
	turn_clock = 75.0; tutorial_hint = true; banner_time = 1.5; banner = "你的回合"; banner_sub = "欢迎来到酒馆 · 拖出卡牌，开始对决"
	deck = ["EX1_015","EX1_556","CS2_024","CS2_189","CS2_029","CS2_182","CS2_124","CS2_023","CS2_179","CS2_120","CS2_029","CS2_124","EX1_556","CS2_024","EX1_015","CS2_179","CS2_029","CS2_120","CS2_124","CS2_182"]
	enemy_deck = ["EX1_015","EX1_556","CS2_124","CS2_179","CS2_182","CS2_024","CS2_120","CS2_179","CS2_124","EX1_556","CS2_029","CS2_189","CS2_120","CS2_182","CS2_179","CS2_124","CS2_024","CS2_029"]
	enemy_hand = ["CS2_189", "CS2_120", "CS2_179", "CS2_024"]
	for key in ["CS2_189", "EX1_015", "EX1_556", "CS2_179", "CS2_024", "CS2_124", "CS2_029"]: _add_card(key, false)
	var a = _new_unit("CS2_120", 0, Vector2(710, FRIEND_Y)); a.ready = true; a.summoning_sick = false; allies.append(a)
	var b = _new_unit("CS2_189", 0, Vector2(890, FRIEND_Y)); b.ready = true; b.summoning_sick = false; allies.append(b)
	var c = _new_unit("CS2_179", 1, Vector2(710, ENEMY_Y)); c.ready = false; c.summoning_sick = false; enemies.append(c)
	var d = _new_unit("CS2_120", 1, Vector2(890, ENEMY_Y)); d.ready = false; d.summoning_sick = false; enemies.append(d)
	_log("练习对局", "经典版 1.0.0.5834 · 4费练习局", GOLD)
	if is_instance_valid(native_turn_banner):native_turn_banner.cancel_original()
	if mode=="normal": flow.begin_normal(seat,match_seed)
	elif mode=="menu": flow.show_menu()
	else:
		play_sound("turn"); play_sound("mana_refresh")
		_show_native_turn_banner()

func restart_match():
	start_match(flow.mode if flow.mode!="menu" else "normal",flow.seat_choice)

func show_match_menu():
	start_match("normal") # Legacy caller compatibility; never enter a menu phase.

func _begin_normal_turn(side: int):
	if game_over: return
	player_turn=side==0;side_turn[side]+=1
	turn=maxi(side_turn[0],side_turn[1])
	if side==0: power_used=false
	_clear_temporary_mana(side);flow.begin_turn()
	if side==0:
		max_mana=mini(10,max_mana+1);mana=max_mana
	else:
		enemy_max_mana=mini(10,enemy_max_mana+1);enemy_mana=enemy_max_mana
	for u in (allies if side==0 else enemies): u.summoning_sick=false;u.attacks_used=0;u.ready=not u.frozen
	rules.begin_turn(side)
	if game_over: return
	_draw_cards(1,side)
	banner="你的回合" if side==0 else "对手回合"
	banner_sub="抽一张牌 · 法力水晶已充满";banner_time=2.1
	if is_instance_valid(native_turn_banner):
		if side==0:_show_native_turn_banner()
		else:native_turn_banner.cancel_original()
	ai_step=0;ai_timer=1.65
	if side==0: play_sound("turn");play_sound("mana_refresh")

func _new_unit(key: String, side: int, pos: Vector2) -> Dictionary:
	var d = definitions[key]
	var unit = {"id": unit_uid, "key": key, "side": side, "atk": d.atk, "hp": d.hp, "max_hp": d.hp, "pos": pos, "target": pos, "ready": d.keyword == "冲锋", "summoning_sick": d.keyword != "冲锋", "attacks_used":0, "indicator_phase": fposmod(unit_uid * 2.39996323, TAU), "frozen": false, "thaw_turn":0, "flash": 0.0, "scale": 1.0, "rotation": 0.0, "animating": false, "appear": 0.0, "dead": false, "lift": 0.0, "hidden": false, "charge_announced":false, "charge_ready_at":-10.0}
	unit_uid += 1
	return unit

func _add_card(key: String, animate: bool = true, source_deck_count:int=-1, source_ticket:int=-1):
	if cards.size() >= 10:
		show_toast("手牌已满！卡牌被烧毁")
		# Retain the old four RNG draws per cosmetic particle so seeded rule
		# outcomes stay unchanged, without rendering the invented orange burst.
		for _unused in range(24):
			rng.randf();rng.randf_range(35,260);rng.randf_range(0.3,0.85);rng.randf_range(2,6)
		if flow!=null: flow.player_burn(key,source_deck_count,source_ticket)
		return
	var waiting=cards.filter(func(card):return card.get("drawing",false)).size()
	var announce_now=waiting==0 and not preload("res://scripts/native_hand_burn_timeline.gd").blocks_draw(self,0,source_ticket)
	var p = Vector2(1392, 596) if animate else Vector2(800, 1100)
	cards.append({"source_presentation_id":source_card_uid,"key": key, "pos": p, "angle": 0.4 if animate else 0.0, "scale": 0.48 if animate else 0.92, "born": elapsed, "spring": Vector2.ZERO, "drawing": animate, "draw_t": -1.60*waiting if animate else 0.0, "lift": 0.0, "announced": announce_now})
	source_card_uid+=1
	if animate and announce_now: play_sound("draw"); _event("draw_depart")

func _process(dt):
	var profile_started: int=Time.get_ticks_usec() if profile_frame_stages or android_match_benchmark!=null else 0
	var stage_started: int=profile_started
	if profile_frame_stages:last_frame_stages={}
	if face_render_mode:
		if profile_frame_stages:last_frame_stages["total_usec"]=Time.get_ticks_usec()-profile_started
		return
	_refresh_render_resolution()
	if native_initial_loading:
		_advance_initial_loading(maxf(dt,0.0))
		if profile_frame_stages:
			stage_started=_profile_frame_stage("initial_loading",stage_started)
			last_frame_stages["total_usec"]=Time.get_ticks_usec()-profile_started
		if android_match_benchmark!=null:android_match_benchmark.game_usec=Time.get_ticks_usec()-profile_started
		return
	_sync_native_card_costs()
	_retire_native_renderers()
	indicator_time += maxf(dt, 0.0)
	var unscaled_visual_delta: float=maxf(dt,0.0)
	var visual_delta: float=unscaled_visual_delta*(native_endgame.visual_time_scale() if is_instance_valid(native_endgame) else 1.0)
	source_visual_delta=visual_delta
	if source_projection!=null and source_projection.is_enabled():
		source_phone_layout.refresh();source_projection=source_phone_layout.context
		camera_shake.advance(visual_delta);camera_shake.present_source_camera(source_projection)
		source_phone_layout.reproject()

	if profile_frame_stages:stage_started=_profile_frame_stage("initial_setup",stage_started)
	if is_instance_valid(original_board_bridge):
		original_board_bridge.set_audio(sound_enabled and SoundManager.sfx_enabled)
		original_board_bridge.advance(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("board_advance",stage_started)
	dt = minf(dt, 0.05)
	elapsed += dt; demo_clock += dt; opening = maxf(0, opening - dt * 1.1)
	if _phone_hand_enabled() and DisplayServer.get_name()=="headless":
		var opposing_logic=_source_opposing_hand()
		if is_instance_valid(opposing_logic) and opposing_logic.logical_only_mode:opposing_logic.advance_draws()
	# ScreenTouch/ScreenDrag are authoritative until a real desktop mouse event.
	# Polling the mouse here can overwrite the active finger between events and
	# cancel a pressed end-turn button (mouse emulation may be disabled/stale).
	if not demo_mode and not scripted_pointer and not touch_input_active: _update_screen_pointer(get_global_mouse_position())
	banner_time = maxf(0, banner_time - dt)
	toast_time = maxf(0, toast_time - dt)
	shake = maxf(0, shake - dt * 22)
	# Preserve the two legacy cosmetic RNG draws even with zero amplitude.
	rng.randf_range(-shake,shake);rng.randf_range(-shake*0.5,shake*0.5)
	shake_offset=Vector2.ZERO
	for i in range(2): hit_flash[i] = maxf(0, hit_flash[i] - dt * 3)
	for i in range(4): corner_pulse[i] = maxf(0, corner_pulse[i] - dt * 0.8)
	if profile_frame_stages:stage_started=_profile_frame_stage("frame_clock_input",stage_started)
	flow.tick(dt)
	flow.tick_clock(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("flow",stage_started)
	_update_interaction()
	_update_hover()
	_sync_source_mana_proposal()
	_update_hand(dt)
	_update_units(dt)
	if profile_frame_stages:stage_started=_profile_frame_stage("interaction_hand_units",stage_started)
	combat_replay.advance(dt)
	if profile_frame_stages:stage_started=_profile_frame_stage("combat_replay",stage_started)
	if is_instance_valid(native_damage):native_damage.advance(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("damage_advance",stage_started)
	if is_instance_valid(native_summon):
		native_summon.advance(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("summon",stage_started)
	if is_instance_valid(native_combat):
		native_combat.advance(visual_delta)
		if is_instance_valid(native_combat.effect_player):native_combat.effect_player.sync_projection()
	if profile_frame_stages:stage_started=_profile_frame_stage("combat",stage_started)
	if is_instance_valid(native_endgame):
		native_endgame.advance(unscaled_visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("endgame_advance",stage_started)
	_update_effects(dt)
	if profile_frame_stages:stage_started=_profile_frame_stage("effects",stage_started)
	if not player_turn and not busy and not game_over and flow.accepts_actions():
		ai_timer -= dt
		if ai_timer <= 0: _ai_action()
	if demo_mode: _demo()
	if state_out != "" and elapsed - last_state_write > 0.3:
		last_state_write = elapsed
		var f = FileAccess.open(state_out, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(get_state()))
	# All request producers have updated. Sample one main-camera transform once.
	var previous_camera_offset:Vector2=world_canvas.position
	if source_projection==null:camera_shake.advance(visual_delta)
	world_canvas.position=presentation_offset+camera_shake.screen_offset
	# Reproject geometry only: camera motion must not start/cancel a spell
	# preview, replay hover audio or perform another input state transition.
	if not demo_mode and not scripted_pointer and world_canvas.position!=previous_camera_offset:
		_update_screen_pointer(screen_pointer);_update_interaction(false);_update_hover(false)
	if profile_frame_stages:stage_started=_profile_frame_stage("tail_logic_camera",stage_started)
	if is_instance_valid(spatial_scene): spatial_scene.sync_from_game()
	if profile_frame_stages:stage_started=_profile_frame_stage("spatial_sync",stage_started)
	if is_instance_valid(native_targeting):native_targeting.sync_from_game(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("targeting_sync",stage_started)
	if is_instance_valid(native_status):native_status.sync_from_game(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("status_sync",stage_started)
	if is_instance_valid(native_highlight):native_highlight.sync_from_game(visual_delta)
	if profile_frame_stages:stage_started=_profile_frame_stage("highlight_sync",stage_started)
	if is_instance_valid(native_damage):native_damage.sync()
	if profile_frame_stages:stage_started=_profile_frame_stage("damage_sync",stage_started)
	if is_instance_valid(native_death):native_death.sync()
	if profile_frame_stages:stage_started=_profile_frame_stage("death_sync",stage_started)
	if is_instance_valid(native_endgame):native_endgame.sync()
	if profile_frame_stages:stage_started=_profile_frame_stage("endgame_sync",stage_started)
	if is_instance_valid(native_transmission):native_transmission.sync()
	if profile_frame_stages:stage_started=_profile_frame_stage("transmission_sync",stage_started)
	if is_instance_valid(native_screen_effects):native_screen_effects.sync(native_combat.effect_player.effects,spatial_scene.camera)
	if profile_frame_stages:stage_started=_profile_frame_stage("screen_effects_sync",stage_started)
	if is_instance_valid(spatial_post):spatial_post.queue_redraw()
	world_canvas.queue_redraw();fixed_canvas.queue_redraw()
	queue_redraw()
	if profile_frame_stages:
		stage_started=_profile_frame_stage("redraw_requests",stage_started)
		last_frame_stages["total_usec"]=Time.get_ticks_usec()-profile_started
	if android_match_benchmark!=null:android_match_benchmark.game_usec=Time.get_ticks_usec()-profile_started

# Opt-in CPU timings; preserve original _process operation order.
func _profile_frame_stage(label:String,started:int)->int:
	var now:=Time.get_ticks_usec()
	last_frame_stages[label]=now-started
	return now

func is_pointer_hover_allowed() -> bool:
	return not touch_input_active or active_touch_index >= 0 or scripted_pointer or demo_mode

func _update_hover(emit_hover_audio:bool=true):
	hover_card = -1; hover_unit = -1; hover_corner = -1
	if not is_pointer_hover_allowed():
		last_hover = -1
		return
	if help_visible or settings_visible or game_over or not flow.accepts_actions(): return
	if drag_index < 0 and selected_unit < 0 and not targeting_power and pending_battlecry.is_empty() and (player_turn or _phone_hand_enabled()):
		if _phone_hand_enabled():
			hover_card=native_phone_hand.hit_card(pointer)
			if native_phone_hand.touched_slot>=0: hover_card=native_phone_hand.focus
			# Desktop keeps click-to-expand and click/drag-to-pick-up, but an
			# expanded hand also previews on mouse hover. Touch still owns its
			# original press/slide selection and must not inherit a stale cursor.
			elif not touch_input_active and not mouse_down:
				if hover_card<0 and native_phone_hand.focus>=0 and native_phone_hand.focus<cards.size():
					var focused=cards[native_phone_hand.focus]
					if focused.has("source_phone_pose") and Geometry2D.is_point_in_polygon(pointer,native_phone_hand.card_polygon(focused.source_phone_pose,definitions[focused.key].kind)):
						hover_card=native_phone_hand.focus
				native_phone_hand.set_focus(hover_card if native_phone_hand.enlarged else -1)
		else:
			# Anchor the hover to the resting fan, so a lifted card does not lose
			# the cursor and oscillate as its face leaves the bottom-edge hit box.
			if pointer.y >= 790 and not cards.is_empty():
				# Resolve the visible overlap from front to back in resting-card local
				# coordinates. Nearest-center selection fails on the rotated source fan.
				for i in range(cards.size()-1,-1,-1):
					var pose=_resting_hand_pose(i,cards.size())
					var local=(pointer-pose.pos).rotated(-pose.angle)/pose.scale
					if Rect2(Vector2(-78,-116)*CARD_FACE_SCALE+CARD_FACE_OFFSET,Vector2(156,232)*CARD_FACE_SCALE).has_point(local):
						if not cards[i].get("drawing",false) and not cards[i].get("returning",false): hover_card=i;break
			# Above the fan, preserve hover while the cursor is over its readable face.
			if hover_card < 0 and last_hover >= 0 and last_hover < cards.size():
				var card = cards[last_hover]
				if not card.get("returning",false) and Rect2(card.pos - CARD_SIZE * card.scale * 0.5, CARD_SIZE * card.scale).has_point(pointer): hover_card = last_hover
			if hover_card < 0:
				var best = 99999.0
				for i in range(cards.size()):
					var c = cards[i]
					if not c.get("drawing",false) and not c.get("returning",false) and Rect2(c.pos - CARD_SIZE * c.scale * 0.5, CARD_SIZE * c.scale).has_point(pointer):
						var distance = absf(pointer.x - c.pos.x)
						if distance < best: best = distance; hover_card = i
	if hover_card != last_hover:
		if hover_card >= 0 and emit_hover_audio: play_sound("hover")
		last_hover = hover_card
	for u in allies + enemies:
		if (pointer - u.pos).length() < 70: hover_unit = u.id
	# Original colliders replace the four synthetic corner circles.
	hover_corner=-1

func _resting_hand_pose(index: int, count: int) -> Dictionary:
	var off=float(index)-float(count)*0.5
	var nine=count==9
	var spacing=47.6 if nine else minf(64.0,440.0/maxf(count,1))
	var cx=794.7 if nine else 796.3
	var by=858.9 if nine else 851.2
	var linear=4.04 if nine else 0.87
	var arc=2.68 if nine else 3.38
	return {"pos":Vector2(cx+off*spacing,by+linear*off+arc*off*off),"angle":off*0.121,"scale":0.74}

func _update_hand(dt):
	if _phone_hand_enabled():
		_update_source_phone_hand(dt);return
	var n = cards.size()
	for i in range(n):
		var c = cards[i]
		var pose=_resting_hand_pose(i,n)
		var p: Vector2=pose.pos
		var angle: float=pose.angle
		var scale_to: float=pose.scale
		if hover_card >= 0:
			if i == hover_card:
				p.y = 678; angle = 0.0; scale_to = 1.88
				p.x += 3.4*(float(i)-float(n)*0.5)-3.5
			else:
				p.x += -36 if i < hover_card else 36
		if drag_index == i:
			if source_held_motion.game==null:source_held_motion.setup(self)
			# Original held position is the ray hit, never the old positional spring.
			# Source HandleUpdateWhileHoldingCard switches to target-arrow/play-spell
			# handling instead of PositionHeldCard when target mode is activated.
			if interaction_state!=Interaction.SPELL_AIM:source_held_motion.apply(c,pointer,dt)
			continue
		if c.get("returning",false):
			c.return_t += dt
			var hold = 0.20 if c.return_rejected else 0.0
			if c.return_t < hold:
				c.pos = c.return_origin + Vector2(sin(c.return_t * 75.0) * 9.0 * (1.0-c.return_t/hold),0)
				c.angle = c.return_angle + sin(c.return_t * 65.0) * 0.035
			else:
				var t = clampf((c.return_t-hold)/0.43,0,1)
				var ease = 1.0-pow(1.0-t,3)
				c.pos = c.return_origin.lerp(p,ease) + Vector2(0,-sin(t*PI)*28)
				c.angle = lerpf(c.return_angle,angle,ease)
				c.scale = lerpf(c.return_scale,scale_to,ease)
				c.lift = lerpf(45.0,0.0,ease)
				if t >= 1.0:
					c.returning=false;c.spring=Vector2.ZERO;_event("card_return_seated")
			continue
		if c.get("drawing",false):
			c.draw_t += dt
			var t=c.draw_t
			var deck_pos=Vector2(1341,540)
			var show_pos=Vector2(1145,475)
			if t<0:
				c.pos=deck_pos;c.scale=0.48;c.lift=0;continue
			if not c.get("announced",true):
				c.announced=true;play_sound("draw");_event("draw_depart")
			if t<0.50:
				var v=1-pow(1-t/0.50,3)
				c.pos=deck_pos.lerp(show_pos,v)+Vector2(0,-sin(v*PI)*45)
				c.scale=lerpf(0.48,1.23,v); c.angle=lerpf(0.12,-0.13,v); c.lift=lerpf(0,65,v)
			elif t<1.50:
				c.pos=show_pos; c.scale=1.23; c.angle=-0.13; c.lift=65
			elif t<2.0:
				var v=(t-1.50)/0.50
				var ease=v*v*(3-2*v)
				c.pos=show_pos.lerp(p,ease)+Vector2(-sin(v*PI)*85,-sin(v*PI)*55)
				c.scale=lerpf(1.23,0.92,ease);c.angle=lerpf(-0.13,angle,ease);c.lift=lerpf(65,0,ease)
			else:
				c.drawing=false; c.spring=Vector2.ZERO; _event("draw_seated")
			continue
		c.lift=lerpf(c.get("lift",0.0),55.0 if drag_index==i else (28.0 if hover_card==i else 0.0),1-exp(-dt*14))
		if hover_card == i and drag_index != i:
			c.pos = c.pos.lerp(p,1-exp(-dt*45)); c.angle = lerpf(c.angle,angle,1-exp(-dt*45)); c.scale = lerpf(c.scale,scale_to,1-exp(-dt*45)); c.spring=Vector2.ZERO
			continue
		# Critically damped spring makes cards feel held and weighted.
		var acceleration = (p - c.pos) * 150 - c.spring * 20
		c.spring += acceleration * dt
		c.pos += c.spring * dt
		c.angle = lerpf(c.angle, angle, 1 - exp(-dt * 18))
		c.scale = lerpf(c.scale, scale_to, 1 - exp(-dt * 14))

func _source_opposing_hand():
	if not _phone_hand_enabled():return null
	if is_instance_valid(spatial_scene) and is_instance_valid(spatial_scene.phone_opposing_hand):return spatial_scene.phone_opposing_hand
	if DisplayServer.get_name()!="headless":return null
	if not is_instance_valid(source_logic_opposing_hand):
		source_logic_opposing_hand=preload("res://scripts/native_phone_opposing_hand.gd").new()
		source_logic_opposing_hand.name="SourceLogicalOpposingHand";add_child(source_logic_opposing_hand)
		source_logic_opposing_hand.setup(self,true)
	return source_logic_opposing_hand

func _phone_hand_enabled()->bool:
	var projection=get("source_projection")
	return projection!=null and projection.is_enabled() and get("native_phone_hand")!=null

func _publish_source_hand_pose(card:Dictionary,pose:Dictionary):
	card.source_phone_pose=pose
	card.source_world_position=pose.position;card.source_world_scale=pose.scale;card.source_world_euler=pose.rotation
	card.source_world_rotation=native_phone_hand.source_basis(pose.rotation).get_rotation_quaternion()
	card.pos=native_phone_hand.project(pose.position)
	card.spring=Vector2.ZERO;card.lift=0.0

func _update_source_phone_hand(dt:float):
	var draw_helper=preload("res://scripts/native_phone_draw.gd")
	draw_helper.advance(self,dt)
	var source_count=draw_helper.layout_count(cards)
	native_phone_hand.advance(dt)
	if mouse_down and native_phone_hand.touched_slot>=0:
		native_phone_hand.touch_age+=dt
		_update_touch_hand_preview(screen_pointer)
	elif native_phone_hand.touched_slot>=0:native_phone_hand.release_touch()
	for i in cards.size():
		var card:Dictionary=cards[i]
		if card.get("drawing",false) and card.get("source_draw_phase","")!="seat":
			continue # Source flight owns pose; queued/unregistered cards stay hidden.
		card.source_phone_hidden=false
		if not pending_battlecry.is_empty() and i==int(pending_battlecry.index):
			# Keep the provisionally placed card on the board until target commit
			# or cancel. Ordinary hand layout must not pull it back each frame.
			_publish_source_hand_pose(card,pending_battlecry.source_phone_pose)
		elif i==drag_index:
			if source_held_motion.game==null:source_held_motion.setup(self)
			var pose:Dictionary=card.get("source_phone_pose",native_phone_hand.source_pose(i,cards.size())).duplicate(true)
			if interaction_state!=Interaction.SPELL_AIM:
				var hit=source_held_motion.hit(pointer)
				if not hit.is_empty():pose.position=hit.source_world
			card.source_grab_age=float(card.get("source_grab_age",0.0))+dt
			var start_scale:Vector3=card.get("source_phone_grab_scale",pose.scale)
			pose.scale=Vector3(source_held_motion.source_scale_at(start_scale.x,card.source_grab_age),source_held_motion.source_scale_at(start_scale.y,card.source_grab_age),source_held_motion.source_scale_at(start_scale.z,card.source_grab_age))
			if card.has("source_phone_rotator"):
				var tilt:Vector2=card.source_phone_rotator.sample(pose.position,dt)
				pose.rotation=card.source_phone_grab_rotation+Vector3(tilt.x,0,tilt.y)
			_publish_source_hand_pose(card,pose)
		else:
			var pose:Dictionary=native_phone_hand.sample(i,source_count,float(card.get("source_draw_seat_step",dt)))
			card.erase("source_draw_seat_step")
			_publish_source_hand_pose(card,pose)
			if card.get("returning",false) and card.source_phone_transition.age>=card.source_phone_transition.duration:
				card.returning=false;_event("card_return_seated")

func _update_units(dt):
	if source_projection!=null and source_projection.is_enabled():
		source_phone_layout.update_units(source_visual_delta)
		PLAYER_HERO=source_phone_layout.snapshot.items.friendly_hero.center
		ENEMY_HERO=source_phone_layout.snapshot.items.opposing_hero.center
		POWER_POS=source_phone_layout.snapshot.items.friendly_power.center
		return
	for side in [allies, enemies]:
		var n = side.size()
		for i in range(n):
			var u = side[i]
			var y = FRIEND_Y if u.side == 0 else ENEMY_Y
			var pos = Vector2(800 + (i - (n - 1) * 0.5) * minf(118, 900.0 / maxf(n, 1)), y)
			if interaction_state == Interaction.PLACEMENT_PREVIEW and u.side == 0:
				var gap = preview_index
				pos.x = 800 + (i - n * 0.5) * minf(118, 900.0 / maxf(n + 1, 1))
				if i >= gap: pos.x += minf(118, 900.0 / maxf(n + 1, 1))
			u.target = pos
			if not u.animating: u.pos = u.pos.lerp(pos, 1 - exp(-dt * 11))
			u.flash = maxf(0, u.flash - dt * 4)
			u.appear = minf(1, u.appear + dt * 4)
			if not u.animating and not u.has("native_combat_scale"): u.scale = lerpf(u.scale, 1.04 if hover_unit == u.id else 1.0, 1 - exp(-dt * 12))

func _update_effects(dt):
	button_travel=flow.visuals.button_press_depth*2.2
	for collection in [impacts,death_ghosts,rejections]:
		for i in range(collection.size()-1,-1,-1):
			collection[i].life-=dt
			if collection[i].life<=0: collection.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]; p.life -= dt; p.p += p.v * dt; p.v.y += p.gravity * dt; p.v *= pow(0.985, dt * 60)
		if p.life <= 0: particles.remove_at(i)
	for i in range(floats.size() - 1, -1, -1):
		floats[i].life -= dt
		if floats[i].life <= 0: floats.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].life -= dt
		if ripples[i].life <= 0: ripples.remove_at(i)
	for i in range(bolts.size() - 1, -1, -1):
		bolts[i].life -= dt
		if bolts[i].life <= 0: bolts.remove_at(i)

func _unhandled_input(event):
	if native_initial_loading:
		if not native_loading_error.is_empty() and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:SoundManager.request_shutdown()
		get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if help_visible: help_visible = false
				elif settings_visible: settings_visible = false
				else: cancel_interaction()
			KEY_SPACE:
				if not help_visible and not settings_visible: end_turn()
			KEY_H: show_toast("Space 结束回合 · M 音效 · B 音乐 · +/- 音乐音量 · [/] 音效音量")
			KEY_M: sound_enabled = not sound_enabled; SoundManager.set_sfx_enabled(sound_enabled); show_toast("音效："+("开启" if sound_enabled else "静音"))
			KEY_B: SoundManager.set_music_enabled(not SoundManager.music_enabled); show_toast("音乐："+("开启" if SoundManager.music_enabled else "静音"))
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: SoundManager.set_music_volume(SoundManager.music_volume+0.1);show_toast("音乐音量 %d%%" % roundi(SoundManager.music_volume*100))
			KEY_MINUS, KEY_KP_SUBTRACT: SoundManager.set_music_volume(SoundManager.music_volume-0.1);show_toast("音乐音量 %d%%" % roundi(SoundManager.music_volume*100))
			KEY_BRACKETLEFT: SoundManager.set_sfx_volume(SoundManager.sfx_volume-0.1);show_toast("音效音量 %d%%" % roundi(SoundManager.sfx_volume*100))
			KEY_BRACKETRIGHT: SoundManager.set_sfx_volume(SoundManager.sfx_volume+0.1);show_toast("音效音量 %d%%" % roundi(SoundManager.sfx_volume*100))
			KEY_R:
				if game_over: restart_match()
			KEY_F12: save_screenshot()
		return
	if event is InputEventScreenTouch:
		touch_input_active = true
		if event.pressed:
			if active_touch_index >= 0: return
			active_touch_index = event.index
			touch_press_window_pos = _touch_window_position(event.position)
			_update_screen_pointer(event.position)
			mouse_down = true
			_update_hover(); _pointer_press()
		elif event.index == active_touch_index:
			_update_screen_pointer(event.position)
			mouse_down = false
			if event.canceled:
				if flow!=null:flow.visuals.button_pressed=false
				cancel_interaction()
			else: _pointer_release()
			active_touch_index = -1
			hover_card = -1; last_hover = -1; hover_unit = -1; hover_corner = -1
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if event.index != active_touch_index: return
		_update_screen_pointer(event.position)
		_update_touch_hand_preview(event.position)
		if mouse_down and pressed_card >= 0 and drag_index < 0 and _touch_card_grab_allowed(event.position):
			_begin_card_drag(pressed_card)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		# Godot may also emit a synthetic mouse event for the same finger.
		if event.device == InputEvent.DEVICE_ID_EMULATION or active_touch_index >= 0: return
		# Android must never inherit a stale desktop cursor/hover after release.
		if OS.has_feature("android") or OS.has_feature("ios"): return
		touch_input_active = false
	if event is InputEventMouseMotion:
		if not scripted_pointer: _update_screen_pointer(event.position)
		if mouse_down and pressed_card >= 0 and drag_index < 0 and _gesture_pointer().distance_to(press_screen_pos) > 7:
			_begin_card_drag(pressed_card)
	if event is InputEventMouseButton:
		if not scripted_pointer: _update_screen_pointer(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_interaction(); return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		mouse_down = event.pressed
		if event.pressed:
			_update_hover();_pointer_press()
		else: _pointer_release()

func _update_touch_hand_preview(viewport_position: Vector2):
	if _phone_hand_enabled():
		if not mouse_down or drag_index>=0 or native_phone_hand.touched_slot<0:return
		if not touch_input_active:return # Mouse selection is fixed at press; motion starts drag.
		if not native_phone_hand.enlarged and native_phone_hand.mini_hand_play_enabled and native_phone_hand.touch_age<=0.10000000149011612:return
		var slot:int=native_phone_hand.update_touch(_touch_window_position(viewport_position))
		hover_card=slot
		if slot>=0 and slot!=pressed_card:
			pressed_card=slot;touch_press_window_pos.y=_touch_window_position(viewport_position).y
		return
	if not mouse_down or pressed_card < 0 or drag_index >= 0: return
	# Source HandleUpdateWhileLeftMouseButtonIsDown IL00bc checks the current
	# hand stand-in before its movement thresholds. A changed non-null preview
	# resets only down.y; a subsequent upward grab takes that preview card.
	# Existing fan/face hit tests supply the compatibility stand-in here.
	_update_hover(false)
	if hover_card >= 0 and hover_card != pressed_card:
		pressed_card = hover_card
		touch_press_window_pos.y = _touch_window_position(viewport_position).y

func _touch_window_position(viewport_position: Vector2) -> Vector2:
	# Godot already inverse-stretches input into viewport coordinates. Restore
	# window pixels before applying Unity Input.mousePosition thresholds.
	# This is NOT board coordinates, DPI normalization or physical-panel pixels.
	return get_viewport().get_stretch_transform() * viewport_position

func _touch_card_grab_allowed(viewport_position: Vector2) -> bool:
	var delta := _touch_window_position(viewport_position) - touch_press_window_pos
	# Original HandleUpdateWhileLeftMouseButtonIsDown rectangular deadzone.
	if absf(delta.x) < 20.0 and absf(delta.y) < 20.0: return false
	# Original phone/tablet MIN_GRAB_Y: Unity positive Y points up.
	return -delta.y > 80.0

func _gesture_pointer()->Vector2:
	return board_to_screen(pointer) if scripted_pointer or demo_mode else screen_pointer

func _pointer_press():
	board_gesture=false
	if help_visible or settings_visible:return
	press_pos = pointer;press_screen_pos=_gesture_pointer()
	if flow.pointer_press(): return
	if game_over:
		if is_instance_valid(native_endgame):native_endgame.request_continue()
		return # Original result Death transition then the existing no-menu restart.
	if drag_index >= 0:return
	if selected_unit >= 0 or targeting_power or not pending_battlecry.is_empty():
		_resolve_target(pointer); return
	if busy or not flow.accepts_actions():
		if flow.accepts_actions():_try_original_board_press()
		return
	# Phone hand stand-ins are in front of the board actors. Claim the touch
	# before overlapping hero-power/end-turn hitboxes can receive it.
	if _phone_hand_enabled():
		if hover_card >= 0:
			if not native_phone_hand.enlarged and not native_phone_hand.mini_hand_play_enabled:return
			native_phone_hand.begin_touch(hover_card,_touch_window_position(screen_pointer))
			pressed_card=hover_card
			if player_turn and definitions[cards[hover_card].key].cost > mana: show_toast("法力值不足"); play_sound("error")
			return
		# Source HandleLeftMouseDown -> HidePhoneHand on a non-hand press;
		# HidePhoneHand does not interrupt the enlargement transition.
		if native_phone_hand.enlarged and native_phone_hand.enlarging_remaining<=0:
			native_phone_hand.set_enlarged(false)
	# Browsing the phone hand does not grant permission to play out of turn.
	# Dragging remains independently guarded by _begin_card_drag.
	if not player_turn:
		_try_original_board_press()
		return
	if flow.visuals.press_button(): return
	if (source_phone_layout.contains("friendly_power",pointer) if _phone_hand_enabled() else (pointer - Vector2(948, 690)).length() < 55):
		if power_used: show_toast("本回合已使用英雄技能"); return
		if mana < 2: show_toast("法力值不足"); play_sound("error"); return
		if hero_classes[0]=="WARLOCK":
			_spend_mana(2);power_used=true;_use_life_tap_with_audio(0);play_sound("mana");return
		targeting_power = true; _begin_spell_audio_preview("CS2_034"); _update_interaction(); play_sound("pickup"); return
	if hover_card >= 0:
		pressed_card = hover_card
		if definitions[cards[hover_card].key].cost > mana: show_toast("法力值不足"); play_sound("error")
		return
	for u in allies:
		if (Geometry2D.is_point_in_polygon(pointer,u.get("source_hit_polygon",PackedVector2Array())) if _phone_hand_enabled() else (pointer - u.pos).length() < 72):
			if not can_attack(u):
				_reject_feedback(u.pos,"该随从还不能攻击" if not u.frozen else "随从已被冻结",u.pos); return
			selected_unit = u.id; native_combat.prepare_attack(u); _announce_attack_audio(u); _update_interaction(); play_sound("pickup"); return
	_try_original_board_press()

func _try_original_board_press():
	if _hand_occludes_scenery(pointer):return
	if hover_card>=0 or hover_unit>=0 or drag_index>=0 or pressed_card>=0:return
	if source_projection!=null:
		for key in ["friendly_hero","opposing_hero","friendly_power","opposing_power","end_turn"]:
			if source_phone_layout.contains(key,pointer):return
	else:
		if ((pointer-PLAYER_HERO).length()<90 or (pointer-ENEMY_HERO).length()<90 or (pointer-POWER_POS).length()<55):return
		if flow.visuals.BUTTON_RECT.has_point(pointer):return
	if is_instance_valid(original_board_bridge):
		board_gesture=original_board_bridge.try_pointer_press(pointer)
		if board_gesture:get_viewport().set_input_as_handled()


func _hand_occludes_scenery(point:Vector2)->bool:
	if _phone_hand_enabled():
		if native_phone_hand.hit_card(point)>=0:return true
		return is_instance_valid(spatial_scene) and is_instance_valid(spatial_scene.phone_opposing_hand) and spatial_scene.phone_opposing_hand.contains(point)
	# Visibility, not action availability: opponent turns still display both hands.
	var outline=_card_surface_outline()
	for card in cards:
		if not card.has("pos") or not card.has("scale"):continue
		var scale_value=maxf(absf(float(card.scale)),0.001)
		var local=(point-card.pos).rotated(-float(card.get("angle",0.0)))/scale_value
		if Geometry2D.is_point_in_polygon(local,outline):return true
	var n=mini(enemy_hand.size(),10 if flow.mode=="normal" else 9)
	for i in range(n):
		var off=i-(n-1)*0.5
		var local=(point-Vector2(800+off*50,8+off*off*4)).rotated(off*0.09)/0.57
		if Rect2(-78,-110,156,222).has_point(local):return true
	return false

func _pointer_release():
	if _phone_hand_enabled():
		var small_touch=native_phone_hand.touched_slot>=0 and not native_phone_hand.enlarged
		var released_on_hand=native_phone_hand.hit_card(pointer)>=0
		native_phone_hand.release_touch()
		if drag_index<0 and small_touch and released_on_hand and native_phone_hand.mini_hand_play_enabled:
			native_phone_hand.set_enlarged(true);pressed_card=-1;hover_card=-1;last_hover=-1;return
	if board_gesture:
		board_gesture=false;mouse_down=false;get_viewport().set_input_as_handled();return
	if help_visible or settings_visible: flow.visuals.button_pressed=false;cancel_interaction();return
	if flow.visuals.release_button(): end_turn();return
	if not flow.accepts_actions(): _clear_selection();return
	if drag_index >= 0:
		_update_interaction()
		var index = drag_index
		var place = preview_index
		if (native_phone_hand.hit_card(pointer)>=0 if _phone_hand_enabled() else pointer.y > 825):
			cancel_interaction(); return
		if _phone_hand_enabled() and rules.needs_target(cards[index].key) and interaction_state!=Interaction.SPELL_AIM:
			cancel_interaction();return # DropHeldSpellLikeCard targeted-without-target-mode cancels.
		# Original DoNetworkOptionTarget rejects without destroying the arrow.
		# Retain a latched targeted card until a legal target or explicit cancel.
		if interaction_state==Interaction.SPELL_AIM:
			var feedback: Dictionary=_target_feedback_at(pointer)
			if feedback.status!="valid":
				_reject_feedback(pointer,feedback.reason,_aim_origin())
				if is_instance_valid(native_targeting):native_targeting.note_invalid_attempt(feedback.reason)
				pressed_card=-1;return
		if is_instance_valid(native_targeting):native_targeting.clear("commit")
		drag_index = -1; pressed_card = -1
		play_card(index, pointer, place)
		if pending_battlecry.is_empty(): _clear_selection()
		else: _update_interaction()
		return
	if pressed_card >= 0:
		if touch_input_active:
			# A tap ends with the finger; only movement starts a held-card drag.
			pressed_card = -1
			return
		# Click-to-pick-up is supported alongside physical dragging.
		_begin_card_drag(pressed_card)
		pressed_card = -1
		return
	if (selected_unit >= 0 or targeting_power or not pending_battlecry.is_empty()) and _gesture_pointer().distance_to(press_screen_pos) > 20: _resolve_target(pointer)

func _begin_card_drag(index: int):
	if not flow.accepts_actions() or not player_turn or busy or help_visible or settings_visible: return
	if index < 0 or index >= cards.size() or cards[index].get("returning",false): return
	if _phone_hand_enabled():
		if native_phone_hand.enlarging_remaining>0:return
		var card:Dictionary=cards[index]
		var pose:Dictionary=card.get("source_phone_pose",native_phone_hand.source_pose(index,cards.size(),index==native_phone_hand.focus))
		card.source_phone_grab_scale=pose.scale;card.source_phone_grab_rotation=pose.rotation
		card.source_phone_rotator=preload("res://scripts/native_drag_rotator.gd").new();card.source_phone_rotator.reset(pose.position)
		_publish_source_hand_pose(card,pose)
	cards[index].erase("source_grab_age");cards[index].erase("source_held_face_pose");
	if not _phone_hand_enabled():cards[index].erase("source_world_position")
	drag_index=index;tracked_drag=index;spell_aim_latched=false;preview_index=-1
	drag_start=cards[index].pos;spell_anchor=_spell_source_shelf(drag_start.x)
	interaction_state=Interaction.CARD_HELD;play_sound("pickup");_event("card_pickup")
	_update_interaction()

func _spell_source_shelf(x: float) -> Vector2:
	# Keep the lifted source beside the hero, without covering the hero or power.
	return Vector2(clampf(x,430,610) if x<800 else clampf(x,1060,1160),770)

func _clear_selection(preserve_attack_audio: bool = false,preserve_spell_preview: bool=false,target_reason: String="selection_cleared"):
	if _phone_hand_enabled():native_phone_hand.finish_spell_target_drop()
	if is_instance_valid(native_targeting):native_targeting.clear(target_reason)
	if not preserve_attack_audio and is_instance_valid(native_combat):native_combat.cancel_prepared()
	if not preserve_spell_preview:_cancel_spell_audio_preview()
	if not preserve_attack_audio:
		if _audio_selected_attack_id >= 0: SoundManager.stop_original_scope("aim:" + str(_audio_selected_attack_id))
		_audio_selected_attack_id = -1
	drag_index=-1;pressed_card=-1;selected_unit=-1;targeting_power=false
	tracked_drag=-1;spell_aim_latched=false;preview_index=-1
	interaction_state=Interaction.IDLE;target_feedback={}

func _return_card(index: int, rejected: bool = false):
	if index<0 or index>=cards.size(): return
	var c=cards[index]
	if _phone_hand_enabled():
		native_phone_hand.finish_spell_target_drop()
		native_phone_hand.release_touch()
		var pose:Dictionary=c.get("source_phone_pose",native_phone_hand.source_pose(index,cards.size())).duplicate(true)
		var target:Dictionary=native_phone_hand.source_pose(index,cards.size())
		c.source_phone_transition={"generation":native_phone_hand.generation,"count":cards.size(),"age":0.0,"from":pose,"pose":pose.duplicate(true),"target":target,"duration":0.5}
		c.returning=true;hover_card=-1;last_hover=-1
		_event("card_rejected_return" if rejected else "card_cancel_return");return
	c.returning=true;c.return_t=0.0;c.return_rejected=rejected
	c.return_origin=c.pos;c.return_angle=c.angle;c.return_scale=c.scale;c.spring=Vector2.ZERO
	hover_card=-1;last_hover=-1
	_event("card_rejected_return" if rejected else "card_cancel_return")

func cancel_interaction():
	mouse_down=false
	if _phone_hand_enabled():native_phone_hand.release_touch()
	var was_native_target: bool=native_targeting.cancel_target_mode() if is_instance_valid(native_targeting) else false
	if _audio_selected_attack_id >= 0: SoundManager.stop_original_scope("aim:" + str(_audio_selected_attack_id))
	_audio_selected_attack_id = -1
	if not pending_battlecry.is_empty():
		if pending_battlecry.has("unit") and is_instance_valid(native_summon):native_summon.cancel_unit(int(pending_battlecry.unit.id))
		busy=false
		_return_card(pending_battlecry.index);pending_battlecry.clear()
		if not was_native_target:play_sound("return")
		_event("battlecry_cancel")
	if drag_index>=0: _return_card(drag_index)
	if drag_index>=0 or selected_unit>=0 or targeting_power:
		if not was_native_target:play_sound("return")
		_event("interaction_cancel")
	_clear_selection()

func _source_play_contains(point:Vector2)->bool:
	if source_projection!=null and source_projection.is_enabled():
		if source_phone_layout.contains("friendly_play",point):return true
		var rows:Dictionary=source_phone_layout.source_items
		return not preload("res://scripts/native_phone_placement.gd").friendly_drop_hit(source_projection,point,rows.friendly_play.source_row,rows.opposing_play.source_row).is_empty()
	return PLAY_RECT.has_point(point)

func _insertion_index(x):
	if _phone_hand_enabled():
		if drag_index<0 or drag_index>=cards.size() or not cards[drag_index].has("source_world_position"):return -1
		var helper=preload("res://scripts/native_phone_placement.gd")
		var hit=helper.ray_hit(source_projection,Vector2(x,pointer.y))
		if hit.is_empty():return -1
		var row:Dictionary=source_phone_layout.source_items.friendly_play.source_row
		return helper.source_slot(row,allies.size(),preview_index+1 if preview_index>=0 else -1,hit.position.x,cards[drag_index].source_world_position.x)-1
	# Use canonical pre-preview slots, never already displaced target positions.
	# Otherwise the gap chases the mouse and oscillates as neighbors reflow.
	var n=allies.size()
	var step=minf(118,900.0/maxf(n,1))
	var index=0
	for i in range(n):
		if x>800+(i-(n-1)*0.5)*step: index+=1
	return index

func _update_interaction(allow_input_transitions:bool=true):
	target_feedback={}
	if not pending_battlecry.is_empty():
		interaction_state=Interaction.BATTLECRY_AIM
	elif drag_index>=0 and drag_index<cards.size():
		if tracked_drag!=drag_index:
			if not allow_input_transitions:return
			tracked_drag=drag_index;spell_aim_latched=false;preview_index=-1
			drag_start=cards[drag_index].pos;spell_anchor=_spell_source_shelf(drag_start.x)
		var d=definitions[cards[drag_index].key]
		if d.kind=="minion":
			interaction_state=Interaction.CARD_HELD
			if _source_play_contains(pointer) and allies.size()<7 and d.cost<=mana:
				interaction_state=Interaction.PLACEMENT_PREVIEW
				var candidate=_insertion_index(pointer.x)
				if _phone_hand_enabled():
					preview_index=candidate
					if candidate>=0:
						var row:Dictionary=source_phone_layout.source_items.friendly_play.source_row
						var slots=preload("res://scripts/source_phone_board_layout.gd").normal_slots(row,allies.size()+1,-1)
						if candidate<slots.size():preview_position=source_projection.source_to_screen(slots[candidate])
				else:
					if preview_index<0 or candidate==preview_index or absf(pointer.x-(800+(mini(candidate,preview_index)-(allies.size()-1)*0.5)*minf(118,900.0/maxf(allies.size(),1))))>12:
						preview_index=candidate
					var n=allies.size()+1
					preview_position=Vector2(800+(preview_index-(n-1)*0.5)*minf(118,900.0/n),FRIEND_Y)
			else: preview_index=-1
		elif rules.needs_target(cards[drag_index].key):
			if _phone_hand_enabled():
				if allow_input_transitions:
					var source_spell=preload("res://scripts/native_phone_spell_input.gd")
					var over_field=source_spell.over_playfield(source_projection,pointer,native_phone_hand.targeting_mode)
					var keep_region=source_spell.keep_targeting(source_projection,pointer)
					var has_response=d.cost<=mana and _source_spell_has_target(cards[drag_index].key)
					var next=source_spell.next_aim(spell_aim_latched,over_field,keep_region,has_response)
					if next and not spell_aim_latched:
						native_phone_hand.enter_spell_target(rules.legal_target(cards[drag_index].key,{"type":"hero","side":0,"pos":PLAYER_HERO},0))
						_event("spell_aim_begin");_begin_spell_audio_preview(cards[drag_index].key)
					elif not next and spell_aim_latched:
						native_phone_hand.targeting_mode=false;_cancel_spell_audio_preview()
					spell_aim_latched=next
				interaction_state=Interaction.SPELL_AIM if spell_aim_latched else Interaction.CARD_HELD
			elif allow_input_transitions and pointer.y<660 and not spell_aim_latched:
				spell_aim_latched=true
				# Lifted card remains on this source shelf while the pointer chooses a target.
				spell_anchor=_spell_source_shelf(drag_start.x)
				_event("spell_aim_begin")
				if d.cost <= mana: _begin_spell_audio_preview(cards[drag_index].key)
			elif not _phone_hand_enabled() and allow_input_transitions and pointer.y>780:
				spell_aim_latched=false
				_cancel_spell_audio_preview()
			interaction_state=Interaction.SPELL_AIM if spell_aim_latched else Interaction.CARD_HELD
		else: interaction_state=Interaction.CARD_HELD
	elif selected_unit>=0: interaction_state=Interaction.ATTACK_AIM
	elif targeting_power: interaction_state=Interaction.POWER_AIM
	else:
		interaction_state=Interaction.IDLE;tracked_drag=-1;preview_index=-1
	if _is_aiming(): target_feedback=_target_feedback_at(pointer)

func _source_spell_has_target(key:String)->bool:
	# Local rules supply HasResponse/EntityHasTargets for this supported classic set.
	for side in [0,1]:
		if rules.legal_target(key,{"type":"hero","side":side,"pos":PLAYER_HERO if side==0 else ENEMY_HERO},0):return true
		for unit in (allies if side==0 else enemies):
			if rules.legal_target(key,{"type":"unit","unit":unit,"pos":unit.pos},0):return true
	return false

func _is_aiming() -> bool:
	return interaction_state in [Interaction.SPELL_AIM,Interaction.ATTACK_AIM,Interaction.POWER_AIM,Interaction.BATTLECRY_AIM]

func _target_is_legal(t: Dictionary) -> bool:
	if t.is_empty(): return false
	var side=t.side if t.type=="hero" else t.unit.side
	if t.type=="unit" and (t.unit.dead or t.unit.get("provisional",false)): return false
	if interaction_state==Interaction.BATTLECRY_AIM: return not pending_battlecry.is_empty()
	if interaction_state==Interaction.ATTACK_AIM: return legal_attack(unit_by_id(selected_unit),t)
	if interaction_state==Interaction.POWER_AIM: return not power_used and mana>=2
	if interaction_state==Interaction.SPELL_AIM and drag_index>=0 and drag_index<cards.size(): return definitions[cards[drag_index].key].cost<=mana and rules.legal_target(cards[drag_index].key,t,0)
	return false

func _target_feedback_at(pos: Vector2) -> Dictionary:
	var t=target_at(pos,1)
	if t.is_empty(): t=target_at(pos,0)
	if t.is_empty(): return {"status":"none","reason":"请选择有效目标","pos":pos}
	if _target_is_legal(t): return {"status":"valid","reason":"","pos":t.pos,"target":t}
	var reason="请选择一个角色"
	if interaction_state==Interaction.ATTACK_AIM:
		var u=unit_by_id(selected_unit)
		var side=t.side if t.type=="hero" else t.unit.side
		if side==0: reason="不能攻击己方角色"
		elif not u.is_empty() and u.frozen: reason="随从已被冻结"
		elif not u.is_empty() and not u.ready: reason="该随从还不能攻击"
		else: reason="必须先攻击具有嘲讽的随从"
	elif interaction_state==Interaction.SPELL_AIM and drag_index>=0 and definitions[cards[drag_index].key].cost>mana: reason="法力值不足"
	return {"status":"invalid","reason":reason,"pos":t.pos,"target":t}

func _aim_origin() -> Vector2:
	if interaction_state==Interaction.BATTLECRY_AIM and not pending_battlecry.is_empty(): return pending_battlecry.pos
	if interaction_state==Interaction.ATTACK_AIM:
		var u=unit_by_id(selected_unit)
		if not u.is_empty(): return u.pos
	if interaction_state==Interaction.POWER_AIM: return POWER_POS
	if interaction_state==Interaction.SPELL_AIM and drag_index>=0 and drag_index<cards.size(): return cards[drag_index].pos+Vector2(0,-100)*cards[drag_index].scale
	return pointer

func _reject_feedback(pos: Vector2, reason: String, origin: Vector2 = Vector2.ZERO):
	rejections.append({"p":pos,"origin":origin,"life":0.58,"max":0.58})
	show_toast(reason)
	if is_instance_valid(native_targeting) and _is_aiming():native_targeting.audio.trigger_display_error(reason)
	else:play_sound("error")
	_event("target_rejected")

func _reject_card(index: int, pos: Vector2, reason: String) -> bool:
	_reject_feedback(pos,reason,cards[index].pos)
	_return_card(index,true)
	return false

func play_card(index: int, target: Vector2, insertion_override: int = -1, battlecry_target: Dictionary = {}) -> bool:
	if not flow.accepts_actions() or not pending_battlecry.is_empty() or not player_turn or busy or game_over or index < 0 or index >= cards.size(): return false
	var c = cards[index]
	var d = definitions[c.key]
	if d.cost > mana: return _reject_card(index,target,"法力值不足")
	if c.key=="CS2_027" and allies.size()>=7: return _reject_card(index,target,"战场已满")
	if d.kind == "minion":
		if not _source_play_contains(target): return _reject_card(index,target,"请放入己方战场")
		if allies.size() >= 7: return _reject_card(index,target,"战场已满")
		var insertion = clampi(insertion_override,0,allies.size()) if insertion_override>=0 else _insertion_index(target.x)
		# No recovered source slot: fail before pending-target, mana or hand mutations.
		if insertion<0:return false
		if d.get("battlecry", "")=="damage1" and battlecry_target.is_empty():
			pending_battlecry={"index":index,"pos":target,"insertion":insertion,"source":c.duplicate(true)}
			if _phone_hand_enabled():
				var row:Dictionary=source_phone_layout.source_items.friendly_play.source_row
				var slots=preload("res://scripts/source_phone_board_layout.gd").normal_slots(row,allies.size()+1,-1)
				var pose:Dictionary=c.source_phone_pose.duplicate(true)
				pose.position=slots[insertion];pose.rotation=Vector3.ZERO
				pending_battlecry.source_phone_pose=pose
				pending_battlecry.source_world_position=pose.position
				pending_battlecry.source_world_scale=preload("res://scripts/source_phone_board_layout.gd").vector(row.phone_card_target_scale)
				pending_battlecry.pos=source_projection.source_to_screen(pose.position)
				_publish_source_hand_pose(c,pose)
			drag_index=-1;pressed_card=-1;_start_battlecry_release();_update_interaction()
			if not is_instance_valid(native_targeting):show_toast("精灵弓箭手：选择战吼目标 · 右键取消")
			_event("battlecry_aim_begin");return true
		if d.get("battlecry", "")=="damage1" and not _valid_character(battlecry_target): return false
		pending_battlecry.clear()
		_spend_mana(d.cost); cards.remove_at(index); hover_card = -1; last_hover = -1
		play_sound("card_play"); play_sound("mana")
		var u = _new_unit(c.key, 0, target)
		u.scale = 1.5; allies.insert(insertion, u)
		if source_projection!=null:
			source_phone_layout.refresh();source_projection=source_phone_layout.context
			camera_shake.present_source_camera(source_projection);source_phone_layout.reproject();source_phone_layout.update_units()
		# This path has just accepted a legal drop on the friendly playfield.
		# Original DoOptionHighlight selects state8/BlueOverBoard for that condition.
		c.source_actor_state=8
		c.source_actor_state_basis="legal_card_over_friendly_playfield"
		_summon_effect(u, c, battlecry_target)
		_log(d.name, "召唤 · " + str(d.atk) + "/" + str(d.hp), d.color)
	else:
		var t={}
		if rules.needs_target(c.key):
			t=target_at(target,1)
			if t.is_empty(): t=target_at(target,0)
			if not rules.legal_target(c.key,t,0): return _reject_card(index,target,"该法术不能选择此目标")
		elif _phone_hand_enabled():
			if not preload("res://scripts/native_phone_spell_input.gd").over_playfield(source_projection,target):return _reject_card(index,target,"将法术拖入战场施放")
		elif target.y>730: return _reject_card(index,target,"将法术拖入战场施放")
		_spend_mana(d.cost);cards.remove_at(index);hover_card=-1;last_hover=-1
		play_sound("card_play");play_sound("mana")
		_cast_dual_spell(c.key,t,0,target if c.key=="GAME_005" else c.pos+Vector2(0,-95)*c.scale)
		_log(d.name,"施放法术",d.color)
	tutorial_hint = false
	return true

func _start_battlecry_release():
	# A provisional presentation actor, not a rule-state summon. The original
	# hand Out -> play In runs now; committing a target must not replay it.
	if not _phone_hand_enabled() or not is_instance_valid(native_summon):return
	var pending=pending_battlecry
	var unit=_new_unit(cards[int(pending.index)].key,0,pending.pos)
	unit.source_world_target=pending.source_world_position
	unit.source_world_target_scale=pending.source_world_scale
	unit.source_world_target_rotation=Quaternion.IDENTITY;unit.source_world_target_euler=Vector3.ZERO
	unit.source_world_position=pending.source_world_position
	unit.source_world_scale=pending.source_world_scale;unit.source_world_rotation=Quaternion.IDENTITY
	unit.provisional=true;pending.unit=unit;pending.releasing=true;busy=true
	var source:Dictionary=pending.source
	source.source_actor_state=8;source.source_actor_state_basis="legal_card_over_friendly_playfield"
	native_summon.begin(unit,source,"hand",func():
		if not pending_battlecry.is_empty() and pending_battlecry.get("unit",{}).get("id",-1)==unit.id:
			pending_battlecry.releasing=false;busy=false;_update_interaction()
	)

func _commit_battlecry_release(pending:Dictionary,target:Dictionary):
	var unit:Dictionary=pending.unit
	unit.erase("provisional")
	var definition:Dictionary=definitions[unit.key]
	_spend_mana(definition.cost);cards.remove_at(int(pending.index))
	hover_card=-1;last_hover=-1;play_sound("card_play");play_sound("mana")
	allies.insert(int(pending.insertion),unit)
	_log(definition.name,"召唤 · "+str(definition.atk)+"/"+str(definition.hp),definition.color)
	var history_id=_history_begin_play(unit.key,0,target,unit)
	busy=true
	_resolve_battlecry(unit,target,func():_history_complete(history_id);busy=false;_check_victory();_announce_charge_ready(unit))
	tutorial_hint=false

func _summon_effect(u, source={}, battlecry_target={}):
	var history_id=_history_begin_play(u.key,int(u.side),battlecry_target,u)
	# The native player owns source FSM waits, real source AnimationClip sampling,
	# effect meshes/materials and particle lifetime. No legacy v18 release timeline.
	busy=true
	native_summon.begin(u,source,"hand",func():
		_resolve_battlecry(u,battlecry_target,func():_history_complete(history_id);busy=false;_check_victory();_announce_charge_ready(u))
	)

func _summon_generated(u: Dictionary):
	if combat_replay.capturing:
		combat_replay.record_born(int(u.id))
		return
	# Generated minions have their own source type26/31 glow path, no hand Out.
	if is_instance_valid(native_summon):native_summon.begin(u,{},"token")

func _announce_charge_ready(u: Dictionary):
	# This belongs to a successfully committed summon, never hover/cancel or turn refresh.
	# The once-per-instance latch also prevents repeated callbacks from replaying the cue.
	if definitions[u.key].keyword != "冲锋" or u.get("charge_announced",false) or not can_attack(u): return
	u.charge_announced=true;u.charge_ready_at=elapsed
	_event("charge_ready")
	if sound_enabled: SoundManager.play_ability_sound("charge_ready",u.key,u.id)

func target_at(pos: Vector2, side: int) -> Dictionary:
	if source_projection!=null and source_projection.is_enabled():
		var source_units=enemies if side==1 else allies
		for unit in source_units:
			var polygon:PackedVector2Array=unit.get("source_hit_polygon",PackedVector2Array())
			if not unit.dead and polygon.size()>=3 and Geometry2D.is_point_in_polygon(pos,polygon):
				return {"type":"unit","unit":unit,"pos":unit.pos,"source_world_position":unit.source_world_position}
		var key="opposing_hero" if side==1 else "friendly_hero"
		if source_phone_layout.contains(key,pos):
			var item=source_phone_layout.snapshot.items[key]
			return {"type":"hero","side":side,"pos":item.center,"source_world_position":item.source_world_position}
		return {}
	var units = enemies if side == 1 else allies
	for u in units:
		if not u.dead and (pos - u.pos).length() < 76: return {"type": "unit", "unit": u, "pos": u.pos}
	var hp = ENEMY_HERO if side == 1 else PLAYER_HERO
	if (pos - hp).length() < 95: return {"type": "hero", "side": side, "pos": hp}
	return {}

func _resolve_target(pos):
	if not pending_battlecry.is_empty():
		if pending_battlecry.get("releasing",false):return
		# Touch users have no right mouse button. Returning to the hand is an
		# explicit cancel; retain card/mana and animate from its placed pose.
		if _phone_hand_enabled() and native_phone_hand.hit_card(pos)>=0:
			cancel_interaction();return
		var t=target_at(pos,1)
		if t.is_empty(): t=target_at(pos,0)
		if t.is_empty():
			_reject_feedback(pos,"请选择战吼目标，或右键取消",pending_battlecry.pos);return
		var pending=pending_battlecry.duplicate();pending_battlecry.clear()
		_clear_selection(false,false,"commit")
		if pending.has("unit"):_commit_battlecry_release(pending,t)
		else:play_card(pending.index,pending.pos,pending.insertion,t)
		return
	_update_interaction()
	var feedback=_target_feedback_at(pos)
	var origin=_aim_origin()
	if feedback.status!="valid":
		_reject_feedback(feedback.pos,feedback.reason,origin)
		if is_instance_valid(native_targeting):native_targeting.note_invalid_attempt(feedback.reason)
		return
	var t=feedback.target
	if targeting_power:
		if power_used or mana<2 or busy:_clear_selection();return
		_clear_selection(false,true,"commit")
		_spend_mana(2);power_used=true;play_sound("mana")
		_cast_projectile(POWER_POS,t,1,Color("ffb455"),false)
		_log("火焰冲击","英雄技能 · 1 点伤害",Color("ffb455"));return
	var u=unit_by_id(selected_unit)
	_clear_selection(true,false,"commit")
	if not u.is_empty(): attack(u,t)

func unit_by_id(id):
	for u in allies + enemies:
		if u.id == id: return u
	return {}

func can_attack(u: Dictionary) -> bool:
	# One rule source for controls, target validation, and the green readiness halo.
	# `ready` tracks summoning sickness / exhausted attacks; Charge starts it true.
	if u.is_empty() or game_over or busy or (flow!=null and not flow.accepts_actions()): return false
	if not u.get("ready",false) or u.get("dead",true) or u.get("frozen",false): return false
	if u.get("hp",0)<=0 or u.get("atk",0)<=0 or u.get("hidden",false) or u.get("animating",false): return false
	if u.side != (0 if player_turn else 1): return false
	var board=allies if u.side==0 else enemies
	return board.any(func(live):return is_same(live,u))

func has_attack_ready_glow(u: Dictionary) -> bool:
	# Opponent AI actions never advertise a player-interactable green control.
	return u.get("side",-1)==0 and can_attack(u) and not help_visible and not settings_visible

func legal_attack(u, t) -> bool:
	if not can_attack(u) or not _valid_character(t): return false
	if t.type=="unit" and t.unit.hp<=0: return false
	if t.type=="hero" and health[t.side]<=0: return false
	var target_side=t.side if t.type=="hero" else t.unit.side
	if target_side==u.side: return false
	var opponents = enemies if u.side == 0 else allies
	var taunts = []
	for target in opponents:
		if definitions[target.key].keyword == "嘲讽" and not target.dead: taunts.append(target.id)
	if not taunts.is_empty():
		if t.type != "unit" or not t.unit.id in taunts: return false
	return true

func attack(u,t) -> bool:
	if busy or game_over: return false
	if not legal_attack(u,t):
		_reject_feedback(t.get("pos",u.get("pos",pointer)),"无法攻击这个目标",u.get("pos",pointer));return false
	var history_id=native_history_events.begin_attack(_history_character({"type":"unit","unit":u}),_history_character(t))
	native_history_events.checkpoint(history_id,_history_board())
	u.ready=false;u.attacks_used=1;u.summoning_sick=false;busy=true;u.animating=true
	_event("attack_anticipation");_announce_attack_audio(u)
	_audio_selected_attack_id = -1
	native_combat.begin_attack(u,t,func():
		_event("attack_contact")
		# Retain the old cosmetic random-stream consumption, without rendering
		# the retired polygon sparks or overlaying their hand-written motion.
		for _i in range(19*4):rng.randf()
		if sound_enabled: SoundManager.play_original_impact(u.atk,{"scope_id":_next_audio_scope("contact"),"card_id":u.key,"unit_id":u.id})
		_audio_combat_pair = [u.id, t.unit.id] if t.type=="unit" else []
		rules.resolve_combat(u,t)
		_log(definitions[u.key].name,"攻击 · "+str(u.atk)+" 点伤害",Color("ebbd7d")),
		func():_clear_dead();_history_complete(history_id);busy=false;_check_victory())
	return true

func _source_spell_audio_targets(key: String,target: Dictionary,side: int) -> Array:
	if key in ["CS2_025","CS2_026","CS2_032"]:
		return (enemies if side==0 else allies).filter(func(u):return not u.dead).map(func(u):return {"type":"unit","unit":u,"pos":u.pos})
	if key=="CS2_062":return rules._characters(0)+rules._characters(1)
	return [target.duplicate()] if not target.is_empty() else []

func _cast_dual_spell(key: String, target: Dictionary, side: int, source: Vector2):
	var history_id=_history_begin_play(key,side,target)
	# Audio records presentation metadata only. Rule resolution and its RNG stay
	# synchronous at the existing callback; original missile voices are sequenced.
	var scope = _take_spell_audio_scope(key,side)
	_audio_scope_sides[scope] = side
	var launch_audio=func():
		_spell_audio(key,"cast",scope)
		_spell_audio(key,"launch",scope,{"event_token":"launch:0"})
		if key != "EX1_277":_spell_audio(key,"release",scope)
	busy=true
	var d=definitions[key]
	var destination=target.get("pos",Vector2(800,340 if side==0 else 496))
	var native: bool=native_combat.supports_spell(key)
	var audio_data: Dictionary={"started":false,"at":0.0,"delays":{}}
	var visual_hit=func():
		if audio_data.started:return
		audio_data.started=true;audio_data.at=native_combat.clock_seconds
		audio_data.delays=_audio_hit_targets(key,scope,_source_spell_audio_targets(key,target,side))
	var resolve=func():
		var old_units = {}
		for unit in allies + enemies: old_units[unit.id] = unit.key
		_audio_resolution = {"key":key,"scope":scope,"targets":[],"deaths":[]}
		rules.resolve_spell(key,target,side)
		var observed = _audio_resolution; _audio_resolution = {}
		if key == "EX1_277":combat_replay.audio=observed # Actual path times schedule original audio.
		else:
			var targets: Array = observed.targets
			if targets.is_empty() and not target.is_empty(): targets.append(target.duplicate(true))
			var hit_delays: Dictionary={}
			if native and audio_data.started:
				for id in audio_data.delays:hit_delays[id]=maxf(0.0,float(audio_data.delays[id])-(native_combat.clock_seconds-float(audio_data.at)))
			else:hit_delays=_audio_hit_targets(key,scope,targets)
			_audio_flush_deaths(observed.deaths,hit_delays)
			_finish_spell_scope(scope)
		for unit in allies + enemies:
			if not old_units.has(unit.id):
				_summon_generated(unit)
			elif old_units[unit.id] != unit.key:
				# Same-entity Play→Play replacement is not source standard Spawn26/31.
				# Existing spell impact remains compatibility presentation.
				native_summon.actor_transformed(unit,str(old_units[unit.id]),key+"/impact" if native else "")
		if native:
			for _i in range((0 if key=="GAME_005" else (55 if key=="CS2_023" else 40))*4):rng.randf()
		else:burst(destination,d.color,40);ring(destination,d.color,130)
	if native:
		if key=="EX1_277":
			combat_replay.begin();resolve.call();combat_replay.finish_capture()
			native_combat.begin_missile_replay(key,source,side,combat_replay.steps,scope,func():combat_replay.finish();_history_complete(history_id);busy=false;_check_victory(),launch_audio)
		else:native_combat.begin_spell(key,source,target,side,resolve,func():_history_complete(history_id);busy=false;_check_victory(),visual_hit,launch_audio)
	else:
		launch_audio.call()
		bolts.append({"start":source,"end":destination,"life":0.48,"max":0.48,"color":d.color})
		var tw=create_tween();tw.tween_interval(0.48);tw.tween_callback(resolve)
		tw.tween_interval(0.35);tw.tween_callback(func():_history_complete(history_id);busy=false;_check_victory())

func _cast_spell(key, t, source: Vector2 = Vector2(800,765)):
	_cast_dual_spell(key,t,0 if player_turn else 1,source)

func _cast_projectile(start, t, damage_amount, color, freezes):
	busy = true
	var audio_key = "CS2_024" if freezes else "CS2_034"
	var history_id=_history_begin_play(audio_key,0 if player_turn else 1,t)
	var audio_scope = _take_spell_audio_scope(audio_key,0 if player_turn else 1)
	_audio_scope_sides[audio_scope] = 0 if player_turn else 1
	var launch_audio=func():
		_spell_audio(audio_key,"cast",audio_scope)
		_spell_audio(audio_key,"launch",audio_scope)
		_spell_audio(audio_key,"release",audio_scope)
	var side: int=0 if player_turn else 1
	var resolve=func():
		_spell_audio(audio_key,"hit",audio_scope)
		_damage(t, damage_amount)
		if freezes:
			if t.type == "unit" and not t.unit.dead:
				var own_turn=(player_turn and t.unit.side==0) or (not player_turn and t.unit.side==1)
				# Reapplying Frozen does not stack another missed attack turn.
				if not t.unit.frozen: t.unit.thaw_turn=side_turn[t.unit.side]+(0 if own_turn and t.unit.ready else 1)
				t.unit.frozen=true;t.unit.ready=false
			elif t.type == "hero":
				hero_frozen[t.side]=true
				hero_thaw_turn[t.side]=side_turn[t.side]+(0 if (player_turn and t.side==0) or (not player_turn and t.side==1) else 1)
		for _i in range(55*4):rng.randf()
	native_combat.begin_spell(audio_key,start,t,side,resolve,func():_clear_dead();_history_complete(history_id);_finish_spell_scope(audio_scope);busy=false;_check_victory(),Callable(),launch_audio)

func _damage(t, amount):
	var hp_before: int=int(health[t.side] if t.type=="hero" else t.unit.hp)
	combat_replay.damage(t,amount)
	if not _audio_resolution.is_empty() and not _audio_resolution.get("ignoring_fatigue",false): _audio_resolution.targets.append(t.duplicate(true))
	if t.type == "hero":
		health[t.side] -= amount; hit_flash[t.side] = 1
	else:
		t.unit.hp -= amount; t.unit.flash = 1
		if t.unit.hp <= 0:
			t.unit.dead = true
			t.unit.death_pending = true
	native_history_events.affected(_history_character(t))
	if is_instance_valid(native_damage):
		var source: Dictionary={"kind":"damage"}
		if not _audio_combat_pair.is_empty():source={"kind":"combat","source_unit_id":_audio_combat_pair[1] if t.type=="unit" and int(t.unit.id)==int(_audio_combat_pair[0]) else _audio_combat_pair[0]}
		elif not _audio_resolution.is_empty():source={"kind":"spell","card_id":_audio_resolution.get("key",""),"side":_audio_scope_sides.get(_audio_resolution.get("scope",""),-1)}
		native_damage.record(t,int(amount),hp_before,int(health[t.side] if t.type=="hero" else t.unit.hp),source)

func _valid_character(t: Dictionary) -> bool:
	if t.is_empty(): return false
	if t.get("type", "")=="hero": return t.get("side",-1) in [0,1]
	if t.get("type", "")=="unit": return not t.unit.dead and (allies.has(t.unit) or enemies.has(t.unit))
	return false

func _resolve_battlecry(u: Dictionary, target: Dictionary, completed:Callable=Callable()):
	var scope = _next_audio_scope("battlecry")
	_audio_scope_sides[scope] = u.side
	var effect_does_nothing = u.key == "EX1_066" and rules.weapons[1-u.side].is_empty()
	var archer_source_audio:bool=u.key=="CS2_189" and _valid_character(target)
	var archer_owner:int=-1
	var launch: Dictionary = {}
	if not effect_does_nothing:
		if SoundManager.has_original_event(u.key,"cast"): _spell_audio(u.key,"cast",scope)
		if not archer_source_audio and SoundManager.has_original_event(u.key,"launch"): launch = _spell_audio(u.key,"launch",scope)
	if archer_source_audio:
		busy=true
		# The recovered source missile schedules its impact after Birth + flight.
		# Keep HP, death and the play-history completion behind that exact event.
		var owner={"id":-1}
		var impact=func():
			_audio_resolution={"key":u.key,"scope":scope,"targets":[],"deaths":[]}
			if _valid_character(target):
				_damage(target,1);_event("battlecry_damage1")
				_log(definitions[u.key].name,"战吼 · 造成1点伤害",GOLD);_clear_dead()
			var observed_damage=_audio_resolution;_audio_resolution={}
			native_combat.effect_player.retain_death_audio(owner.id,observed_damage.deaths)
		var finish=func():
			_finish_spell_scope(scope);busy=false
			if completed.is_valid():completed.call()
		var cancel=func():_finish_spell_scope(scope);busy=false
		owner.id=native_combat.effect_player.play_archer(u,target,scope,impact,finish,cancel)
		return
	_audio_resolution = {"key":u.key,"scope":scope,"targets":[],"deaths":[]}
	var observed_weapon_target = {"type":"hero","side":1-u.side,"pos":ENEMY_HERO if u.side==0 else PLAYER_HERO} if u.key=="EX1_066" and not effect_does_nothing else {}
	var prior_capacity = max_mana if u.side == 0 else enemy_max_mana
	var handled = rules.battlecry(u,target)
	if handled:
		if u.key == "EX1_301" and u.side == 0 and max_mana < prior_capacity and sound_enabled:
			if source_projection==null:SoundManager.play_original_event("@mana","destroy",{"scope_id":scope+":mana","source_side":0,"card_id":u.key})
			SoundManager.original_audio.finish_scope(scope+":mana")
		if not observed_weapon_target.is_empty(): _audio_resolution.targets.append(observed_weapon_target)
	else:
		var effect=definitions[u.key].get("battlecry", "")
		if effect=="draw1":
			_draw_cards(1,u.side);_event("battlecry_draw1")
			_log(definitions[u.key].name,"战吼 · 抽一张牌",BLUE)
		elif effect=="damage1" and _valid_character(target):
			archer_owner=native_combat.effect_player.play_archer(u,target,scope)
			_damage(target,1);_event("battlecry_damage1")
			_log(definitions[u.key].name,"战吼 · 造成1点伤害",GOLD);_clear_dead()
	var observed = _audio_resolution; _audio_resolution = {}
	var flight = _audio_missile_flight(u.key,scope) if launch.get("accepted",false) else 0.0
	var origin = {"origin_activation":launch.activation_id} if launch.has("activation_id") else {}
	if archer_owner>=0:
		# Rules already removed lethal targets. Only the observed legacy death
		# sounds wait for this exact visual missile's impact, without another draw.
		native_combat.effect_player.retain_death_audio(archer_owner,observed.deaths)
	else:
		var hit_delays = _audio_hit_targets(u.key,scope,observed.targets,flight,origin)
		_audio_flush_deaths(observed.deaths,hit_delays,origin)
	_finish_spell_scope(scope)
	if completed.is_valid():completed.call()

func _clear_dead():
	# Remove the whole simultaneous death wave before any deathrattle resolves.
	# Deathrattles then follow summon sequence, keeping each original board gap.
	var wave=[]
	for side_index in range(2):
		var board=allies if side_index==0 else enemies
		for i in range(board.size()):
			if board[i].hp<=0:
				wave.append({"unit":board[i],"slot":i,"side":side_index})
		for i in range(board.size()-1,-1,-1):
			if board[i].hp<=0: board.remove_at(i)
	wave.sort_custom(func(a,b):return a.unit.id<b.unit.id)
	var audible_death_id = -1
	var native_death_selection = not SoundManager.original_audio.catalog.is_empty()
	if native_death_selection:
		if is_instance_valid(native_endgame):audible_death_id=native_endgame.choose_death_voice(wave,_audio_combat_pair)
		else:
			var selected = SoundManager.original_audio.choose_death_index(wave,_audio_combat_pair)
			if selected >= 0: audible_death_id = wave[selected].unit.id
	_audio_combat_pair.clear()
	death_queue=wave.duplicate()
	var resolved=[]
	while not death_queue.is_empty():
		var entry=death_queue.pop_front();var u=entry.unit
		u.dead=true;u.death_pending=false
		native_history_events.affected(_history_character({"type":"unit","unit":u}))
		if is_instance_valid(native_damage):native_damage.retain_dead(u)
		# Retire the handmade portrait fragments/dust, but retain the exact old
		# cosmetic random draws. Historical rules RNG and death/audio stay intact.
		for _i in range(12*5):rng.randf()
		_audio_death_actor(u)
		if not native_death_selection or u.id == audible_death_id:
			_audio_death(u)
		else:
			SoundManager.original_audio._record("death_suppressed",{"card_id":u.key,"unit_id":u.id,"selected_unit_id":audible_death_id})
		_event("death_fracture")
		var token=definitions[u.key].get("deathrattle", "")
		if token!="":
			var board=allies if entry.side==0 else enemies
			if board.size()<7:
				var gap=entry.slot
				for other in wave:
					if other.side==entry.side and other.slot<entry.slot: gap-=1
				for other in resolved:
					if other.side==entry.side and other.slot<entry.slot and other.get("spawned",false): gap+=1
				var summoned=_new_unit(token,entry.side,u.pos)
				board.insert(clampi(gap,0,board.size()),summoned);entry.spawned=true
				_summon_generated(summoned)
				_event("deathrattle_summon");_log("亡语",definitions[token].name+" · 2/1",GOLD)
		resolved.append(entry)

	combat_replay.settled()

func _draw_cards(n: int, side: int = 0):
	for i in range(n):
		var pile=deck if side==0 else enemy_deck
		if pile.is_empty():
			fatigue[side]+=1
			var was_ignoring_fatigue = bool(_audio_resolution.get("ignoring_fatigue",false))
			if not _audio_resolution.is_empty(): _audio_resolution.ignoring_fatigue = true
			_damage({"type":"hero","side":side,"pos":PLAYER_HERO if side==0 else ENEMY_HERO},fatigue[side]);_check_victory()
			if not _audio_resolution.is_empty(): _audio_resolution.ignoring_fatigue = was_ignoring_fatigue
		else:
			var key=pile.pop_front()
			var source_ticket=flow.next_draw_ticket() if flow!=null else -1
			if side==0:
				var old_count=cards.size();_add_card(key,true,pile.size()+1,source_ticket)
				native_history_events.drawn(key,side,false,cards.size()==old_count)
				if cards.size()>old_count:
					cards.back().source_draw_deck_count=pile.size()+1
					cards.back().source_draw_tracker=i
					cards.back().source_draw_ticket=source_ticket
			else:
				var burned=enemy_hand.size()>=10
				native_history_events.drawn(key,side,not burned,burned)
				if not burned:
					enemy_hand.append(key)
					if _phone_hand_enabled():
						var source_hand=_source_opposing_hand()
						if is_instance_valid(source_hand):source_hand.enqueue_draw(enemy_hand.size()-1,pile.size()+1,i,source_ticket)
				if flow!=null: flow.opponent_draw(key,burned,pile.size()+1,source_ticket)

func _thaw_at_end(side: int):
	var board=allies if side==0 else enemies
	for u in board:
		if u.frozen and side_turn[side]>=u.get("thaw_turn",side_turn[side]): u.frozen=false;u.ready=false
	if hero_frozen[side] and side_turn[side]>=hero_thaw_turn[side]: hero_frozen[side]=false

func end_turn(timed_out: bool = false):
	if not player_turn or busy or game_over or flow.phase!="playing": return
	if not timed_out and not pending_battlecry.is_empty(): return
	if is_instance_valid(native_rope_host):native_rope_host.end_turn_requested(timed_out)
	if flow.mode=="normal":
		cancel_interaction();_thaw_at_end(0);_clear_temporary_mana(0)
		play_sound("end");_begin_normal_turn(1);return
	flow.begin_turn()
	cancel_interaction();_thaw_at_end(0);side_turn[1]+=1; player_turn = false; banner_time = 1.7; banner = "对手回合"; banner_sub = "酒馆老友正在思考…"
	enemy_max_mana = mini(10, enemy_max_mana + 1); enemy_mana = enemy_max_mana
	_draw_cards(1,1)
	for u in enemies:
		u.summoning_sick = false
		u.attacks_used=0
		u.ready = not u.frozen
	ai_step = 0; ai_timer = 1.65; play_sound("click"); play_sound("end")

func _ai_action():
	if not flow.accepts_actions(): return
	if _phone_hand_enabled():
		var source_hand=_source_opposing_hand()
		if is_instance_valid(source_hand) and source_hand.draws_pending():return
	# Decisions deliberately pause between cards and attacks, preserving readable rhythm.
	for i in range(enemy_hand.size()):
		var key=enemy_hand[i]
		var d=definitions[key]
		if d.cost>enemy_mana: continue
		if d.kind=="minion" and enemies.size()<7:
			var source={}
			if _phone_hand_enabled():
				var source_hand=_source_opposing_hand()
				if not is_instance_valid(source_hand):return
				var pose:Dictionary=source_hand.source_pose(i,enemy_hand.size())
				source={"key":key,"source_world_position":pose.position,"source_world_scale":pose.scale,"source_world_rotation":native_phone_hand.source_basis(pose.rotation).get_rotation_quaternion(),"source_world_euler":pose.rotation,"source_actor_profile":"Card_Hidden"}
			_spend_mana(d.cost,1);enemy_hand.remove_at(i);play_sound("card_play");play_sound("mana")
			var u=_new_unit(key,1,Vector2(1250,160));enemies.append(u)
			if _phone_hand_enabled():source_phone_layout.refresh();source_phone_layout.update_units()
			var target={"type":"hero","side":0,"pos":PLAYER_HERO}
			if not allies.is_empty(): target={"type":"unit","unit":allies[0],"pos":allies[0].pos}
			_summon_effect(u,source,target);_log("对手 · "+d.name,"召唤随从",d.color);ai_timer=1.1;return
		elif d.kind=="spell":
			if key=="CS2_027" and enemies.size()>=7: continue
			if key=="GAME_005" and not enemy_hand.any(func(k):return k!="GAME_005" and definitions[k].cost==enemy_mana+1): continue
			var target=rules.ai_target(key,1)
			if rules.needs_target(key) and not rules.legal_target(key,target,1): continue
			_spend_mana(d.cost,1);enemy_hand.remove_at(i);play_sound("card_play");play_sound("mana")
			_cast_dual_spell(key,target,1,ENEMY_HERO);_log("对手 · "+d.name,"施放法术",d.color);ai_timer=1.1;return
	for u in enemies:
		if not can_attack(u): continue
		var target = {"type": "hero", "side": 0, "pos": PLAYER_HERO}
		for a in allies:
			if definitions[a.key].keyword == "嘲讽": target = {"type": "unit", "unit": a, "pos": a.pos}; break
		if target.type == "hero" and not allies.is_empty() and flow.random.randf() > 0.45:
			var a = allies[flow.random.randi_range(0, allies.size() - 1)]
			target = {"type": "unit", "unit": a, "pos": a.pos}
		attack(u, target); ai_timer = 0.85; return
	if flow.mode=="normal" and enemy_mana>=2 and not flow.enemy_power_used:
		if hero_classes[1]=="WARLOCK" and (health[1]<=5 or enemy_hand.size()>=9 or enemy_deck.is_empty()):
			_begin_player_turn();return
		_spend_mana(2,1);flow.enemy_power_used=true;play_sound("mana")
		if hero_classes[1]=="WARLOCK": _use_life_tap_with_audio(1)
		else: _cast_projectile(Vector2(948,196),{"type":"hero","side":0,"pos":PLAYER_HERO},1,Color("ffb455"),false)
		ai_timer=1;return
	_begin_player_turn()

func _begin_player_turn():
	if game_over: return
	if flow.mode=="normal":
		_thaw_at_end(1);_clear_temporary_mana(1);_begin_normal_turn(0);return
	flow.begin_turn()
	_thaw_at_end(1);side_turn[0]+=1
	player_turn = true; turn += 1; max_mana = mini(10, max_mana + 1); mana = max_mana; power_used = false; turn_clock = 75
	for u in allies:
		u.summoning_sick = false
		u.attacks_used=0
		u.ready = not u.frozen
	_draw_cards(1); banner = "你的回合"; banner_sub = "抽一张牌 · 法力水晶已充满"; banner_time = 2.1
	_show_native_turn_banner()
	play_sound("turn"); play_sound("mana_refresh")

func _check_victory():
	if game_over: return
	if health[0] <= 0 or health[1] <= 0:
		# Fatigue can enter this gate without a minion death-clear callback.
		if is_instance_valid(native_endgame):native_endgame.observe_unprocessed_hero_death()
		game_over = true; game_tied=health[0]<=0 and health[1]<=0;won = health[1] <= 0 and not game_tied; combat_replay.pending_victory=combat_replay.capturing
		if not combat_replay.capturing:_begin_endgame_presentation()
		help_visible=false;settings_visible=false;mouse_down=false;pressed_card=-1
		# Preserve the former100-particle cosmetic RNG consumption, but do not
		# substitute handmade gold particles for the original hero/result effects.
		for _i in range(100*4):rng.randf()

func _begin_endgame_presentation():
	if not game_over:return
	cancel_interaction()
	help_visible=false;settings_visible=false;mouse_down=false;pressed_card=-1
	if is_instance_valid(flow.audio):flow.audio.stop()
	if is_instance_valid(native_endgame):
		var dead_sides: Array=[]
		for side in range(2):
			if health[side]<=0:dead_sides.append(side)
		var heroes: Array=[]
		for hero_class in hero_classes:heroes.append("HERO_07" if hero_class=="WARLOCK" else "HERO_08")
		native_endgame.request({"outcome":"tie" if game_tied else ("win" if won else "lose"),"winner_side":-1 if game_tied else (0 if won else 1),"dead_sides":dead_sides,"health":health.duplicate(),"hero_cards":heroes,"rule_time":elapsed})

func show_toast(message):
	toast = message; toast_time = 2.2

func _history_character(target: Dictionary) -> Dictionary:
	if target.is_empty():return {}
	if target.get("type","")=="unit":
		var unit: Dictionary=target.unit
		var result={"entity_id":"unit:"+str(unit.id),"key":str(unit.key),"side":int(unit.side),"kind":"minion"}
		for field in ["hp","max_hp","atk","dead","frozen","shield"]:
			if unit.has(field):result[field]=unit[field]
		return result
	if target.get("type","")=="hero":
		var side=int(target.side)
		return {"entity_id":"hero:"+str(side),"key":"HERO_08" if hero_classes[side]=="MAGE" else "HERO_07","side":side,"kind":"hero","hp":int(health[side]),"dead":health[side]<=0,"frozen":hero_frozen[side]}
	return {}

func _history_board() -> Array:
	var snapshots: Array=[]
	for side in range(2):snapshots.append(_history_character({"type":"hero","side":side}))
	for unit in allies+enemies:snapshots.append(_history_character({"type":"unit","unit":unit}))
	return snapshots

func _history_begin_play(key: String, side: int, target: Dictionary = {}, unit: Dictionary = {}) -> int:
	var source: Dictionary={"key":key,"side":side,"kind":definitions.get(key,{}).get("kind","spell")}
	if key in ["CS2_034","CS2_056"]:source.kind="hero_power";source.entity_id="power:"+str(side)
	if not unit.is_empty():source=_history_character({"type":"unit","unit":unit})
	var serial=native_history_events.begin_play(source,_history_character(target))
	native_history_events.checkpoint(serial,_history_board())
	return serial

func _history_complete(serial: int):
	native_history_events.complete(serial,_history_board())

func _log(label, detail, color):
	if combat_replay.capturing and not combat_replay.current.is_empty():combat_replay.current.logs.append({"label":label,"detail":detail,"color":color});return
	recent_log.push_front({"label": label, "detail": detail, "color": color, "time": elapsed})
	if recent_log.size() > 7: recent_log.pop_back()

func burst(p, color, count):
	for i in range(count):
		var angle = rng.randf() * TAU
		var speed = rng.randf_range(35, 260)
		var life = rng.randf_range(0.3, 0.85)
		particles.append({"p": p, "v": Vector2(cos(angle), sin(angle)) * speed, "life": life, "max": life, "size": rng.randf_range(2, 6), "color": color, "gravity": 90})

func ring(p, color, radius):
	ripples.append({"p": p, "color": color, "radius": radius, "life": 0.55, "max": 0.55})

func _corner_position(i):
	return [Vector2(352, 171), Vector2(1225, 174), Vector2(290, 765), Vector2(1250, 775)][i]

func _presentation_units() -> Array:
	var boards: Array=_presentation_boards()
	return boards[1]+boards[0]

func _presentation_boards() -> Array:
	var boards: Array=combat_replay.boards if combat_replay.playing else [allies,enemies]
	if not combat_replay.playing and pending_battlecry.has("unit"):
		boards=[allies.duplicate(),enemies];boards[0].insert(int(pending_battlecry.insertion),pending_battlecry.unit)
	return native_damage.append_dying(boards) if is_instance_valid(native_damage) else boards

func _setup_presentation_canvases():
	world_canvas=Node2D.new();world_canvas.name="WorldPresentation";add_child(world_canvas)
	world_canvas.draw.connect(_draw_world)
	world_canvas.position=presentation_offset
	fixed_layer=CanvasLayer.new();fixed_layer.name="CompatibilityScreenOverlay";fixed_layer.layer=2;add_child(fixed_layer)
	fixed_canvas=Node2D.new();fixed_canvas.name="FixedCursorAndHints";fixed_canvas.visibility_layer=2;fixed_layer.add_child(fixed_canvas)
	fixed_canvas.draw.connect(_draw_fixed_overlay)
	fixed_canvas.position=presentation_offset

func screen_to_board(point:Vector2)->Vector2:
	return world_canvas.global_transform.affine_inverse()*point if is_instance_valid(world_canvas) else point

func board_to_screen(point:Vector2)->Vector2:
	return world_canvas.global_transform*point if is_instance_valid(world_canvas) else point

func _update_screen_pointer(point:Vector2):
	screen_pointer=point;pointer=screen_to_board(point)

func _draw():
	if face_render_mode:
		draw_target=self
		_draw_card({"key":face_render_key,"pos":Vector2(164,242),"angle":0.0,"scale":2.0,"lift":0.0},-2)

func _draw_world():
	draw_target=world_canvas
	draw_target.draw_set_transform(shake_offset)
	_draw_board()
	_draw_turn_button()
	_draw_history()
	if not is_instance_valid(spatial_view):_draw_post_spatial()

func _draw_post_spatial():
	draw_target=spatial_post if is_instance_valid(spatial_post) else world_canvas
	if is_instance_valid(spatial_view):
		draw_target.draw_set_transform(Vector2.ZERO)
		draw_target.draw_texture_rect(spatial_view.get_texture(), (Rect2(-presentation_offset,presentation_size) if source_projection!=null else Rect2(0,0,W,H)), false, Color(1,1,1,2))
	_draw_effects(false)
	_draw_staged_cards()
	if not pending_battlecry.is_empty() and not is_instance_valid(spatial_scene):
		var preview_card=cards[pending_battlecry.index].duplicate()
		preview_card.pos=pending_battlecry.pos;preview_card.scale=0.72;preview_card.angle=0;preview_card.lift=20
		_draw_card(preview_card,-3)
	for i in range(cards.size()):
		if (pending_battlecry.is_empty() or i!=pending_battlecry.index) and i != hover_card and i != drag_index and not cards[i].get("drawing",false) and not cards[i].get("returning",false): _draw_card(cards[i], i)
	if hover_card >= 0 and hover_card < cards.size() and hover_card != drag_index: _draw_card(cards[hover_card], hover_card)
	for i in range(cards.size()):
		if cards[i].get("drawing",false) or cards[i].get("returning",false): _draw_card(cards[i],-1)
	if drag_index >= 0 and drag_index < cards.size():
		_draw_card(cards[drag_index], drag_index)
		_draw_held_card_rim(cards[drag_index])
	draw_target.draw_set_transform(shake_offset)
	_draw_hover_type_label()
	_draw_targeting()
	_draw_effects(true)
	flow.draw_ui()

func _draw_fixed_overlay():
	draw_target=fixed_canvas
	draw_target.draw_set_transform(Vector2.ZERO)
	_draw_top_labels()
	_draw_overlays()
	draw_target.draw_set_transform(Vector2.ZERO)
	if not headless and not touch_input_active and not _is_aiming():
		var cursor_key="hearthstone-grab" if drag_index>=0 else ("hearthstone-click" if mouse_down else "hearthstone-cursor")
		draw_target.draw_texture_rect(classic_ui[cursor_key],Rect2((board_to_screen(pointer) if scripted_pointer or demo_mode else screen_pointer)-presentation_offset-Vector2(10,2),Vector2(32,32)),false)

func _draw_board():
	# One live texture under WorldPresentation; no screenshot fallback or fake corner glows.
	if is_instance_valid(board_sprite):board_sprite.position=Vector2(800,450)

func _draw_top_labels():
	if source_projection!=null:
		if source_phone_name_banners==null:
			source_phone_name_banners=preload("res://scripts/native_phone_name_banner.gd").new()
		var name_mode=""
		if flow.phase in ["intro","deal","mulligan","replace"] and not game_over:name_mode="mulligan"
		elif flow.phase in ["coin","gather","playing"]:name_mode="gameplay"
		var names={"opponent":"Gnomepunter" if reference_fixture else "酒馆老友","friendly":"HexFrog" if reference_fixture else "旅店法师"}
		# Local heroes remain the existing mage/warlock. No rule/entity state changes.
		source_phone_name_banners.prepare(name_mode,names,presentation_size,{"opponent":"术士","friendly":"法师"})
		source_phone_name_banners.draw(draw_target,-presentation_offset)
		return
	for side in range(2):
		var y = 28.0 if side==1 else 827.0
		var label = ("Gnomepunter" if side==1 else "HexFrog") if reference_fixture else ("酒馆老友" if side==1 else "旅店法师")
		var width = 138.0 if reference_fixture else 112.0
		var poly = PackedVector2Array([Vector2(0,y-19),Vector2(width-8,y-19),Vector2(width,y),Vector2(width-8,y+14),Vector2(0,y+14)])
		draw_target.draw_colored_polygon(poly,Color(0.05,0.045,0.035,0.8))
		_text(label,Vector2(7,y+5),16,Color("e7e3d7"),false,reference_fixture)

func _draw_turn_button():
	flow.visuals.draw_button()
	flow.draw_rope()

func _draw_history():
	# HistoryManager assets now render in the shared source phone scene.
	# Do not reintroduce screenshot fragments, guessed panels or label-based art.
	return

# Outer-alpha silhouette sampled from the actual Sunwell frame; geometry data, not repainted art.
var _card_surface_base:=PackedVector2Array()
func _card_surface_outline(factor=1.0) -> PackedVector2Array:
	# Compute the fixed frame/offset once; native packed-array scaling returns
	# caller-owned points without caching unbounded animated lift factors.
	if _card_surface_base.is_empty():
		var points = PackedVector2Array([Vector2(-78.000,-90.840), Vector2(-77.112,-94.351), Vector2(-76.224,-96.398), Vector2(-75.040,-97.569), Vector2(-73.560,-99.032), Vector2(-72.080,-100.202), Vector2(-69.120,-101.665), Vector2(-66.159,-102.250), Vector2(-63.199,-102.250), Vector2(-60.239,-102.250), Vector2(-57.279,-102.250), Vector2(-54.319,-102.250), Vector2(-51.359,-102.250), Vector2(-48.398,-102.250), Vector2(-45.438,-102.250), Vector2(-42.478,-102.250), Vector2(-39.518,-102.250), Vector2(-36.558,-102.250), Vector2(-33.598,-102.250), Vector2(-30.638,-102.250), Vector2(-27.677,-104.883), Vector2(-24.717,-107.516), Vector2(-21.757,-109.271), Vector2(-18.797,-111.026), Vector2(-15.837,-112.489), Vector2(-12.877,-113.367), Vector2(-9.917,-114.537), Vector2(-6.956,-115.122), Vector2(-3.996,-115.415), Vector2(-1.036,-115.707), Vector2(1.924,-115.707), Vector2(4.884,-115.122), Vector2(7.844,-114.830), Vector2(10.805,-113.952), Vector2(13.765,-113.074), Vector2(16.725,-112.197), Vector2(19.685,-110.441), Vector2(22.645,-108.979), Vector2(25.605,-106.931), Vector2(28.565,-104.590), Vector2(31.526,-102.250), Vector2(34.486,-102.250), Vector2(37.446,-102.250), Vector2(40.406,-102.250), Vector2(43.366,-102.250), Vector2(46.326,-102.250), Vector2(49.287,-101.079), Vector2(52.247,-102.250), Vector2(55.207,-102.250), Vector2(58.167,-102.250), Vector2(61.127,-102.250), Vector2(64.087,-102.250), Vector2(67.047,-102.250), Vector2(70.008,-102.250), Vector2(72.968,-100.787), Vector2(74.448,-99.032), Vector2(75.928,-97.276), Vector2(77.112,-94.936), Vector2(77.704,-47.541), Vector2(77.704,-31.743), Vector2(77.112,107.516), Vector2(75.928,110.149), Vector2(74.448,112.197), Vector2(72.968,113.952), Vector2(70.008,114.830), Vector2(67.047,115.415), Vector2(64.087,115.415), Vector2(61.127,115.415), Vector2(58.167,115.415), Vector2(55.207,115.415), Vector2(52.247,115.415), Vector2(49.287,115.415), Vector2(46.326,115.415), Vector2(43.366,115.415), Vector2(40.406,115.415), Vector2(37.446,115.415), Vector2(34.486,115.415), Vector2(31.526,115.415), Vector2(28.565,115.415), Vector2(25.605,115.415), Vector2(22.645,115.415), Vector2(19.685,115.415), Vector2(16.725,115.415), Vector2(13.765,115.415), Vector2(10.805,115.415), Vector2(7.844,115.415), Vector2(4.884,115.415), Vector2(1.924,115.415), Vector2(-1.036,115.122), Vector2(-3.996,115.122), Vector2(-6.956,115.122), Vector2(-9.917,115.122), Vector2(-12.877,115.122), Vector2(-15.837,115.122), Vector2(-18.797,115.122), Vector2(-21.757,114.537), Vector2(-24.717,115.122), Vector2(-27.677,115.122), Vector2(-30.638,115.122), Vector2(-33.598,115.122), Vector2(-36.558,115.122), Vector2(-39.518,115.122), Vector2(-42.478,115.122), Vector2(-45.438,115.122), Vector2(-48.398,115.122), Vector2(-51.359,115.122), Vector2(-54.319,115.122), Vector2(-57.279,115.122), Vector2(-60.239,115.122), Vector2(-63.199,115.122), Vector2(-66.159,115.122), Vector2(-69.120,114.245), Vector2(-72.080,113.074), Vector2(-73.560,112.197), Vector2(-75.040,110.734), Vector2(-76.224,109.271), Vector2(-77.112,107.516), Vector2(-78.000,92.010)])
		for i in range(points.size()):points[i]=points[i]*CARD_FACE_SCALE+CARD_FACE_OFFSET
		_card_surface_base=points
	return Transform2D(Vector2(factor,0),Vector2(0,factor),Vector2.ZERO)*_card_surface_base

# Selection is a separate state from affordable-hand green and attack-ready green.
# The official held Grizzly has a narrow cyan upper/sides rim; its lower stat
# medallions remain mostly unlit until the committed full-face transformation.
const HELD_RIM_BLUE = Color("469dcc")
const HELD_RIM_CYAN = Color("62e5ff")
const HELD_RIM_LIGHT = Color("c1ffff")

func held_card_rim_paths(minion: bool = true) -> Array:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	if minion:
		# Independent traced contour from held source frames, normalized to the face.
		# A narrower crown, straighter shoulders and tight upper corners replace
		# the uniformly expanded silhouette sampled from the replacement artwork.
		upper=PackedVector2Array([Vector2(-78,78),Vector2(-78,68),Vector2(-78,45),Vector2(-78,-45),Vector2(-78,-65),Vector2(-78,-82),Vector2(-78,-96),Vector2(-76,-100),Vector2(-72,-102),Vector2(-32,-102),Vector2(-27,-104),Vector2(-22,-108),Vector2(-15,-112),Vector2(-7,-115),Vector2(0,-116),Vector2(7,-115),Vector2(15,-111),Vector2(22,-107),Vector2(29,-103),Vector2(34,-102),Vector2(72,-102),Vector2(76,-100),Vector2(78,-96),Vector2(78,-68),Vector2(78,45),Vector2(78,68),Vector2(78,78)])
		for i in range(upper.size()): upper[i]=upper[i]*CARD_FACE_SCALE+CARD_FACE_OFFSET
		# Bottom contour follows the attack medallion and health-drop silhouette.
		lower=PackedVector2Array([Vector2(77.7,78),Vector2(78.8,98),Vector2(77.0,108),Vector2(73,114),Vector2(65,118),Vector2(57,117),Vector2(49,113),Vector2(-44,113),Vector2(-51,117),Vector2(-62,118),Vector2(-72,114),Vector2(-78,107),Vector2(-80,96),Vector2(-78,78)])
	else:
		# Spell card frames do not carry the minion portrait crown/stat badges.
		upper=PackedVector2Array([Vector2(-78,92),Vector2(-78,-94),Vector2(-75,-100),Vector2(-69,-103),Vector2(69,-103),Vector2(75,-100),Vector2(78,-94),Vector2(78,92)])
		for i in range(upper.size()): upper[i]=upper[i]*CARD_FACE_SCALE+CARD_FACE_OFFSET
		lower=PackedVector2Array([Vector2(78,92),Vector2(78,108),Vector2(73,114),Vector2(-73,114),Vector2(-78,108),Vector2(-78,92)])
	for i in range(lower.size()): lower[i]=lower[i]*CARD_FACE_SCALE+CARD_FACE_OFFSET
	return [upper,lower]

func held_card_rim_style(transform_progress: float = 0.0) -> Dictionary:
	var t=clampf(transform_progress,0.0,1.0)
	return {"blue":HELD_RIM_BLUE,"cyan":HELD_RIM_CYAN,"light":HELD_RIM_LIGHT,
		"width":lerpf(4.8,6.2,t),"lower_alpha":lerpf(0.055,1.0,t),"bloom":lerpf(1.0,1.32,t)}

func selected_card_face_pose(c: Dictionary) -> Dictionary:
	if c.has("source_held_face_pose") and not c.has("phase"):return c.source_held_face_pose
	# Match the selected face's observed projection without changing physical
	# position, hit testing, motion/timings or the separately calibrated v16 shadow.
	var staged=float(c.get("phase_t",0.0)) if c.get("phase","")=="card" else (1.0 if c.has("phase") else 0.0)
	var t=clampf(staged,0.0,1.0)
	return {"pos":c.pos+Vector2(-1.2,2.75).lerp(Vector2(-2.8,7.5),t),
		"scale":Vector2(0.95,0.97).lerp(Vector2(0.92,1.0),t)*float(c.scale),
		"angle":float(c.angle)*0.4}

func held_card_rim_strength(point: Vector2, minion: bool, progress: float = 0.0) -> float:
	if not minion: return 1.0
	var local=(point-CARD_FACE_OFFSET)/CARD_FACE_SCALE
	var bottom=1.0-smoothstep(62.0,80.0,local.y)
	# The mana medallion interrupts the bright lip; keep its surrounding blue bloom.
	var mana=1.0-0.88*smoothstep(-48.0,-68.0,local.x)*smoothstep(-63.0,-87.0,local.y)
	return lerpf(bottom*mana,1.0,clampf(progress,0.0,1.0))

func _draw_held_card_rim(_c: Dictionary, _transform_progress: float = 0.0, _opacity: float = 1.0):
	# Retired traced cyan polylines. Held card uses original state6/7/8 selection
	# in classic_spatial; committed hand-out uses NativeSummonPlayer assets.
	pass

func _draw_card(c, index):
	if not face_render_mode and is_instance_valid(spatial_scene) and index >= -1: return
	var d = definitions[c.key]
	var face_pose=selected_card_face_pose(c) if c.has("phase") else {"pos":c.pos,"scale":Vector2.ONE*c.scale,"angle":c.angle}
	var card_transform=Transform2D(face_pose.angle, CARD_FACE_SCALE*face_pose.scale, 0.0, face_pose.pos+(CARD_FACE_OFFSET*face_pose.scale).rotated(face_pose.angle)+shake_offset)
	draw_target.draw_set_transform_matrix(card_transform)
	if not face_render_mode and card_face_textures.has(c.key):
		draw_target.draw_texture_rect(card_face_textures[c.key],Rect2(-82,-121,164,242),false)
		draw_target.draw_set_transform(shake_offset)
		return
	var minion = d.kind == "minion"
	var rect = Rect2(-78,-116,156,232)
	# Original neutral stone / mage spell material, not a generated gold frame.
	if minion:
		_portrait(d.art, Rect2(-51,-112,102,136),d.color)
	else:
		draw_target.draw_texture_rect(raw_portraits[d.art],Rect2(-65,-101,130,122),false)
	var frame_key=d.get("frame","frame-minion-neutral" if minion else "frame-spell-mage")
	if classic_ui.has(frame_key): draw_target.draw_texture_rect(classic_ui[frame_key],rect,false)
	else:
		draw_target.draw_texture_rect(classic_ui["frame-minion-neutral" if minion else "frame-spell-neutral"],rect,false,Color("b99bc7"))
		_text("职业框待补",Vector2(0,102),9,Color("873d4e"),true)
	if missing_portrait_indices.has(d.art): _text("原画待补",Vector2(0,-46),12,Color.WHITE,true)
	var name_key = "name-banner-minion" if minion else "name-banner-spell"
	draw_target.draw_texture_rect(classic_ui[name_key],Rect2(-63,-6,126,34),false)
	_card_title(d.name,Vector2(0,13),card_transform,minion)
	var lines = d.desc
	var first_y = 69 if lines.size()<2 else 61
	for k in range(lines.size()): _text(lines[k],Vector2(0,first_y+k*16),11,Color("29241e"),true)
	if d.has("race_name"):
		draw_target.draw_texture_rect(classic_ui["race-banner"],Rect2(-46,94,92,17),false)
		_stat_text(d.race_name,Vector2(0,106),9,Color.WHITE)
	_gem(Vector2(-61,-88),15,Color("2263af"),str(reference_hand_costs.get(c.key,d.cost)),25)
	if minion:
		_attack_badge(Vector2(-62,99),16,str(d.atk))
		_health_badge(Vector2(62,99),16,str(d.hp))
	draw_target.draw_set_transform(shake_offset)

func _draw_hover_type_label():
	if hover_card<0 or hover_card>=cards.size() or drag_index>=0: return
	var c=cards[hover_card]
	if c.scale<1.7: return
	var d=definitions[c.key]
	var p=c.pos+Vector2(0,(116*CARD_FACE_SCALE.y+CARD_FACE_OFFSET.y)*c.scale+3)
	var rect=Rect2(p+Vector2(-94,0),Vector2(188,30))
	_panel(rect,Color("7faad0"),Color("494c45"),4,3)
	draw_target.draw_line(rect.position+Vector2(6,4),rect.position+Vector2(182,4),Color("c1d1d4"),2,true)
	var label=("Minion" if d.kind=="minion" else "Spell") if reference_fixture else ("随从" if d.kind=="minion" else "法术")
	_text(label,p+Vector2(0,24),25,Color("1f2834"),true,true)

func _card_title(label: String, baseline: Vector2, card_transform: Transform2D, minion: bool):
	var latin = label.to_utf8_buffer().size() == label.length()
	var f = stat_font if latin else font
	var size=13
	while f.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>114 and size>9: size-=1
	var width=f.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var x=-width*0.5
	for i in range(label.length()):
		var letter=label.substr(i,1)
		var advance=f.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var u=(x+advance*0.5)/63.0
		var rise=-3.8*u+3.2*u*u if minion else 3.0*u*u
		var slope=(-3.8+6.4*u)/63.0 if minion else 6.0*u/63.0
		var at=baseline+Vector2(x,rise)
		draw_target.draw_set_transform_matrix(card_transform*Transform2D(atan(slope),at))
		draw_target.draw_string_outline(f,Vector2.ZERO,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size,2,Color("231d17"))
		draw_target.draw_string(f,Vector2.ZERO,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("fffbed"))
		x+=advance
	draw_target.draw_set_transform_matrix(card_transform)

func has_summoning_sleep(u: Dictionary) -> bool:
	# Fresh-summon waiting only. An exhausted attack is not sleep, and Frozen
	# has its own ice cue. This is visual bookkeeping, not the Dormant keyword.
	if u.is_empty() or game_over or help_visible or settings_visible: return false
	if not u.get("summoning_sick",false) or u.get("ready",false): return false
	if u.get("dead",true) or u.get("frozen",false) or u.get("hp",0)<=0: return false
	if u.get("hidden",false) or u.get("animating",false): return false
	var board=allies if u.get("side",-1)==0 else enemies
	return board.any(func(live):return is_same(live,u))

func sleep_z_samples(u: Dictionary, at_time: float = -1.0) -> Array:
	# Three overlapping lifetimes: each letter rises, grows, drifts, then fades.
	# Absolute-time sampling prevents frame-rate-dependent particle stepping.
	if not has_summoning_sleep(u): return []
	var t=indicator_time if at_time<0.0 else at_time
	var phase=u.get("indicator_phase",0.0)
	var samples: Array=[]
	for i in range(3):
		var age=fposmod(t/2.4+phase/TAU+float(i)/3.0,1.0)
		var alpha=smoothstep(0.0,0.12,age)*(1.0-smoothstep(0.72,1.0,age))
		var drift=sin(age*PI*1.65+phase)*3.0
		samples.append({"age":age,"pos":Vector2(40.0+age*25.0+drift,-44.0-age*63.0),
			"scale":0.62+age*0.58,"alpha":alpha,"tilt":-0.11+sin(age*PI+phase)*0.09})
	return samples

func _classic_shield_outline() -> PackedVector2Array:
	# Traced proportions from official 2013 footage: shallow top, broad shoulders,
	# near-vertical upper sides and an unlit lower point. No crown/spikes.
	var spans=[
		[Vector2(-68,-79),Vector2(-45,-82),Vector2(-23,-85),Vector2(0,-85)],
		[Vector2(0,-85),Vector2(23,-85),Vector2(45,-82),Vector2(68,-79)],
		[Vector2(68,-79),Vector2(69,-47),Vector2(69,4),Vector2(61,34)],
		[Vector2(61,34),Vector2(54,60),Vector2(25,83),Vector2(0,96)],
		[Vector2(0,96),Vector2(-25,83),Vector2(-54,60),Vector2(-61,34)],
		[Vector2(-61,34),Vector2(-69,4),Vector2(-69,-47),Vector2(-68,-79)]]
	var points=PackedVector2Array()
	for span in spans:
		for i in range(12):points.append(span[0].bezier_interpolate(span[1],span[2],span[3],float(i)/12.0))
	points.append(points[0])
	return points

func ready_glow_sample(_u: Dictionary, at_time: float = -1.0) -> Dictionary:
	# Native temporal samples do not justify v8's expanding ellipse, contour wobble
	# or orbiting highlight. Keep a stable frame-bound edge; sleep Zs remain animated.
	return {"time":indicator_time if at_time<0.0 else at_time,
		"energy":1.0,"width":1.0,"expand":0.0}

func ready_glow_outline(u: Dictionary, _sample: Dictionary, inset: float = 0.0) -> PackedVector2Array:
	var points=PackedVector2Array()
	if definitions[u.key].keyword=="嘲讽":
		# Open contour from left stat badge, over shield shoulders, to right badge.
		var spans=[
			[Vector2(-63,52),Vector2(-76,27),Vector2(-76,-43),Vector2(-75,-78)],
			[Vector2(-75,-78),Vector2(-75,-83),Vector2(-74,-85),Vector2(-69,-86)],
			[Vector2(-69,-86),Vector2(-44,-89),Vector2(-22,-91),Vector2(0,-91)],
			[Vector2(0,-91),Vector2(22,-91),Vector2(44,-89),Vector2(69,-86)],
			[Vector2(69,-86),Vector2(74,-85),Vector2(75,-83),Vector2(75,-78)],
			[Vector2(75,-78),Vector2(76,-43),Vector2(76,27),Vector2(63,52)]]
		for span in spans:
			for i in range(24):
				var p=span[0].bezier_interpolate(span[1],span[2],span[3],float(i)/24.0)
				points.append(p+p.normalized()*inset)
		points.append(Vector2(63,52)+Vector2(63,52).normalized()*inset)
	else:
		# About 265 degrees: lower portrait rim deliberately remains unlit.
		var start=PI-asin(51.0/83.0)
		var end=TAU+asin(51.0/83.0)
		for i in range(97):
			var angle=lerpf(start,end,float(i)/96.0)
			points.append(Vector2(cos(angle)*(66.0+inset),sin(angle)*(83.0+inset)-1.0))
	return points

func ready_glow_opacity(p: Vector2) -> float:
	# Official edge disappears into the stat badges, well before the lower tip.
	return 1.0-smoothstep(24.0,53.0,p.y)

func _draw_targeting():
	# v34 uses only recovered original targeting meshes and CIL motion.
	if is_instance_valid(native_targeting):return
	if _is_aiming():
		var origin=_aim_origin()
		var endpoint=target_feedback.get("pos",pointer) if target_feedback.get("status","")=="valid" else pointer
		_draw_segmented_arrow(origin,endpoint,1.0,target_feedback.get("status","")=="invalid",target_feedback.get("status","")=="valid")
		if target_feedback.get("status","")=="valid":
			_draw_target_reticle(endpoint,1.0)
		elif target_feedback.get("status","")=="invalid":
			_draw_prohibited(pointer,0.85,1.0+sin(elapsed*9)*0.04)
	for rejection in rejections:
		var t=1.0-rejection.life/rejection.max
		var alpha=1.0-t
		var p=rejection.p+Vector2(sin(t*38)*7*(1-t),0)
		if rejection.origin!=Vector2.ZERO and t<0.32:
			_draw_segmented_arrow(rejection.origin,rejection.origin.lerp(rejection.p,1.0-t/0.32),alpha*0.65,true)
		_draw_prohibited(p,alpha,1.0+sin(t*PI)*0.25)

func _draw_target_reticle(p: Vector2,alpha: float):
	draw_target.draw_arc(p+Vector2(3,4),32,0,TAU,48,Color(0.25,0.07,0.03,alpha*0.7),9,true)
	draw_target.draw_arc(p,32,0,TAU,48,Color(0.8,0.13,0.08,alpha),8,true)
	draw_target.draw_arc(p+Vector2(-1,-1),32,PI,PI*1.8,24,Color(1,0.39,0.18,alpha),2,true)
	draw_target.draw_arc(p,12,0,TAU,32,Color(0.88,0.2,0.12,alpha),3,true)

func _draw_prohibited(p: Vector2,alpha: float,scale_amt: float):
	var r=29*scale_amt
	draw_target.draw_circle(p,r+5,Color(0.13,0.035,0.02,0.92*alpha))
	draw_target.draw_arc(p,r,0,TAU,48,Color(1,0.24,0.15,alpha),5,true)
	draw_target.draw_line(p+Vector2(-r*0.7,r*0.7),p+Vector2(r*0.7,-r*0.7),Color(1,0.69,0.51,alpha),8,true)
	draw_target.draw_arc(p+Vector2(-1,-1),r,PI,PI*1.55,12,Color(1,0.72,0.45,alpha),2,true)

func _draw_segmented_arrow(origin: Vector2,destination: Vector2,alpha: float,invalid: bool = false,locked: bool = false):
	var delta=destination-origin
	if delta.length()<38:return
	var dir=delta.normalized()
	var normal=Vector2(-dir.y,dir.x)
	var count=maxi(0,int((delta.length()-80)/51))
	var flow=fmod(elapsed*1.6,1.0)
	var body=Color("a52c25") if invalid else Color("cf3d29")
	body.a=alpha
	var border=Color(0.29,0.1,0.055,alpha)
	for i in range(count):
		var t=(float(i)+flow)/maxf(count,1)
		var p=origin+delta.normalized()*(20+(i+flow)*(delta.length()-90)/maxf(count,1))+normal*sin(t*PI)*12
		var width=lerpf(24,15,t)
		var poly=PackedVector2Array([p-dir*17-normal*width,p+dir*17-normal*width,p+dir*17+normal*width,p-dir*17+normal*width])
		var shadow=PackedVector2Array()
		for point in poly: shadow.append(point+Vector2(3,5))
		draw_target.draw_colored_polygon(shadow,Color(0.28,0.055,0.025,alpha))
		draw_target.draw_colored_polygon(poly,body);draw_target.draw_polyline(poly+PackedVector2Array([poly[0]]),border,2,true)
		draw_target.draw_line(p-dir*14-normal*(width-2),p+dir*14-normal*(width-2),Color(1,0.48,0.25,alpha),3,true)
	var tip=destination-dir*27 if locked else destination
	var head=PackedVector2Array([tip+dir*8,tip-dir*29+normal*26,tip-dir*18,tip-dir*29-normal*26])
	draw_target.draw_colored_polygon(head,body);draw_target.draw_polyline(head+PackedVector2Array([head[0]]),border,3,true)
	draw_target.draw_line(head[0],head[1],Color(1,0.69,0.4,alpha),3,true)

func _drag_spell():
	return interaction_state==Interaction.SPELL_AIM

func _draw_effects(front):
	if not front:
		for r in ripples:
			var t = 1 - r.life / r.max
			var col = r.color; col.a = (1 - t) * 0.7
			draw_target.draw_arc(r.p, 12 + r.radius * t, 0, TAU, 64, col, 5 * (1 - t) + 1, true)
		for b in bolts:
			var t = 1 - b.life / b.max
			var pos = b.start.lerp(b.end, t) + Vector2(0, -sin(t * PI) * 100)
			for i in range(7):
				var tt = maxf(0, t - i * 0.025)
				var pp = b.start.lerp(b.end, tt) + Vector2(0, -sin(tt * PI) * 100)
				draw_target.draw_circle(pp, 18 - i * 2, Color(b.color, 0.8 - i * 0.1))
			_glow(pos, 35, b.color, 0.5)
			draw_target.draw_circle(pos, 9, Color("fff7df"))
	else:
		_draw_contact_and_death()
		for p in particles:
			var col = p.color; col.a = p.life / p.max
			if p.get("shape",0)==1:
				draw_target.draw_line(p.p,p.p-p.v.normalized()*p.size*3,col,1.5,true)
			elif p.get("shape",0)==2:
				var z=maxf(0.8,p.size*(p.life/p.max))
				draw_target.draw_colored_polygon(PackedVector2Array([p.p+Vector2(-z,-z*0.3),p.p+Vector2(z,-z),p.p+Vector2(z*0.7,z),p.p+Vector2(-z*0.6,z)]),col)
			else: draw_target.draw_circle(p.p,p.size*(0.5+p.life/p.max*0.5),col)
		for f in floats:
			var t = 1 - f.life / f.max
			var pos = f.p + Vector2(0, -maxf(0,t-0.6)*35)
			var scale_amt = 0.88 + sin(minf(1,t*5)*PI)*0.22
			draw_target.draw_set_transform(pos + shake_offset, 0, Vector2.ONE * scale_amt)
			var star = PackedVector2Array()
			for i in range(16):
				var a = i * TAU / 16
				star.append(Vector2(cos(a), sin(a)) * (40 if i % 2 == 0 else 29))
			draw_target.draw_colored_polygon(star, Color(0.92,0.63,0.16,minf(1,f.life*4)))
			draw_target.draw_polyline(star+PackedVector2Array([star[0]]),Color(0.28,0.16,0.04,minf(1,f.life*4)),3,true)
			_stat_text(f.text,Vector2(0,12),32,Color(f.color,minf(1,f.life*4)))
			draw_target.draw_set_transform(shake_offset)

func _draw_overlays():
	if hover_unit>=0 and not _is_aiming() and drag_index<0:
		var u=unit_by_id(hover_unit)
		if not u.is_empty():
			var d=definitions[u.key]
			var lines=PackedStringArray(["%d费  %d攻 / %d生命" % [d.cost,d.atk,d.hp]])
			for line in d.desc: lines.append(line)
			lines.append(d.card_id)
			_tooltip(Rect2(1100,650,300,44+lines.size()*23),d.name,lines)
	if not demo_caption.is_empty():
		_panel(Rect2(390,12,820,40),Color(0.09,0.07,0.045,0.9),Color("a58e64"),12,2)
		_text(demo_caption,Vector2(800,39),16,CREAM,true)
	# Original TurnStartIndicator owns its entry/exit timeline, triggered at turn start.
	if toast_time > 0:
		_text(toast, Vector2(800, 289), 19, Color("ffdf9d"), true)
	if game_over and not combat_replay.playing and not is_instance_valid(native_endgame):
		_text("平局" if game_tied else ("胜利！" if won else "对局结束"),Vector2(800,440),48,CREAM,true)
		_text("按 R 再战一局",Vector2(800,490),21,GOLD,true)

func _modal_base(title, subtitle):
	draw_target.draw_rect(Rect2(0, 0, W, H), Color(0.045, 0.026, 0.017, 0.8))
	_panel(Rect2(365, 225, 870, 620), Color("35251b"), GOLD.darkened(0.15), 24, 4)
	_text(title, Vector2(800, 292), 36, CREAM, true)
	_text(subtitle, Vector2(800, 326), 16, GOLD, true)
	draw_target.draw_line(Vector2(420, 344), Vector2(1180, 344), GOLD.darkened(0.5), 1)

func _button(rect, label):
	_panel(rect, Color("bd9555") if rect.has_point(pointer) else Color("967140"), Color("e0bd7d"), 10, 3)
	_text(label, rect.get_center() + Vector2(0, 9), 23, Color("fff0c5"), true)

func _tooltip(rect, title, lines):
	_panel(rect, Color(0.12, 0.075, 0.045, 0.96), GOLD.darkened(0.1), 10, 2)
	_text(title, rect.position + Vector2(16, 28), 17, CREAM)
	for i in range(lines.size()): _text(lines[i], rect.position + Vector2(16, 51 + i * 22), 13, GOLD)

var _panel_styles:Dictionary={}
func _panel(rect, color, border, radius, width):
	# Internal immutable draw resources; rect/transform remain per-call inputs.
	# Bound animated-color/style diversity instead of retaining it indefinitely.
	var key=[color,border,int(radius),int(width)]
	var style:StyleBoxFlat=_panel_styles.get(key)
	if style==null:
		if _panel_styles.size()>=64:_panel_styles.clear()
		style=StyleBoxFlat.new()
		style.bg_color=color;style.border_color=border
		style.set_corner_radius_all(radius);style.set_border_width_all(width)
		style.anti_aliasing=true;style.anti_aliasing_size=1.0
		_panel_styles[key]=style
	draw_target.draw_style_box(style,rect)

func _text(txt, baseline, size, color, center = false, serif = false):
	var f = (stat_font if txt.to_utf8_buffer().size()==txt.length() else title_font) if serif else font
	var pos = baseline
	if center: pos.x -= f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	# Tiny dark letterpress shadow keeps type crisp against illustrated textures.
	draw_target.draw_string(f, pos + Vector2(0, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.035, 0.02, 0.01, color.a * 0.65))
	draw_target.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _ellipse(center, radii, color):
	var points = PackedVector2Array()
	for i in range(64):
		var a = i * TAU / 64
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_target.draw_colored_polygon(points, color)

func _arc_ellipse(center, radii, color, width):
	var points = PackedVector2Array()
	for i in range(65):
		var a = i * TAU / 64
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_target.draw_polyline(points, color, width, true)

func _portrait(index, rect, fallback):
	# Native cards use the raw portrait and their own shader masks. Only the
	# compatibility face drawing path needs a separately masked texture.
	if index >= 0 and index < raw_portraits.size():
		var raw: Texture2D = raw_portraits[index]
		var id := raw.get_instance_id()
		if not masked_portraits.has(id):
			var image := raw.get_image()
			if image != null and not image.is_empty():
				preload("res://scripts/portrait_circle_mask.gd").apply(image)
				masked_portraits[id] = ImageTexture.create_from_image(image)
		if masked_portraits.has(id):
			draw_target.draw_texture_rect(masked_portraits[id], rect, false)
			return
	_ellipse(rect.get_center(), rect.size * 0.5, fallback.darkened(0.4))
	_ellipse(rect.get_center() + Vector2(0, -10), rect.size * Vector2(0.22, 0.25), fallback)
	_ellipse(rect.get_center() + Vector2(0, 32), rect.size * Vector2(0.34, 0.3), fallback.darkened(0.2))

func _gem(p, radius, color, label, text_size, text_color = Color.WHITE):
	if classic_ui.has("cost-mana") and label != "?":
		draw_target.draw_texture_rect(classic_ui["cost-mana"],Rect2(p-Vector2(radius,radius*1.04),Vector2(radius*2,radius*2.08)),false)
		_stat_text(label,p+Vector2(0,text_size*0.32),text_size,text_color)
		return
	draw_target.draw_circle(p + Vector2(2, 3), radius + 2, Color(0.08, 0.04, 0.025, 0.65))
	draw_target.draw_circle(p, radius + 1, Color("3d2d22"))
	draw_target.draw_circle(p, radius - 1, Color("cbb583"))
	draw_target.draw_circle(p, radius - 4, color)
	draw_target.draw_arc(p, radius - 5, PI * 1.06, PI * 1.83, 24, color.lightened(0.4), 3, true)
	draw_target.draw_circle(p + Vector2(-radius * 0.25, -radius * 0.35), radius * 0.22, Color(1, 1, 1, 0.12))
	_text(label, p + Vector2(0, text_size * 0.35), text_size, text_color, true, true)

func _diamond(p, radii, color, border):
	var pts = PackedVector2Array([p + Vector2(0, -radii.y), p + Vector2(radii.x, 0), p + Vector2(0, radii.y), p + Vector2(-radii.x, 0)])
	draw_target.draw_colored_polygon(pts, color)
	draw_target.draw_colored_polygon(PackedVector2Array([p, pts[0], pts[1]]), color.lightened(0.24))
	draw_target.draw_polyline(pts + PackedVector2Array([pts[0]]), border, 1.5, true)

func _glow(p, radius, color, alpha):
	for i in range(8, 0, -1):
		var ratio = i / 8.0
		draw_target.draw_circle(p, radius * ratio, Color(color, alpha * (1 - ratio) * 0.3))

func _card_back(rect):
	if classic_ui.has("cardback"): draw_target.draw_texture_rect(classic_ui.cardback,rect,false)
	else: _panel(rect,Color("385179"),Color("c3a14e"),7,3)

func _next_audio_scope(kind: String) -> String:
	_audio_action_sequence += 1
	return kind + ":" + str(_audio_action_sequence)

func _begin_spell_audio_preview(key: String):
	if _audio_spell_preview.get("key","") == key: return
	_cancel_spell_audio_preview()
	var scope = _next_audio_scope("spell")
	_audio_spell_preview = {"key":key,"scope":scope}
	if is_instance_valid(native_combat):native_combat.prepare_spell(key,POWER_POS if key=="CS2_034" else PLAYER_HERO,0)
	_spell_audio(key,"precast",scope)

func _cancel_spell_audio_preview():
	if is_instance_valid(native_combat):native_combat.cancel_prepared_spell()
	if _audio_spell_preview.is_empty(): return
	var preview = _audio_spell_preview
	_audio_spell_preview = {}
	_spell_audio(preview.key,"cancel",preview.scope)
	# The explicit source stop/fade actions handle original loop tails.
	_finish_spell_scope(preview.scope)

func _take_spell_audio_scope(key: String,side: int=0) -> String:
	if _audio_spell_preview.get("key","") == key:
		var scope = str(_audio_spell_preview.scope)
		_audio_spell_preview = {}
		return scope
	_cancel_spell_audio_preview()
	var scope = _next_audio_scope("spell")
	_audio_scope_sides[scope]=side
	# Non-pointer/AI execution still has the effect's Birth before Action.
	_spell_audio(key,"precast",scope)
	return scope

func _card_audio(card_id: String, event: String, context: Dictionary = {}):
	if not sound_enabled: return
	if SoundManager.has_original_event(card_id,event):
		SoundManager.play_original_event(card_id,event,context)
		if context.has("scope_id"): SoundManager.original_audio.finish_scope(context.scope_id)
	elif event in ["play","attack","death"]:
		# Explicit legacy card-bound assets only, never another character's sound.
		SoundManager.play_card_sound(card_id,event)

func _spell_audio(card_id: String, event: String, scope: String, options: Dictionary = {}) -> Dictionary:
	if not sound_enabled: return {}
	var root_scope = ":".join(scope.split(":").slice(0,2))
	var context = {"scope_id":scope,"event_token":event,"state":event,"source_side":_audio_scope_sides.get(root_scope,0)}
	context.merge(options,true)
	if event == "release":
		context.delay_sec = float(context.get("delay_sec",0)) + float(SoundManager.original_audio.catalog.get("cards",{}).get(card_id,{}).get("start_action_completion",{}).get("delay_sec",0))
	return SoundManager.play_original_event(card_id,event,context)

func _finish_spell_scope(scope: String):
	SoundManager.original_audio.finish_scope(scope)
	_audio_scope_sides.erase(scope)

func _audio_has_role(key: String, event: String, roles: Array) -> bool:
	var route = SoundManager.original_audio.catalog.get("cards",{}).get(key,{}).get("events",{}).get(event,{})
	for layer in route.get("layers",[]) + route.get("stops",[]):
		if layer.get("stage_role","") in roles: return true
	return false

func _audio_hit_targets(key: String, scope: String, targets: Array, delay: float = 0.0, origin: Dictionary = {}) -> Dictionary:
	var delays = {}
	if _audio_has_role(key,"hit",["area","caster_impact","start"]):
		_spell_audio(key,"hit",scope,{"stage_filter":["area","caster_impact","start"],"delay_sec":delay,"event_token":"hit:area"})
	if not _audio_has_role(key,"hit",["impact"]): return delays
	for i in range(targets.size()):
		var target = targets[i]
		var target_scope = scope + ":impact:" + str(i)
		var id = int(target.unit.id) if target.get("type","") == "unit" else -1-int(target.get("side",0))
		var options = {"stage_filter":["impact"],"delay_sec":delay,"target_id":id,"target_position":target.get("pos",Vector2.ZERO)}
		options.merge(origin,true)
		var request = _spell_audio(key,"hit",target_scope,options)
		delays[id] = float(request.get("first_delay_sec",delay))
		SoundManager.original_audio.finish_scope(target_scope)
	return delays

func _audio_actor(unit_id: int, card_id: String, spell_type: int, delay: float = 0.0, defer_frames: int = 0, origin: Dictionary = {}):
	if not sound_enabled: return
	var scope = "actor:" + str(unit_id) + ":" + str(spell_type)
	var options = {"scope_id":scope,"card_id":card_id,"unit_id":unit_id,"delay_sec":delay,"defer_frames":defer_frames,"event_token":"actor"}
	options.merge(origin,true)
	SoundManager.play_original_event("@actor","type_"+str(spell_type),options)
	SoundManager.original_audio.finish_scope(scope)

func _audio_hand_actor(unit: Dictionary, entering: bool):
	var cost = int(definitions[unit.key].cost)
	var types = [2,42] if entering else [1,1]
	if cost >= 7: types = [25,69] if entering else [23,1]
	elif cost >= 4: types = [24,68] if entering else [22,1]
	if entering: _audio_actor(unit.id,unit.key,int(types[unit.side]))
	elif sound_enabled:
		var scope = "hand:"+str(unit.id)
		SoundManager.play_original_event("@hand","type_"+str(types[unit.side]) if unit.side == 0 else "hidden_out",{"scope_id":scope,"card_id":unit.key,"unit_id":unit.id,"source_side":unit.side})
		SoundManager.original_audio.finish_scope(scope)

func _audio_death_actor(unit: Dictionary):
	# v35 source Birth owns type5 audio. Never also enqueue the retired timing path.
	if is_instance_valid(native_death):return
	if not _audio_resolution.is_empty():
		_audio_resolution.deaths.append({"key":unit.key,"id":unit.id,"damage_index":maxi(0,_audio_resolution.targets.size()-1),"kind":"actor"})
	else: _audio_actor(unit.id,unit.key,5)

func _audio_death(unit: Dictionary):
	if is_instance_valid(native_death):native_death.queue_voice(unit);return
	if not _audio_resolution.is_empty():
		_audio_resolution.deaths.append({"key":unit.key,"id":unit.id,"damage_index":maxi(0,_audio_resolution.targets.size()-1),"kind":"character"})
	else:
		_card_audio(unit.key,"death",{"scope_id":"unit:" + str(unit.id),"event_token":"death","unit_id":unit.id})

func _audio_flush_deaths(deaths: Array, delays: Dictionary, origin: Dictionary = {}):
	for entry in deaths:
		if entry.get("kind","") == "actor":
			_audio_actor(entry.id,entry.key,5,float(delays.get(entry.id,0.0)),1,origin); continue
		var options = {"scope_id":"unit:" + str(entry.id),"event_token":"death","unit_id":entry.id,"delay_sec":float(delays.get(entry.id,0.0)),"defer_frames":1}
		options.merge(origin,true)
		_card_audio(entry.key,"death",options)

func _audio_missile_flight(key: String, scope: String) -> float:
	var catalog = SoundManager.original_audio.catalog.cards.get(key,{})
	var setting = catalog.get("missile_sequence",{})
	var birth_wait = 0.0
	for layer in catalog.get("events",{}).get("launch",{}).get("layers",[]):
		birth_wait = maxf(birth_wait,SoundManager.original_audio._sample_delay(layer,scope))
	# OnMissileSpellStateFinished only starts FireMissileOnPath after Birth.
	return birth_wait + SoundManager.original_audio.random.randf_range(float(setting.get("path_duration_min",0)),float(setting.get("path_duration_max",0)))

func _audio_missile_sequence(key: String, scope: String, observed: Dictionary, elapsed_since_launch: float):
	var settings = SoundManager.original_audio.catalog.cards.get(key,{}).get("missile_sequence",{})
	var minimum = float(settings.get("path_duration_min",0.5)); var maximum = float(settings.get("path_duration_max",0.7))
	var arrival = 0.0
	var death_delays = {}
	for i in range(observed.targets.size()):
		var target = observed.targets[i]
		var shot_scope = scope if i == 0 else scope + ":missile:" + str(i)
		if i > 0: _spell_audio(key,"launch",shot_scope,{"delay_sec":maxf(0,arrival-elapsed_since_launch),"event_token":"launch:"+str(i),"skip_spawn_delay":true})
		if i == observed.targets.size()-1: _spell_audio(key,"release",scope,{"delay_sec":maxf(0,arrival-elapsed_since_launch)})
		arrival += SoundManager.original_audio.random.randf_range(minimum,maximum)
		var delay = maxf(0,arrival-elapsed_since_launch)
		_audio_hit_targets(key,shot_scope,[target],delay)
		for entry in observed.deaths:
			if entry.damage_index == i: death_delays[entry.id] = delay
		SoundManager.original_audio.finish_scope(shot_scope)
	_audio_flush_deaths(observed.deaths,death_delays)
	_finish_spell_scope(scope)

func _announce_attack_audio(unit: Dictionary):
	if _audio_selected_attack_id == unit.id: return
	_audio_selected_attack_id = unit.id
	_card_audio(unit.key,"attack",{"scope_id":"aim:" + str(unit.id),"unit_id":unit.id})

func _use_life_tap_with_audio(side: int):
	var history_id=_history_begin_play("CS2_056",side)
	var scope = _next_audio_scope("power")
	_audio_scope_sides[scope] = side
	_spell_audio("CS2_056","cast",scope)
	_spell_audio("CS2_056","launch",scope)
	busy=true
	var target: Dictionary={"type":"hero","side":side,"pos":PLAYER_HERO if side==0 else ENEMY_HERO}
	native_combat.begin_spell("CS2_056",POWER_POS if side==0 else Vector2(948,196),target,side,func():
		rules.use_power(side);_finish_spell_scope(scope),
		func():_history_complete(history_id);busy=false;_check_victory(),func():_spell_audio("CS2_056","hit",scope))

func play_sound(kind):
	if source_projection!=null and kind in ["mana","mana_refresh"]:return # Original source manager/live queue owns these events.
	if native_initial_loading:
		native_initial_sounds.append(kind);return
	if sound_enabled: SoundManager.play_sfx(kind)

func get_state():
	var state = {"turn": turn, "player_turn": player_turn, "busy": busy, "health": health.duplicate(), "mana": mana, "max_mana": max_mana, "hand": [], "allies": [], "enemies": [], "game_over": game_over, "won": won, "selected": selected_unit, "drag_index": drag_index, "power_used": power_used, "hover_card": hover_card,"staged_cards":staged_cards.size(),"death_ghosts":death_ghosts.size(),"demo_step":demo_step,"event_trace":event_trace,"native_combat":native_combat.get_audit() if is_instance_valid(native_combat) else {},"native_damage":native_damage.get_audit() if is_instance_valid(native_damage) else {},"native_death":native_death.get_audit() if is_instance_valid(native_death) else {},"native_endgame":native_endgame.get_audit() if is_instance_valid(native_endgame) else {},"native_targeting":native_targeting.get_audit() if is_instance_valid(native_targeting) else {},"native_status":native_status.get_audit() if is_instance_valid(native_status) else {},"native_highlight":native_highlight.get_audit() if is_instance_valid(native_highlight) else {},"native_summon":native_summon.get_audit() if is_instance_valid(native_summon) else {},"interaction_state":Interaction.keys()[interaction_state],"preview_index":preview_index,"target_status":target_feedback.get("status","none"),"rejections":rejections.size(),"returning_cards":cards.filter(func(c):return c.get("returning",false)).size()}
	for c in cards: state.hand.append(c.key)
	for u in allies: state.allies.append({"id": u.id, "key": u.key, "hp": u.hp, "ready": u.ready, "frozen": u.frozen, "can_attack":can_attack(u), "attack_ready_glow":has_attack_ready_glow(u), "summoning_sleep":has_summoning_sleep(u), "charge_announced":u.get("charge_announced",false), "pos": [u.pos.x, u.pos.y]})
	for u in enemies: state.enemies.append({"id": u.id, "key": u.key, "hp": u.hp, "ready": u.ready, "frozen": u.frozen, "can_attack":can_attack(u), "attack_ready_glow":has_attack_ready_glow(u), "summoning_sleep":has_summoning_sleep(u), "charge_announced":u.get("charge_announced",false), "pos": [u.pos.x, u.pos.y]})
	if is_instance_valid(native_rope_host):state["source_rope"]=native_rope_host.get_audit()
	state.merge({"mode":flow.mode,"phase":flow.phase,"first_side":flow.first_side,"opening_hand":flow.opening_hand,"mulligan_selected":flow.selected,"deck_count":deck.size(),"enemy_deck_count":enemy_deck.size(),"enemy_hand_count":enemy_hand.size(),"enemy_mana":enemy_mana,"enemy_max_mana":enemy_max_mana,"turn_clock":turn_clock,"timeout_pending":flow.timeout_pending,"game_tied":game_tied,"match_seed":flow.seed_value})
	return state

func save_screenshot():
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var folder = "user://captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path = folder + "/screenshot_%s.png" % Time.get_unix_time_from_system()
	var error = image.save_png(path)
	print("SCREENSHOT ", path, " status=", error)

func _demo():
	# A repeatable real-engine interaction pass, exercising the live action methods.
	if demo_step==0 and demo_clock>0.6:
		var c=cards.pop_back();_add_card(c.key,true);demo_step=1
	elif demo_step==1 and demo_clock>2.6:
		pointer=cards[2].pos;demo_step=2
	elif demo_step==2 and demo_clock>3.7:
		drag_index=2;play_sound("pickup");demo_step=3
	elif demo_step==3:
		pointer=pointer.lerp(Vector2(890,680),0.1)
		if demo_clock>4.8:cancel_interaction();pointer=Vector2(450,720);demo_step=4
	elif demo_step==4 and demo_clock>5.8:
		pointer=cards[4].pos;demo_step=5
	elif demo_step==5 and demo_clock>6.5:
		drag_index=4;play_sound("pickup");demo_step=6
	elif demo_step==6:
		pointer=pointer.lerp(Vector2(810,548),0.09)
		if demo_clock>7.5:drag_index=-1;play_card(4,Vector2(810,548));demo_step=7
	elif demo_step==7 and demo_clock>9.2 and not busy:
		selected_unit=allies[0].id;pointer=allies[0].pos;demo_step=8
	elif demo_step==8:
		pointer=pointer.lerp(enemies[0].pos,0.1)
		if demo_clock>10.3:_resolve_target(enemies[0].pos);demo_step=9
	elif demo_step==9 and demo_clock>12 and not busy:
		for u in allies:
			if u.key=="CS2_124":selected_unit=u.id;pointer=u.pos
		demo_step=10
	elif demo_step==10:
		pointer=pointer.lerp(enemies[0].pos,0.1)
		if demo_clock>13:_resolve_target(enemies[0].pos);demo_step=11
	elif demo_step==11 and demo_clock>15:
		pointer=Vector2(1350,450);end_turn();demo_step=12
	elif demo_step==12 and player_turn and not busy and demo_clock>22.0 and banner_time<0.5 and not cards.any(func(c):return c.get("drawing",false)):
		var index=-1
		for i in range(cards.size()):
			if cards[i].key=="CS2_029":index=i;break
		if index>=0:drag_index=index;pointer=cards[index].pos;play_sound("pickup")
		demo_step=13
	elif demo_step==13:
		pointer=pointer.lerp(ENEMY_HERO,0.07)
		if pointer.distance_to(ENEMY_HERO)<12 and drag_index>=0:
			var idx=drag_index;drag_index=-1;play_card(idx,ENEMY_HERO);demo_step=14
	elif demo_step==14 and not busy:
		pointer=Vector2(1120,780);demo_step=15

func _arch_shape(r):
	var pts=PackedVector2Array([Vector2(-r.x,r.y),Vector2(-r.x,-r.y*0.23)])
	for i in range(25):
		var a=PI+PI*i/24
		pts.append(Vector2(cos(a)*r.x,-r.y*0.23+sin(a)*r.y*0.77))
	pts.append(Vector2(r.x,r.y))
	return pts

func _health_badge(p,r,label,col=Color.WHITE):
	if classic_ui.has("health"):
		draw_target.draw_texture_rect(classic_ui["health"],Rect2(p-Vector2(r*0.85,r*1.38),Vector2(r*1.7,r*2.45)),false)
		_badge_number(label,p+Vector2(0,r*0.54),r,col)
		return
	# Classic health reads as an upward-pointed drop, with a full rounded base.
	# Smooth curves and directional vertex colours give the small gem real volume.
	var edge=_stat_drop_contour(p,r)
	var inset=_stat_drop_contour(p,r*0.86)
	var shadow=PackedVector2Array()
	for v in edge: shadow.append(v+Vector2(r*0.07,r*0.12))
	draw_target.draw_colored_polygon(shadow,Color(0.04,0.025,0.018,0.72))
	draw_target.draw_colored_polygon(edge,Color("20221c"))
	_stat_bevel_ring(edge,inset,p,r,Color("c6b894"),Color("343b30"))
	_stat_domed_face(inset,p+Vector2(-r*0.16,r*0.16),Color("fa4e26"),Color("7b1014"),Color("a91814"),p,r)
	# A darker ruby tip and a soft amber reflection low on the left, as in the
	# reference's sculpted gem; neither is an independent animated state effect.
	var shine=PackedVector2Array()
	for i in range(29,43): shine.append(inset[i])
	draw_target.draw_polyline(shine,Color(1.0,0.53,0.23,0.72),maxf(0.9,r*0.075),true)
	var glint=PackedVector2Array()
	for i in range(34,39): glint.append(inset[i]+Vector2(r*0.055,0))
	draw_target.draw_polyline(glint,Color(1.0,0.86,0.55,0.8),maxf(0.8,r*0.055),true)
	_badge_number(label,p+Vector2(0,r*0.54),r,col)

func _attack_badge(p,r,label):
	if classic_ui.has("attack-minion"):
		draw_target.draw_texture_rect(classic_ui["attack-minion"],Rect2(p-Vector2(r*1.07,r*1.2),Vector2(r*2.14,r*2.4)),false)
		_badge_number(label,p+Vector2(0,r*0.54),r,Color.WHITE)
		return
	# Rounded gold medallion with the two diagonal metal spurs visible on the
	# classic icon. The old eight-point flat star deliberately is not reused.
	var edge=PackedVector2Array()
	var inset=PackedVector2Array()
	for i in range(64):
		var a=TAU*i/64.0
		edge.append(p+Vector2(cos(a),sin(a)*0.98)*r)
		inset.append(p+Vector2(cos(a),sin(a)*0.98)*r*0.79)
	_ellipse(p+Vector2(r*0.08,r*0.12),Vector2(r*1.04,r),Color(0.045,0.03,0.018,0.76))
	draw_target.draw_colored_polygon(edge,Color("24271d"))
	_stat_bevel_ring(edge,inset,p,r,Color("c2b993"),Color("434632"))
	_stat_domed_face(inset,p+Vector2(-r*0.22,r*0.14),Color("fff3a1"),Color("bc8416"),Color("e9b82c"),p,r)
	# Convex inner gold reflection, with an irregularly lit dark-gold bezel.
	draw_target.draw_arc(p,r*0.72,PI*0.70,PI*1.06,16,Color(1.0,0.91,0.39,0.92),maxf(1.1,r*0.10),true)
	draw_target.draw_arc(p,r*0.72,-PI*0.42,-PI*0.08,16,Color(0.50,0.31,0.055,0.76),maxf(0.9,r*0.065),true)
	for flip in [-1.0,1.0]:
		var spur=PackedVector2Array([p+Vector2(0.58,0.42)*r*flip,p+Vector2(0.96,0.35)*r*flip,p+Vector2(1.02,1.03)*r*flip,p+Vector2(0.42,0.81)*r*flip])
		draw_target.draw_colored_polygon(spur,Color("24271e"))
		var a=p+Vector2(0.61,0.48)*r*flip
		var b=p+Vector2(0.89,0.42)*r*flip
		var tip=p+Vector2(0.92,0.92)*r*flip
		var c=p+Vector2(0.50,0.76)*r*flip
		draw_target.draw_polygon(PackedVector2Array([a,b,tip]),PackedColorArray([Color("d2c9a8"),Color("8c8d73"),Color("bfc2a3")]))
		draw_target.draw_polygon(PackedVector2Array([a,tip,c]),PackedColorArray([Color("aea98b"),Color("565e4d"),Color("3d4436")]))
	_badge_number(label,p+Vector2(0,r*0.54),r,Color.WHITE)

func _stat_drop_contour(p,r):
	var pts=PackedVector2Array()
	var segments=[
		[Vector2(0.10,-1.43),Vector2(0.18,-0.93),Vector2(0.77,-0.39),Vector2(0.77,0.19)],
		[Vector2(0.77,0.19),Vector2(0.78,0.73),Vector2(0.43,0.96),Vector2(0.0,0.96)],
		[Vector2(0.0,0.96),Vector2(-0.49,0.96),Vector2(-0.79,0.72),Vector2(-0.77,0.19)],
		[Vector2(-0.77,0.19),Vector2(-0.76,-0.37),Vector2(-0.16,-0.98),Vector2(0.10,-1.43)]
	]
	for seg in segments:
		for i in range(12):
			var t=i/12.0
			var q=1.0-t
			pts.append(p+r*(seg[0]*q*q*q+3.0*seg[1]*q*q*t+3.0*seg[2]*q*t*t+seg[3]*t*t*t))
	return pts

func _stat_bevel_ring(edge,inset,p,r,light,shade):
	for i in range(edge.size()):
		var j=(i+1)%edge.size()
		var direction=((edge[i]+edge[j])*0.5-p).normalized()
		var lit=clampf((direction.dot(Vector2(-0.63,-0.78))+1.0)*0.5,0.0,1.0)
		var outer=shade.darkened(0.43).lerp(light,lit*0.77)
		var inner=shade.lerp(light,lit*0.56+0.17)
		draw_target.draw_polygon(PackedVector2Array([edge[i],edge[j],inset[j],inset[i]]),PackedColorArray([outer,outer,inner,inner]))
	# Hairline inner crevice makes the metal rim sit above the coloured glass.
	draw_target.draw_polyline(inset+PackedVector2Array([inset[0]]),Color(0.075,0.052,0.021,0.85),maxf(0.75,r*0.045),true)

func _stat_domed_face(edge,center,bright,dark,mid,p,r):
	# A triangle fan interpolates the highlights continuously rather than piling
	# up flat discs, so all scales retain the same softly rounded shading.
	for i in range(edge.size()):
		var j=(i+1)%edge.size()
		var ca=_stat_face_edge(edge[i],p,r,dark,mid)
		var cb=_stat_face_edge(edge[j],p,r,dark,mid)
		draw_target.draw_polygon(PackedVector2Array([center,edge[i],edge[j]]),PackedColorArray([bright,ca,cb]))

func _stat_face_edge(v,p,r,dark,mid):
	var d=(v-p)/r
	var light=clampf(0.35-d.x*0.38+d.y*0.24,0.0,1.0)
	return dark.lerp(mid,light)

func _badge_number(label,pos,r,col):
	var size=int(round(r*1.88))
	var f=stat_font if stat_font else title_font
	while size>12 and f.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>r*1.58:
		size-=1
	_stat_text(label,pos,size,col)

func _stat_text(txt,pos,size,col):
	var f=(font if txt.to_utf8_buffer().size()!=txt.length() else stat_font) if stat_font else title_font
	var sz=f.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
	var v=pos-Vector2(sz.x*0.5,0)
	var outline=maxi(2,int(round(size*0.07)))
	# Belwe from the official current website; not verified as the 2013 font file.
	# Dark relief, an ivory face, and a narrow upper lip keep the numbers legible.
	var face=Color("fff4d8") if col.is_equal_approx(Color.WHITE) else col
	face.a=col.a
	draw_target.draw_string_outline(f,v+Vector2(0,size*0.045),txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline+1,Color(0.045,0.026,0.013,col.a))
	draw_target.draw_string_outline(f,v,txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline,Color(0.075,0.040,0.019,col.a))
	draw_target.draw_string(f,v,txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size,face.darkened(0.28))
	draw_target.draw_string(f,v+Vector2(-size*0.009,-size*0.025),txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size,face)

func _event(name):
	# Rule heal() has an explicit side/amount event after its presentation append.
	# Bridge that presentation only, without editing the historical rules module.
	if str(name).begins_with("heal_") and is_instance_valid(native_damage):
		var bits: PackedStringArray=str(name).split("_")
		if bits.size()==3:
			var side: int=int(bits[1]);var amount: int=int(bits[2])
			if amount>0:
				if not floats.is_empty() and floats[-1].text=="+"+str(amount):floats.pop_back()
				native_damage.record({"type":"hero","side":side,"pos":PLAYER_HERO if side==0 else ENEMY_HERO},-amount,int(health[side])-amount,int(health[side]),{"kind":"heal"})
	event_trace.append({"time":snappedf(elapsed,0.001),"event":name,"frame":Engine.get_process_frames()})

func _surface_dust(p,count):
	for i in range(count):
		var a=rng.randf()*TAU
		var life=rng.randf_range(0.3,0.6)
		particles.append({"p":p+Vector2(cos(a)*40,sin(a)*15+40),"v":Vector2(cos(a)*rng.randf_range(40,100),rng.randf_range(-45,10)),"life":life,"max":life,"size":rng.randf_range(2,5),"color":Color("b6a181"),"gravity":130,"shape":2})

func _contact_sparks(p,dir,count):
	for i in range(count):
		var v=dir.rotated(rng.randf_range(-1.25,1.25))*rng.randf_range(120,350)
		var life=rng.randf_range(0.12,0.32)
		particles.append({"p":p,"v":v,"life":life,"max":life,"size":rng.randf_range(2,5),"color":Color("ffebac"),"gravity":10,"shape":1})

func _draw_staged_cards():
	for c in staged_cards:
		var phase: String=c.phase
		var t: float=c.phase_t
		if phase=="card" or phase=="outline":
			_draw_card(c,-3)
			# Preserve the recognizable face throughout the blue transformation.
			var face_pose=selected_card_face_pose(c)
			draw_target.draw_set_transform(face_pose.pos+shake_offset,face_pose.angle,face_pose.scale)
			var path=_card_surface_outline()
			var age=maxf(0.0,elapsed-float(c.get("release_started",elapsed)))
			var light=smoothstep(0.06,0.28,age)
			if card_face_textures.has(c.key):
				draw_target.draw_texture_rect(card_face_textures[c.key],Rect2(-82,-121,164,242),false,Color(0.78,1.40,1.75,light))
			draw_target.draw_colored_polygon(path,Color(0.10,0.53,1.0,0.12*light))
			_draw_held_card_rim(c,t)
		elif phase=="morph":
			_draw_release_shell_interior(c)
			# Oval is already visible at full size; only its former card shell dissolves.
			var face_pose=selected_card_face_pose(c)
			draw_target.draw_set_transform(face_pose.pos+shake_offset,face_pose.angle,face_pose.scale)
			var path=_card_surface_outline()
			if card_face_textures.has(c.key): draw_target.draw_texture_rect(card_face_textures[c.key],Rect2(-82,-121,164,242),false,Color(0.60,0.95,1.0,0.08*(1-t)))
			draw_target.draw_colored_polygon(path,Color(0.70,0.98,1.0,0.025*(1-t)))
			_draw_held_card_rim(c,1.0,0.55*(1-t))
		elif phase=="impact":
			draw_target.draw_set_transform(c.pos+shake_offset)
			_arc_ellipse(Vector2.ZERO,Vector2(51,66),Color(0.30,0.83,1.0,0.22*(1-t)),3*(1-t)+1)
			_arc_ellipse(Vector2(0,-1),Vector2(49,64),Color(0.82,1.0,1.0,0.16*(1-t)),1)
		draw_target.draw_set_transform(shake_offset)

func _draw_release_shell_interior(c: Dictionary):
	# Translucent pale shell is normal-alpha composited so the warm board cannot
	# saturate an additive fill into a flat cream rectangle. Its narrow lip is
	# still additive in the independent effect layer.
	if not is_instance_valid(release_fx):return
	var age=maxf(0.0,elapsed-float(c.get("release_started",elapsed)))
	var strength=float(release_fx.phase_values(age).shell)
	if strength<=0.0:return
	var pose=selected_card_face_pose(c)
	draw_target.draw_set_transform(pose.pos+shake_offset,pose.angle,pose.scale)
	var outer=_card_surface_outline()
	var center=Vector2(2,-48)
	var inner=PackedVector2Array()
	for point in outer:
		var d=point-center
		var k=1.0/sqrt(pow(d.x/53.0,2)+pow(d.y/70.0,2))
		inner.append(center+d*k)
	for i in range(outer.size()):
		var j=(i+1)%outer.size()
		var edge_a=(0.66+0.10*sin(outer[i].y*0.11+outer[i].x*0.08+age*10.0))*strength
		var edge_b=(0.66+0.10*sin(outer[j].y*0.11+outer[j].x*0.08+age*10.0))*strength
		var outer_a=Color(0.77,0.96,1.0,edge_a)
		var outer_b=Color(0.77,0.96,1.0,edge_b)
		var center_color=Color(0.75,0.90,0.94,0.42*strength)
		var triangles=[PackedVector2Array([outer[i],outer[j],inner[j]]),PackedVector2Array([outer[i],inner[j],inner[i]])]
		var colors=[PackedColorArray([outer_a,outer_b,center_color]),PackedColorArray([outer_a,center_color,center_color])]
		for k in range(2):
			var tri:PackedVector2Array=triangles[k]
			if absf((tri[1]-tri[0]).cross(tri[2]-tri[0]))>0.01:draw_target.draw_polygon(tri,colors[k])
	draw_target.draw_set_transform(shake_offset)

func _draw_contact_and_death():
	for f in impacts:
		var t=1-f.life/f.max
		var dir=f.dir;var n=Vector2(-dir.y,dir.x)
		var scale_amt=1+sin(t*PI)*0.35
		var shape=PackedVector2Array([f.p-dir*70*scale_amt,f.p-dir*10-n*12,f.p-n*45*scale_amt,f.p+dir*13-n*7,f.p+dir*77*scale_amt,f.p+dir*8+n*9,f.p+n*38*scale_amt,f.p-dir*12+n*8])
		draw_target.draw_colored_polygon(shape,Color(1,0.96,0.72,(1-t)*0.95))
	for g in death_ghosts:
		var t=1-g.life/g.max
		for i in range(12):
			var a=TAU*i/12;var b=TAU*(i+1)/12
			var center=Vector2(sin(i*13.7+g.seed)*9,cos(i*9.3+g.seed)*8)
			var local=PackedVector2Array([center,Vector2(cos(a)*53,sin(a)*66),Vector2(cos(b)*53,sin(b)*66)])
			var uv=PackedVector2Array()
			for point in local:uv.append((point+Vector2(54,67))/Vector2(108,134))
			var velocity=Vector2(cos((a+b)*0.5)*(52+fmod(i*31.7,49)),sin((a+b)*0.5)*(35+fmod(i*23.3,30))-25)
			draw_target.draw_set_transform(g.p+velocity*t+Vector2(0,t*t*95)+shake_offset,(i%3-1)*t*0.8,Vector2.ONE*0.9)
			draw_target.draw_polygon(local,PackedColorArray([Color(0.75,0.71,0.61,1-t)]),uv,raw_portraits[g.art])
			draw_target.draw_line(local[1],local[2],Color(0.4,0.42,0.34,1-t),3,true)
		draw_target.draw_set_transform(shake_offset)

# Android Back cancels the active gesture instead of losing the match.
func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		cancel_interaction()

func _spend_mana(cost:int,side:int=0):
	var temporary=mini(cost,int(flow.temporary_mana[side])) if flow!=null else 0
	if flow!=null:flow.temporary_mana[side]-=temporary
	if side==0:mana-=cost
	else:enemy_mana-=cost
	if source_phone_layout!=null:
		source_phone_layout.record_mana_spend(side,cost,temporary)

func _clear_temporary_mana(side:int):
	if flow==null:return
	var temporary=int(flow.temporary_mana[side])
	if side==0:mana=maxi(0,mana-temporary)
	else:enemy_mana=maxi(0,enemy_mana-temporary)
	flow.temporary_mana[side]=0

func _sync_source_mana_proposal():
	if not is_instance_valid(source_mana_controller):return
	var candidate=-1
	var cost=0
	if source_projection!=null and player_turn and not busy and not game_over and flow.accepts_actions() and drag_index<0 and selected_unit<0 and not targeting_power and pending_battlecry.is_empty() and hover_card>=0 and hover_card<cards.size():
		var card=cards[hover_card];var definition=definitions[card.key]
		var valid=int(definition.cost)<=mana and not card.get("drawing",false) and not card.get("returning",false) and not card.get("source_alternate_cost",false)
		if definition.kind=="minion" or card.key=="CS2_027":valid=valid and allies.size()<7
		if valid and rules.needs_target(card.key):
			valid=false
			for side in range(2):
				if rules.legal_target(card.key,{"type":"hero","side":side,"pos":PLAYER_HERO if side==0 else ENEMY_HERO},0):valid=true
			for unit in allies+enemies:
				if rules.legal_target(card.key,{"type":"unit","unit":unit,"pos":unit.pos},0):valid=true
		if valid and card.has("source_presentation_id"):
			candidate=int(card.source_presentation_id);cost=int(definition.cost)
	# Original CardButton branch includes the local hero power; reserve a stable
	# local presentation identity, not a fabricated server EntityID.
	if candidate<0 and source_projection!=null and player_turn and not busy and not game_over and flow.accepts_actions() and drag_index<0 and selected_unit<0 and not targeting_power and pending_battlecry.is_empty() and not power_used and mana>=2 and is_pointer_hover_allowed() and source_phone_layout.contains("friendly_power",pointer):
		candidate=0;cost=2
	if source_mana_proposal_id>=0 and source_mana_proposal_id!=candidate:source_mana_controller.cancel_proposal(source_mana_proposal_id)
	source_mana_proposal_id=candidate
	if candidate>=0:source_mana_controller.propose(candidate,cost)
