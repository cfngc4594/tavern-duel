extends RefCounted
## Compatibility mobile layout, not recovered original Android constants.
## Gameplay remains1600x900. Expanded scenery uses the extra display area.
const LOGICAL_SIZE := Vector2i(1600,900)
const DEFAULT_MAX_SCALE := 1.6
const MAX_SCENERY_PIXELS := 4608000.0

static func canvas_size(output:Vector2i) -> Vector2:
 var fit := maxf(0.001,minf(float(output.x)/1600.0,float(output.y)/900.0))
 return Vector2(output)/fit

static func target_size(output:Vector2i,maximum_scale:float=DEFAULT_MAX_SCALE) -> Vector2i:
 var canvas := canvas_size(output)
 var fit := minf(float(output.x)/canvas.x,float(output.y)/canvas.y)
 var factor := minf(clampf(fit,0.5,clampf(maximum_scale,0.5,2.0)),sqrt(MAX_SCENERY_PIXELS/(canvas.x*canvas.y)))
 # Spatial targets stay exact16:9; all targets share this pixel density.
 var units := maxi(1,int(floor(100.0*factor+0.00001)))
 return Vector2i(units*16,units*9)

static func scenery_size(canvas:Vector2,spatial_target:Vector2i) -> Vector2i:
 var density := float(spatial_target.y)/900.0
 return Vector2i(maxi(1,int(round(canvas.x*density))),maxi(1,int(round(canvas.y*density))))

static func logical_to_target(point:Vector2,target:Vector2i) -> Vector2:
 return point*Vector2(target)/Vector2(LOGICAL_SIZE)

static func target_to_logical_scale(target:Vector2i) -> Vector2:
 return Vector2(LOGICAL_SIZE)/Vector2(target)
