extends SceneTree
var game
var records=[]
const KEY='cab-3563ba8b89db13ca6eb196aa111591f1:6001481727099282376'
func _initialize():call_deferred('run')
func snap(label,e):
 var mats=[]
 for node_key in e.state.get('materials',{}):
  for m in e.state.materials[node_key]:
   if str(m.get_meta('source_key',''))==KEY:mats.append({'node':node_key,'id':m.get_instance_id(),'color':str(m.get_shader_parameter('_Color')),'meta':str(m.get_meta('source_colors',{}))})
 records.append({'stage':label,'materials':mats})
 print(label,': ',mats)
func run():
 game=load('res://main.tscn').instantiate();game.startup_mode='practice';root.add_child(game);game.set_process(false);game.sound_enabled=false
 game.headless=false;game._setup_spatial_presentation()
 var ep=game.native_combat.effect_player
 var e=ep._spawn(ep.routes['CS2_026/friendly_area'].root_key,Vector2(800,450),'CS2_026/friendly_area',123)
 e.context={'key':'CS2_026','side':0,'source':game.PLAYER_HERO,'target':{}}
 snap('spawn incl RTsetup',e)
 for event in ['__start__','None','Action']:
  ep._start_event(e,event,0.0);snap('event '+event,e)
 for age in [0.0,0.1,0.2,0.3,0.45,0.65]:
  e.age=age
  ep._run_schedules(e);snap(str(age)+' schedule',e)
  ep._sample_animations(e,age);snap(str(age)+' animation actions',e)
  for p in e.clips.values():ep.assets.sample_clip(e.state,p.clip,maxf(0.0,(age-p.start)*p.speed),p.path)
  snap(str(age)+' clips',e)
  for action in e.continuous:ep._apply_continuous(e,action)
  snap(str(age)+' continuous',e)
  for p in e.particles.values():p.node.seek(age-p.start)
  snap(str(age)+' particles',e)
  ep._bind_scene_inputs(e);snap(str(age)+' scene',e)
  e.rendertexture.sync(age);snap(str(age)+' RTsync',e)
  game.native_transmission.sync();snap(str(age)+' Tsync',e)
  await process_frame;snap(str(age)+' afterframe',e)
 FileAccess.open('/tmp/v32_color_stage_probe.json',FileAccess.WRITE).store_string(JSON.stringify(records,'  '))
 ep.cancel_all();game.queue_free();await process_frame;quit()
