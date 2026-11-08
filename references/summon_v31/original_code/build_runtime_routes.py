import json,hashlib
from pathlib import Path
ROOT=Path('v31_work/source_code'); ASSET=Path('v31_work/TavernDuel/assets/original_summon_v31')
manifest=json.load(open(ASSET/'manifest.json')); objects=manifest['objects']
clips={}
for k,v in objects.items():
 if v['type']=='AnimationClip':
  d=v['data']; times=[x['time'] for c in ['m_RotationCurves','m_EulerCurves','m_PositionCurves','m_ScaleCurves','m_FloatCurves','m_PPtrCurves'] for curve in d.get(c,[]) for x in curve.get('curve',{}).get('m_Curve',[])]
  clips[d['m_Name']]={'key':k,'path_id':v['path_id'],'file':v['files'].get('animation'),'curve_last_key_seconds':max(times) if times else None,'duration_evidence':'legacy_curve_bounds_reconstruction','native_clip_length_measured':False}
def val(v):
 if isinstance(v,dict):
  if 'm_FileID' in v and 'm_PathID'in v:return {'file_id':v['m_FileID'],'path_id':str(v['m_PathID'])}
  if 'ownerOption' in v:return {'owner_option':v['ownerOption'],'game_object':val(v['gameObject'])}
  if v.get('useVariable') and v.get('name'):return {'variable':v['name'],'default':val(v.get('value'))}
  if 'value'in v:return val(v['value'])
  return {k:val(x) for k,x in v.items()}
 if isinstance(v,list):return [val(x) for x in v]
 return v
def convert(a):
 p=val(a['params']);out={'action_index':a['index'],'class_name':a['class_name'],'params':p}
 n=p.get('animName',p.get('m_AnimName'));out.update({'clip':clips[n]} if isinstance(n,str) and n in clips else {})
 for target in ('gameObject','m_GameObject','m_ActorObject'):
  if target in p:
   t=p[target];t=t.get('game_object',t) if isinstance(t,dict) else t
   if isinstance(t,dict) and t.get('path_id') and t['path_id']!='0':
    matches=[v for v in objects.values() if v['path_id']==t['path_id']]
    if len(matches)==1:out['target_object_key']=matches[0]['key'];out['target_object_name']=matches[0]['name']
 return out
