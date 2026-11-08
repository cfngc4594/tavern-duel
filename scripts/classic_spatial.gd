extends Node3D
## The full board's transparent 3D minion layer. One world unit is 100 logical pixels.
## Keep the table, shadows, indicators and live stat labels in the game's 2D pass.
## Usage: add to a transparent SubViewport, setup(game, viewport.size), then call
## sync_from_game() after the game's animation update and before drawing its texture.

const PIXELS_PER_UNIT := 100.0
const UNIT_SCALE := 0.9
const SEGMENTS := 80
const SourceDragRotator=preload("res://scripts/native_drag_rotator.gd")
# Same explicit source-to-board registration as NativeSummonPlayer. Undo this
# scale/axis map before source world-delta arithmetic; not original camera parity.
const DRAG_SOURCE_PROJECTION_SCALE=0.78*0.9
func _drag_source_basis()->Basis:
	return Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))

var camera: Camera3D
var game: Node
var logical_size := Vector2i(1600, 900)
var pieces: Dictionary = {}
var card_pieces: Array[Dictionary] = []
var preview_piece: Dictionary = {}
var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
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
	_make_materials()
	_setup_world()
	if not game.native_initial_loading:sync_from_game()

func _setup_world() -> void:
	var viewport := get_viewport()
	if viewport is SubViewport:
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
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

func sync_from_game() -> void:
	if not is_instance_valid(game) or not _configured:
		return
	_sync_projection_camera()
	phone_blockers.clear()
	if is_instance_valid(phone_history_renderer) and source_projection()==null:phone_history_renderer.sync()
	if source_projection()==null and is_instance_valid(phone_burn_renderer):phone_burn_renderer.clear()
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
				pieces[id] = _make_piece(definition, id, signature)
			var piece: Dictionary = pieces[id]
			var root: Node3D = piece.root
			root.visible = (piece.get("native_actor",false) or not (bool(unit.get("hidden", false)) or bool(unit.get("native_summon_hidden",false)))) and (not bool(unit.get("dead", false)) or bool(unit.get("death_pending", false)))
			if phone_projection_active:
				_sync_phone_unit(piece,unit)
				continue
			if piece.get("native_actor",false):piece.projection.basis=_drag_source_basis()*0.78
			var lift: float = float(unit.get("lift", 0.0))
			for shield in piece.get("shield_nodes",[]): shield.visible=not is_instance_valid(game.native_status) and not (bool(unit.get("hidden",false)) or bool(unit.get("native_summon_hidden",false))) and (not bool(unit.get("animating",false)) or lift<1.0)
			var shake_offset: Vector2 = game.shake_offset
			# The extra screen-Y shift retains exact registration with the existing
			# raised labels/aim indicators; Z is also real physical separation.
			root.position = screen_to_world(unit.pos + shake_offset + (Vector2.ZERO if piece.get("native_actor",false) and unit.has("native_summon_position") else Vector2(0, -lift)), lift if not unit.has("native_summon_position") else 0.0)
			var scale_amount: float = float(unit.get("scale", 1.0)) * UNIT_SCALE
			root.scale = Vector3.ONE * scale_amount
			# Only the piece pitches during hover/attack, never the board/camera.
			var hover_amount: float = 1.0 if game.hover_unit == id else 0.0
			var pitch: float = 4.0 + clampf(lift * 0.34, 0.0, 9.0) + hover_amount * 1.5
			root.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(1.4 + hover_amount), -float(unit.get("rotation", 0.0)))
			var flash: float = clampf(float(unit.get("flash", 0.0)), 0.0, 1.0)
			var frozen: bool = bool(unit.get("frozen", false))
			if piece.get("native_actor",false):
				# Native Actor already carries its original rotation curve. Do not add
				# the legacy lift-driven pitch on top of the source animation.
				root.rotation=Vector3(0,0,-float(unit.get("rotation",0.0)))
				var actor: Node3D=piece.actor.root
				for renderer in piece.actor.renderers.values():renderer.visible=not (bool(unit.get("hidden",false)) or bool(unit.get("native_summon_hidden",false)))
				for label in piece.actor.stat_nodes.values():label.visible=not (bool(unit.get("hidden",false)) or bool(unit.get("native_summon_hidden",false)))
				actor.position=unit.get("native_combat_position",unit.get("native_summon_position",Vector3.ZERO))
				actor.quaternion=unit.get("native_combat_rotation",unit.get("native_summon_rotation",Quaternion.IDENTITY))
				actor.scale=unit.get("native_combat_scale",Vector3.ONE)
				actor.position+=unit.get("native_shake_position",Vector3.ZERO)
				actor.quaternion=actor.quaternion*unit.get("native_shake_rotation",Quaternion.IDENTITY)
				game.native_card_renderer.update_world_minion_stats(piece.actor,int(unit.atk),maxi(0,int(unit.hp)),int(unit.max_hp),int(game.definitions[unit.key].hp))
				_register_native_shield_depth(piece)
				continue
			var portrait_material: StandardMaterial3D = piece.portrait_material
			var portrait_color := Color("c7e9fa") if frozen else Color.WHITE
			portrait_material.albedo_color = portrait_color.lerp(Color("fff1c8"), flash * 0.65)
			portrait_material.emission_enabled = flash > 0.005
			portrait_material.emission = Color(1.0, 0.71, 0.38) * flash * 0.20
	for id in pieces.keys():
		if not live.has(id):
			_dispose_piece(id)
	sync_cards_from_game()

