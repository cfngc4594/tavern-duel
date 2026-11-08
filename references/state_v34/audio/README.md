# v34 original state audio

Seven complete original AudioClip payloads, five enabled original FSM audio actions, fixed official visual build37.0.0.255130.254477. Gameplay remains the existing historic5834 Mage/Warlock30-entry pool. No production files modified and no official client run/login or GPU rendering.

## Integration

Copy clips/ to assets/original_status_audio_v34/clips. runtime_manifest.json is compatible with OriginalAudioRouter schema1/cards/sound_defs. At a native FSM audio action, use action_lookup[route_id + "|" + state_name + "|" + action_index] or action_lookup_nested[route][state][str(index)]. All layer delays are local0: the native FSM already provides Birth0.6000000238 or Death state timing. Do not apply the aggregate offset again.

- Frozen minion Death action2: one of three Shared_Frost_Impact_Small variants, equal weight1, gain1, random pitch1–1.2000000477.
- Frozen hero Death action2: Ice_FrozenMinion_Impact_Sound, gain0.6999999881, random pitch1–1.2000000477.
- Taunt State6 action4: taunt_shield_up, gain1/pitch1, summonVO=true, keywordVO=true.
- Taunt State6 action5: taunt_shout, gain0.8999999762/pitch1, summonVO=true, keywordVO=false.
- Taunt State4 action6: taunt_shield_break, gain1/pitch1, no summonVO/keywordVO.
- Sleep has no serialized audio action.

Apply the exact source suppression gates retained in each lookup/event/layer. AudioPlayClipAction skips SUPPRES_ALL_SOUNDS_FOR_ENTITY3093 unless its skip flag is true. For summonVO, absent GameState or SUPPRESS_ALL_SUMMON_VO1458 suppresses, except keywordVO with game DONT_SUPPRESS_KEYWORD_VO2636. Do not infer these tags merely from a token's identity. Trigger once per real FSM entry, not visual polling/reconstruction; use instance/action generation tokens and independent presentation RNG.

## Null AudioSource clips are dynamically loaded

Both frozen AudioSources have null serialized clip/resource and playOnAwake=false, but their exact GameObjects contain SoundDef components. They are not silent no-ops. AudioPlaythroughAction.Play0x06016aca uses SoundManager.Play(source,null,null,options) when OneShotSound is null. SoundManager.RegisterExtension0x0601475a calls GetDefFromSource0x06014793, LoadClipForPlayback0x0601475d resolves random/main GUIDs, and InitNewClipOnSource0x0601475f sets AudioSource.clip. sound_runtime.cil.json/txt retains the exact23-method chain.

This audio path is separate from the hero prefab's legacy visual Birth SpellState, whose nonrecursive particle lookup is a visual no-op. That earlier visual audit must not be interpreted as an audio no-op.

## Lifetimes and source mix

Audio actions finish immediately after dispatch, not after clip duration. Taunt PlayClip generated sources attach to SoundManager.SceneObject, not the effect's root; parentObject supplies position only (InitSourceTransform0x06014798). Keep the1.487s break and2.563s shout tails through normal visual state cleanup. Reuse finish_scope rather than prematurely stopping on visual None. Effective gain is action/code × source × SoundDef randomized volume × category × ducking; pitch is action/code × source × SoundDef randomized pitch. User SFX controls remain in force.

No exact GUID/PCM-hash matches were found in the existing v30 audio provenance/manifests, so these are missing state layers, not duplicates of existing card VO. Still dispatch each source action only once; do not add a separate card-event copy.

## Verification

clips_provenance.json retains original GUID, CAB/pathID, AudioClip resource metadata, original FSB and output PCM hashes, rates, channels and full durations. All7 clips decoded without trimming, gain, resampling, pitch alteration or remix. source_bundle_provenance.json verifies the cached56MB essential_base_global-audio-0.unity3d against its original CASC install content MD5. No network fetch was needed. verification.json covers full PCM and schema checks. audio_audit_manifest.json retains the full source actions, SoundDefs, audio sources, event schedules and exact reference binding. Decode initialization logged unavailable PulseAudio output in the sandbox; decoding completed and all payload/frame checks passed. No live playback was attempted.
