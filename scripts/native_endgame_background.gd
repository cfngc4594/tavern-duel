extends Node
## Original EndGameScreen FullScreenFX request and a local canvas adaptation.
## Preset37: Type7, Perspective1, .5 scaled seconds, easeOutCirc19.
## This owns only the result view. It never changes the game's viewport/material,
## shared glow manager, rules, or other source effect handles.
const SourceProjection=preload("res://scripts/source_board_projection.gd")
const DURATION: float=0.5
const SHADER_PATH="res://shaders/native_endgame_background.gdshader"
const LITE_SHADER_PATH="res://shaders/native_endgame_background_lite.gdshader"
const VIGNETTE_MASK_PATH="res://assets/original_endgame_v33/background/vignette_mask.png"
const LITE_SETTING="render_quality/terminal_background_lite"
var game: Node
var phase: String="idle"
var age: float=0.0
var amount: float=0.0
var from_amount: float=0.0
var generation: int=0
var history: Array=[]
var blockers: Array=[]
var layer: CanvasLayer
var board_view: SubViewport
var passes
var overlay: ColorRect
var result_view: SubViewport
var result_scene: Node3D
var result_camera: Camera3D
var transmission
var dimensions:=Vector2i(1600,900)
var allocated: int=0
var retired: int=0
var backdrop_lite: bool=false
var backdrop_setup_usec: int=0
var result_setup_usec: int=0

func setup(owner_game: Node):
 game=owner_game;set_process(false)

func begin() -> Node3D:
 blockers.clear()
 backdrop_setup_usec=0;result_setup_usec=0
 generation+=1;age=0.0;from_amount=amount;phase="active";set_process(false)
 history.append({"event":"StartEffect","preset":"BlurVignetteDesaturatePerspective","generation":generation})
 if game.headless:return null
 var use_lite:=_use_lite_backdrop()
 if is_instance_valid(layer) and backdrop_lite!=use_lite:
  _retire_result()
  _dispose_canvas()
 backdrop_lite=use_lite
 if not _shaders_ready():
  blockers.append("Original FullScreenFX shader translation not available")
  return null
 var setup_started:=Time.get_ticks_usec()
 _ensure_canvas()
 backdrop_setup_usec=Time.get_ticks_usec()-setup_started
 setup_started=Time.get_ticks_usec()
 _make_result_view()
 result_setup_usec=Time.get_ticks_usec()-setup_started
 _update_uniforms()
 return result_scene

func _use_lite_backdrop() -> bool:
 match ProjectSettings.get_setting("render_quality/android_fx_benchmark_arm", ""):
  "candidate", "endgame", "candidate_hero_lite", "candidate_spell_lite":return true
  "reference", "no_bloom", "spell":return false
 return bool(ProjectSettings.get_setting_with_override(LITE_SETTING)) if ProjectSettings.has_setting(LITE_SETTING) else false

func _ensure_canvas():
 if is_instance_valid(layer):return
 dimensions=game.board_render_target_size
 if not backdrop_lite:
  board_view=SubViewport.new();board_view.name="LiveBoardCanvasOnly";board_view.size=dimensions;board_view.disable_3d=true;board_view.use_hdr_2d=false
  board_view.world_2d=game.get_viewport().world_2d;board_view.canvas_cull_mask=1
  board_view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS;board_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(board_view)
  board_view.canvas_transform=Transform2D(Vector2(float(dimensions.x)/game.presentation_size.x,0),Vector2(0,float(dimensions.y)/game.presentation_size.y),Vector2.ZERO)
  passes=preload("res://scripts/native_endgame_background_passes.gd").new();passes.setup(self,board_view.get_texture(),dimensions)
  allocated+=1+passes.views.size()
 layer=CanvasLayer.new();layer.name="OriginalEndGameBackgroundScope";layer.layer=1;add_child(layer)
 overlay=ColorRect.new();overlay.name="FullScreenFXThenOriginalResult";overlay.size=game.presentation_size;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.visibility_layer=2
 var material:=ShaderMaterial.new();overlay.material=material
 if backdrop_lite:
  # Existing effects have already copied the screen earlier on layer 0.
  # Refresh the copy here after the board and before the result and fixed GUI.
  var copy:=BackBufferCopy.new();copy.name="TerminalBoardCopy";copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;copy.visibility_layer=2;layer.add_child(copy)
  material.shader=load(LITE_SHADER_PATH)
  material.set_shader_parameter("_VignetteMask",load(VIGNETTE_MASK_PATH))
 else:material.shader=load(SHADER_PATH)
 layer.add_child(overlay)
 allocated+=1

