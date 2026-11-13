extends RefCounted
## Original phone prefab + AspectRatioDependentPosition.Awake interpolation.
## Resize reapplication is a Godot adapter, not verified original live resize.
const PHONE_PATH="res://original_board/references/phone_camera.json"
const REFLECTION=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
const RECIPE_SETTING="render_quality/macos_source_camera_recipe_cache"
static var runtime_layout_verified:=false
static var camera_recipe_cache_enabled:=_camera_recipe_cache_requested()
# Platform identity is input/provenance only. The phone UI is the sole product
# layout; editor preview uses it without pretending to be Android.
static var qa_phone_platform:=false
static func phone_platform_requested()->bool:
 return OS.has_feature("android") or OS.has_feature("ios") or qa_phone_platform
static func source_ui_enabled()->bool:
 # Camera, scene, actors, hand, mana and hit tests switch atomically. Keep the
 # existing readiness gates so an incomplete layout cannot produce mixed UI.
 return runtime_layout_verified and bool(ProjectSettings.get_setting("native_mobile/source_camera_enabled",false)) and bool(ProjectSettings.get_setting("native_mobile/source_consumers_verified",false))
static func is_phone()->bool:
 # Compatibility alias for historical source/fixture callers, not OS identity.
 return source_ui_enabled()
# Packaged source camera data is immutable. Return a fresh copy to preserve
# caller-owned Dictionary semantics; never expose the cached backing data.
static var _phone_data_cache: Dictionary={}
static var _recipe_canvas:=Vector2.ZERO
static var _camera_recipe:Dictionary={}

static func _camera_recipe_cache_requested()->bool:
 var args:=OS.get_cmdline_user_args()
 return OS.has_feature("macos") and not args.has("--mac-skip-source-camera-recipe-cache") \
  and (args.has("--mac-source-camera-recipe-cache") or bool(ProjectSettings.get_setting(RECIPE_SETTING,false)))

static func reset_phone_data_cache()->void:
 _phone_data_cache.clear()
 _camera_recipe.clear()
static func phone_data()->Dictionary:
 if Engine.is_editor_hint():return JSON.parse_string(FileAccess.get_file_as_string(PHONE_PATH))
 if _phone_data_cache.is_empty():_phone_data_cache=JSON.parse_string(FileAccess.get_file_as_string(PHONE_PATH))
 return _phone_data_cache.duplicate(true)
static func raw_transform(t:Dictionary)->Transform3D:
 var p=t.m_LocalPosition;var q=t.m_LocalRotation;var s=t.m_LocalScale
 var b=REFLECTION*Basis(Quaternion(q.x,q.y,q.z,q.w).normalized())*REFLECTION
 return Transform3D(Basis(b.x*s.x,b.y*s.y,b.z*s.z),REFLECTION*Vector3(p.x,p.y,p.z))
static func phone_position(aspect:float)->Vector3:
 return aspect_position(phone_data().aspect_positions,aspect)
static func aspect_position(poses:Dictionary,aspect:float)->Vector3:
 var anchors=phone_data().aspect_anchors
 var values=[poses.m_minLocalPosition,poses.m_wideLocalPosition,poses.m_extraWideLocalPosition]
 var lo=0;var hi=2
 for i in range(3):
  if float(anchors[i])>aspect:
   lo=maxi(0,i-1);hi=i if i>0 else 1;break
 var t=clampf((aspect-float(anchors[lo]))/(float(anchors[hi])-float(anchors[lo])),0.0,1.0)
 var a=values[lo];var b=values[hi]
 return Vector3(a.x,a.y,a.z).lerp(Vector3(b.x,b.y,b.z),t)
static func settings()->Dictionary:
 return phone_data().camera
static func source_fov(aspect:float)->float:
 var data=phone_data()
 var base=float(data.camera['field of view'])
 # Recovered source anchors stop at 3:2. Preserve their horizontal field below
 # that aspect so resizable 4:3 windows do not crop the end-turn/mana controls.
 # Within the source's supported range the camera stays exactly unchanged.
 var widen=maxf(1.0,float(data.aspect_anchors[0])/maxf(aspect,0.001))
 return rad_to_deg(2.0*atan(tan(deg_to_rad(base)*0.5)*widen))
static func apply(camera:Camera3D,camera_root:Node3D,canvas:Vector2)->void:
 if camera_recipe_cache_enabled and not Engine.is_editor_hint():
  if _camera_recipe.is_empty() or canvas!=_recipe_canvas:
   var data=phone_data();var c=settings()
   var aspect:=canvas.x/maxf(canvas.y,0.001)
   _camera_recipe={
    "root":raw_transform(data.root_transform),"camera":raw_transform(data.camera_transform),
    "position":REFLECTION*phone_position(aspect),"fov":source_fov(aspect),
    "projection":Camera3D.PROJECTION_ORTHOGONAL if c.orthographic else Camera3D.PROJECTION_PERSPECTIVE,
    "near":float(c['near clip plane']),"far":float(c['far clip plane'])
   }
   _recipe_canvas=canvas
  camera_root.transform=_camera_recipe.root
  camera.transform=_camera_recipe.camera
  camera.position=_camera_recipe.position
  camera.fov=_camera_recipe.fov
  camera.projection=_camera_recipe.projection
  camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=_camera_recipe.near;camera.far=_camera_recipe.far
 else:
  var data=phone_data();var c=settings()
  camera_root.transform=raw_transform(data.root_transform)
  camera.transform=raw_transform(data.camera_transform)
  camera.position=REFLECTION*phone_position(canvas.x/maxf(canvas.y,0.001))
  camera.fov=source_fov(canvas.x/maxf(canvas.y,0.001))
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL if c.orthographic else Camera3D.PROJECTION_PERSPECTIVE
  camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=float(c['near clip plane']);camera.far=float(c['far clip plane'])
 camera.set_meta("source_camera_platform","phone")
 camera.set_meta("native_phone_registered",true)
 camera.set_meta("source_unshaken_global_transform",camera.global_transform)
 camera.set_meta("source_camera_shake_offset",Vector3.ZERO)
