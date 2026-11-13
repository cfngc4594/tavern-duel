extends Node3D
## Source-native mobile actors, hand, mana and history in one transparent 3D pass.
## The registered phone camera owns their shared visual and input geometry.
## Usage: add to a transparent SubViewport, setup(game, viewport.size), then call
## sync_from_game() after the game's animation update and before drawing its texture.

const PIXELS_PER_UNIT := 100.0
var camera: Camera3D
var game: Node
var logical_size := Vector2i(1600, 900)
var pieces: Dictionary = {}
var _configured := false
var hand_highlight: Node2D
var phone_mana_renderer:Node3D
var phone_deck_renderer:Node3D
var phone_board_actors: Node3D
var phone_history_renderer: Node3D
var phone_burn_renderer: Node3D
var phone_hand_renderer: Node3D
var phone_opposing_hand: Node3D
var phone_projection_active:=false
var phone_blockers:Array[String]=[]

func source_projection():
	var context=game.get("source_projection") if is_instance_valid(game) else null
	return context if context!=null and context.is_enabled() else null

func _sync_projection_camera():
	var context=source_projection()
	phone_projection_active=context!=null
	if context!=null:
		context.copy_camera(camera)
	else:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.transform=Transform3D(Basis.IDENTITY,Vector3(0,0,30))
		camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=0.05;camera.far=60.0
		_resize_camera()

func setup(owner_game: Node, viewport_size: Vector2i = Vector2i(1600, 900)) -> void:
	game = owner_game
	logical_size = viewport_size
	if _configured:
		_resize_camera()
		return
	_configured = true
	name = "ClassicSpatialMinions"
	hand_highlight=preload("res://scripts/native_hand_highlight.gd").new();add_child(hand_highlight);hand_highlight.setup(game)
	_setup_world()
	if not game.native_initial_loading:sync_from_game()

func _setup_world() -> void:
	var viewport := get_viewport()
	if viewport is SubViewport:
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = int(ProjectSettings.get_setting_with_override("render_quality/spatial_msaa_3d")) as Viewport.MSAA
	# No floor, sky or projected board image: only the actual pieces are rendered.
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e3e4e3")
	environment.ambient_light_energy = 0.33
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.name = "SoftWarmBoardLight"
	key.light_color = Color("fff4e7")
	key.light_energy = 0.92
	key.rotation_degrees = Vector3(-39, -47, 0)
	key.shadow_enabled = false
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "QuietCoolFill"
	fill.light_color = Color("cbd6de")
	fill.light_energy = 0.12
	fill.rotation_degrees = Vector3(24, 40, 0)
	add_child(fill)
	camera = Camera3D.new()
	camera.name = "RegisteredTopDownCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = Vector3(0, 0, 30)
	camera.near = 0.05
	camera.far = 60.0
	add_child(camera)
	# A camera's default forward axis is -Z; XY geometry is exactly screen aligned.
	camera.current = true
	_resize_camera()

func _resize_camera() -> void:
	if camera:
		camera.size = float(logical_size.y) / PIXELS_PER_UNIT

