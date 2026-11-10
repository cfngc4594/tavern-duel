extends Node
const SourceStore=preload('res://original_board/scripts/board_source_store.gd')
const Curves=preload('res://original_board/scripts/source_legacy_curves.gd')
const SOURCE='res://original_board/assets/door/door.json'
var probe
var source:Dictionary
var clips:Dictionary={}
var targets:Dictionary={}
var state='closed'
var animation_time=0.0
var animation_name=''
var rng=RandomNumberGenerator.new()
var events:Array=[]
var audio_players:Array=[]
var audio_enabled=true
var listener:AudioListener3D
var closed=false
func setup(p,options:Dictionary={}):
 probe=p;source=SourceStore.json_for(probe,str(options.get('source_file',SOURCE)));rng.randomize()
 for name in source.clips:
  clips[name]=SourceStore.json_for(probe,'res://original_board/assets/door/'+source.clips[name].raw_file)
 for path in source.nodes.animated_targets:
  targets[path]=probe.source_nodes[source.nodes.animated_targets[path]]
 listener=AudioListener3D.new();listener.name='OriginalBoardAudioListener';probe.camera_root.add_child(listener)
 if source.has('listener_transform'):
  listener.transform=probe.raw_transform(source.listener_transform)
 else:
  var cameras=SourceStore.json_for(probe,'res://original_board/references/board_cameras_source.json')
  listener.transform=probe.raw_transform(cameras.objects['cab-82d08c8cc01bd15ce55e7d57190fd3af:-7043871136962440904'].data)
 listener.make_current()
 events.append({'event':'ready','state':state})
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
 if discriminant<0:return false
 return -b+sqrt(discriminant)>=0
func target_screen()->Vector2:
 var node=probe.source_nodes[source.nodes.click_collider]
 return probe.camera.unproject_position(node.global_transform*probe.source_vector(source.collider.data.m_Center))
func handle_input(event)->bool:
 if event is not InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return false
 if not hit_test(event.position):return false
 if state not in ['closed','open']:
  events.append({'event':'busy_click_ignored','state':state});return true
 _start('opening' if state=='closed' else 'closing');return true
func _start(next:String):
 state=next;animation_time=0.0
 animation_name=source.state_contract[state].clip
 Curves.apply(clips[animation_name],0.0,targets)
 events.append({'event':'animation_start','state':state,'clip':animation_name})
 _play_sound(source.state_contract[state].audio)
func advance(dt:float):
 if closed:return
 if state in ['opening','closing']:
  animation_time+=dt
  var duration=float(source.clips[animation_name].duration_seconds)
  Curves.apply(clips[animation_name],minf(animation_time,duration),targets)
  if animation_time>=duration:
   state=source.state_contract[state].on_animation_finished
   events.append({'event':'animation_finished','state':state,'sample_time':duration,'endpoint_hold':'compatibility; native post-disable pose persistence not sampled'})
 for player in audio_players.duplicate():
  if not is_instance_valid(player):audio_players.erase(player)
func _play_sound(kind:String):
 var a=source.audio[kind]
 var total=0.0
 for w in a.weights:total+=float(w)
 var r=rng.randf()*total;var chosen=a.clips.size()-1
 for i in range(a.clips.size()):
  r-=float(a.weights[i])
  if r<=0:chosen=i;break
 var c=a.clips[chosen];var pitch=rng.randf_range(a.pitch_min,a.pitch_max)
 var pos=probe.source_nodes[source.nodes.audio_anchor].global_position
 var distance=pos.distance_to(listener.global_position)
 var cfg=source.runtime_audio_source_template.audio_source
 var gain=1.0-clampf((distance-float(cfg.MinDistance))/(float(cfg.MaxDistance)-float(cfg.MinDistance)),0.0,1.0)
 var e={'event':'audio_start','kind':kind,'source_guid':c.guid,'clip':c.file,'pitch':pitch,'volume':a.volume_min,'distance':distance,'linear_distance_gain':gain,'spatial_blend':a.spatial_blend,'backend':'Godot 3D pan compatible; Unity mixer/pan not pixel-sampled','audio_enabled':audio_enabled}
 events.append(e)
 if not audio_enabled:return
 var stream=AudioStreamWAV.load_from_file('res://original_board/assets/door/'+c.file)
 if stream==null:events.append({'event':'audio_error','file':c.file});return
 var player=AudioStreamPlayer3D.new();player.bus=&"SFX";player.name='OriginalDoorSound';probe.source_root.add_child(player);player.global_position=pos
 player.stream=stream;player.pitch_scale=pitch;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;player.max_distance=0
 player.volume_db=linear_to_db(maxf(float(a.volume_min)*gain,0.00001));player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
 audio_players.append(player);player.finished.connect(player.queue_free);player.play()
func get_audit():
 return {'state':state,'animation_time':animation_time,'animation_name':animation_name,'events':events.duplicate(true),'active_audio_players':audio_players.filter(func(p):return is_instance_valid(p)).size(),'input':'original sphere collider ray test; no other board colliders active','curve_policy':'original unweighted Hermite quaternion components + normalization','endpoint_hold':'compatibility; native disabled-pose behavior not sampled','spatial_audio':'source listener/anchor/clip/volume/pitch/linear rolloff; Godot pan, no native mixer parity','audio_omissions':['Original listener ReverbZone preset27 not translated','Original mixer/ducking/global user settings not reproduced']}
func close_interaction():
 if closed:return
 closed=true
 for p in audio_players:
  if is_instance_valid(p):p.stop();p.queue_free()
 audio_players.clear();targets.clear()
 if is_instance_valid(listener):listener.clear_current();listener.queue_free()
