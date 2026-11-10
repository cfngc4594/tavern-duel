extends Node
## Same-build original opening hierarchy, clips, source-camera cards and audio.
## Unity font rasterization, particle simulation and local-server readiness are
## explicit compatibility boundaries, not a claim of client pixel equivalence.
const Audio=preload("res://scripts/source_opening_audio.gd")
const Shake=preload("res://scripts/source_opening_camera_shake.gd")
const Lighting=preload("res://scripts/source_opening_lighting.gd")
const IntroAudio=preload("res://scripts/source_opening_intro_audio.gd")
const Assets=preload("res://scripts/source_opening_assets.gd")
const Timeline=preload("res://scripts/source_opening_timeline.gd")
const Hit=preload("res://scripts/source_opening_hit.gd")
const Motion=preload("res://scripts/source_opening_motion.gd")
const Curves=preload("res://scripts/native_summon_curves.gd")
const Rotation=preload("res://scripts/source_itween_rotation.gd")
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const CameraPolicy=preload("res://scripts/source_board_camera_policy.gd")
const BoardProbe=preload("res://original_board/scripts/board_probe.gd")
const PREFIX="cab-69c88b234dfa427e02d1fcee9337ae34:"
var disposed:=false
var game
var assets
var layout:Dictionary={}
var roots:Dictionary={}
var mobile:=true
var viewport:SubViewport
var camera_root:Node3D
var camera:Camera3D
var world:Node3D
var sprite:Sprite2D
var background_copy:BackBufferCopy
var transmission:Node
var tooltip_viewport:SubViewport
var tooltip_world:Node3D
var tooltip_camera:Camera3D
var tooltip_sprite:Sprite2D
var tooltip_background_copy:BackBufferCopy
var tooltip_transmission:Node
var ui:Dictionary={}
var cards:Dictionary={}
var particles:Array=[]
var phase:=""
var match_time:=0.0
var phase_frames:=0
var choices_age:=0.0
var coin_motion_age:=0.0
var replacement_choices_age:=0.0
var replacement_launch_positions:Dictionary={}
var button_birth_age:=-1.0
var button_original_position:=Vector3.ZERO
var hero_saved:Dictionary={}
var hero_labels:Node
var intro_audio:Node
var starting_taunts:Node
var weld:Node
var weld_started:=false
var shake_started:=false
var shake_finished:=false
var shake_capture:=Vector3.ZERO
var deal_started_at:=-1.0
var intro_extension:float=IntroAudio.intro_extension()
var audio_bindings:Dictionary={}
var played:Dictionary={}
var cosmetic=RandomNumberGenerator.new()
var highlight_source:Dictionary={}
var highlight_materials:Dictionary={}
var audit:Dictionary={"build":"37.0.0.255130.254477","compatibility":["Godot source-camera/shader bridge","Godot original-font rasterization, not Unity glyph parity","source ParticleSystem modules on compatibility solver","announcer and START scheduling uses decoded duration, not original SoundManager frame-polling","START option12 enabled as local presentation setting; START actor-light fade not ported","Godot cosmetic RNG differs from Unity global RNG"]}