func _sync_phone_unit(piece:Dictionary,unit:Dictionary):
	var root:Node3D=piece.root
	if not piece.get("native_actor",false) or not unit.has("source_world_position") or not unit.has("source_world_rotation") or not unit.has("source_world_scale"):
		root.visible=false;phone_blockers.append("Source actor/world TRS missing: "+str(unit.get("id","?")));return
	var context=source_projection()
	root.transform=Transform3D(Basis.IDENTITY,context.source_to_render(unit.source_world_position))
	var source_rotation:Quaternion=unit.get("source_world_rotation",Quaternion.IDENTITY)
	var source_scale:Vector3=unit.get("source_world_scale",Vector3.ONE)
	piece.projection.basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)*Basis(source_rotation)*Basis.from_scale(source_scale)
	for shield in piece.get("shield_nodes",[]):shield.visible=false
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

func _make_material(color: Color, grain: Texture2D = null) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	material.metallic = 0.10
	material.metallic_specular = 0.24
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if grain:
		material.albedo_texture = grain
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

func _make_materials() -> void:
	# Low-contrast, deterministic brushed grain. No reflected chrome or baked frame.
	var grain_image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = 84217
	for y in range(128):
		for x in range(128):
			var grain := 0.945 + random.randf_range(-0.025, 0.025) + sin(float(x) * 1.9 + float(y) * 0.17) * 0.018
			grain_image.set_pixel(x, y, Color(grain, grain, grain))
	grain_image.generate_mipmaps()
	var grain_texture := ImageTexture.create_from_image(grain_image)
	_materials["edge"] = _make_material(Color("333a3e"), grain_texture)
	_materials["shadow"] = _make_material(Color("1e292e"), grain_texture)
	_materials["steel"] = _make_material(Color("8b9397"), grain_texture)
	_materials["light"] = _make_material(Color("bac1c2"), grain_texture)
	_materials["shield"] = _make_material(Color("737d83"), grain_texture)
	_materials["groove"] = _make_material(Color("38474d"), grain_texture)
	_materials["light"].roughness = 0.72
	_materials["light"].metallic = 0.16

