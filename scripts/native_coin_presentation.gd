extends Node
## Separate source-camera layer; no invented orthographic placement or token path.
## Candidate adapter. Not attached to match flow until source camera routing is verified.
const CameraPolicy=preload("res://scripts/source_board_camera_policy.gd")
const Player=preload("res://scripts/native_coin_player.gd")
const BoardProbe=preload("res://original_board/scripts/board_probe.gd")
var game
var camera_config:Dictionary={}
var viewport:SubViewport
var camera_root:Node3D
var camera:Camera3D
var player:Node3D
var sprite:Sprite2D
var transmission:Node
var background_copy:BackBufferCopy
var source_reflection=Transform3D(Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK),Vector3.ZERO)
func setup(host):
 game=host
 camera_config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var config=camera_config
 viewport=SubViewport.new();viewport.name="SourceCoinViewport";viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
 camera_root=Node3D.new();camera_root.transform=BoardProbe.raw_transform(config.unity_camera_root.data);viewport.add_child(camera_root)
 camera=Camera3D.new();camera_root.add_child(camera);camera.transform=BoardProbe.raw_transform(config.unity_camera.transform)
 var c=config.unity_camera.data
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL if c.orthographic else Camera3D.PROJECTION_PERSPECTIVE
 camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.fov=float(c['field of view']);camera.near=float(c['near clip plane']);camera.far=float(c['far clip plane']);camera.current=true
 camera.set_meta("source_base_fov",camera.fov)
 var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0);env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=env
 player=Player.new();player.transform=source_reflection;viewport.add_child(player);player.setup()
 # Same proven spatial C + RGB_T * background path as the main board.
 # A plain Sprite alpha blend would discard the source additive RGB at alpha0.
 transmission=preload("res://scripts/native_combat_transmission.gd").new();add_child(transmission);transmission.setup(viewport,player)
 background_copy=BackBufferCopy.new();background_copy.name="PreSourceCoinBackgroundCopy";background_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;background_copy.z_index=5;game.world_canvas.add_child(background_copy)
 process_priority=100 # Run after host source/card/gather animation updates.
 sprite=Sprite2D.new();sprite.name="SourceCoinPresentation";sprite.texture=viewport.get_texture();sprite.visible=false;sprite.z_index=5;game.world_canvas.add_child(sprite)
 sprite.material=transmission.make_composite_material();sprite.modulate=Color(1,1,1,2)
 refresh_layout()
 set_active(false)
func refresh_layout():
 viewport.size=game.board_render_target_size
 sprite.position=Vector2(800,450);sprite.scale=game.presentation_size/Vector2(viewport.size)
 CameraPolicy.apply(camera,camera_root,camera_config,game.presentation_size,CameraPolicy.source_ui_enabled())
func set_active(value:bool):
 sprite.visible=value;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
 background_copy.visible=value
 transmission.transmission_view.render_target_update_mode=viewport.render_target_update_mode
func _process(_delta:float):
 if is_instance_valid(sprite) and sprite.visible:sync_composite()
func sync_source_camera():
 var projection=preload("res://scripts/source_board_projection.gd").from_game(game)
 if projection!=null:projection.copy_camera(camera)
func sync_composite():
 sync_source_camera()
 if is_instance_valid(transmission):transmission.sync()
func _exit_tree():
 if is_instance_valid(sprite):sprite.texture=null;sprite.queue_free()
 if is_instance_valid(background_copy):background_copy.queue_free()

func begin_source_drop(friendly_goes_first:bool=false):
 player.place_at_source_bone()
 player.enable_source_ports(true)
 player.play_drop(friendly_goes_first)
 set_active(true)

func begin_source_birth(play_sound:bool=true):
 player.send_birth(play_sound)

func advance_source(delta:float,scene_seconds:float):
 if viewport.size!=game.board_render_target_size:refresh_layout()
 player.bind_source_scene_clock(scene_seconds)
 player.advance(delta)

var card_actor:Dictionary={}
var card_birth:Node3D
signal card_birth_finished
func begin_source_card():
 if not card_actor.is_empty():return
 card_actor=game.native_card_renderer.clone_world_hand("GAME_005")
 player.add_child(card_actor.root)
 # Original initial-coin path calls Actor.Hide before ActorSpell2 Birth.
 card_actor.root.visible=false
 var bone:Dictionary=player.source_spawn_bone()
 card_actor.root.position=Vector3(bone.m_LocalPosition.x,bone.m_LocalPosition.y,bone.m_LocalPosition.z)
 card_actor.root.scale=Vector3(bone.m_LocalScale.x,bone.m_LocalScale.y,bone.m_LocalScale.z)
 card_birth=load("res://scripts/native_card_birth.gd").new();player.add_child(card_birth)
 card_birth.setup(game.native_card_renderer,card_actor)
 card_birth.finished.connect(func():card_birth_finished.emit())
 card_birth.begin()

