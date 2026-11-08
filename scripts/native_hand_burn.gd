extends Node3D
## Original Card_Hand_Ally_HandFull prefab, CardBurnUpFire clip, textures and audio.
## Godot source-material/particle adapters remain explicit compatibility layers.
const Hand=preload("res://scripts/native_phone_hand.gd")
const Draw=preload("res://scripts/native_phone_draw.gd")
const Timeline=preload("res://scripts/native_hand_burn_timeline.gd")
const Assets=preload("res://scripts/native_combat_assets.gd")
const Particles=preload("res://scripts/native_combat_particles.gd")
const BASE="res://assets/original_hand_burn/"
var game
var source_generation:int=-1
var assets=Assets.new()
var mill_bones:Dictionary={}
var deck_bones:Dictionary={}
var pieces:Dictionary={}
var blockers:Array=[]
var history:Array=[]
var audio:Node
var full_hand_voice=preload("res://scripts/native_hand_full_voice.gd").new()
func setup(host):
 game=host;basis=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
 assets.setup(game.native_card_renderer,BASE)
 mill_bones=JSON.parse_string(FileAccess.get_file_as_string(BASE+"mill_bones.json")).rows
 deck_bones=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_deck_runtime.json")).rows
 # A root-owned sink can finish AudioServer retirement when this scene resets.
 audio=preload("res://scripts/native_hand_burn_audio.gd").new();get_tree().root.add_child(audio);audio.setup(game)
 full_hand_voice.setup(game);source_generation=game.flow.burn_generation
func clear():
 full_hand_voice.clear()
 for piece in pieces.values():_dispose(piece)
 pieces.clear()
 if is_instance_valid(audio):audio.stop_all()
func shutdown():
 clear()
 if is_instance_valid(audio):await audio.shutdown()
func _exit_tree():
 clear()
 if is_instance_valid(audio):audio.shutdown()
func _dispose(piece:Dictionary):
 if is_instance_valid(piece.root):piece.root.queue_free()
 if is_instance_valid(piece.get("effect_holder")):piece.effect_holder.queue_free()
func _make(entry:Dictionary)->Dictionary:
 var actor:Dictionary=game.native_card_renderer.clone_world_hand(entry.key)
 if actor.is_empty():
  blockers.append("Original hand actor unavailable: "+str(entry.key));return {}
 var holder=Node3D.new();holder.name="SourceMillCard_%d"%int(entry.ticket);add_child(holder);holder.add_child(actor.root)
 actor.root.transform=Transform3D.IDENTITY
 var root_object=actor.root.get_node_or_null("RootObject")
 if root_object!=null:root_object.transform=Transform3D.IDENTITY
 var bone=mill_bones.FriendlyMillCard if int(entry.side)==0 else mill_bones.OpponentMillCard
 var zone="Zone_Friendly_Deck" if int(entry.side)==0 else "Zone_Opposing_Deck"
 var start=deck_bones[zone+":m_Tickness"+Draw.thickness(int(entry.deck_count))+"TopOfDeck"]
 return {"root":holder,"actor":actor,"entry":entry,"effect":{},"effect_holder":null,"particles":[],"start":Hand.vector(start.phone_world_position),"finish":Hand.vector(bone.phone_world_position),"finish_scale":Hand.vector(bone.phone_local.scale)}
func _birth(piece:Dictionary):
 # SpellUtils.SetPositionFromLocation copies world position only (0x06014ab9).
 # m_SetParentToLocation=false, m_Facing=0: do NOT inherit card's 357-degree roll.
 var effect_holder=Node3D.new();effect_holder.name="SourceHandFull_%d"%int(piece.entry.ticket);add_child(effect_holder)
 effect_holder.position=piece.finish;piece.effect_holder=effect_holder
 piece.effect=assets.instantiate(assets.manifest.root,effect_holder)
 for key in piece.effect.particles:
  var spec:Dictionary=piece.effect.particles[key].duplicate()
  spec.compatibility_basis=basis;spec.source_scope_root=piece.effect.root
  var particle=Particles.new();particle.setup(spec,assets,effect_holder,int(piece.entry.ticket)*391+piece.particles.size())
  piece.particles.append(particle)
  piece.effect.materials[key]=[particle.material]
  for unsupported in particle.unsupported:
   var note=str(assets.objects[key].name)+": "+str(unsupported)
   if not blockers.has(note):blockers.append(note)
 var emitter:Node3D=piece.effect.nodes["cab-865f43f611eb20762339650558784e7a:-9117196804631356181"]
 var world:Vector3=emitter.global_position
 var source_position=Vector3(world.x,world.y,-world.z)
 var sound=audio.play_burn(int(piece.entry.ticket),source_position) if is_instance_valid(audio) else {}
 history.append({"ticket":piece.entry.ticket,"event":"Birth","at":Timeline.FLIGHT,"audio":sound,"original_root":assets.manifest.root})
func sync():
 if source_generation!=game.flow.burn_generation:
  clear();source_generation=game.flow.burn_generation
 if is_instance_valid(audio):audio.advance(0.0)
 var live:Dictionary={}
 for entry in game.flow.burn_cards:
  var ticket:int=entry.ticket;live[ticket]=true
  if str(entry.phase) in ["queued","blocked"]:
   if entry.has("blocker") and not blockers.has(entry.blocker):blockers.append(entry.blocker)
   continue
  if entry.get("remind_full_hand",false) and not entry.get("emote_dispatched",false):
   entry.emote_dispatched=true;full_hand_voice.play(entry)
  if not pieces.has(ticket):
   var piece=_make(entry)
   if piece.is_empty():continue
   pieces[ticket]=piece
  var piece:Dictionary=pieces[ticket]
  var pose=Draw.flight(piece.start,piece.finish,piece.finish_scale,minf(float(entry.age),Timeline.FLIGHT))
  var b=Hand.source_basis(pose.rotation)
  piece.root.transform=Transform3D(Basis(b.x*pose.scale.x,b.y*pose.scale.y,b.z*pose.scale.z),pose.position)
  var age:float=float(entry.age)-Timeline.FLIGHT
  if age<0:continue
  if piece.effect.is_empty():_birth(piece)
  piece.actor.root.visible=age<Timeline.HIDE_ACTOR
  assets.sample_clip(piece.effect,"CardBurnUpFire",age,"BurnCardQuad")
  for particle in piece.particles:particle.seek(age)
  for group in piece.effect.materials.values():
   for material in group:
    if material is ShaderMaterial:material.set_shader_parameter("_UnityTimeX",float(game.elapsed)*0.05)
 for ticket in pieces.keys():
  if not live.has(ticket):_dispose(pieces[ticket]);pieces.erase(ticket)
 # Reset/menu removed all logical records, so retire sounds immediately too.
 if live.is_empty():
  if is_instance_valid(audio):audio.stop_all()
  full_hand_voice.clear()
func get_audit()->Dictionary:
 var particle_counts:Array=[]
 for piece in pieces.values():
  for particle in piece.particles:particle_counts.append({"source":particle.source_key,"emitted":particle.emitted_count,"live":particle.live_count,"unsupported":particle.unsupported})
 return {"instances":pieces.size(),"source_objects":assets.objects.size(),"missing":assets.missing,"untranslated_materials":assets.material_audit,"blockers":blockers,"particles":particle_counts,"history":history,"full_hand_voice":full_hand_voice.history,"compatibility":"Source data/curves/FSM; Godot native-particle adapter, not Unity execution or pixel parity"}
