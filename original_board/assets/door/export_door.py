from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
M=ROOT/'v36_work/source_board_assets/assets/manifest.json';m=json.loads(M.read_text());objs=m['objects']
fsms=json.loads((ROOT/'v36_work/source_board_flow/mop_interactions.json').read_text())
fsm=next(f for f in fsms['fsms'] if f['path'].endswith('/Mill_Door_Clickable') and f['fsm_enabled'])
scene=json.loads((ROOT/'v36_work/BoardProbe/assets/scene.json').read_text());ns={n['id']:n for n in scene['nodes']}
root='cab-995e7cbc44ff3e7f4314fc93360989d0:8367120315102262385'
col='cab-995e7cbc44ff3e7f4314fc93360989d0:4700183809534063729';sound='cab-995e7cbc44ff3e7f4314fc93360989d0:4628007443326628977'
def components(k,typ=None):
 cs=[objs[v] for r,v in objs[k]['refs'].items() if r.startswith('.m_Component[')]
 return [x for x in cs if typ is None or x['type']==typ]
def child_path(k):
 if k==root:return ''
 n=ns[k];return (child_path(n['parent'])+'/'+n['name']).strip('/')
children={}
def walk(k):
 children[child_path(k)]=k
 for n in ns.values():
  if n['parent']==k:walk(n['id'])
walk(root)
clips={}
for name in ['MOP_DoorOpen','MOP_DoorClose']:
 a=next(x for x in objs.values() if x['type']=='AnimationClip' and x['name']==name)
 src=M.parent/a['files']['animation'];d=json.loads(src.read_text());dest=OUT/'animations'/src.name;dest.parent.mkdir(exist_ok=True);shutil.copy2(src,dest)
 tracks=[]
 for rc in d['m_RotationCurves']:
  tracks.append({'path':rc['path'],'target_node_id':children[rc['path']],'property':'local_quaternion_xyzw','curve':rc['curve']})
 duration=max(key['time'] for t in tracks for key in t['curve']['m_Curve'])
 clips[name]={'source_id':a['key'],'source_sha256':a['source_object_sha256'],'raw_file':str(dest.relative_to(OUT)),'raw_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'duration_seconds':duration,'sample_rate':d['m_SampleRate'],'legacy':d['m_Legacy'],'wrap_mode_serialized':d['m_WrapMode'],'rotation_tracks':tracks,'other_curves':{k:d[k] for k in ['m_CompressedRotationCurves','m_EulerCurves','m_PositionCurves','m_ScaleCurves','m_FloatCurves','m_PPtrCurves']},'events':d['m_Events']}
prov=json.loads((ROOT/'v36_work/source_board_assets/audio/clips_provenance.json').read_text());bindings=json.loads((ROOT/'v36_work/source_board_assets/audio/sound_bindings.json').read_text())
audio={}
for state,label in [('State 2','open'),('State 3','close')]:
 s=next(x for x in fsm['states'] if x['name']==state);action=next(x for x in s['actions'] if x['class_name']=='AudioPlayRandomClipAction')['params']
 sources=[]
 for ptr in action['m_Sounds']:
  k='cab-94702b40f3bc7e46c8686903984a1bff:'+str(ptr['m_PathID']);b=bindings[k];g=b['clip_base_guids'][0];p=prov[g]
  src=ROOT/'v36_work/source_board_assets/audio'/p['source_path'];assert hashlib.sha256(src.read_bytes()).hexdigest()==p['export_sha256']
  dst=OUT/'audio'/src.name;dst.parent.mkdir(exist_ok=True);shutil.copy2(src,dst)
  sources.append({'sound_def_id':k,'sound_def':b['configuration'],'guid':g,'file':str(dst.relative_to(OUT)),'source_file':str(src.relative_to(ROOT)),'sha256':p['export_sha256'],'duration_seconds':p['duration_sec'],'sample_rate':p['sample_rate'],'channels':p['channels'],'provenance':p})
 audio[label]={'clips':sources,'weights':[x['value'] for x in action['m_Weights']],'volume_min':action['m_MinVolume']['value'],'volume_max':action['m_MaxVolume']['value'],'pitch_min':action['m_MinPitch']['value'],'pitch_max':action['m_MaxPitch']['value'],'spatial_blend':action['m_SpatialBlend']['value'],'delay_seconds':action['m_Delay'],'category':action['m_Category'],'template_source_override':None,'instance_limited':action['m_InstanceLimited'],'native_action':'AudioPlayRandomClipAction.Play 0x06016abe calls SoundManager.PlayClip(args, true, options), then Finish immediately; it does not await audio completion.'}
template=json.loads((ROOT/'v30_work/audio_assets_evidence/play_clip_template.json').read_text())
door={'schema':'source-mill-door-v1','build':m['build'],'source_manifest_sha256':hashlib.sha256(M.read_bytes()).hexdigest(),'fsm':fsm,'nodes':{'animation_root':root,'click_collider':col,'audio_anchor':sound,'animated_targets':children},'collider':components(col,'SphereCollider')[0],'animation_component':components(root,'Animation')[0],'audio_anchor_component_not_runtime_template':components(sound,'AudioSource')[0],'runtime_audio_source_template':template,'clips':clips,'audio':audio,'state_contract':{'initial':'closed','closed':{'source_state':'State 1','left_mouse_down_over_collider':'opening'},'opening':{'source_state':'State 2','clip':'MOP_DoorOpen','audio':'open','on_animation_finished':'open','mouse_input':False},'open':{'source_state':'State 4','left_mouse_down_over_collider':'closing'},'closing':{'source_state':'State 3','clip':'MOP_DoorClose','audio':'close','on_animation_finished':'closed','mouse_input':False},'gate_click_min':0,'gate_click_max':0,'gate_reset_on_open':True,'additional_colliders':[],'animation_play_mode':4,'animation_play_mode_name':'StopAll','blend_time':0.0,'stop_on_exit':False,'animation_speed':'No SetAnimationSpeed action in active door FSM; native default animation state speed assumed 1.0, not a serialized per-state speed.','finish_policy':'PlayAnimation.OnUpdate sends FINISHED when AnimationState.enabled=false; special wrapMode==8 also finishes when time>length. No audio wait. No explicit transform restore in PlayAnimation.OnExit when stopOnExit=false.','pose_persistence_boundary':'Raw Animation and clips have wrapMode=0, no PlayAutomatically; managed source does not resolve native Unity post-disable pose persistence. Holding sampled endpoint is a compatibility behavior unless native runtime sampled.'},'known_boundaries':['Quaternion component Hermite then normalization is a declared adapter of original nonweighted legacy curves, not a native Unity interpolation golden sample.','Generated source uses SoundConfig default template minDistance100/max500/linear; do not use minDistance1 from unrelated audio-anchor component.','Source Unity spatialBlend1, listener position and native pan/mixer/ducking must be separately mapped; 2D mono playback is not equivalent spatialization.','Only this enabled FSM is the behavioral owner; disabled duplicate under MOP_Mill_Door must not run.']}
(OUT/'door.json').write_text(json.dumps(door,ensure_ascii=False,indent=2)+'\n')
(OUT/'animation-playmode-enum.json').write_text(json.dumps({'assembly':'UnityEngine.AnimationModule.dll','type':'UnityEngine.PlayMode','StopSameLayer':0,'StopAll':4},indent=2))
print(json.dumps({'clips':{k:v['duration_seconds'] for k,v in clips.items()},'nodes':children,'audio_files':6,'output':str(OUT/'door.json')}))
