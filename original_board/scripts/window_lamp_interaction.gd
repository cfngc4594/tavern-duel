extends Node
## Enabled original Window_Clickable FSM, not its disabled collider-attached duplicate.
const SOURCE='res://original_board/assets/window_lamp/window.json'
var probe
var source:Dictionary={}
var state='State 1'
var wait_elapsed=0.0
var closed=false
var audio_enabled=true
var rng=RandomNumberGenerator.new()
var events:Array=[]
var errors:Array=[]
var audio_players:Array=[]
var target_renderer:MeshInstance3D
var original_material:Material
var shifted_material:ShaderMaterial
var listener:AudioListener3D
func setup(p):
 probe=p;source=JSON.parse_string(FileAccess.get_file_as_string(SOURCE));rng.randomize()
 if not source.source_enabled or not source.source_active:
  errors.append('Source enabled controller expected');closed=true;return
 listener=probe.door_interaction.listener
 target_renderer=probe.renderer_nodes[source.nodes.target_renderer]
 original_material=target_renderer.get_surface_override_material(int(source.material_index))
 if original_material is not ShaderMaterial:
  errors.append('Source shader material missing');closed=true;return
 var off=source.materials.state1;var on=source.materials.state4
 if off.shader!=on.shader or off.texture!=on.texture:
  errors.append('Source material clone contract no longer valid');closed=true;return
 if probe.data.materials[off.id].shader!=off.shader:
  errors.append('Base source shader does not match');closed=true;return
 shifted_material=original_material.duplicate(false)
 if probe.has_method('register_source_lighting_material'):probe.register_source_lighting_material(shifted_material)
 shifted_material.resource_name=on.name
 var st=on.st
 shifted_material.set_shader_parameter('_MainTex_ST',Vector4(st[0],st[1],st[2],st[3]))
 events.append({'event':'ready','state':state,'source_fsm':source.source_fsm_id,'changed_surface':int(source.material_index),'original_material':off.id,'shifted_material':on.id})
 _play_sound('State 1')
func hit_test(screen:Vector2)->bool:
 if closed:return false
 var node=probe.source_nodes[source.nodes.click_collider]
 var c=source.collider.data
 if not c.m_Enabled or not node.is_visible_in_tree():return false
 var center=node.global_transform*probe.source_vector(c.m_Center)
 var scale=node.global_basis.get_scale().abs()
 var radius=float(c.m_Radius)*maxf(scale.x,maxf(scale.y,scale.z))
 var origin=probe.camera.project_ray_origin(screen)
 var direction=probe.camera.project_ray_normal(screen).normalized()
 var rel=origin-center;var b=rel.dot(direction);var discriminant=b*b-(rel.dot(rel)-radius*radius)
 return discriminant>=0 and -b+sqrt(maxf(discriminant,0.0))>=0
func target_screen()->Vector2:
 var node=probe.source_nodes[source.nodes.click_collider]
 return probe.camera.unproject_position(node.global_transform*probe.source_vector(source.collider.data.m_Center))
func handle_input(event)->bool:
 if closed or event is not InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return false
 if not hit_test(event.position):return false
 if state not in ['State 1','State 4']:
  events.append({'event':'busy_click_ignored','state':state});return true
 wait_elapsed=0.0
 if state=='State 1':
  state='State 2';target_renderer.set_surface_override_material(int(source.material_index),shifted_material)
  events.append({'event':'material_swap','state':state,'material':source.materials.state4.id,'surface':int(source.material_index)})
  _play_sound('State 2')
 else:
  state='State 3';target_renderer.set_surface_override_material(int(source.material_index),original_material)
  events.append({'event':'material_swap','state':state,'material':source.materials.state1.id,'surface':int(source.material_index)})
 return true
func advance(dt:float):
 if closed:return
 if state in ['State 2','State 3']:
  wait_elapsed+=maxf(dt,0.0)
  if wait_elapsed>=float(source.wait_seconds):
   state='State 4' if state=='State 2' else 'State 1'
   events.append({'event':'wait_finished','state':state,'source_wait':source.wait_seconds})
   if state=='State 1':_play_sound('State 1')
 for player in audio_players.duplicate():
  if not is_instance_valid(player):audio_players.erase(player)
func _play_sound(state_name:String):
 var a=source.audio[state_name]
 var total=0.0
 for w in a.weights:total+=float(w)
 var r=rng.randf()*total;var chosen=a.clips.size()-1
 for i in range(a.clips.size()):
  r-=float(a.weights[i])
  if r<=0:chosen=i;break
 var c=a.clips[chosen]
 var pitch=rng.randf_range(a.pitch_min,a.pitch_max);var volume=rng.randf_range(a.volume_min,a.volume_max)
 var pos=probe.source_nodes[a.anchor].global_position
 var distance=pos.distance_to(listener.global_position)
 var cfg=source.runtime_audio_source_template.audio_source
 var gain=1.0-clampf((distance-float(cfg.MinDistance))/(float(cfg.MaxDistance)-float(cfg.MinDistance)),0.0,1.0)
 events.append({'event':'audio_start','source_state':state_name,'source_guid':c.guid,'clip':c.file,'pitch':pitch,'volume':volume,'distance':distance,'linear_distance_gain':gain,'spatial_blend':a.spatial_blend,'audio_enabled':audio_enabled})
 if not audio_enabled:return
 var stream=AudioStreamWAV.load_from_file('res://original_board/assets/window_lamp/'+c.file)
 if stream==null:errors.append('Audio load failed '+c.file);return
 var player=AudioStreamPlayer3D.new();player.bus=&"SFX";player.name='OriginalWindowLampSound';probe.source_root.add_child(player);player.global_position=pos
 player.stream=stream;player.pitch_scale=pitch;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance=0
 player.volume_db=linear_to_db(maxf(volume*gain,0.00001));player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
 audio_players.append(player);player.finished.connect(player.queue_free);player.play()
func get_audit():
 return {'state':state,'wait_elapsed':wait_elapsed,'closed':closed,'errors':errors.duplicate(),'events':events.duplicate(true),'active_audio_players':audio_players.filter(func(p):return is_instance_valid(p)).size(),'source_fsm':source.get('source_fsm_id',''),'material_index':0,'input':'source sphere collider ray; source zero click gate; press only; wait ignores clicks','material_policy':'same source Diffuse shader and texture, exact source UV ST; only target renderer slot0 changed; slot1 unchanged','audio_policy':'Original clips, anchors, ranges, linear-distance template; shared original listener; separate visual RNG; Godot panning compatibility, no Unity mixer/reverb parity','shader_boundary':'BoardProbe source-formula adapter; ambient/URP/shadow compatibility boundaries retained'}
func close_interaction():
 if closed:return
 closed=true
 if is_instance_valid(target_renderer):target_renderer.set_surface_override_material(int(source.material_index),original_material)
 for p in audio_players:
  if is_instance_valid(p):p.stop();p.queue_free()
 audio_players.clear();shifted_material=null;original_material=null;target_renderer=null;listener=null