func setup(host):
 game=host;mobile=CameraPolicy.source_ui_enabled();cosmetic.randomize()
 intro_audio=IntroAudio.new();add_child(intro_audio);intro_audio.setup(game);intro_audio.muted=not game.sound_enabled
 starting_taunts=preload("res://scripts/source_opening_starting_taunts.gd").new();add_child(starting_taunts);starting_taunts.setup(game);starting_taunts.muted=not game.sound_enabled
 assets=Assets.new();assets.setup(game.native_card_renderer)
 roots=assets.manifest.root_labels
 layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/original_opening/layout.json"))
 audio_bindings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/original_opening/data/opening_audio_bindings.json"))
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/OriginalCards/highlight_selection_evidence.json"))
 for profile in source.profiles:highlight_source[profile.label]=profile
 highlight_materials=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/opening_highlight_materials.json"))
 viewport=SubViewport.new();viewport.name="OriginalOpeningViewport";viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 camera_root=Node3D.new();camera_root.transform=BoardProbe.raw_transform(config.unity_camera_root.data);viewport.add_child(camera_root)
 camera=Camera3D.new();camera_root.add_child(camera);camera.transform=BoardProbe.raw_transform(config.unity_camera.transform)
 var c=config.unity_camera.data;camera.fov=float(c["field of view"]);camera.near=float(c["near clip plane"]);camera.far=float(c["far clip plane"]);camera.current=true;camera.keep_aspect=Camera3D.KEEP_HEIGHT
 camera.set_meta("source_base_fov",camera.fov)
 var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0);env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=env
 world=Node3D.new();world.basis=SourceProjection.REFLECTION;viewport.add_child(world)
 transmission=preload("res://scripts/native_combat_transmission.gd").new();add_child(transmission);transmission.setup(viewport,world)
 background_copy=BackBufferCopy.new();background_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;background_copy.z_index=4;game.world_canvas.add_child(background_copy)
 sprite=Sprite2D.new();sprite.name="OriginalOpeningPresentation";sprite.texture=viewport.get_texture();sprite.z_index=4;sprite.material=transmission.make_composite_material();sprite.modulate=Color(1,1,1,2);game.world_canvas.add_child(sprite)
 _setup_tooltip_pass()
 weld=preload("res://scripts/source_opening_weld.gd").new();add_child(weld);weld.setup(game,assets,world);weld.play_source_audio=game.sound_enabled
 hero_labels=preload("res://scripts/source_opening_hero_labels.gd").new();add_child(hero_labels);hero_labels.setup(game,assets,world);hero_labels.fade_out_start=.6+intro_extension
 ui.vs=assets.instantiate_opening(roots.versus,world,mobile);ui.vs.root.position=anchor("VS_Position")
 ui.banner=assets.instantiate_opening(roots.mulliganChooseBannerPrefab,world,mobile);ui.banner.root.position=anchor("ChoiceBanner")
 ui.confirm=assets.instantiate_opening(roots.confirm,world,mobile)
 button_original_position=ui.confirm.nodes[PREFIX+"-8031207015573253587"].position
 for state in ui.values():state.root.visible=false
 refresh_layout();process_priority=101

func _setup_tooltip_pass():
 # Original HS_ForwardPerspectiveRenderer (globalgamemanagers.assets:7801)
 # ends with TooltipRenderObjects (:7784): Event500, ClearDepth=1,
 # LayerMask=16384. X and replacement-label renderers are source layer14.
 # A separate source-camera framebuffer restores that cleared-depth pass.
 # Keep source geometry, ZTest and ZWrite, rather than lifting X over cards.
 tooltip_viewport=SubViewport.new();tooltip_viewport.name="OriginalTooltipPass"
 tooltip_viewport.own_world_3d=true;tooltip_viewport.transparent_bg=true
 tooltip_viewport.msaa_3d=viewport.msaa_3d
 tooltip_viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
 tooltip_viewport.set_meta("source_render_event",500)
 tooltip_viewport.set_meta("source_clear_depth",true)
 tooltip_viewport.set_meta("source_layer_mask",16384)
 add_child(tooltip_viewport)
 tooltip_camera=Camera3D.new();tooltip_viewport.add_child(tooltip_camera)
 tooltip_camera.current=true;tooltip_camera.environment=camera.environment
 tooltip_world=Node3D.new();tooltip_world.basis=SourceProjection.REFLECTION
 tooltip_viewport.add_child(tooltip_world)
 tooltip_transmission=preload("res://scripts/native_combat_transmission.gd").new()
 add_child(tooltip_transmission);tooltip_transmission.setup(tooltip_viewport,tooltip_world)
 tooltip_background_copy=BackBufferCopy.new()
 tooltip_background_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
 tooltip_background_copy.z_index=6;game.world_canvas.add_child(tooltip_background_copy)
 tooltip_sprite=Sprite2D.new();tooltip_sprite.name="OriginalOpeningTooltipPresentation"
 tooltip_sprite.texture=tooltip_viewport.get_texture();tooltip_sprite.z_index=6
 tooltip_sprite.material=tooltip_transmission.make_composite_material()
 tooltip_sprite.modulate=Color(1,1,1,2);game.world_canvas.add_child(tooltip_sprite)