func advance_card(delta:float):
 if is_instance_valid(card_birth):card_birth.advance(delta)

var gather_from=Transform3D.IDENTITY
var gather_to=Transform3D.IDENTITY
var gather_started=false
var gather_source_rotation=false
var gather_start_euler=Vector3.ZERO
var gather_end_euler=Vector3.ZERO
static func source_very_slow_ease(age:float)->float:
 var u=clampf(age,0.0,1.0)
 return 4.0*u*u*u if u<0.5 else 1.0-pow(-2.0*u+2.0,3.0)*0.5
static func source_hand_center_for_platform(mobile:bool)->Vector3:
 # Recovered category1 TransformOverride phone-collapsed versus desktop collider.
 return Vector3(-2.800000190735,0.852410078049,-8.599999904633) if mobile else Vector3(-8.149087906,2.871613026,-9.713716984)

func begin_hand_transition(pose:Dictionary):
 if card_actor.is_empty():return
 # Source callback destroys coinObject, but actual card has its own lifetime.
 player.finish_coin_object()
 gather_from=card_actor.root.transform
 var projection=preload("res://scripts/source_board_projection.gd").from_game(game)
 if projection!=null and game.get("native_phone_hand")!=null:
  # Original initial coin is generated directly, never a deck-draw trajectory.
  # Existing caller passes a legacy screen pose; raw phone branch ignores it.
  var index=int(game.flow.first_hand_count)
  var source_pose:Dictionary=game.native_phone_hand.source_pose(index,index+1,false)
  var b=game.native_phone_hand.source_basis(source_pose.rotation)
  var scale_value:Vector3=source_pose.scale
  gather_source_rotation=true
  var initial_euler=gather_from.basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
  gather_start_euler=Vector3(fposmod(rad_to_deg(initial_euler.x),360.0),fposmod(rad_to_deg(initial_euler.y),360.0),fposmod(rad_to_deg(initial_euler.z),360.0))
  gather_end_euler=source_pose.rotation
  gather_to=Transform3D(Basis(b.x*scale_value.x,b.y*scale_value.y,b.z*scale_value.z),source_pose.position)
  gather_started=true
  return
 # Explicit endpoint adapter to existing baked-hand renderer. Source tween is
 # VERY_SLOW=1s/easeInOutCubic; source ZoneHand collider supplies target depth.
 var source_hand_center=source_hand_center_for_platform(OS.has_feature("android") or OS.has_feature("ios"))
 var hand_world=player.global_transform*source_hand_center
 var depth=-(camera.global_transform.affine_inverse()*hand_world).z
 var screen=(Vector2(pose.pos)+game.presentation_offset)*Vector2(viewport.size)/game.presentation_size
 var center_world=camera.project_position(screen,depth)
 var pixels_per_logical=float(viewport.size.y)/game.presentation_size.y
 var s=(242.0*float(pose.scale)*pixels_per_logical/float(viewport.size.y))*(2.0*depth*tan(deg_to_rad(camera.fov)*0.5))/3.23
 var bake_inverse=Basis.from_euler(Vector3(PI/2.0,0,0))
 var source_mirror=source_reflection.basis
 var basis=camera.global_transform.basis*Basis(Vector3.BACK,-float(pose.angle))*bake_inverse*source_mirror
 basis=basis.scaled(Vector3.ONE*s)
 var source_face_center=Vector3(-0.05385,0,0.04296)
 gather_to=player.global_transform.affine_inverse()*Transform3D(basis,center_world-basis*source_face_center)
 gather_started=true
func sample_hand_transition(age:float):
 if not gather_started:return
 var a=source_very_slow_ease(age)
 if gather_source_rotation:
  var tween=preload("res://scripts/source_itween_rotation.gd")
  var b=tween.source_basis(tween.interpolate(gather_start_euler,gather_end_euler,a))
  var s=gather_from.basis.get_scale().lerp(gather_to.basis.get_scale(),a)
  card_actor.root.transform=Transform3D(Basis(b.x*s.x,b.y*s.y,b.z*s.z),gather_from.origin.lerp(gather_to.origin,a))
  return
 var ea=gather_from.basis.orthonormalized().get_euler(EULER_ORDER_YXZ);var eb=gather_to.basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
 var angles=Vector3(lerp_angle(ea.x,eb.x,a),lerp_angle(ea.y,eb.y,a),lerp_angle(ea.z,eb.z,a))
 var scale=gather_from.basis.get_scale().lerp(gather_to.basis.get_scale(),a)
 card_actor.root.transform=Transform3D(Basis.from_euler(angles,EULER_ORDER_YXZ)*Basis.from_scale(scale),gather_from.origin.lerp(gather_to.origin,a))
