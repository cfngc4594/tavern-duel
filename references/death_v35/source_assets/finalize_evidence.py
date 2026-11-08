import json,pathlib,hashlib,collections,wave
from PIL import Image
R=pathlib.Path(__file__).parent;A=R/'assets';m=json.load(open(A/'manifest.json'));o=m['objects'];pool=json.load(open(R/'card_pool_bindings.json'));clips=json.load(open(R/'audio/clips_provenance.json'));sounds=json.load(open(R/'audio/sound_bindings.json'))
def save(p,d):p.write_text(json.dumps(d,indent=2))
def comp(g,kind):return next(o[k]for k in o[g]['refs'].values()if o[k]['class_name']==kind)
def hashfile(p):return hashlib.sha256(p.read_bytes()).hexdigest()
body=m['root_labels']['minion_death'];bs=comp(body,'SoundDef');ba=comp(body,'AudioSource');events={}
for cid,c in pool['cards'].items():
 if not c['voice_roots']:continue
 root=c['voice_roots'][0];cs=comp(root,'CardSoundSpell');aud=o[cs['refs']['.m_CardSoundData.m_AudioSource']];sd=comp(aud['refs']['.m_GameObject'],'SoundDef');g=sd['data']['m_AudioClip'].rsplit(':',1)[-1]
 events[cid]=dict(event='CardDef.m_DeathEffectDef.m_SoundSpellPaths[0]',root_key=root,card_sound_spell_key=cs['key'],audio_source_key=aud['key'],sound_def_key=sd['key'],clip_base_guid=g,resolved_guid=clips[g]['resolved_guid'],locale=clips[g]['locale'],localized_voice=clips[g]['locale']=='zhCN',delay_sec=cs['data']['m_CardSoundData']['m_DelaySec'],category=sd['data']['m_Category'],pitch=[sd['data']['m_RandomPitchMin'],sd['data']['m_RandomPitchMax']],volume=[sd['data']['m_RandomVolumeMin'],sd['data']['m_RandomVolumeMax']],clip_source_path=clips[g]['source_path'],existing_production_path=clips[g]['existing_production_path'],portrait_texture_key=c['portrait_texture_key'])
shared=dict(event='type5 body FSM Birth Animate action2 AudioPlaythroughAction',root_key=body,audio_source_key=ba['key'],sound_def_key=bs['key'],delay_sec=0,category=bs['data']['m_Category'],pitch=[bs['data']['m_RandomPitchMin'],bs['data']['m_RandomPitchMax']],volume=[1,1],selection=[dict(clip_base_guid=x['m_Clip'].rsplit(':',1)[-1],weight=x['m_Weight'])for x in bs['data']['m_RandomClips']],independent_of_character_audio=True)
save(R/'audio/event_bindings.json',dict(build=m['build'],shared_body=shared,character_death_audio=events,localized_zhCN_character_ids=[c for c,x in events.items()if x['localized_voice']],global_character_ids=[c for c,x in events.items()if not x['localized_voice']],notes=['13 character death audio files plus6 common death-body sounds. Five are catalog-resolved zhCN voice files; eight are global effects/vocalizations.','Do not replay common audio twice when source FSM and existing original-audio router both describe the same body activation.']))
errors=[];checked_files=[]
for k,r in o.items():
 for f,target in r['refs'].items():
  if target not in o:errors.append(dict(key=k,field=f,missing=target))
 for kind,path in r['files'].items():
  p=A/path
  if not p.exists():errors.append(dict(key=k,missing_file=path));continue
  checked_files.append(dict(path='assets/'+path,bytes=p.stat().st_size,sha256=hashfile(p)))
 if r['type']=='Texture2D'and 'png'in r['files']:
  im=Image.open(A/r['files']['png']);assert im.size==(r['data']['m_Width'],r['data']['m_Height'])
 if r['type']=='Mesh':
  d=json.load(open(A/r['files']['mesh']));assert all(0<=i<len(d['vertices'])for sub in d['triangles']for tri in sub for i in tri)
for k,c in clips.items():
 for path,h in [(c['source_path'],c['export_sha256']),(c['encoded_path'],c['original_encoded_sha256'])]:assert hashfile(R/'audio'/path)==h
 p=R.parent/'../v34_work/TavernDuel'/c['existing_production_path'].removeprefix('res://');assert p.exists()and hashfile(p)==c['export_sha256']
assert len(events)==13 and len(clips)==19 and len(pool['cards'])==30
assert all(not c['custom_death']and not c['death_effect']['m_SpellPath']for c in pool['cards'].values())
assert not m['unresolved']and not m['export_errors']and not errors
validation=dict(build=m['build'],objects=len(o),type_counts=dict(collections.Counter(r['type']for r in o.values())),asset_files=len(checked_files),checked_files=checked_files,all_pointer_references_resolve=True,export_errors=m['export_errors'],unresolved=m['unresolved'],carddefs=30,minion_entities=13,collectible_minions=11,token_minions=['CS2_tk1','CS2_mirror'],all_custom_death_and_death_effect_visual_paths_empty=True,audio_clips=19,all_audio_matches_existing_v34_exactly=True,locale_counts=dict(collections.Counter(c['locale']for c in clips.values())),no_production_files_changed_by_this_worker=True,limitations=['Original binary shaders are retained but cannot run directly in Godot; equation recovery is a separate deliverable.','Native Unity particle RNG, collision/integration, culling and projected-shadow renderer do not become pixel-identical merely by exporting data.','No original client launch or GPU comparison was performed in this source-recovery task.'])
save(R/'recovery_validation.json',validation);print('PASS objects',len(o),'files',len(checked_files),'audio19 same as existing v34','missing0')