func _sync_tooltip_camera():
 tooltip_viewport.size=viewport.size
 tooltip_sprite.position=sprite.position;tooltip_sprite.scale=sprite.scale
 for property in ["projection","keep_aspect","fov","size","frustum_offset","near","far","h_offset","v_offset"]:
  tooltip_camera.set(property,camera.get(property))
 tooltip_camera.global_transform=camera.global_transform

static func array_vector(value:Array)->Vector3:return Vector3(value[0],value[1],value[2])
func anchor(key:String)->Vector3:return array_vector(layout[key]["phone" if mobile else "desktop"].position)
func row_position(index:int,initial:bool=false)->Vector3:
 return Motion.row_position(index,game.flow.first_hand_count,anchor("StartingHandZone"),float(layout.StartingHandZone["phone" if mobile else "desktop"].bounds_size[0]),anchor("Zone_Friendly_Hand").y,mobile,initial)
static func intro_duration()->float:return 1.57+IntroAudio.intro_extension()
static func deal_delay(index:int)->float:return Timeline.bonus_card_launch() if index==3 else Timeline.base_card_launch(index)
static func deal_duration(first_side:int)->float:return Timeline.deal_duration(first_side==0)
func refresh_layout():
 viewport.size=game.board_render_target_size;sprite.position=Vector2(800,450);sprite.scale=game.presentation_size/Vector2(viewport.size)
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 CameraPolicy.apply(camera,camera_root,config,game.presentation_size,mobile)
 _sync_tooltip_camera()
func _process(_delta:float):
 if disposed or not is_instance_valid(sprite) or not sprite.visible:return
 # finish_opening runs after visuals.tick and creates the real hand this frame.
 # Hide clones before the late source-camera presentation pass, not next tick.
 if not game.flow.phase in ["intro","deal","mulligan","replace","coin","gather"]:
  set_active(false);dispose();return
 var projection=SourceProjection.from_game(game)
 _apply_intro_shake(projection)
 if projection!=null:projection.copy_camera(camera)
 if is_instance_valid(hero_labels):hero_labels.sample(match_time)
 _sample_heroes()
 if match_time>=1.52+intro_extension and not weld_started:
  weld_started=true
  if is_instance_valid(game.spatial_scene.phone_board_actors):
   weld.play_source_audio=Audio.permitted(game);weld.begin()
 if weld_started:weld.advance(match_time-1.52-intro_extension)
 if is_instance_valid(game.spatial_scene):game.spatial_scene._sync_projection_camera()
 if is_instance_valid(game.flow.visuals.source_coin):game.flow.visuals.source_coin.sync_composite()
 if is_instance_valid(game.native_transmission):game.native_transmission.sync()
 transmission.sync()
 _sync_tooltip_camera();tooltip_transmission.sync()
func _exit_tree():dispose()
func dispose():
 if disposed:return
 disposed=true;set_process(false)
 if is_instance_valid(sprite):set_active(false)
 Audio.stop_tree(self)
 if is_instance_valid(intro_audio):intro_audio.reset()
 if is_instance_valid(starting_taunts):starting_taunts.reset()
 if is_instance_valid(hero_labels):hero_labels.clear()
 if is_instance_valid(weld):weld.clear()
 var projection=SourceProjection.from_game(game)
 if projection!=null and shake_started and not shake_finished:projection.camera.global_position=SourceProjection.source_to_render(shake_capture)
 _restore_heroes()
 if is_instance_valid(sprite):sprite.texture=null;sprite.queue_free()
 if is_instance_valid(background_copy):background_copy.queue_free()
 if is_instance_valid(tooltip_sprite):tooltip_sprite.texture=null;tooltip_sprite.queue_free()
 if is_instance_valid(tooltip_background_copy):tooltip_background_copy.queue_free()
func set_active(value:bool):
 sprite.visible=value;background_copy.visible=value
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
 transmission.transmission_view.render_target_update_mode=viewport.render_target_update_mode
 tooltip_sprite.visible=value;tooltip_background_copy.visible=value
 tooltip_viewport.render_target_update_mode=viewport.render_target_update_mode
 tooltip_transmission.transmission_view.render_target_update_mode=viewport.render_target_update_mode