func _make_piece(definition: Dictionary, id: int, signature: String) -> Dictionary:
	if is_instance_valid(game.native_card_renderer):return _make_native_piece(definition,id,signature)
	var root := Node3D.new()
	root.name = "Minion_%d" % id
	add_child(root)
	var is_taunt: bool = definition.get("keyword", "") == "嘲讽"
	var suffix := "_taunt" if is_taunt else "_normal"
	var shield_nodes: Array = []
	# Actual sidewalls retain thickness and pitch; original transparent textures
	# supply the detailed painted front, independently of all live values/state.
	if is_taunt:
		shield_nodes.append(_add_cached(root, "original_shield_body", _beveled_prism(_shield_outline(), 0.0, 0.065, 0.025), _materials.edge))
		var shield_mat := _original_ui_material("inplay_minion_taunt")
		shield_nodes.append(_add_cached(root,"original_shield_face",_rectangle_face(1.68,1.96,0.070),shield_mat))
	_add_cached(root,"original_oval_body"+suffix,_beveled_prism(_ellipse(0.535,0.710),0.065,0.135,0.018),_materials.edge)
	var portrait_material := _make_material(Color.WHITE)
	portrait_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portrait_material.metallic = 0.0
	var art: int = int(definition.art)
	if art >= 0 and art < game.raw_portraits.size():
		portrait_material.albedo_texture = game.raw_portraits[art]
	else:
		portrait_material.albedo_color = definition.get("color", Color("80684e"))
	portrait_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var portrait:=_add_cached(root,"original_portrait"+suffix,_portrait_face(0.500,0.657,0.142,Vector2(0.70,0.92)),portrait_material)
	portrait.position=Vector3(0.006,0.070,0)
	_add_cached(root,"original_inplay_ring",_rectangle_face(1.68,1.96,0.150),_original_ui_material("inplay_minion"))
	return {"root": root, "signature": signature, "portrait_material": portrait_material,"shield_nodes":shield_nodes}

