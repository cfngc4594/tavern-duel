extends Node
## Original HeroLabel hierarchy + localized strings; Godot font raster compatibility.
const Assets = preload("res://scripts/source_opening_assets.gd")
const Curves = preload("res://scripts/native_summon_curves.gd")
var game
var source_assets
var world: Node3D
var contract: Dictionary = {}
var states: Dictionary = {}
var blockers: Array = []
var fade_out_start: float = 0.6
var last_age: float = 0.0

func setup(host, assets, source_world: Node3D) -> void:
 game = host
 world = source_world
 source_assets = Assets.new()
 source_assets.setup(assets.renderer)
 # Independent shallow object map: do not mutate the immutable cached manifest.
 var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/original_opening/hero_labels.json"))
 source_assets.objects = source_assets.objects.duplicate()
 source_assets.objects.merge(extra.objects, true)
 source_assets.manifest = source_assets.manifest.duplicate()
 source_assets.manifest["root_labels"] = source_assets.manifest.root_labels.duplicate()
 source_assets.manifest.root_labels.merge(extra.root_labels, true)
 contract = JSON.parse_string(FileAccess.get_file_as_string("res://assets/original_opening/data/hero_label_contract.json"))
 sample(0.0)

func _attach_available() -> void:
 if game == null or not is_instance_valid(game.spatial_scene.phone_board_actors): return
 var holder = game.spatial_scene.phone_board_actors
 for side in range(2):
  if states.has(side): continue
  var entry: Dictionary = holder.actors.get("hero:" + str(side), {})
  if entry.is_empty(): continue
  var actor: Dictionary = entry.actor
  var attach: Node3D = actor.nodes.get(str(contract.attachment.source_mesh_go_key))
  if attach == null:
   if not blockers.has("Missing original hero Mesh node"): blockers.append("Missing original hero Mesh node")
   continue
  var state: Dictionary = source_assets.instantiate_opening("heroLabelPrefab", world, false)
  # Unity Transform.set_parent retains world rotation/scale. Then localPosition=offset.
  # Both classic hero frames return zero offset; retain the two child text poses.
  state.root.transform = Transform3D.IDENTITY
  # Identity in source-world coordinates retains the shared handedness reflection.
  state.root.reparent(attach, true)
  state.root.position = Vector3.ZERO
  state["hero_labels"] = []
  state["detached"] = false
  var hero: Dictionary = contract.heroes["HERO_08" if side == 0 else "HERO_07"]
  for role in contract.specs:
   var spec: Dictionary = contract.specs[role]
   var raw: Dictionary = spec.data
   var parent: Node3D = state.nodes.get(str(spec.go_key))
   var label := Label3D.new()
   label.name = "OriginalHero_" + str(role)
   label.text = str(hero[role])
   label.font = load(str(contract.font))
   label.font_size = int(spec.font_size)
   label.pixel_size = float(spec.pixel_size)
   label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
   label.modulate = Curves.color(raw.m_TextColor)
   label.outline_modulate = Curves.color(raw.m_OutlineColor)
   label.outline_size = int(round(float(raw.m_OutlineSize)))
   label.render_priority = int(raw.m_RenderQueue)
   label.outline_render_priority = label.render_priority
   label.shaded = false
   label.double_sided = true
   label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
   parent.add_child(label)
   label.set_meta("source_ubertext", spec.source_key)
   label.set_meta("compatibility", "Original GLEI00M font; Godot rasterization, not exact Unity glyphs")
   state.hero_labels.append(label)
  states[side] = state

func sample(age: float) -> void:
 last_age = age
 if age < fade_out_start + 1.0: _attach_available()
 var alpha: float = 1.0 - clampf((age - fade_out_start) / 0.5, 0.0, 1.0)
 for state in states.values():
  if not is_instance_valid(state.root): continue
  if age>=fade_out_start and not state.detached:
   state.root.reparent(world,true);state.detached=true
  state.root.visible = age < fade_out_start + 1.0
  for label in state.hero_labels:
   label.modulate.a = alpha
   label.outline_modulate.a = alpha
 # Keep hidden source roots for deterministic replay/reset; source destroys at +1s.

func fade_out(age: float = -1.0) -> void:
 fade_out_start = last_age if age < 0.0 else age
 sample(last_age)

func clear() -> void:
 for state in states.values():
  if is_instance_valid(state.root): state.root.visible=false;state.root.queue_free()
 states.clear()