func _source_card(key:String)->Dictionary:
 var actor:Dictionary=game.native_card_renderer.clone_world_hand(key)
 # Original Actor.SetCard resets Actor and RootObject under the physical Card.
 actor.root.transform=Transform3D.IDENTITY
 if actor.paths.has("RootObject"):actor.paths.RootObject.transform=Transform3D.IDENTITY
 var outer=Node3D.new();world.add_child(outer);outer.add_child(actor.root)
 var data={"key":key,"root":outer,"actor":actor,"pose":{},"highlights":{},"highlight":null}
 _add_highlights(data)
 return data
func _add_highlights(card:Dictionary):
 var renderer=game.native_card_renderer
 var kind="minion_in_hand" if game.definitions[card.key].kind=="minion" else "spell_in_hand"
 var prof:Dictionary=renderer.profiles[kind]
 var record:Dictionary=highlight_source[kind].highlight_state_component
 var refs:Dictionary={}
 for ref in record.references:refs[ref.field]=ref.get("key","")
 var mask_key:String=refs.get("/m_StaticSilouetteTexture","")
 for render in prof.renderers:
  if not render.get("readyHighlight",false):continue
  var node_path=""
  for n in prof.nodes:
   if str(n.id)==str(render.nodeId):node_path=str(n.path).trim_prefix(str(prof.nodes[0].path)).trim_prefix("/");break
  var parent=card.actor.paths.get(node_path)
  if not is_instance_valid(parent):continue
  var plane=MeshInstance3D.new();plane.mesh=renderer._geometry(renderer.meshes[render.meshKey]);parent.add_child(plane);plane.visible=false;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for index in record.data.m_HighlightStates.size():
   var state_id=int(record.data.m_HighlightStates[index].m_StateType)
   if state_id not in [5,7]:continue
   var key:String=refs.get("/m_HighlightStates/%d/m_Material"%index,"")
   if not highlight_materials.has(key):continue
   var md:Dictionary=highlight_materials[key]
   var mat=ShaderMaterial.new();mat.shader=load("res://shaders/native_summon_highlight.gdshader")
   for value in md.floats:mat.set_shader_parameter(value.name,float(value.value))
   for value in md.colors:mat.set_shader_parameter(value.name,renderer.col(value.value))
   for value in md.textures:
    if renderer.textures.has(value.key):mat.set_shader_parameter(value.name,renderer.textures[value.key])
   mat.set_shader_parameter("_MainTex",renderer.textures.get(mask_key));mat.set_shader_parameter("_Seed",cosmetic.randf());mat.set_meta("source_blend","SrcAlpha OneMinusSrcAlpha");mat.set_meta("source_base_shader_path",mat.shader.resource_path)
   card.highlights[state_id]=mat
  card.highlight=plane
  return
func _apply_pose(card:Dictionary,pose:Dictionary):
 card.pose=pose
 var b:Basis=Basis(pose.quaternion) if pose.has("quaternion") else Rotation.source_basis(pose.rotation);var s:Vector3=pose.scale
 card.root.transform=Transform3D(Basis(b.x*s.x,b.y*s.y,b.z*s.z),pose.position)
 card.root.visible=bool(pose.get("visible",true))
func _deck_top()->Vector3:
 if is_instance_valid(game.spatial_scene.phone_deck_renderer):return game.spatial_scene.phone_deck_renderer.top_of_deck(0)
 # Desktop candidate may not have the phone deck actor. The source full bone
 # is read from the same verified original hierarchy, never from screen pixels.
 var d=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_deck_runtime.json"))
 return array_vector(d.rows["Zone_Friendly_Deck:m_TicknessFullTopOfDeck"].phone_world_position)