func _original_ui_material(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var mat:=_make_material(Color.WHITE,game.classic_ui[key])
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mat.metallic=0.0
		_materials[key]=mat
	return _materials[key]

func _add_cached(parent: Node3D, key: String, candidate: ArrayMesh, material: Material) -> MeshInstance3D:
	# Mesh resources are shared; only portrait materials are per live unit.
	if not _mesh_cache.has(key):
		_mesh_cache[key] = candidate
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh_cache[key]
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _ellipse(rx: float, ry: float, count: int = SEGMENTS) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		outline.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return outline

func _shield_outline() -> PackedVector2Array:
	# Classic shield: broad rounded shoulders, straight upper sides, single low tip.
	var spans := [
		[Vector2(-65, -73), Vector2(-44, -77), Vector2(-21, -79), Vector2(0, -79)],
		[Vector2(0, -79), Vector2(21, -79), Vector2(44, -77), Vector2(65, -73)],
		[Vector2(65, -73), Vector2(66, -43), Vector2(66, 2), Vector2(58, 30)],
		[Vector2(58, 30), Vector2(51, 56), Vector2(23, 75), Vector2(0, 86)],
		[Vector2(0, 86), Vector2(-23, 75), Vector2(-51, 56), Vector2(-58, 30)],
		[Vector2(-58, 30), Vector2(-66, 2), Vector2(-66, -43), Vector2(-65, -73)]
	]
	var outline := PackedVector2Array()
	for span in spans:
		for i in range(14):
			var point: Vector2 = span[0].bezier_interpolate(span[1], span[2], span[3], float(i) / 14.0)
			outline.append(Vector2(point.x, -point.y) / PIXELS_PER_UNIT)
	# Maintain CCW coordinates for the same outward normal convention as ellipses.
	outline.reverse()
	return outline

func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ellipse_ring(rx: float, ry: float, z: float, width: float, depth: float) -> ArrayMesh:
	return _outline_ring(_ellipse(rx, ry), z, width, depth)

func _outline_ring(outline: PackedVector2Array, z: float, width: float, depth: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var cross_sections := 10
	var count := outline.size()
	for i in range(count):
		var tangent := (outline[(i + 1) % count] - outline[(i + count - 1) % count]).normalized()
		var outward := Vector2(tangent.y, -tangent.x)
		for k in range(cross_sections):
			var angle := TAU * float(k) / float(cross_sections)
			var p := outline[i] + outward * cos(angle) * width
			vertices.append(Vector3(p.x, p.y, z + sin(angle) * depth))
			normals.append(Vector3(outward.x * cos(angle) / width, outward.y * cos(angle) / width, sin(angle) / depth).normalized())
			uvs.append(Vector2(p.x * 2.0 + 0.5, p.y * 2.0 + 0.5))
			var a := i * cross_sections + k
			var b := ((i + 1) % count) * cross_sections + k
			var c := ((i + 1) % count) * cross_sections + ((k + 1) % cross_sections)
			var d := i * cross_sections + ((k + 1) % cross_sections)
			indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	return _mesh(vertices, normals, uvs, indices)

func _beveled_prism(outline: PackedVector2Array, bottom: float, top: float, bevel: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := outline.size()
	var max_radius := 0.0
	for p in outline:
		max_radius = maxf(max_radius, p.length())
	var inset: float = 1.0 - bevel / max_radius
	var levels := [Vector2(0.979, bottom), Vector2(1.0, bottom + 0.015), Vector2(1.0, top - 0.018), Vector2(inset, top)]
	for layer in range(levels.size()):
		for i in range(count):
			var point: Vector2 = outline[i] * levels[layer].x
			var tangent := (outline[(i + 1) % count] - outline[(i + count - 1) % count]).normalized()
			var normal := Vector3(tangent.y, -tangent.x, 0.0)
			if layer == 0:
				normal.z = -0.5
			elif layer == levels.size() - 1:
				normal.z = 0.9
			vertices.append(Vector3(point.x, point.y, levels[layer].y))
			normals.append(normal.normalized())
			uvs.append(Vector2(point.x + 0.5, point.y + 0.5))
			if layer < levels.size() - 1:
				var a := layer * count + i
				var b := layer * count + ((i + 1) % count)
				var c := (layer + 1) * count + ((i + 1) % count)
				var d := (layer + 1) * count + i
				indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	# Separate face vertices keep the inset plane normal flat and the rim round.
	var center_index := vertices.size()
	vertices.append(Vector3(0, 0, top))
	normals.append(Vector3(0, 0, 1))
	uvs.append(Vector2(0.5, 0.5))
	for point in outline:
		vertices.append(Vector3(point.x * inset, point.y * inset, top))
		normals.append(Vector3(0, 0, 1))
		uvs.append(Vector2(point.x + 0.5, point.y + 0.5))
	for i in range(count):
		indices.append_array(PackedInt32Array([center_index, center_index + 1 + ((i + 1) % count), center_index + 1 + i]))
	return _mesh(vertices, normals, uvs, indices)

func _shield_dome(outline: PackedVector2Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rings := 9
	var count := outline.size()
	for ring in range(rings + 1):
		var radius := float(ring) / float(rings)
		for point in outline:
			var p := point * radius
			var height := 0.065 + 0.084 * (1.0 - radius * radius)
			vertices.append(Vector3(p.x, p.y, height))
			normals.append(Vector3(p.x * 0.55, p.y * 0.39, 1.0).normalized())
			uvs.append(Vector2(p.x + 0.5, p.y + 0.5))
		if ring < rings:
			for i in range(count):
				var a := ring * count + i
				var b := ring * count + ((i + 1) % count)
				var c := (ring + 1) * count + ((i + 1) % count)
				var d := (ring + 1) * count + i
				indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	return _mesh(vertices, normals, uvs, indices)

func _portrait_face(rx: float, ry: float, z: float, uv_scale: Vector2 = Vector2.ONE) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(0, 0, z)])
	var normals := PackedVector3Array([Vector3(0, 0, 1)])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()
	for point in _ellipse(rx, ry):
		vertices.append(Vector3(point.x, point.y, z))
		normals.append(Vector3(0, 0, 1))
		# UV Y is inverted because raw images use screen-Y down and world-Y up.
		uvs.append(Vector2(point.x / (2.0 * rx) * uv_scale.x + 0.5, 0.5 - point.y / (2.0 * ry) * uv_scale.y))
	for i in range(SEGMENTS):
		indices.append_array(PackedInt32Array([0, ((i + 1) % SEGMENTS) + 1, i + 1]))
	return _mesh(vertices, normals, uvs, indices)

func sync_cards_from_game() -> void:
	if not is_instance_valid(game):
		return
	_sync_projection_camera()
	if phone_projection_active:
		for piece in card_pieces:piece.root.visible=false
		if not preview_piece.is_empty():preview_piece.root.visible=false
		if not is_instance_valid(phone_hand_renderer):
			phone_hand_renderer=preload("res://scripts/native_phone_hand_renderer.gd").new();add_child(phone_hand_renderer)
			phone_hand_renderer.setup(game,hand_highlight)
		phone_hand_renderer.visible=true;phone_hand_renderer.sync()
		if not is_instance_valid(phone_opposing_hand):
			phone_opposing_hand=preload("res://scripts/native_phone_opposing_hand.gd").new();add_child(phone_opposing_hand);phone_opposing_hand.setup(game)
		phone_opposing_hand.visible=true;phone_opposing_hand.sync()
		return
	if is_instance_valid(phone_hand_renderer):phone_hand_renderer.visible=false
	if is_instance_valid(phone_opposing_hand):phone_opposing_hand.visible=false
	var face_textures = game.get("card_face_textures")
	if not face_textures is Dictionary:
		return
	while card_pieces.size() > game.cards.size():
		var removed: Dictionary = card_pieces.pop_back()
		removed.root.visible = false
		removed.root.queue_free()
	for i in range(game.cards.size()):
		var card: Dictionary = game.cards[i]
		if i >= card_pieces.size():
			card_pieces.append(_make_card_piece())
		var piece: Dictionary = card_pieces[i]
		var pending: bool = not game.pending_battlecry.is_empty() and int(game.pending_battlecry.index) == i
		piece.root.visible = not pending and face_textures.has(card.key)
		_sync_card_piece(piece, card, i, false)
	if not game.pending_battlecry.is_empty():
		var index: int = int(game.pending_battlecry.index)
		if index >= 0 and index < game.cards.size():
			if preview_piece.is_empty():
				preview_piece = _make_card_piece()
			var preview: Dictionary = game.cards[index].duplicate()
			preview.pos = game.pending_battlecry.pos
			preview.scale = 0.72
			preview.angle = 0.0
			preview.lift = 20.0
			preview_piece.root.visible = face_textures.has(preview.key)
			_sync_card_piece(preview_piece, preview, index, true)
	elif not preview_piece.is_empty():
		preview_piece.root.visible = false

func _make_card_piece() -> Dictionary:
	var root := Node3D.new()
	root.name = "ThinHandCard"
	add_child(root)
	if not _materials.has("card_edge"):
		_materials["card_edge"] = _make_material(Color("54432f"))
		_materials["card_bevel"] = _make_material(Color("b4a17b"))
		var glow := _make_material(Color(0.33, 0.88, 0.15, 0.65))
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.no_depth_test = false
		_materials["card_glow"] = glow
		glow.albedo_color=Color(0.35,1.0,0.10,0.36)
	var outline := _classic_card_outline()
	_add_cached(root, "card_body", _beveled_prism(outline, 0.0, 0.028, 0.009), _materials.card_edge)
	_add_cached(root, "card_bevel", _outline_ring(outline, 0.025, 0.006, 0.004), _materials.card_bevel)
	var face_material := _make_material(Color.WHITE)
	face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add_cached(root, "card_face", _rectangle_face(1.64, 2.42, 0.034), face_material)
	var glow_mesh := _add_cached(root, "card_ready", _outline_ring(_classic_card_outline(1.025), 0.02, 0.012, 0.006), _materials.card_glow)
	glow_mesh.visible = false
	return {"root": root, "face_material": face_material, "glow": glow_mesh, "key": ""}

func _sync_card_piece(piece: Dictionary, card: Dictionary, index: int, preview: bool) -> void:
	var root: Node3D = piece.root
	var lift: float = float(card.get("lift", 0.0))
	var active: bool = index == game.hover_card or index == game.drag_index
	var drawing: bool = bool(card.get("drawing", false))
	var returning: bool = bool(card.get("returning", false))
	var depth := 0.25 + float(index) * 0.065
	if active:
		depth = 1.8
	if returning:
		depth = 2.4
	if drawing:
		depth = 3.0
	if preview:
		depth = 2.0
	# Hand animation already stores its visible raised location in card.pos.
	root.position = screen_to_world(card.pos + game.shake_offset, lift)
	root.position.z += depth
	root.scale = Vector3.ONE * float(card.get("scale", 1.0))
	var pitch: float = clampf(lift * 0.09, 0.0, 5.5)
	var yaw := 0.0
	root.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), -float(card.get("angle", 0.0)))
	if index == game.drag_index and not preview:
		var face_pose: Dictionary=game.selected_card_face_pose(card)
		root.position=screen_to_world(face_pose.pos+game.shake_offset,lift)
		root.position.z+=depth
		root.scale=Vector3(face_pose.scale.x,face_pose.scale.y,float(card.scale))
		root.rotation.z=-face_pose.angle
		var projection=_drag_source_basis()
		# Remove camera shake: it is not Actor.transform.position movement.
		var source_position:Vector3=card.get("source_world_position",projection.inverse()*screen_to_world(face_pose.pos,lift)/DRAG_SOURCE_PROJECTION_SCALE)
		if not piece.has("source_drag") or not is_same(piece.get("drag_card"),card):
			piece.drag_card=card
			piece.source_drag=SourceDragRotator.new();piece.source_drag.reset(source_position)
			piece.drag_initial_rotation=root.quaternion;piece.drag_sample_clock=float(game.elapsed)
			piece.drag_rotation=Vector2.ZERO
		var delta=maxf(0.0,float(game.elapsed)-float(piece.drag_sample_clock))
		if delta>0.0:
			piece.drag_rotation=piece.source_drag.sample(source_position,delta)
			piece.drag_sample_clock=float(game.elapsed)
		var angles:Vector2=piece.drag_rotation
		# Source pitch X and roll Z are world-rebased back onto the baked card.
		var source_rotation=Basis(Vector3.RIGHT,deg_to_rad(angles.x))*Basis(Vector3.BACK,deg_to_rad(angles.y))
		root.quaternion=(projection*source_rotation*projection.inverse()).get_rotation_quaternion()*piece.drag_initial_rotation
	else:
		piece.erase("source_drag")
	var material: StandardMaterial3D = piece.face_material
	if piece.key != str(card.key) or material.albedo_texture != game.card_face_textures.get(card.key):
		material.albedo_texture = game.card_face_textures.get(card.key)
		piece.key = str(card.key)
	var definition: Dictionary = game.definitions[card.key]
	piece.glow.visible = false # Retired homemade ring; source mesh/material owns selection.
	if is_instance_valid(hand_highlight):hand_highlight.sync_piece(piece,card,index,preview)

