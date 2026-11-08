from pathlib import Path
import json,hashlib,wave
R=Path(__file__).parent;S=R.parent
objects=json.load(open(S/'assets/manifest.json'))['objects'];visual=json.load(open(S/'runtime_routes.json'));clips=json.load(open(R/'clips_provenance.json'));byguid={c['base_guid']:name for name,c in clips.items()}
def write(n,d):(R/n).write_text(json.dumps(d,indent=2,ensure_ascii=False))
def val(x):return x.get('value')if isinstance(x,dict)else x
routes={};defs={};proof=[]
for route_id,route in visual['routes'].items():
 for event,sched in route['event_schedules'].items():
  for state in sched['state_enter_schedule']:
   for action in state['actions']:
    if not action['enabled']or action['class_name']not in ['AudioPlaythroughAction','AudioPlayClipAction']:continue
    p=action['params'];go=action['target_object_key'];audio=None
    if action['class_name']=='AudioPlayClipAction':sk=action['reference_keys']['params.m_Sound.value'];gain=val(p['m_Volume']);pitch=val(p['m_Pitch']);mechanism='explicit SoundDef -> SoundManager.PlayClip(createNewSource=true)'
    else:
     sk=next(k for k,v in objects.items()if v['class_name']=='SoundDef'and str(v['data']['m_GameObject']['m_PathID'])==go.rsplit(':',1)[1]);audio=next(v for v in objects.values()if v['type']=='AudioSource'and v['refs'].get('.m_GameObject')==go);gain=val(p['m_VolumeScale'])*audio['data']['m_Volume'];pitch=audio['data']['m_Pitch'];mechanism='AudioSource same-GameObject SoundDef dynamically loaded by SoundManager.Play/RegisterExtension/LoadClipForPlayback/InitNewClipOnSource'
    sd=objects[sk];defs[sk]=sd;d=sd['data'];alts=d['m_RandomClips']or[{'m_Clip':d['m_AudioClip'],'m_Weight':1.0}];variants=[{'clip':byguid[a['m_Clip'].split(':')[-1]],'asset_reference':a['m_Clip'],'weight':a['m_Weight']}for a in alts]
    rid=route_id+'|'+state['state_name']+'|'+str(action['index'])
    routes[rid]={'route_id':route_id,'event':event,'state_name':state['state_name'],'state_index':state['state_index'],'action_index':action['index'],'action_class':action['class_name'],'at_sec':state['at'],'action_delay_sec':p['m_Delay'],'total_nominal_delay_sec':state['at']+p['m_Delay'],'clock':'source-scaled seconds; state transitions are frame quantized','sound_def_key':sk,'game_object_key':go,'variants':variants,'gain':gain,'pitch':pitch,'def_random_volume':[d['m_RandomVolumeMin'],d['m_RandomVolumeMax']],'def_random_pitch':[d['m_RandomPitchMin'],d['m_RandomPitchMax']],'loop':False,'bus':'SFX','source_category':d['m_Category'],'spatial_blend':val(p.get('m_SpatialBlend',0)),'selection':'SoundUtils.GetRandomClipFromDef: sum weights; uniform random[0,sum]; first cumulative >= draw, otherwise final. Current minion break variants weights1,1,1. Use independent presentation RNG, never rule RNG.','is_minion_summon_vo':p['m_IsMinionSummonVO'],'is_keyword_vo':p['m_IsKeywordVO'],'skip_suppress_entity_sound_check':p.get('m_SkipSuppressEntitySoundCheck',False),'mechanism':mechanism,'source_action':action,'source_audio_source':audio,'finished_behavior':'Action finishes immediately after dispatch, not after clip duration.'}