func advance(delta:float):
 if disposed:return
 if viewport.size!=game.board_render_target_size:refresh_layout()
 var next:String=game.flow.phase
 if not next in ["intro","deal","mulligan","replace","coin","gather"]:set_active(false);_restore_heroes();return
 set_active(true)
 if next!=phase:_enter_phase(next)
 var t:float=game.flow.phase_time+delta
 if phase=="mulligan":choices_age=t
 if phase=="coin":coin_motion_age=t
 if phase=="intro":match_time=t
 else:match_time+=delta
 intro_audio.muted=not game.sound_enabled;intro_audio.sample(match_time)
 if deal_started_at>=0 and bool(ProjectSettings.get_setting("native_mobile/source_opening_start_taunts",true)):
  starting_taunts.muted=not game.sound_enabled;starting_taunts.sample(match_time-deal_started_at)
 for sequence in [intro_audio,starting_taunts]:
  for audio in sequence.players:
   if is_instance_valid(audio):audio.volume_db=0.0 if game.sound_enabled else -80.0
 ui.vs.root.visible=match_time<1.4666667+intro_extension
 # GameStartVsLetters.Awake0x06013bf0 caches GetComponentInChildren<Animation>.
 # Empty-path tracks are local to this child, never the VS_Position outer root.
 assets.sample_clip(ui.vs,"GameStart_VS_Letters_Edit",maxf(0.0,match_time-1.2-intro_extension),"GameStart_VS_Letters_Root")
 phase_frames+=1
 if phase=="mulligan" and phase_frames>=2 and button_birth_age<0:
  button_birth_age=t;play_audio("button_birth");_start_particles(ui.confirm,.2,"floatymotes")
 ui.banner.root.visible=phase in ["deal","mulligan"]
 ui.confirm.root.visible=(phase=="mulligan" and button_birth_age>=0) or (phase=="replace" and t<1.5)
 _button_sample(t-button_birth_age if phase=="mulligan" else t)
 for i in game.flow.first_hand_count:
  if not cards.has(i):cards[i]=_source_card(game.flow.opening_hand[i])
  var card:Dictionary=cards[i]
  var pose:Dictionary=_card_pose(i,t)
  var wanted:String=pose.get("key",game.flow.opening_hand[i])
  if card.key!=wanted:
   card.root.queue_free();cards[i]=_source_card(wanted);card=cards[i]
  _apply_pose(card,pose)
  if is_instance_valid(card.highlight):
   card.highlight.visible=phase=="mulligan" and not game.flow.selected.has(i)
   var state_id=7 if game.is_pointer_hover_allowed() and card_contains(i,game.pointer) else 5
   card.highlight.material_override=card.highlights.get(state_id)
   if card.highlight.material_override!=null:card.highlight.material_override.set_shader_parameter("_ShaderTime",fmod(float(game.elapsed)/20.0,65535.0))
  _selection(i,card)
 _audio_tick(t)
 for row in particles:
  row.node.visible=match_time>=float(row.start)
  if row.node.visible:
   row.node.seek(match_time-float(row.start))
   if row.node.material is ShaderMaterial:row.node.material.set_shader_parameter("_UnityTimeX",float(game.elapsed)/20.0)

func _enter_phase(next:String):
 if next=="replace":
  replacement_choices_age=choices_age;replacement_launch_positions.clear()
  for rank in game.flow.selected.size():
   var index:int=game.flow.selected[rank]
   # Source MoveTo starts at the physical current pose. Later staggered launches
   # see the continuing first-player spread, not a snap at confirmation.
   replacement_launch_positions[index]=cards[index].pose.position if rank==0 and cards.has(index) else _choices_position(index,choices_age+rank*.5)
 phase=next;phase_frames=0;played.clear()
 if phase=="deal":
  deal_started_at=match_time;_start_particles(ui.banner,0.0)
 elif phase=="mulligan":
  choices_age=0.0;button_birth_age=-1.0;_place_confirm()
 elif phase=="replace":
  for row in particles:
   if is_instance_valid(row.node):row.node.queue_free()
  particles.clear()
  play_audio("dismiss")
  _start_particles(ui.confirm,0.2,"FX_Evaporate")
func _place_confirm():
 # DealStartingCards0x6005c90:0dfb-0e6e overwrites prefab position/Euler.
 var hero_z:float=game.source_phone_layout.snapshot.items.friendly_hero.source_pose.origin.z
 if is_instance_valid(game.spatial_scene.phone_board_actors):
  var entry:Dictionary=game.spatial_scene.phone_board_actors.actors.get("hero:0",{})
  if not entry.is_empty():hero_z=SourceProjection.render_to_source(entry.actor.root.global_position).z
 var scale_value:Vector3=ui.confirm.root.scale
 ui.confirm.root.transform=Transform3D(Rotation.source_basis(Vector3(90,90,90)).scaled(scale_value),Vector3(anchor("StartingHandZone").x,anchor("Zone_Friendly_Hand").y,hero_z))