func screen_to_world(screen_position: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3((screen_position.x - logical_size.x * 0.5) / PIXELS_PER_UNIT,
		(logical_size.y * 0.5 - screen_position.y) / PIXELS_PER_UNIT,
		lift / PIXELS_PER_UNIT)

func sync_from_game(summon_profile: Variant = null) -> void:
	if not is_instance_valid(game) or not _configured:
		return
	_sync_projection_camera()
	phone_blockers.clear()
	if is_instance_valid(phone_history_renderer) and source_projection()==null:phone_history_renderer.sync()
	if source_projection()==null and is_instance_valid(phone_burn_renderer):phone_burn_renderer.clear()
	# Fixtures and teardown may temporarily have no registered presentation.
	# Do not construct a second geometry path while mobile assets are unavailable.
	if not phone_projection_active or not is_instance_valid(game.get("native_card_renderer")):
		for piece in pieces.values():piece.root.visible=false
		_sync_card_renderers()
		return
	if source_projection()!=null:
		if not is_instance_valid(phone_burn_renderer) and not game.flow.burn_cards.is_empty():
			phone_burn_renderer=preload("res://scripts/native_hand_burn.gd").new();add_child(phone_burn_renderer);phone_burn_renderer.setup(game)
		if is_instance_valid(phone_burn_renderer):phone_burn_renderer.sync()
		if not is_instance_valid(phone_board_actors):
			phone_board_actors=preload("res://scripts/native_phone_board_actors.gd").new();add_child(phone_board_actors);phone_board_actors.setup(game)
		phone_board_actors.sync()
		if not is_instance_valid(phone_history_renderer):
			phone_history_renderer=preload("res://scripts/native_history_renderer.gd").new();add_child(phone_history_renderer);phone_history_renderer.setup(game)
		phone_history_renderer.sync()
		# Source deck geometry intersects the board slot. Render in the board's
		# world so its frame/play surface can depth-occlude the stack; compositing
		# a separate transparent viewport cannot preserve that depth relationship.
		if not is_instance_valid(phone_deck_renderer):
			var board_bridge=game.get("original_board_bridge")
			if is_instance_valid(board_bridge) and is_instance_valid(board_bridge.probe):
				phone_deck_renderer=preload("res://scripts/native_phone_deck.gd").new()
				board_bridge.probe.add_child(phone_deck_renderer)
				phone_deck_renderer.setup(game.native_card_renderer)
		if is_instance_valid(phone_deck_renderer):
			phone_deck_renderer.set_count(0,game.deck.size());phone_deck_renderer.set_count(1,game.enemy_deck.size())
		if not is_instance_valid(phone_mana_renderer):
			phone_mana_renderer=preload("res://scripts/native_phone_mana_renderer.gd").new();add_child(phone_mana_renderer);phone_mana_renderer.setup(game.native_card_renderer)
		if not is_instance_valid(game.source_mana_controller):
			game.source_mana_controller=preload("res://scripts/native_phone_mana_controller.gd").new();add_child(game.source_mana_controller);game.source_mana_controller.setup(game,phone_mana_renderer)
		game.source_mana_controller.update(game.source_phone_layout.snapshot,game.source_visual_delta)


	if source_projection()!=null and is_instance_valid(game.native_turn_ui) and game.source_phone_layout!=null:
		var item=game.source_phone_layout.snapshot.items.get("end_turn",{})
		if item.has("source_pose"):
			game.native_turn_ui.attach_source_scene(self,item.source_pose)
			game.native_turn_ui.request_state(game.flow.visuals.button_source_state())

	var live: Dictionary = {}
	for side in game._presentation_boards():
		for unit in side:
			var id: int = int(unit.id)
			live[id] = true
			var definition: Dictionary = game.definitions[unit.key]
			var signature: String = str(unit.key) + ":" + str(definition.art) + ":" + str(definition.get("keyword", "") == "嘲讽")
			if pieces.has(id) and pieces[id].signature != signature:
				var previous: Dictionary=pieces[id]
				var reused: bool=false
				if previous.get("native_actor",false) and is_instance_valid(game.native_status) and game.native_status.can_reuse_actor(str(previous.actor.card),str(unit.key)):
					reused=game.native_card_renderer.update_world_minion_card(previous.actor,str(unit.key),definition,game.raw_portraits[int(definition.art)])
					if reused:previous.signature=signature
				if not reused:_dispose_piece(id)
			if not pieces.has(id):
				var build_started := Time.get_ticks_usec() if summon_profile != null else 0
				pieces[id] = _make_native_piece(definition, id, signature)
				if summon_profile != null:
					summon_profile["board_actor_usec"] = int(summon_profile.get("board_actor_usec", 0)) + Time.get_ticks_usec() - build_started
			var piece: Dictionary = pieces[id]
			var root: Node3D = piece.root
			root.visible = not bool(unit.get("dead",false)) or bool(unit.get("death_pending",false))
			_sync_phone_unit(piece,unit)
	for id in pieces.keys():
		if not live.has(id):
			_dispose_piece(id)
	var hand_started := Time.get_ticks_usec() if summon_profile != null else 0
	_sync_card_renderers()
	if summon_profile != null:summon_profile["hand_sync_usec"] = Time.get_ticks_usec() - hand_started

func _sync_phone_unit(piece:Dictionary,unit:Dictionary):
	var root:Node3D=piece.root
	if not piece.get("native_actor",false) or not unit.has("source_world_position") or not unit.has("source_world_rotation") or not unit.has("source_world_scale"):
		root.visible=false;phone_blockers.append("Source actor/world TRS missing: "+str(unit.get("id","?")));return
	var context=source_projection()
	if context==null:
		root.visible=false;return
	root.transform=Transform3D(Basis.IDENTITY,context.source_to_render(unit.source_world_position))
	var source_rotation:Quaternion=unit.get("source_world_rotation",Quaternion.IDENTITY)
	var source_scale:Vector3=unit.get("source_world_scale",Vector3.ONE)
	piece.projection.basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)*Basis(source_rotation)*Basis.from_scale(source_scale)
	var actor:Node3D=piece.actor.root
	var hidden=bool(unit.get("hidden",false)) or bool(unit.get("native_summon_hidden",false))
	for renderer in piece.actor.renderers.values():renderer.visible=not hidden
	for label in piece.actor.stat_nodes.values():label.visible=not hidden
	actor.position=unit.get("native_combat_position",unit.get("native_summon_position",Vector3.ZERO))+unit.get("native_shake_position",Vector3.ZERO)
	actor.quaternion=unit.get("native_combat_rotation",unit.get("native_summon_rotation",Quaternion.IDENTITY))*unit.get("native_shake_rotation",Quaternion.IDENTITY)
	actor.scale=unit.get("native_combat_scale",Vector3.ONE)
	game.native_card_renderer.update_world_minion_stats(piece.actor,int(unit.atk),maxi(0,int(unit.hp)),int(unit.max_hp),int(game.definitions[unit.key].hp))