small=.5;enemy=.4300000071525574;med=clips['AllyInPlaySpawn_Med']['curve_last_key_seconds'];large=clips['AllyInHandRaysUp']['curve_last_key_seconds'];token=clips['AllyInPlay_SummonMinionGlowFadeIn']['curve_last_key_seconds'];fadeout=clips['AllyInPlay_SummonMinionGlowFadeOut']['curve_last_key_seconds'];hidden=.5+.3499999940395355
# Pure non-premium, non-elite branch. Zero-duration transitions are in source order.
plans={
 'hand_out_small':('Card_Hand_Ally_SummonOut',[(0,1),(0,11),(0,13),(0,4),(0,7),(0,5),(1,3),(2,2)],1),
 'hand_out_medium':('Card_Hand_Ally_SummonOut_Medium_PM',[(0,1),(0,6),(0,5),(0,7),(1,3),(2,2)],1),
 'hand_out_large':('Card_Hand_Ally_SummonOut_Large_PM',[(0,1),(0,4),(0,6),(0,7),(large,3),(large,2)],large),
 'hand_out_hidden':('Card_Hidden_SummonOut',[(0,1),(.5,2),(hidden,4),(hidden+1.25,3)],hidden),
 'play_in_small':('Card_Play_Ally_SummonIn',[(0,1),(0,4),(small,2),(small+2,3)],small),
 'play_in_medium':('Card_Play_Ally_SummonIn_Medium_PM',[(0,1),(med,3),(med,2),(med+2.5,4)],med),
 'play_in_large':('Card_Play_Ally_SummonIn_Large_PM',[(0,1),(med,3),(med,2)],med),
 'play_in_opponent':('Card_Play_Ally_SummonIn_Opponent',[(0,1),(0,4),(enemy,2),(enemy+2,3)],enemy),
 'spawn_friendly':('Card_Play_Ally_Spawn_Minion',[(0,1),(token,2),(token+fadeout,3)],token),
 'spawn_opponent':('Card_Play_Ally_Spawn_Minion_Opponent',[(0,1),(token,2),(token+fadeout,3)],token)
}
routes={}
for key,(stem,schedule,finished) in plans.items():
 f=ROOT/(stem+'.prefab.fsm.json');d=json.load(open(f));states={s['state_index']:s for s in d['states']};r={'prefab':d['prefab'],'root_key':manifest['root_labels'][key],'fsm_component':{**d['component'],'path_id':str(d['component']['path_id'])},'finished_seconds_nominal':finished,'source_file':f.name,'source_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'state_enter_schedule':[]}
 for t,idx in schedule:
  s=states[idx];r['state_enter_schedule'].append({'at_seconds_nominal':t,'state_index':idx,'state_name':s['name'],'parallel_actions':not s['is_sequence'],'actions':[convert(a) for a in s['actions'] if a['enabled']]})
 r['disabled_actions']=[{'state_index':s['state_index'],'action_index':a['index'],'class_name':a['class_name']}for s in d['states']for a in s['actions']if not a['enabled']]
 routes[key]=r
raw_large=objects['cab-824a57d31e8915d6162164fd62a4305d:6855863801349825029']['data']['fsm']
raw_array=raw_large['states'][2]['actionData']['fsmArrayParams'][0]
large_cleanup={'raw_fsm_component':'cab-824a57d31e8915d6162164fd62a4305d:6855863801349825029','raw_parameter_path':'fsm.states[2].actionData.fsmArrayParams[0]','raw_array':raw_array,'matching_variable':raw_large['variables']['arrayVariables'][0],'wait_seconds_realtime':3.5999999046325684,'method_token':'0x06016C1A','calls_fsm_action_finish':False}
(ROOT/'large_cleanup_array_evidence.json').write_text(json.dumps(large_cleanup,indent=2))
for stage in routes['play_in_large']['state_enter_schedule']:
 if stage['state_index']==2:
  for a in stage['actions']:
   if a['class_name']=='RemoveAfterDelayAction':
    a['params']['gameObjectList']={'variable':raw_array['name'],'object_references':[val(x) for x in raw_array['objectReferences']]}
    a['resolved_from']='large_cleanup_array_evidence.json'
routes['play_in_large']['tail_cleanup']={'delay_after_none_realtime':3.5999999046325684,'targets':[{'path_id':str(x['m_PathID']),'name':objects['cab-824a57d31e8915d6162164fd62a4305d:'+str(x['m_PathID'])]['name']} for x in raw_array['objectReferences']]}
routes['play_in_large']['tail_note']='NONE Wait3.5 has no explicit finish event and RemoveAfterDelayAction never calls FsmStateAction.Finish. It spawns an independent coroutine using WaitForSecondsRealtime3.5999999046325684 then destroys the three objects in tail_cleanup. Do not invent a state4 transition from the3.5s wait. SetMaterialColor everyFrame=true also persists; in_finished is unaffected.'
routes['hand_out_large']['finish_note']='First explicit FINISHED wins: RaysUp end approximately0.9166666865 precedes Highlight AnimateFloat end1.0; Sub_Birth2 then NONE triggers FinishIfNecessary. No extra cleanup wait.'
for k in ('spawn_friendly','spawn_opponent'):
 routes[k]['finish_note']='General gate=max(FadeIn clip completion,AudioPlayAction template source inactive). Here template clip=null/playOnAwake=false and explicit OneShotSound uses PlayClip(createNewSource=true), so fresh ordinary route nominally gates only on FadeIn. Card.OnSpellFinished_StandardSpawnCharacter performs Actor.Show and readiness.'
def unresolved(v,path=''):
 if isinstance(v,dict):
  if 'serialized_type' in v: yield {'parameter_path':path,'serialized_type':v['serialized_type'],'pos':v.get('pos')}
  else:
   for k,x in v.items():yield from unresolved(x,path+'.'+k)
 elif isinstance(v,list):
  for i,x in enumerate(v):yield from unresolved(x,path+'['+str(i)+']')
for route in routes.values():
 route['unresolved_serialized_parameters']=list(unresolved(route['state_enter_schedule'],'state_enter_schedule'))
 route['execution_status']='Static event/curve schedule, not a complete PlayMaker interpreter. Any unresolved_serialized_parameters must be resolved from original raw fields before executing those actions; no placeholder is a zero/default authorization.'
out={'schema_version':1,'build':manifest['build'],'scope':'Ordinary non-premium non-elite shared visual routes. Cost bands use base EntityDef cost. Large included for diagnostic coverage. No client execution.','timing_semantics':['Times are continuous-time reconstruction; Unity/PlayMaker update scheduling can add frame quantization.','Parallel actions enter in source action index order. Explicit named events can transition before other actions finish.','AnimationPlaythroughAction starts playback then finishes immediately; PlayAnimation normally waits.','SpellFinishAction finishes Card callback without ending FSM; None-state SpellStateAction also finishes if necessary.','64-bit PPtr path IDs are decimal strings. Raw FSM files preserve original wrappers and unresolved serialized values.','Do not substitute m_MuscleClip.m_StopTime=1 when m_MuscleClipSize=0; duration estimates use actual legacy curve bounds.'],'selection':{'friendly_hand':{'cost_lt4':[1,2],'cost_4_to6':[22,24],'cost_ge7':[23,25]},'opponent_hand':{'out_type':1,'in_types_by_same_cost_bands':[42,68,69],'all_in_types_share':'play_in_opponent'},'generated_spawn':{'friendly':26,'opponent':31,'hand_out':False}},'routes':routes,'clip_index':clips}
(ROOT/'runtime_routes.json').write_text(json.dumps(out,indent=2,ensure_ascii=False));print('Wrote',ROOT/'runtime_routes.json',len(routes),'routes')