func _start_particles(state:Dictionary,start:float,filter:String=""):
 for key in state.particles:
  var spec:Dictionary=state.particles[key]
  if filter!="":
   var accepted=false
   var ancestor:Node=spec.node
   while is_instance_valid(ancestor) and ancestor!=state.root:
    if str(ancestor.name).to_lower().contains(filter.to_lower()):accepted=true;break
    ancestor=ancestor.get_parent()
   if not accepted:continue
  if spec.renderer.is_empty():continue
  var player=preload("res://scripts/native_combat_particles.gd").new()
  spec=spec.duplicate();spec.autoplay=true;spec.source_scope_root=world;spec.compatibility_basis=world.global_basis
  player.setup(spec,assets,world,cosmetic.randi());particles.append({"node":player,"start":match_time+start})
func _button_sample(t:float):
 var enabled=ui.confirm.nodes.get(PREFIX+"-990170164037840339")
 var disabled=ui.confirm.nodes.get(PREFIX+"8618818023545999917")
 if is_instance_valid(enabled):enabled.visible=phase=="mulligan" and t>=0.2
 if is_instance_valid(disabled):disabled.visible=false
 var echo=ui.confirm.nodes.get(PREFIX+"2957582161440772653")
 if is_instance_valid(echo):
  var path:String=ui.confirm.root.get_path_to(echo)
  assets.sample_clip(ui.confirm,"AllyInHandScryLines",t*(1.5 if phase=="mulligan" else 2.0),path)
 var alpha=clampf((t-.2)/.4,0,1) if phase=="mulligan" else 1.0-clampf(t/.3,0,1)
 assets.set_labels_alpha(ui.confirm,alpha)
 var button:Node3D=ui.confirm.nodes[PREFIX+"-8031207015573253587"]
 var bone:Node3D=ui.confirm.nodes[PREFIX+"8981422828628578861"]
 if phase=="mulligan" and game.is_pointer_hover_allowed() and confirm_contains(game.pointer):button.global_position=bone.global_position
 else:button.position=button_original_position
func _selection(index:int,card:Dictionary):
 var id="selection:"+str(index)
 if not ui.has(id):
  ui[id]={"x":assets.instantiate_opening(roots.mulliganXlabelPrefab,tooltip_world,mobile),"text":assets.instantiate_opening(roots.mulliganReplaceLabelPrefab,tooltip_world,mobile)}
 var selected=phase=="mulligan" and game.flow.selected.has(index)
 var row:Dictionary=ui[id];row.x.root.visible=selected;row.text.root.visible=selected
 if not selected:return
 row.x.root.position=card.pose.position;row.x.root.basis=Rotation.source_basis(card.pose.rotation).scaled(Vector3.ONE*(1.700000047683716 if mobile else 1.91))
 row.text.root.position=card.pose.position+Vector3(0,.1,-1.1 if mobile else -float(layout.StartingHandZone.desktop.bounds_size[2])/2.6)
 if mobile:row.text.root.scale=Vector3.ONE*.9

func _choices_position(index:int,age:float)->Vector3:
 var target:Vector3=row_position(index)
 if game.flow.first_hand_count!=3:return target
 return Motion.spread_position(row_position(index,true),target,Timeline.deal_age_during_choices(age,true)-Timeline.spread_start())