func refresh_layout():
 if not is_instance_valid(overlay):return
 dimensions=game.board_render_target_size
 overlay.size=game.presentation_size
 if is_instance_valid(board_view):
  board_view.size=dimensions
  board_view.canvas_transform=Transform2D(Vector2(float(dimensions.x)/game.presentation_size.x,0),Vector2(0,float(dimensions.y)/game.presentation_size.y),Vector2.ZERO)
  if passes!=null:
   retired+=passes.views.size();passes.dispose()
  passes=preload("res://scripts/native_endgame_background_passes.gd").new();passes.setup(self,board_view.get_texture(),dimensions)
  allocated+=passes.views.size()
 if is_instance_valid(result_view):result_view.size=dimensions
 if is_instance_valid(result_camera):_copy_camera(game.spatial_scene.camera)
 if is_instance_valid(transmission):transmission.sync()
 _update_uniforms()

func _make_result_view():
 _retire_result()
 var source_camera: Camera3D=game.spatial_scene.camera
 var source_view: Viewport=source_camera.get_viewport()
 dimensions=game.board_render_target_size
 result_view=SubViewport.new();result_view.name="OriginalResultColor";result_view.size=dimensions
 result_view.own_world_3d=true;result_view.transparent_bg=true;result_view.msaa_3d=source_view.msaa_3d
 result_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;result_view.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
 add_child(result_view)
 result_scene=Node3D.new();result_scene.name="OriginalResultSceneOnly";result_view.add_child(result_scene)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0)
 environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;result_scene.add_child(environment)
 # Existing host lighting is compatibility input, not recovered Unity globals.
 for child in game.spatial_scene.get_children():
  if child is DirectionalLight3D:result_scene.add_child(child.duplicate())
 result_camera=Camera3D.new();result_camera.name="OriginalResultRegistrationCamera";result_scene.add_child(result_camera);result_camera.current=true
 _copy_camera(source_camera)
 transmission=preload("res://scripts/native_combat_transmission.gd").new();add_child(transmission);transmission.setup(result_view,result_scene)
 overlay.size=game.presentation_size
 overlay.material.set_shader_parameter("_ResultColor",result_view.get_texture())
 overlay.material.set_shader_parameter("_ResultTransmission",transmission.get_texture())
 overlay.material.set_shader_parameter("_HasResult",true)
 allocated+=2

func _copy_camera(source: Camera3D):
 if not is_instance_valid(result_camera):return
 var source_projection=SourceProjection.from_game(game)
 if source_projection!=null:
  source_projection.copy_camera(result_camera);return
 for property in ["projection","keep_aspect","fov","size","frustum_offset","near","far","h_offset","v_offset","cull_mask"]:result_camera.set(property,source.get(property))
 result_camera.global_transform=source.global_transform
 if source.projection==Camera3D.PROJECTION_ORTHOGONAL:result_camera.size=source.size*game.presentation_size.y/900.0
 # TwoScoop.Start / EndGameScreen.Awake set layer19: main-camera contents
 # exempt from full-screen effects, NOT fixed GUI. This independent viewport
 # receives the same final screen translation once; board_view already has it.
 var offset:Vector2=game.world_canvas.position-game.presentation_offset
 result_camera.position+=Vector3(-offset.x/100.0,offset.y/100.0,0.0)

func advance(delta: float):
 if phase=="idle":return
 age+=maxf(0.0,delta)
 var eased: float=_ease_out_circ(clampf(age/DURATION,0.0,1.0))
 amount=lerpf(from_amount,1.0 if phase=="active" else 0.0,eased)
 _update_uniforms()
 if phase=="released" and age>=DURATION:
  _dispose_canvas();phase="idle";amount=0.0;set_process(false)
  history.append({"event":"StopEffect interpolation completed","generation":generation})

func _process(delta: float):
 # The result owner no longer advances once clear/restart sets its phase idle.
 # Only this released, generation-owned handle finishes its original .5s fade.
 if phase=="released":advance(delta)