func refresh_card_face_textures() -> void:
	# Same card ID can now refer to a replacement renderer's ViewportTexture.
	# Rebind even hidden/preview pieces before retiring the old SubViewports.
	for piece in card_pieces:
		piece.face_material.albedo_texture = game.card_face_textures.get(piece.key)
	if not preview_piece.is_empty():
		preview_piece.face_material.albedo_texture = game.card_face_textures.get(preview_piece.key)

func _classic_card_outline(factor: float = 1.0) -> PackedVector2Array:
	var points: PackedVector2Array=game._card_surface_outline(factor)
	for i in range(points.size()): points[i]=Vector2(points[i].x,-points[i].y)/100.0
	return points

func _rounded_rectangle(width: float, height: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers := [Vector2(width * 0.5 - radius, height * 0.5 - radius), Vector2(-width * 0.5 + radius, height * 0.5 - radius), Vector2(-width * 0.5 + radius, -height * 0.5 + radius), Vector2(width * 0.5 - radius, -height * 0.5 + radius)]
	for corner in range(4):
		for i in range(10):
			var angle := float(corner) * PI * 0.5 + float(i) * PI * 0.5 / 9.0
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _rectangle_face(width: float, height: float, z: float) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(-width * 0.5, height * 0.5, z), Vector3(width * 0.5, height * 0.5, z), Vector3(width * 0.5, -height * 0.5, z), Vector3(-width * 0.5, -height * 0.5, z)])
	var normals := PackedVector3Array([Vector3(0,0,1), Vector3(0,0,1), Vector3(0,0,1), Vector3(0,0,1)])
	var uvs := PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)])
	return _mesh(vertices, normals, uvs, PackedInt32Array([0,1,2,0,2,3]))