func _card_pose(index:int,t:float)->Dictionary:
 # Motion helper owns the source spline/ease contract. The local match already
 # resolves replacement IDs synchronously; no visual timer chooses any card.
 var count:int=game.flow.first_hand_count
 var target:Vector3=row_position(index)
 var pose={"position":target,"rotation":Vector3.ZERO,"scale":Motion.card_scale(mobile),"visible":phase!="intro","key":game.flow.opening_hand[index]}
 if phase=="deal":
  var local:float=t-deal_delay(index)
  var initial:Vector3=row_position(index,count==3)
  pose.position=Motion.deal_position(_deck_top(),initial,local)
  pose.rotation=Motion.deal_rotation(Motion.DECK_EULER,local)
  pose.scale=Motion.deal_scale(Motion.DECK_SCALE,local,mobile)
  pose.visible=local>=0
  if count==3 and t>=Timeline.spread_start():pose.position=Motion.spread_position(initial,target,t-Timeline.spread_start())
  return pose
 if phase=="mulligan":pose.position=_choices_position(index,t)
 if phase=="replace":pose.position=_choices_position(index,replacement_choices_age+t)
 if phase=="replace" and game.flow.selected.has(index):
  var rank:int=game.flow.selected.find(index);var out_start:float=rank*.5;var in_start:float=game.flow.selected.size()*.5+rank*.5
  var history:Dictionary=game.flow.replacement_history[rank]
  if t<game.flow.selected.size()*.5:
   pose.key=history.old
   if t>=out_start:
    var start:Vector3=replacement_launch_positions.get(index,target)
    pose.position=Motion.replacement_out_position(start,anchor("MulliganedCardsPosition"),anchor("Zone_Friendly_Deck"),t-out_start)
    _replacement_clip(pose,maxf(0,t-out_start),false)
  else:
   pose.key=history.new;pose.position=Motion.replacement_in_position(_deck_top(),anchor("MulliganedCardsPosition"),target,t-in_start);pose.visible=t>=in_start
   _replacement_clip(pose,maxf(0,t-in_start),true)
 if phase in ["coin","gather"] and game.get("native_phone_hand")!=null:
  var rest:Dictionary=game.native_phone_hand.source_pose(index,count+(1 if game.flow.first_side==1 else 0),false)
  var age=t if phase=="coin" else coin_motion_age+t
  pose.position=target.lerp(rest.position,Rotation.ease_out_expo_progress(age,.5))
  pose.rotation=Rotation.interpolate(Vector3.ZERO,rest.rotation,Rotation.ease_out_expo_progress(age,.25))
  pose.scale=pose.scale.lerp(rest.scale,Rotation.ease_out_expo_progress(age,.25))
 return pose
func _replacement_clip(pose:Dictionary,age:float,reverse:bool):
 var name="MulliganCardFlipDownToDeck_iPhone" if mobile else "MulliganCardFlipDownToDeck"
 var data:Dictionary=assets.clips[name].data
 var duration:float=float(data.m_MuscleClip.m_StopTime)
 var t=clampf(duration-age if reverse else age,0,duration)
 for track in data.get("m_RotationCurves",[]):pose.quaternion=Curves.quaternion_curve(track.curve,t)
 for track in data.get("m_ScaleCurves",[]):pose.scale=Curves.vector_curve(track.curve,t,pose.scale)
func _audio_tick(t:float):
 if phase=="deal":
  for i in game.flow.first_hand_count:
   var name="deal:"+str(i)
   if t>=deal_delay(i)+.04 and not played.has(name):played[name]=true;play_audio("deal")
 elif phase=="replace":
  if t>=.2 and not played.has("button_death"):played.button_death=true;play_audio("button_death")
  for rank in game.flow.selected.size():
   var name="replace:"+str(rank)
   if t>=game.flow.selected.size()*.5+rank*.5+.5 and not played.has(name):played[name]=true;play_audio("replace")
func play_audio(event:String):
 if disposed or not Audio.permitted(game):return
 var paths={"keep":"keep_GM_ChatWarning.wav","reject":"reject_HeroDropItem1.wav","deal":"deal_FX_GameStart09_CardsOntoTable.wav","dismiss":"dismiss_FX_GameStart28_CardDismissWoosh2_v2.wav","replace":"replace_FX_GameStart30_CardReplaceSingle.wav","button_birth":"button_birth_floating_button_appears.wav","button_death":"button_death_floating_button_press.wav"}
 if not paths.has(event):return
 var player=AudioStreamPlayer.new();player.bus=&"SFX";add_child(player);player.stream=load("res://assets/original_opening/audio/"+paths[event]);player.pitch_scale=cosmetic.randf_range(.9,1.1) if event in ["keep","reject"] else 1.0;player.volume_db=linear_to_db(.5 if event.begins_with("button_") else 1.0);player.finished.connect(player.queue_free);player.play()
func project(point:Vector3)->Vector2:
 return camera.unproject_position(SourceProjection.REFLECTION*point)*game.presentation_size/Vector2(viewport.size)-game.presentation_offset