func sync():
 if is_instance_valid(result_camera):_copy_camera(game.spatial_scene.camera)
 if is_instance_valid(transmission):transmission.sync()
 _update_uniforms()

func _shaders_ready() -> bool:
 if backdrop_lite:return ResourceLoader.exists(LITE_SHADER_PATH) and ResourceLoader.exists(VIGNETTE_MASK_PATH)
 if not ResourceLoader.exists(SHADER_PATH):return false
 for suffix in ["desaturation","vignette","blur","blend"]:
  if not ResourceLoader.exists("res://shaders/native_endgame_bg_"+suffix+".gdshader"):return false
 return true

func _update_uniforms():
 if not is_instance_valid(overlay):return
 if backdrop_lite:
  overlay.material.set_shader_parameter("_BackdropAmount",amount)
  overlay.material.set_shader_parameter("_BackdropSaturation",pow(1.0-.5*amount,3.0))
  overlay.material.set_shader_parameter("_BackdropVignette",pow(1.0-.4*amount,3.0))
 elif passes!=null:
  passes.update(amount)
  overlay.material.set_shader_parameter("_FilteredBackground",passes.get_texture())

func release():
 if phase=="idle":return
 history.append({"event":"StopEffect","generation":generation,"released":true})
 from_amount=amount;age=0.0;phase="released";_retire_result()
 set_process(true)

func _retire_result():
 if is_instance_valid(result_scene):result_scene.visible=false
 if is_instance_valid(transmission):
  for mirror in transmission.mirrors.values():
   if is_instance_valid(mirror):mirror.visible=false
  if is_instance_valid(transmission.transmission_view):transmission.transmission_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 if is_instance_valid(result_view):result_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 if is_instance_valid(overlay):
  overlay.material.set_shader_parameter("_HasResult",false)
  overlay.material.set_shader_parameter("_ResultColor",null)
  overlay.material.set_shader_parameter("_ResultTransmission",null)
 if is_instance_valid(transmission):transmission.queue_free();retired+=1
 if is_instance_valid(result_view):result_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;result_view.queue_free();retired+=1
 transmission=null;result_camera=null;result_scene=null;result_view=null

func _dispose_canvas():
 if is_instance_valid(overlay):overlay.visible=false
 if is_instance_valid(overlay) and not backdrop_lite:overlay.material.set_shader_parameter("_FilteredBackground",null)
 if is_instance_valid(layer):layer.queue_free();retired+=1
 if is_instance_valid(board_view):board_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;board_view.queue_free();retired+=1
 if passes!=null:retired+=passes.views.size();passes.dispose()
 passes=null;board_view=null;layer=null;overlay=null

func dispose():
 set_process(false);_retire_result();_dispose_canvas();phase="idle";amount=0.0

func _ease_out_circ(t: float) -> float:
 return sqrt(maxf(0.0,1.0-(t-1.0)*(t-1.0)))

func get_audit() -> Dictionary:
 var backdrop_viewports:=int(is_instance_valid(board_view))+(int(passes.views.size()) if passes!=null else 0)
 var compatibility:="Live board screen copy and approximate single-pass background filter" if backdrop_lite else "Live shared-World2D board capture excludes result overlay; original Unity perspective camera/layer partition and exact framebuffer precision are not reproduced"
 return {"phase":phase,"generation":generation,"time":age,"blend":amount,"source_preset":{"types":7,"camera_pass":1,"time":DURATION,"ease":19,"blur_amount":1.0,"blur_brightness":0.5,"blur_blend":amount,"vignette":0.4000000059604645*amount,"desaturate":0.5*amount},"source_lifecycle":"Show starts FullScreenFX; Close does not stop it; OnDestroy/clear releases with original interpolation","backdrop_mode":"single_pass" if backdrop_lite else "original_passes","backdrop_viewports":backdrop_viewports,"backdrop_setup_usec":backdrop_setup_usec,"result_setup_usec":result_setup_usec,"live_result_viewports":int(is_instance_valid(result_view))+int(is_instance_valid(transmission)),"live_canvas":is_instance_valid(layer),"live_board_view":is_instance_valid(board_view),"passes":passes.get_audit() if passes!=null else {},"allocated":allocated,"retired":retired,"blockers":blockers.duplicate(),"history":history.duplicate(true),"native_pixel_equivalence":false,"compatibility":compatibility}