func _make_native_piece(definition: Dictionary,id: int,signature: String) -> Dictionary:
	var root:=Node3D.new();root.name="OriginalMinion_%d"%id;add_child(root)
	var projection:=Node3D.new();root.add_child(projection)
	# The fixed legacy board has no recovered original camera. This one explicit
	# orthographic mapping adapts Unity X/Z tabletop, Y height to the 2D board.
	# No clip key or local mesh geometry is changed by the mapping.
	projection.basis=Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*0.78
	var actor: Dictionary=game.native_card_renderer.build_world_minion(str(definition.get("card_id","")),definition,game.raw_portraits[int(definition.art)])
	projection.add_child(actor.root)
	if phone_projection_active:
		actor.root.transform=Transform3D.IDENTITY
		var root_object=actor.root.get_node_or_null("RootObject")
		if root_object!=null:root_object.transform=Transform3D.IDENTITY
	var shield_nodes: Array=[]
	if definition.get("keyword","")=="嘲讽":
		# Existing taunt indicator is separate from the migrated generic actor.
		shield_nodes.append(_add_cached(root,"original_shield_body",_beveled_prism(_shield_outline(),0.0,0.065,0.025),_materials.edge))
		shield_nodes.append(_add_cached(root,"original_shield_face",_rectangle_face(1.68,1.96,0.070),_original_ui_material("inplay_minion_taunt")))
	return {"root":root,"signature":signature,"shield_nodes":shield_nodes,"native_actor":true,"actor":actor,"projection":projection}