func card_contains(index:int,point:Vector2)->bool:
 if not cards.has(index) or cards[index].pose.is_empty():return false
 var pixel:Vector2=(point+game.presentation_offset)*Vector2(viewport.size)/game.presentation_size
 var origin:Vector3=SourceProjection.render_to_source(camera.project_ray_origin(pixel))
 var direction:Vector3=SourceProjection.render_to_source(camera.project_ray_normal(pixel))
 return Hit.ray_distance(origin,direction,cards[index].pose,game.definitions[cards[index].key].kind!="minion")>=0
func confirm_contains(point:Vector2)->bool:
 # DealStartingCards enables the root Collider directly. Use a ray/OBB hit,
 # not a screen rectangle or a second child collider from the visual prefab.
 var collider:Dictionary=assets.component(roots.confirm,"BoxCollider")
 if collider.is_empty():return false
 return _hit_box(ui.confirm.root,Curves.vec(collider.data.m_Center),Curves.vec(collider.data.m_Size),point)
func _hit_box(node:Node3D,center:Vector3,size:Vector3,point:Vector2)->bool:
 var pixel:Vector2=(point+game.presentation_offset)*Vector2(viewport.size)/game.presentation_size
 var inverse:Transform3D=node.global_transform.affine_inverse()
 var origin:Vector3=inverse*camera.project_ray_origin(pixel)
 var direction:Vector3=inverse.basis*camera.project_ray_normal(pixel)
 return AABB(center-size*.5,size).intersects_ray(origin,direction)!=null
func opening_position(index:int)->Vector2:
 return project(row_position(index))
func _sample_heroes():
 if not is_instance_valid(game.spatial_scene.phone_board_actors):return
 var holder=game.spatial_scene.phone_board_actors
 for side in range(2):
  var entry:Dictionary=holder.actors.get("hero:"+str(side),{})
  if entry.is_empty():continue
  var actor:Dictionary=entry.actor
  if match_time>=1.57+intro_extension:
   var blend:float=Lighting.blend(match_time-1.57-intro_extension)
   for material in actor.materials.get(PREFIX+"-5325575736001315186",[]):
    if material is ShaderMaterial:material.set_shader_parameter("_LightingBlend",blend)
  if not hero_saved.has(side):
   hero_saved[side]={"root":actor.root,"transform":actor.root.transform,"gems":[],"lighting":[]}
   for material in actor.materials.get(PREFIX+"-5325575736001315186",[]):
    if material is ShaderMaterial:hero_saved[side].lighting.append({"material":material,"value":material.get_shader_parameter("_LightingBlend")})
   for path in ["RootObject/DecorationRoot/HealthObject","RootObject/DecorationRoot/AttackObject"]:
    var gem=actor.paths.get(path)
    if is_instance_valid(gem):hero_saved[side].gems.append({"node":gem,"visible":gem.visible})
  # EndMulligan0x6005c50 shows health/attack immediately before hand layout.
  for gem in hero_saved[side].gems:gem.node.visible=gem.visible and phase in ["coin","gather"]
  if match_time<2.6333334+intro_extension:
   var clip=("hisheroAnimatesToPosition" if side==0 else "myheroAnimatesToPosition")+("_iPhone" if mobile else "")
   assets.sample_clip(actor,str(assets.objects[roots[clip]].name),maxf(0,match_time-1.1-intro_extension))
  else:actor.root.transform=hero_saved[side].transform
func _restore_heroes():
 for row in hero_saved.values():
  if is_instance_valid(row.root):row.root.transform=row.transform
  for gem in row.gems:
   if is_instance_valid(gem.node):gem.node.visible=gem.visible
  for lighting in row.lighting:
   if is_instance_valid(lighting.material):lighting.material.set_shader_parameter("_LightingBlend",lighting.value)
 hero_saved.clear()

func _apply_intro_shake(projection):
 if projection==null or shake_finished:return
 var age:float=match_time-1.57-intro_extension
 if age<0:return
 if not shake_started:
  shake_capture=SourceProjection.render_to_source(projection.camera.global_position);shake_started=true
 var offset:Vector3=Shake.draw_offset(age,cosmetic.randf_range)
 projection.camera.global_position=SourceProjection.source_to_render(shake_capture+offset)
 if age>=Shake.DURATION:shake_finished=true
