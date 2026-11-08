from pathlib import Path
import json,hashlib,collections
R=Path(__file__).parent
m=json.load(open(R/'assets/manifest.json'));o=m['objects'];en=json.load(open(R/'code/status_enum_constants.json'));tag_names={v:k for k,v in en['GAME_TAG'].items()};cfg=json.load(open(R/'tag_visual_config.json'));entries=[]
for idx,r in enumerate(cfg['data']['m_TagVisuals']):
 if r['m_Tag']not in [43,50,271,190,260,217,197,791,930,3672,297]:continue
 item={'source_index':idx,'tag_name':tag_names.get(r['m_Tag']),**r}
 for n,v in item.items():
  if not isinstance(v,dict):continue
  for a in v.get('m_Actions',[]):
   a['action_name']={v:k for k,v in en['TagVisualActorFunction'].items()}.get(a['m_Action'])
   a['state_function_name']={v:k for k,v in en['TagVisualActorStateFunction'].items()}.get(a['m_StateFunctionParameters'])
   c=a['m_Condition'];c['condition_name']={v:k for k,v in en['TagVisualActorCondition'].items()}.get(c['m_Condition'])
 entries.append(item)
(R/'trigger_config_selected.json').write_text(json.dumps({'source':cfg['key'],'entries':entries},indent=2))
ls=[]
for k,ob in o.items():
 if ob['type']=='Material':
  s=o.get(ob['refs'].get('.m_Shader'),{})
  ls.append({'key':k,'name':ob['name'],'shader_key':ob['refs'].get('.m_Shader'),'shader':s.get('data',{}).get('m_ParsedForm',{}).get('m_Name'),'properties':ob['data'].get('m_SavedProperties'),'source_refs':ob['refs']})
(R/'material_bindings.json').write_text(json.dumps(ls,indent=2))
placement={}
for label,k in m['root_labels'].items():
 cs=[o[v]for v in o[k]['refs'].values()if v in o];root_t=next(c for c in cs if c['type']=='Transform');sp=next(c for c in cs if c['class_name']=='Spell')
 ps={'root_key':k,'transform':root_t['data'],'spell':sp['data'],'spell_refs':sp['refs'],'root_components':[{'key':c['key'],'class_name':c['class_name']}for c in cs]}
 placement[label]=ps
(R/'placement_oracle.json').write_text(json.dumps(placement,indent=2))
# Keep exact original CIL relevant to placement/lifetime, without redumping all assembly methods.
wanted={'LoadSpell','GetSpellParent','ShowSpellTable','HideSpellTable','ReleaseSpells','ActivateAllSpellsDeathStates','DeactivateAllSpells','OnSpellFinished_HandToPlay_SummonIn','OnSpellFinished_DefaultPlaySpawn','OnSpellFinished_StandardSpawnCharacter'}
methods=[]
for path in ['v30_work/audio_code_evidence/fsm_actor.cil.json','v30_work/audio_code_evidence/binding.cil.json']:
 d=json.load(open(path))
 for a in d['methods']:
  if a['method']in wanted:methods.append({'source_file':path,**a})
(R/'code/placement_lifecycle_methods.json').write_text(json.dumps(methods,indent=2))
pool=json.load(open('v34_work/TavernDuel/assets/data/dual_deck_cards_5834.json'));cards=pool['cards'];defs=json.load(open('v30_work/audio_assets_evidence/carddefs.json'))
mat={'rules_build':5834,'source_visual_build':m['build'],'scope':'27 collectible cards + Sheep/Mirror Image/Coin tokens only','pool_ids':list(cards),'freeze_producers':['CS2_024','CS2_026','CS2_033'],'freeze_targets':{'CS2_024':'surviving character','CS2_026':'enemy minions','CS2_033':'character actually damaged'},'hero_freeze':'State is reachable on base heroes, though current pool has no hero attack path. No invented hero taunt.','taunt_cards':[cid for cid,c in cards.items()if c.get('keyword')=='嘲讽'],'sleep_cards':[cid for cid,c in cards.items()if c['kind']=='minion'],'deathrattle':{'reachable':False,'matching_current_cards':[],'verified_table_types':[34,35],'implemented_in_scope':False},'corruption':{'reachable':True,'producer':'CS2_063','enchantment':'CS2_063e','carddef_guid':'7add494886e16ce48b9dccbdc3f8acfb','persistent_visual_binding':None,'evidence':'binding_roots.json: all play/lifetime/death effect paths empty. Cast uses actual finite ReuseFX_Warlock_Corruption_Impact already in v32. No same-build persistent skull/deathrattle substitute verified.'},'status_spell_overrides':{cid:[c.get('m_SpellTableOverrides',[])for c in d['data'].get('components',[])if 'm_SpellTableOverrides'in c]for cid,d in defs.items()if cid in cards},'missing_carddef_evidence_ids':[cid for cid in cards if cid not in defs]}
(R/'reachability_manifest.json').write_text(json.dumps(mat,ensure_ascii=False,indent=2))
summary={'build':m['build'],'root_labels':m['root_labels'],'object_counts':dict(collections.Counter(v['type']for v in o.values())),'unresolved':m['unresolved'],'export_errors':m['export_errors'],'files':['assets/manifest.json','runtime_routes.json','trigger_config_selected.json','tag_visual_config.json','placement_oracle.json','mesh_color_channels.json','material_bindings.json','reachability_manifest.json','binding_roots.json'],'provenance':'assets/data/source_bundle_provenance.json'}
(R/'recovery_summary.json').write_text(json.dumps(summary,indent=2))
print(summary)
