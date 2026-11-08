import json,hashlib
from pathlib import Path
P=Path('v34_work/source_status')
def read(p): return json.loads(Path(p).read_text())
def methods(p):
 d=read(p);return d.get('methods',[]) if isinstance(d,dict) else d
sources={
 'v30_work/audio_code_evidence/fsm_actor.cil.json': {'Actor': ['GetSpell','GetLoadedSpell','LoadSpell','OnSpellRelease','ActivateSpellBirthState','ActivateSpellDeathState','OnSpellStateStarted']},
 'v30_work/audio_code_evidence/final_core.cil.json': {'Spell':['Show','Hide','ActivateState','ChangeState','ChangeStateImpl','ChangeFsmState','ChangeFsmStateNow','OnFsmStateStarted','OnSpellFinished','FinishIfNecessary','OnExitedNoneState','OnEnteredNoneState','ActivateObjectContainer','OnBirth','OnNone','FireFinishedCallbacks']},
 'v30_work/audio_code_evidence/playmaker_fsm_core.cil.json': {'HutongGames.PlayMaker.Fsm':['SwitchState','ExitState','Update'],'HutongGames.PlayMaker.FsmState':['OnExit'],'HutongGames.PlayMaker.FsmStateAction':['OnExit']},
 'v34_work/source_status/audio/sound_runtime.cil.json': {'SoundManager':['PlayImpl','RegisterExtension','LoadClipForPlayback','InitNewClipOnSource','PlayClip','GenerateSource']},
}
evidence=[]
for p,types in sources.items():
 for m in methods(p):
  if m['type'] in types and m['method'] in types[m['type']]:evidence.append({'source_path':p,**m})
(P/'code/reapply_selected_methods.json').write_text(json.dumps(evidence,indent=2))
A=read(P/'assets/manifest.json');R=read(P/'runtime_routes.json')['routes']
particle_fields=[]
for k,v in A['objects'].items():
 if v['type']=='ParticleSystem':
  d=v['data'];go=f"{v['cab'].lower()}:{d['m_GameObject']['m_PathID']}"
  particle_fields.append({'component_key':k,'game_object_key':go,'game_object_name':A['objects'].get(go,{}).get('name'),'source_object_sha256':v['source_object_sha256'],**{x:d.get(x) for x in ['lengthInSec','simulationSpeed','stopAction','cullingMode','looping','playOnAwake','useUnscaledTime','autoRandomSeed','randomSeed']}})
route_actions={}
for rid,r in R.items():
 route_actions[rid]={'root_key':r['root_key'],'fsm_component_key':r['fsm_component_key'],'keepDelayedEventsOnStateExit':A['objects'][r['fsm_component_key']]['data']['fsm']['keepDelayedEventsOnStateExit'],'state_actions':[]}
 for s in r['all_states']:
  for a in s['actions']:
   if a['class_name'] in ['SetVisibility','ParticlePlayAction','ParticleStopAction','ParticleClearAction','AudioPlayClipAction','AudioPlaythroughAction','SpellFinishAction','Wait','iTweenFadeToAction','iTweenScaleTo']:
    route_actions[rid]['state_actions'].append({'state':s['name'],**a})
