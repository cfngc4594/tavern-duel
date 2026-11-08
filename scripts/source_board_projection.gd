extends RefCounted
## Shared phone camera registration. All public world coordinates are raw Unity.
## A logical point has no world height: callers must supply a verified anchor or
## an explicit source plane. Never infer a table height from a screen point.
const REFLECTION=Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK)
const META="source_board_projection"
var camera:Camera3D
var viewport_size:=Vector2.ZERO
var canvas_size:=Vector2.ZERO
var presentation_offset:=Vector2.ZERO
var anchors:Dictionary={}
var blockers:Array=[]

static func install(game:Node,source_camera:Camera3D,size:Vector2,canvas:Vector2,offset:Vector2,source_anchors:Dictionary):
 var context=load("res://scripts/source_board_projection.gd").new()
 context.configure(source_camera,size,canvas,offset,source_anchors)
 if not context.is_enabled():return null
 game.set_meta(META,context)
 return context

static func unregister(game:Node):
 if game.has_meta(META):game.remove_meta(META)

static func from_game(game:Node):
 if not is_instance_valid(game) or not game.has_meta(META):return null
 var context=game.get_meta(META)
 return context if context!=null and context.is_enabled() else null

func configure(source_camera:Camera3D,size:Vector2,canvas:Vector2,offset:Vector2,source_anchors:Dictionary):
 camera=source_camera;viewport_size=size;canvas_size=canvas;presentation_offset=offset;anchors=source_anchors

func is_enabled()->bool:
 return is_instance_valid(camera) and bool(camera.get_meta("native_phone_registered",false)) and viewport_size.x>0 and viewport_size.y>0 and canvas_size.x>0 and canvas_size.y>0

func block(reason:String):
 if not blockers.has(reason):blockers.append(reason)

static func vector(value):
 if value is Vector3:return value if value.is_finite() else null
 if value is Array and value.size()==3:return Vector3(value[0],value[1],value[2])
 if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):return Vector3(value.x,value.y,value.z)
 return null

static func source_to_render(point:Vector3)->Vector3:return REFLECTION*point
static func render_to_source(point:Vector3)->Vector3:return REFLECTION*point

func source_to_screen(point:Vector3)->Vector2:
 if not is_enabled():return Vector2.INF
 return camera.unproject_position(source_to_render(point))*canvas_size/viewport_size-presentation_offset

func render_to_screen(point:Vector3)->Vector2:return source_to_screen(render_to_source(point))

func screen_ray_to_source(point:Vector2)->Dictionary:
 if not is_enabled() or not point.is_finite():return {}
 var pixel=(point+presentation_offset)*viewport_size/canvas_size
 return {"origin":render_to_source(camera.project_ray_origin(pixel)),"direction":render_to_source(camera.project_ray_normal(pixel)).normalized()}

func screen_to_source_on_plane(point:Vector2,plane:Plane)->Dictionary:
 var ray=screen_ray_to_source(point)
 if ray.is_empty():return {}
 var hit=plane.intersects_ray(ray.origin,ray.direction)
 return {"position":hit} if hit!=null else {}

func resolve_anchor(subject)->Dictionary:
 var result:Dictionary={}
 if subject is String:
  if not anchors.has(subject):block("Missing verified source anchor: "+subject);return {}
  result=anchors[subject].duplicate()
  if not bool(result.get("verified",false)) or str(result.get("source","")).is_empty():block("Unverified source anchor: "+subject);return {}
 elif subject is Dictionary:
  if subject.has("source_world_position"):
   result={"position":subject.source_world_position,"source":"runtime source_world_position"}
   if subject.has("source_world_scale"):result.scale=subject.source_world_scale
   if subject.has("source_world_rotation"):result.rotation=subject.source_world_rotation
  elif subject.get("type","")=="unit" and subject.has("unit"):return resolve_anchor(subject.unit)
  elif subject.get("type","")=="hero" and subject.has("side"):return resolve_anchor("hero:"+str(subject.side))
  else:block("Runtime subject has no explicit source_world_position");return {}
 else:block("Unsupported source anchor subject");return {}
 var point=vector(result.get("position"))
 if point==null or not point.is_finite():block("Source anchor has no finite position");return {}
 result.position=point
 if result.has("scale"):
  var scale_value=vector(result.scale)
  if scale_value==null:block("Source anchor has invalid scale");return {}
  result.scale=scale_value
 return result

func unit_target(unit:Dictionary)->Dictionary:
 var point=vector(unit.get("source_world_target"))
 if point==null:block("Unit has no explicit source_world_target");return {}
 return {"position":point,"source":"runtime source_world_target"}

func source_delta_to_screen(anchor:Vector3,delta:Vector3)->Vector2:
 return source_to_screen(anchor+delta)-source_to_screen(anchor)

func copy_camera(target:Camera3D)->bool:
 if not is_enabled() or not is_instance_valid(target):return false
 for property in ["projection","keep_aspect","fov","size","frustum_offset","near","far","h_offset","v_offset"]:target.set(property,camera.get(property))
 target.global_transform=camera.global_transform
 target.set_meta("native_phone_registered",true)
 if camera.has_meta("source_unshaken_global_transform"):target.set_meta("source_unshaken_global_transform",camera.get_meta("source_unshaken_global_transform"))
 target.set_meta("source_camera_shake_offset",camera.get_meta("source_camera_shake_offset",Vector3.ZERO))
 return true

func get_audit()->Dictionary:
 return {"enabled":is_enabled(),"viewport_size":viewport_size,"canvas_size":canvas_size,"offset":presentation_offset,"anchor_keys":anchors.keys(),"blockers":blockers.duplicate(),"world_space":"raw Unity; Z reflection applied exactly once at rendering"}

func apply_camera_source_offset(source_offset:Vector3)->bool:
 if not is_enabled() or not source_offset.is_finite():return false
 if not camera.has_meta("source_unshaken_global_transform"):
  block("Source camera base transform was not registered by CameraPolicy");return false
 var base:Transform3D=camera.get_meta("source_unshaken_global_transform")
 # CameraShakeMgr uses Transform.position (WORLD), not local camera axes.
 camera.global_transform=Transform3D(base.basis,base.origin+source_to_render(source_offset))
 camera.set_meta("source_camera_shake_offset",source_offset)
 return true

func restore_camera_base()->bool:
 return apply_camera_source_offset(Vector3.ZERO)

func sync_camera_followers(followers:Array)->void:
 for follower in followers:
  if is_instance_valid(follower) and follower!=camera:copy_camera(follower)