func _dispose_piece(id: int) -> void:
	var root: Node3D = pieces[id].root
	root.visible = false
	root.queue_free()
	pieces.erase(id)

func sync_cards_from_game() -> void:
	if not is_instance_valid(game):
		return
	_sync_projection_camera()
	_sync_card_renderers()

func _sync_card_renderers() -> void:
	if not phone_projection_active or not is_instance_valid(game.get("native_card_renderer")):
		if is_instance_valid(phone_hand_renderer):phone_hand_renderer.visible=false
		if is_instance_valid(phone_opposing_hand):phone_opposing_hand.visible=false
		return
	if not is_instance_valid(phone_hand_renderer):
		phone_hand_renderer=preload("res://scripts/native_phone_hand_renderer.gd").new();add_child(phone_hand_renderer)
		phone_hand_renderer.setup(game,hand_highlight)
	phone_hand_renderer.visible=true;phone_hand_renderer.sync()
	if not is_instance_valid(phone_opposing_hand):
		phone_opposing_hand=preload("res://scripts/native_phone_opposing_hand.gd").new();add_child(phone_opposing_hand);phone_opposing_hand.setup(game)
	phone_opposing_hand.visible=true;phone_opposing_hand.sync()

func _make_native_piece(definition: Dictionary,id: int,signature: String) -> Dictionary:
	var root:=Node3D.new();root.name="OriginalMinion_%d"%id;add_child(root)
	var projection:=Node3D.new();root.add_child(projection)
	var actor: Dictionary=game.native_card_renderer.build_world_minion(str(definition.get("card_id","")),definition,game.raw_portraits[int(definition.art)])
	projection.add_child(actor.root)
	actor.root.transform=Transform3D.IDENTITY
	var root_object=actor.root.get_node_or_null("RootObject")
	if root_object!=null:root_object.transform=Transform3D.IDENTITY
	return {"root":root,"signature":signature,"native_actor":true,"actor":actor,"projection":projection}