func _register_native_shield_depth(piece: Dictionary) -> void:
	if piece.get("shield_nodes",[]).is_empty():return
	# The retained v30 shield is a camera-facing compatibility indicator. Its
	# old z=.070 was behind the old flat portrait z=.142, but intersects the
	# recovered inclined Actor. Register it behind the actual transformed Actor
	# mesh bounds; preserve the existing XY outline, texture and visibility.
	var root: Node3D=piece.root
	var to_root:=root.global_transform.affine_inverse()
	var minimum_z:=INF
	for renderer in piece.actor.renderers.values():
		if not is_instance_valid(renderer) or renderer.mesh==null:continue
		var transform: Transform3D=to_root*renderer.global_transform
		var box: AABB=renderer.mesh.get_aabb()
		for corner in range(8):
			var vertex:=box.position+Vector3(box.size.x if corner&1 else 0.0,box.size.y if corner&2 else 0.0,box.size.z if corner&4 else 0.0)
			minimum_z=minf(minimum_z,(transform*vertex).z)
	if not is_finite(minimum_z):return
	var maximum_shield_z: float=-INF
	for shield in piece.shield_nodes:
		var box: AABB=shield.mesh.get_aabb()
		# A small numeric depth separation, not a screen-space visual adjustment.
		shield.position.z=minimum_z-box.end.z-0.001
		maximum_shield_z=maxf(maximum_shield_z,shield.position.z+box.end.z)
	piece.native_actor_depth_min=minimum_z
	piece.compatibility_shield_depth_max=maximum_shield_z
