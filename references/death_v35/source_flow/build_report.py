from pathlib import Path
import json,hashlib
out=Path('v35_work/source_death_flow')
assembly_default='v30_work/original_code/Assembly-CSharp.dll'
assembly_map={
'death_builtin_materials':'v30_work/original_code/Blizzard.T5.PlayMakerCustomActions.Runtime.dll',
'death_material_service':'v35_work/source_death_assets/managed/Blizzard.T5.MaterialService.mac.dll',
'death_itween':'v30_work/original_code/Blizzard.T5.iTween.dll',
'death_itween_defaults':'v30_work/original_code/Blizzard.T5.iTween.dll',
'death_itween_actions':'v30_work/original_code/Blizzard.T5.PlayMakerCustomActions.Runtime.dll',
'death_visibility_actions':'v30_work/original_code/Blizzard.T5.PlayMakerCustomActions.Runtime.dll',
'death_particle_action':'v30_work/original_code/Blizzard.T5.PlayMakerCustomActions.Runtime.dll'}
assemblies={}
for s in sorted(set([assembly_default,*assembly_map.values(),'v31_work/source_code/managed/UnityEngine.ParticleSystemModule.dll'])):
 p=Path(s);assemblies[s]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
logs=[]
for p in sorted(out.glob('*.cil.json')):
 d=json.loads(p.read_text()); asm=assembly_map.get(p.name.removesuffix('.cil.json'),assembly_default)
 logs.append({'file':str(p),'assembly':asm,'types':len(d['types']),'methods':len(d['methods']),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 for m in d['methods']:
  pass
json.dump({'build':'37.0.0.255130.254477','read_only_originals':True,'assemblies':assemblies,'cil_dumps':logs},open(out/'source_provenance.json','w'),indent=2)
# Token-scoped method index keeps assembly identity because MethodDef tokens repeat across DLLs.
lines=['# v35 source method log','', 'Original binaries were parsed statically, not loaded or executed. Tokens are assembly-scoped. Each entry links to the full instruction dump with real IL branch offsets.','']
for log in logs:
 p=Path(log['file']);d=json.loads(p.read_text())
 lines += ['## '+p.stem, '', 'Assembly: '+log['assembly'], 'SHA-256: '+assemblies[log['assembly']]['sha256'], '']
 for m in d['methods']:
  lines.append(f"- {m['token']} {m['type']}::{m['method']} ({m['rva']}, {m.get('code_size','native/no body')} CIL bytes)")
 lines.append('')
(out/'METHOD_LOG.md').write_text('\n'.join(lines))
voices=json.load(open(out/'voice_root_components.json')); voices=[v for v in voices if v['class']=='CardSoundSpell']
sem={
'build':'37.0.0.255130.254477',
'scope':{'card_entities':30,'ordinary_minion_identities':13,'ids':[x['label'].removeprefix('death_voice_').removesuffix('_0') for x in voices],'no_rule_changes':True},
'source_trigger':{'condition':'PowerTaskList BLOCK_DEATH -> character ZONE tag 49 becomes GRAVEYARD 4; not simply health<=0','evidence':['GameUtils.IsCharacterDeathTagChange 0x06014cf9','DeathSpellController.AddDeadCardsToTargetList 0x0601164f','PowerProcessor.DoTaskListWithSpellController 0x06005ff9']},
'death_wave_order':[
 {'order':1,'event':'wait for source/target actor/assets readiness','evidence':'SpellController.IsCardBusy 0x060149d6; <WaitForCardsThenDoTaskList>d__40.MoveNext 0x060149e7','not_waiting':'damage splat end or voice end'},
 {'order':2,'event':'choose one character death voice; suppress others; activate character effects for all dying targets','evidence':'DeathSpellController.OnProcessTaskList 0x0601164e; PickDeathSoundCardIndex 0x06011651'},
 {'order':3,'event':'base controller completes task callback; DoCurrentTaskList applies zone changes','evidence':'SpellController.OnProcessTaskList 0x060149ce; PowerProcessor.OnSpellControllerFinishedTaskList 0x06006002'},
 {'order':4,'event':'zone Play->Graveyard launches standard type5 on retained old Actor','evidence':'Card.Check_VariousZonesToGraveyard 0x06012e29; HandlePlayActorDeath 0x06012e79; ActivateDeathSpell 0x06012db1'}],
'voice':{'root_count':len(voices),'all_card_sound_delay_sec_zero':all(v['data']['m_CardSoundData']['m_DelaySec']==0 for v in voices),'all_block_server_events_zero':all(v['data']['m_BlockServerEvents']==0 for v in voices),'all_block_on_enter_death_zero':all(v['data']['m_BlockPowerProcessing']['m_OnEnterDeathState']==0 for v in voices),'wait_for_completion_before_body':False,'fixed_frame_defer':False,'sounddef_delay_and_pitch':'retain authored values','exception':'Card.ActivateSoundSpell waits while game option 39 is true. This is a boolean gate, not a one-frame delay or damage/voice-end callback.','evidence':['Card.ActivateSoundSpell 0x06012d5b','CardSoundSpell.<DelayedPlay>d__13.MoveNext 0x06011d90','<WaitThenActivateSoundSpell>d__306.MoveNext 0x06012f93']},
'logical_vs_visual_removal':'ZONE->GRAVEYARD model update precedes old visual Actor retention. The 3.5s callback destroys old Actor, not a delayed rules death or necessarily Entity destruction.',
'normal_body_timeline':[
 {'offset_sec':0,'event':'type5 Birth starts AllyInPlay_Death and authored generic sound; shake runs .5 seconds','boundary':'origin is original zone-transition callback; simulator maps its visible death wave to this origin'},
 {'offset_sec':0.30000001192092896,'event':'PrepareForDeathAnimation invokes keyword Death, including frozen/taunt/sleep when active','evidence':'<WaitAndPrepareForDeathAnimation>d__562.MoveNext 0x06012f7b; Card.PrepareForDeathAnimation 0x06012e77'},
 {'offset_sec':0.5,'event':'RootObject renderers off; fragment subtree renderers on; child particle play; start collision-plane tween with 1.5 second delay and 1.5 second duration'},
 {'offset_sec':2.0,'event':'collision plane movement begins, not whole debris-group translation'},
 {'offset_sec':3.5,'event':'disable shadow; Spell enters None; old Actor destroyed and spells released','evidence':'Spell.ChangeStateImpl 0x0601496c; Card.OnSpellStateFinished_DestroyActor 0x06012dca; Actor.Destroy 0x060127ef'}],
'damage':{'route':'Card.OnMetaData 0x06012d78 uses spell type7 and DamageSplat.SetDamage then Action3','wait_before_death':False,'ownership':'Damage splat under Actor/Spells is separate from hidden RootObject; may overlap body/keyword death until release','type10_death_splat':'Direct call sites are InputManager.ShowSkull lethal attack preview (0x06005a5f), DisableSkull (0x06005a61), and HistoryItem.DisplaySkullOnActor (0x060058e1). Not an automatic ordinary death effect; do not add to Destroy/Corruption.'},
'materials':{'portrait':'GetCardPortraitTextureAction 0x06016b77 -> old ancestor Actor -> GetStaticPortraitTexture 0x06012892. Raw source portrait; not full-card screenshot; action does no UV/resize.','per_actor_material':'SetMaterial 0x06000059 / SetMaterialTexture 0x0600006c -> MaterialService RendererExtension; index0 renderer.material accessor. Keep per-Actor material isolation.','nonpremium':'PremiumMaterialSwitcher 0x06015335 with premium<1 and absent original cache leaves serialized defaults.','root_binding':'SpellInitActorVariables.GetActor 0x06016d08 prefers ancestor Actor; OnEnter 0x06016d0a binds RootObjectMesh to Actor.GetMeshRenderer(true).','placement':'standard ActivateDeathSpell does not SetSource; preserve actor/spells parent and original local prefab transforms, despite m_Location=2.'},
'particles':{'wrapper':'CustomActions Runtime ParticlePlayAction.OnEnter 0x060000ee: if target has PS, PS.Play(includeChildren); if no PS and includeChildren=true, enumerate children and each.Play(true).','subemitter_type2':'Death (verified same-build enum); not Collision.','culling_mode':'Automatic0, PauseAndCatchup1, Pause2, AlwaysSimulate3 (verified enum)','simulation_space':'public enum Local0,World1,Custom2 verified, but raw serialized moveWithTransform=0 is NOT proven same encoding; do not force-map.','visibility':'SetVisibilityRecursiveAction.OnEnter 0x06000112 unconditionally sets enabled on every returned renderer. Initially disabled rock renderer can become enabled at .5 if active descendant.','boundary':'Unity native subemitter play scheduling, collision solver, particle culling, moveWithTransform serialization bridge, and exact RNG sequence not recovered by managed CIL.'},
'itween':{'shake':'ApplyShakePositionTargets 0x06000054: offset per-axis uniform random +-amount*(1-percentage), relative to cached start, not accumulated, default world isLocal=false; no sine approximation.','move':'ApplyMoveToTargets 0x0600004e; easeType21 uses linear 0x0600009b. Animate only FX_CollisionPlaneLocation1.','rng':'presentation randomness must not consume rule RNG'},
'hero_boundary':{'trigger':'Card.Check_HeroToGraveyard 0x06012e28: prior ZoneHero -> ZoneGraveyard calls oldActor.DoCardDeathVisuals immediately at IL001b; no minion .3 delay.','independent_endgame':'GameEntity.ActivateSpellForDestroyedHero 0x060054f3 selects endgame body effects, but does not itself call keyword death. Original packet interval unavailable.','integration':'Do not clear frozen at generic game_over; map explicit hero graveyard presentation transition if available, documenting atomic simulator compatibility origin.'},
'polymorph':{'death':False,'evidence':'v34_work/source_status/polymorph_actor_semantics.json','semantics':'same normal Actor update; changed frozen/taunt tags may run their own Death, no type5 body or character death VO. Unchanged active status instance is retained.'},
'projected_shadow':{'managed_recovered':True,'fully_ported':False,'evidence':'ProjectedShadow.Start 0x0601533c, RenderToShadowTexture 0x06015351, CreateProjector 0x06015352','dependencies':['graphics realtime-shadow settings','Board height','Resources Prefabs/ShadowProjector','DecalProjector','CommandBuffer mesh silhouette RT','Custom/ContactShadow','Custom/Selection/HighlightMultiSample','Custom/Unlit/Color/White','Custom/Unlit/Color/DarkGrey'],'boundary':'No proof that a generic 2D oval is equivalent. Source disable at 3.5 is known; projection rendering remains a separate compatibility boundary.'}
}
json.dump(sem,open(out/'death_flow_semantics.json','w'),ensure_ascii=False,indent=2)
checks={'voice_roots':len(voices),'voice_delay_zero':sem['voice']['all_card_sound_delay_sec_zero'],'voice_block_zero':sem['voice']['all_block_server_events_zero'] and sem['voice']['all_block_on_enter_death_zero'],'source_logs_present':all(Path(x['file']).is_file() for x in logs),'dump_errors':[],'production_edited':False}
for log in logs:
 for m in json.load(open(log['file']))['methods']:
  if 'error' in m:checks['dump_errors'].append({'file':log['file'],'token':m['token'],'error':m['error']})
assert checks['voice_roots']==13 and checks['voice_delay_zero'] and checks['voice_block_zero'] and not checks['dump_errors']
json.dump(checks,open(out/'static_validation.json','w'),indent=2)
print(json.dumps(checks));print('methods',sum(x['methods'] for x in logs))