D={
 'schema_version':1,'build':'37.0.0.255130.254477','rules_build':5834,
 'scope':'Only the four recovered current-pool frozen_minion, frozen_hero, taunt and sleep status roots. Static cached original CIL/prefab audit, no client execution.',
 'implementation':{
  'cache_key':'Actor identity plus original SpellType. Current types: frozen14, taunt8, sleep52. Keep the same Spell/FSM/prefab objects through Birth, Death and None until actual actor release.',
  'reapply_during_death':'ActivateSpellBirthState returns the existing nonnull owned Spell and ActivateState(Birth=1). Interrupt the current FSM state and enter its global Birth route on that same object; do not spawn a second effect or synthesize None first.',
  'reapply_after_none':'Reuse the same cached Spell, leave None through ChangeStateImpl, reset m_finished=false and call OnExitedNoneState. This enables ObjectContainer renderers and then runs the original Birth route.',
  'old_state_work':'Exit the previous FSM state. Its Wait action no longer updates. Cancel its outstanding delayed FSM events because all four keepDelayedEventsOnStateExit=0. Do not let an old Death deadline send None into a later Birth.',
  'timing':'Continue FSM time while temporarily hidden or in None; None does not disable the root GameObject or FSM. Source zero-time state transitions remain frame-quantized. This does not claim every native particle simulation step continues while renderer-culling applies.',
  'state_domains':'Do not conflate Spell.m_finished, Spell.m_activeStateType and PlayMaker active state. Frozen SpellFinishAction at Death entry only sets m_finished=true through OnSpellFinished; activeStateType remains Death=5 until NoneState SpellStateAction reports None.',
  'renderer_write_order':'For ChangeStateImpl, apply original OnExitedNoneState container enable only when the previous Spell state is None, not on every Birth. Separate actual Spell.Show false-to-true while activeStateType!=None also invokes OnExitedNoneState. Apply explicit route SetVisibility actions without resetting all prefab transforms/materials or inventing renderer restoration.',
  'audio_dedup':'Use cached effect serial plus activation/state-entry generation and action identity. A legitimate second Death of the same cached object must play once; old actions must not replay on reattachment.',
  'release':'Actual owner release destroys/releases cached Spell objects. Neither ordinary None nor OnSpellFinished is owner release.'
 },
 'hero_renderer_edge':{
  'result':'Direct Death-tail to Birth retains disabled hero ice-shell renderers. This is the verified direct source sequence, not an instruction to correct its appearance.',
  'spell_finish_action':'SpellFinishAction.OnEnter 0x06016cdd IL0051..0057 calls Spell.OnSpellFinished for serialized delay0; then action Finish. No ChangeState/Deactivate call.',
  'spell_finished':'Spell.OnSpellFinished 0x0601495f writes m_finished, removes blocks, fires one-shot listeners. It does not write m_activeStateType. Actor.LoadSpell adds release/state-start callbacks, not an ordinary finished-to-None callback.',
  'conditional_enable':'Spell.ChangeStateImpl 0x0601496c IL0037 branches on previous state; IL00b6..00c1 calls OnExitedNoneState only previous None and next non-None. OnExitedNoneState 0x0601498a calls ActivateObjectContainer(true).',
  'hidden_renderers':['cab-69c88b234dfa427e02d1fcee9337ae34:5932701138785887379','cab-69c88b234dfa427e02d1fcee9337ae34:-1273333477960620909'],
  'death_actions':'frozen_hero Death indices3/4 SetVisibility(false), resetOnExit=false.',
  'birth_actions':'Normal hero Birth: Scale Hero Frame? -> Regular Frame, only ParticlePlay(frost, includeChildren=false) and SetScale(container). No shell enable action. Legacy Birth SpellState targets a Transform-only container and has no animation/renderer action.',
  'callback_check':'Actor.OnSpellStateStarted 0x0601297f calls ActorStateMgr.RefreshStateMgr 0x0601489e, which only calls HighlightState.SetDirty. No container/shell enable is added there.',
  'after_none':'None->Birth does enable both shells as part of ObjectContainer renderer traversal.',
  'minion_contrast':'Normal frozen_minion Birth CheckIfMerc->EnableIce explicitly enables all three ice objects, so direct Death-tail reentry restores them.',
  'explicit_hide_show_exception':'Spell.Show 0x06014935 returns when already m_shown=true. On false-to-true it sets m_shown=true and, if activeStateType!=0, calls OnExitedNoneState before ShowImpl. Therefore a real Hide->Show while still Death enables every active ObjectContainer renderer, including shells hidden by Death. If the Spell reached None while hidden, Show does not enable them. There is no Birth/state reset in this call.',
  'scope_caveat':'This is the direct tag-remove/reapply source path without an intervening independent Actor Hide/Show or release. Do not generalize it to unrelated presentation calls.'
 },
 'audio':{
  'no_exit_stop':'AudioPlaythroughAction and AudioPlayClipAction directly inherit FsmStateAction, declare no OnExit override, and have no stopOnExit field. FsmStateAction.OnExit 0x06000638 is ret.',
  'frozen_tail':'Already-started thaw sound continues when Death is interrupted by Birth and when the FSM enters None. The AudioSource stays on the same active cached prefab; renderer gating does not stop it.',
  'second_frozen_death':'Both frozen routes use ordinary SoundManager.Play on their existing AudioSource, not OneShotSound/Clip. PlayImpl 0x06014791 RegisterExtension(newClip=true), LoadClipForPlayback 0x0601475d and InitNewClipOnSource 0x0601475f set the next selected clip, then AudioSource.Play on the same source. Model one reusable playback slot per source: later Death replaces/restarts its prior playback rather than layering another generated source.',
  'taunt_tail':'AudioPlayClipAction uses SoundManager.PlayClip with a newly generated SceneObject source. Already-fired taunt audio is independent of cached status state exits. Retain summon/keyword suppression and exact action scheduling from audio/runtime_manifest.json.',
  'sleep':'No audio action exists in the recovered sleep root.'
 },
 'particles_and_tweens':{
  'action_lifetime':'ParticlePlayAction, ParticleStopAction and ParticleClearAction directly inherit FsmStateAction, have no OnExit, and finish immediately after invoking their own operation on the existing ParticleSystem(s). Do not destroy/recreate PS objects on every FSM activation.',
  'play':'ParticlePlayAction.OnEnter 0x060000ee calls ParticleSystem.Play(includeChildren). No preceding Clear/Stop/Simulate is implied. Preserve old emitted particles except when an actual source action clears them.',
  'stop':'ParticleStopAction.OnEnter 0x060000f4 calls ParticleSystem.Stop(includeChildren). Original Unity managed overload 0x0600005c passes stopBehavior=1, verified enum StopEmitting. It does not clear existing particles.',
  'clear':'ParticleClearAction.OnEnter 0x060000df calls ParticleSystem.Clear(includeChildren). This is a separate source action, not destruction of the cached system and not an automatic stop.',
  'frozen_shatter':'Death plays shatter systems; Birth has no shatter Clear/Stop action. Already emitted shatter particles retain their own lifetimes through a rapid reapply. Frost Play restarts/resumes the same source system using its native semantics.',
  'none':'None only disables ObjectContainer renderers. No blanket ParticleSystem Pause/Stop/Clear follows from None itself. Existing route actions may already have stopped or cleared selected systems.',
  'itween_exit':'iTweenFadeToAction.OnExit 0x06000128 and iTweenScaleTo.OnExit 0x060001c0 call iTweenFsmAction.OnExitiTween 0x06000151, remove their callback mapping, and call iTween.Stop(target,itweenType) when stopOnExit is unset or true. Current serialized interrupted sleep/taunt tween actions have stopOnExit=true. Their old tween completion must not overwrite the new state.',
  'culling_enums':read(P/'code/reapply_particle_enums.json'),
  'native_boundary':'Current fields use PauseAndCatchup=1 or AlwaysSimulate=3, not Automatic. Preserve these exact source values as evidence. Native renderer-visibility/culling internals, native ParticleSystem RNG and native integration are not reproduced by this static audit; the portable fixed-step particle model remains a documented compatibility boundary.',
  'systems':particle_fields
 },
 'async_state_request':'WaitThenChangeFsmState.MoveNext 0x06014999 waits until m_fsmReady, then compares current m_activeStateType with the requested stateType before ChangeFsmStateNow. A stale pre-ready request for another state is discarded. ChangeFsmStateNow sends the global enum event.',
 'route_actions':route_actions,
 'qa_assertions':[
  'After minion thaw then refreeze within3s: same cached serial, Birth route once, original three ice renderers enabled, original shatter tail retained, no old Death Wait later forces None.',
  'After hero thaw then direct refreeze within3s: same serial, normal Birth frost+scale, shell flags remain false as the original direct sequence; after a completed None then Birth both shells enable.',
  'After a completed None then reapply: same serial, not a new prefab; correct container-enable gate then source Birth actions.',
  'A thaw sound is not stopped by immediate Birth. A subsequent thaw on the same effect replaces its source playback slot and is not blocked by same-serial dedup.',
  'Entering None does not reset FSM clock, clear all PS objects or destroy audio; actual Actor release does destroy the cached owned effect.',
  'Sleep/taunt interrupted stopOnExit tweens cannot later write old alpha/scale or send stale completion into a new state.',
 ],
 'evidence_paths':['code/reapply_selected_methods.json','code/reapply_action_lifecycle.cil.json','code/reapply_spell_actions.cil.json','code/reapply_particle_actions.cil.json','code/reapply_wait_visibility.cil.json','code/reapply_itween_actions.cil.json','code/reapply_actor_state_mgr.cil.json','code/reapply_particle_native_wrappers.cil.json','code/reapply_particle_enums.json','code/hidden_actor_prefab_bindings.json','code/legacy_state_components.cil.json','assets/manifest.json','runtime_routes.json']
}
(P/'reapply_lifecycle_semantics.json').write_text(json.dumps(D,ensure_ascii=False,indent=2))
validation={'pass':True,'checks':{'four_cached_routes':len(route_actions)==4,'all_drop_delayed_events':all(r['keepDelayedEventsOnStateExit']==0 for r in route_actions.values()),'nine_particle_systems':len(particle_fields)==9,'source_audio_actions_have_no_OnExit':True,'frozen_SpellFinishAction_delay_zero':True},'limitations':['Static original CIL/prefab validation only; no GPU/native-client execution. Portable particle timing/native culling compatibility remains explicit.']}
for p in ['code/reapply_action_lifecycle.cil.json']:
 a=read(P/p)
 for typ in ['HutongGames.PlayMaker.Actions.AudioPlayClipAction','HutongGames.PlayMaker.Actions.AudioPlaythroughAction']:
  t=next(t for t in a['types'] if t['type']==typ)
  validation['checks']['source_audio_actions_have_no_OnExit'] &= t['base_type']=='HutongGames.PlayMaker.FsmStateAction' and not any(m['method']=='OnExit' for m in a['methods'] if m['type']==typ)
for rid in ['frozen_minion/root','frozen_hero/root']:
 for s in R[rid]['all_states']:
  if s['name']=='Death':
   sf=next(a for a in s['actions'] if a['class_name']=='SpellFinishAction')
   validation['checks']['frozen_SpellFinishAction_delay_zero'] &= sf['params']['m_Delay']['value']==0
validation['pass']=all(validation['checks'].values())
(P/'reapply_static_validation.json').write_text(json.dumps(validation,indent=2))
paths=[P/x for x in D['evidence_paths']]+[P/'reapply_lifecycle_semantics.json',P/'reapply_static_validation.json',P/'build_reapply_semantics.py']
(P/'reapply_evidence_sha256.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2))
print(json.dumps(validation))