# Exact methods with resolved tokens and offsets already in fixed-build recovery.
want={'SoundManager':{'Play','PlayImpl','GetDefFromSource','RegisterExtension','LoadClipForPlayback','InitNewClipOnSource','SetVolume','UpdateVolume','UpdatePitch','PlayClip','RegisterSourceExtensionCommon'},'SoundUtils':{'GetRandomClipFromDef','GetRandomVolumeFromDef','GetRandomPitchFromDef'},'HutongGames.PlayMaker.Actions.AudioPlaythroughAction':{'OnEnter','GetSource','Play','GetActor'},'HutongGames.PlayMaker.Actions.AudioPlayClipAction':{'OnEnter','Play','GetActor'}}
for path in ['v30_work/audio_code_evidence/final_core.cil.json','v30_work/audio_code_evidence/fsm_actor.cil.json']:
 for m in json.load(open(path))['methods']:
  if m['method']in want.get(m['type'],set()) and not any(x['token']==m['token']for x in proof):proof.append({'source_file':path,**m})
write('sound_runtime.cil.json',proof)
with open(R/'sound_runtime.cil.txt','w')as f:
 for m in proof:
  f.write('\n'+m['token']+' '+m['type']+'::'+m['method']+'\n')
  for i in m['instructions']:f.write(i['offset']+' '+i['opcode']+' '+i['operand']+'\n')
# Verify bounded audio restoration and detect existing dispatch evidence by exact GUID/hash.
existing=[]
for p in Path('v34_work/TavernDuel/assets').glob('original_audio_v30/*json'):
 txt=p.read_text();found=[name for name,c in clips.items()if c['base_guid']in txt or c['export_sha256']in txt]
 if found:existing.append({'file':str(p),'clips':found})
checks=[]
for name,c in clips.items():
 p=R/c['source_path'];raw=R/c['encoded_path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==c['export_sha256'];assert hashlib.sha256(raw.read_bytes()).hexdigest()==c['original_encoded_sha256']
 with wave.open(str(p))as w:assert w.getframerate()==c['sample_rate'];assert w.getnchannels()==c['channels'];assert w.getnframes()==c['sample_frames']
 checks.append({'clip':name,'verified_full_pcm':True,'verified_encoded_hash':True,'verified_wav_hash':True})
manifest={'schema_version':1,'source_build':visual['build'],'rules_build':visual['rules_build'],'scope':'Only five enabled original state audio actions: frozen minion Death, frozen hero Death, taunt State6(up+shout) and State4(break). Sleep has no audio action.','clips':clips,'routes':routes,'sound_defs':defs,'gates':{'AudioPlayClipAction':'If !skipSuppress and Actor.Entity.SUPPRES_ALL_SOUNDS_FOR_ENTITY3093 then skip. For isMinionSummonVO, suppress if GameState missing, or entity SUPPRESS_ALL_SUMMON_VO1458 unless isKeywordVO && gameEntity.DONT_SUPPRESS_KEYWORD_VO2636.','AudioPlaythroughAction':'Frozen actions have isMinionSummonVO=false,isKeywordVO=false. No summonVO gate. TeammateBoardViewer gate is irrelevant for current two-player pool.','pool':'Do not infer suppression from token status alone; use verified equivalent source event context. No new cards or modern modes.'},'mix':'Effective volume = code/action volume * source volume * SoundDef random volume * category volume * ducking volume. Pitch = code/action pitch * source pitch * SoundDef random pitch. Reuse existing user SFX controls and verified ducking when available.','deduplication':{'existing_v30_exact_guid_or_pcm_hash_matches':existing,'instruction':'Dispatch once when original status FSM enters each audio action. Do not additionally schedule a separate card-event copy. The existing v30 manifest does not contain these clips by exact GUID/hash.'},'source_evidence':['../assets/manifest.json','../runtime_routes.json','sound_runtime.cil.json','source_bundle_provenance.json'],'missing_clips':[]}
write('runtime_manifest.json',manifest);write('verification.json',{'clips':checks,'clip_count':len(clips),'action_routes':len(routes),'expected_action_routes':5,'missing':[],'original_bundle_md5_verified':all(x['verified']for x in json.load(open(R/'source_bundle_provenance.json'))),'existing_v30_matches':existing});print('PASS',len(clips),'clips',len(routes),'audio actions',len(proof),'CIL methods',len(existing),'pre-existing exact matches')
