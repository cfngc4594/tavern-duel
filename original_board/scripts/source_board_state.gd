extends RefCounted
## Board.cs source state, not a screen tint or board transform animation.
## Phone binding only. The host owns when to advance the opening/gameplay clock.
## Evidence: phone_board_p6_mulligan/SOURCE_BOARD_STATE.md.
const MULLIGAN_AMBIENT=Color(0.1607843041419983,0.19215689599514008,0.282353013753891,1.0)
const RAISE_SECONDS=3.0
const NORMAL_SPEED=1.0
const QUICK_SPEED=5.0
var owner_probe
var ambient_target=Color.WHITE
var directional_target=0.0
var ambient=Color.WHITE
var directional_intensity=0.0
var raised_lights=false
var tween_active=false
var tween_elapsed=0.0
var tween_duration=0.0
var tween_from_ambient=Color.WHITE
var tween_to_ambient=Color.WHITE
var tween_from_intensity=0.0
var tween_to_intensity=0.0
var combined_node:Node3D
var split_node:Node3D
var closed=false
var raise_count=0
var ignored_raise_count=0
var lifecycle=0
var last_operation='serialized_settled'

func setup(probe):
 owner_probe=probe
 var board:Dictionary=probe.data.board.data
 var c:Dictionary=board.m_AmbientColor
 ambient_target=Color(c.r,c.g,c.b,c.a)
 directional_target=float(board.m_DirectionalLightIntensity)
 var cab=str(probe.data.board.id).get_slice(':',0)
 combined_node=probe.source_nodes.get(cab+':'+str(board.m_CombinedPlaySurface.m_PathID))
 split_node=probe.source_nodes.get(cab+':'+str(board.m_SplitPlaySurface.m_PathID))
 # The static probe enters at the already-settled board. A real opening calls
 # SetMulliganLighting after this setup, before the first visible opening frame.
 ambient=ambient_target;directional_intensity=directional_target
 _publish_lighting()

func set_mulligan_lighting():
 if closed:return
 # Board.SetMulliganLighting does NOT reset m_raisedLights or stop ValueTo.
 ambient=MULLIGAN_AMBIENT;directional_intensity=0.0
 last_operation='set_mulligan_lighting'
 _publish_lighting()

func combined_surface()->bool:
 return _set_surface(true)

func split_surface()->bool:
 return _set_surface(false)

func _set_surface(combined:bool)->bool:
 if closed or not is_instance_valid(combined_node) or not is_instance_valid(split_node):return false
 # Match the source's all-or-nothing reference checks and assignment order.
 combined_node.visible=combined
 split_node.visible=not combined
 last_operation='combined_surface' if combined else 'split_surface'
 return true

func raise_lights(speed:float=NORMAL_SPEED)->bool:
 if closed:return false
 if raised_lights:
  ignored_raise_count+=1
  return false
 # Production source callers use only 1 or 5. Invalid adapter input must not
 # poison renderer uniforms; this validation is not claimed as source behavior.
 if not is_finite(speed) or speed<=0.0:return false
 tween_from_ambient=ambient;tween_to_ambient=ambient_target
 tween_from_intensity=directional_intensity;tween_to_intensity=directional_target
 tween_duration=RAISE_SECONDS/speed;tween_elapsed=0.0;tween_active=true
 raised_lights=true;raise_count+=1;last_operation='raise_lights'
 return true

func raise_lights_quickly()->bool:
 return raise_lights(QUICK_SPEED)

static func ease_in_out_quad(t:float)->float:
 # Blizzard.T5.iTween.dll EaseType=2, easeInOutQuad 0x060000a0.
 if t<0.5:return 2.0*t*t
 return -0.5*((2.0*t-1.0)*(2.0*t-3.0)-1.0)

func advance(dt:float):
 if closed or not tween_active or not is_finite(dt) or dt<0.0:return
 # iTween.Update -> TweenUpdate applies the CURRENT percentage and callback,
 # then UpdatePercentage adds deltaTime. Completion writes the exact endpoint
 # on the following Update. Keep this source sample-before-increment order.
 if tween_elapsed>=tween_duration:
  ambient=tween_to_ambient;directional_intensity=tween_to_intensity
  tween_active=false;last_operation='raise_complete'
 else:
  var weight=ease_in_out_quad(tween_elapsed/tween_duration)
  ambient=tween_from_ambient.lerp(tween_to_ambient,weight)
  directional_intensity=lerpf(tween_from_intensity,tween_to_intensity,weight)
  tween_elapsed+=dt
 _publish_lighting()

func reset_for_board_load():
 if closed:return
 # Host lifecycle adapter: a new match in this reusable Godot board corresponds
 # to a NEW source Board instance. Never call this from SetMulliganLighting.
 tween_active=false;tween_elapsed=0.0;tween_duration=0.0;raised_lights=false
 raise_count=0;ignored_raise_count=0;lifecycle+=1
 ambient=ambient_target;directional_intensity=directional_target
 split_surface();last_operation='fresh_board_lifecycle'
 _publish_lighting()

func _publish_lighting():
 if owner_probe==null:return
 if is_instance_valid(owner_probe.source_light):owner_probe.source_light.light_energy=directional_intensity
 if owner_probe.material_factory!=null:owner_probe.material_factory.apply_source_lighting(ambient,directional_intensity)

func get_lighting()->Dictionary:
 return {'ambient':ambient,'directional_intensity':directional_intensity}

func get_audit()->Dictionary:
 return {'source':'Board.SetMulliganLighting 0x06012c27; RaiseTheLights 0x06012c26; Combined/Split 0x06012c2e/2f',
  'ambient_rgba':[ambient.r,ambient.g,ambient.b,ambient.a],'target_ambient_rgba':[ambient_target.r,ambient_target.g,ambient_target.b,ambient_target.a],
  'directional_intensity':directional_intensity,'target_directional_intensity':directional_target,
  'raised_lights':raised_lights,'tween_active':tween_active,'elapsed':tween_elapsed,'duration':tween_duration,
  'easing':'iTween.EaseType 2 = easeInOutQuad','sample_order':'Apply current percentage, then add deltaTime; exact endpoint next Update',
  'combined_active':combined_node.visible if is_instance_valid(combined_node) else null,
  'split_active':split_node.visible if is_instance_valid(split_node) else null,
  'raise_count':raise_count,'ignored_raise_count':ignored_raise_count,'lifecycle':lifecycle,'last_operation':last_operation,'closed':closed,
  'geometry_mutation':false,'limits':['Ordinary base PHONE board. Seasonal events, corner replacements and custom cosmetics are not inferred.','Raw ambient to flat SH.w remains the existing compatibility projection, not recovered native SH coefficients.']}

func close():
 closed=true;tween_active=false;owner_probe=null;combined_node=null;split_node=null
