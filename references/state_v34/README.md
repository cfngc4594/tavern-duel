# v34 original state visual recovery

Static recovery from official client build 37.0.0.255130.254477. Gameplay scope is the existing historic 5834 Mage/Warlock pool: 27 collectibles + Sheep/Mirror Image/Coin. No client launch/login, no GPU rendering, no production edits.

## Ready for integration

- `assets/manifest.json`: four roots (`frozen_minion`, `frozen_hero`, `sleep`, `taunt`), 242 original objects, zero unresolved references/export errors. Original PNG decoding, mesh vertices/UVs, material properties, particles, transforms, animations retained.
- `runtime_routes.json`: source-owned root keys, state/action graph, target/ref/clip keys, variables, exact current-pool event-entry schedule. Every 64-bit object reference is a string. Correct nested PlayMaker custom structs and named numeric variables are decoded.
- `assets/data/source_bundle_provenance.json`: original install MD5 and actual bundle MD5 match. Fixed-build provenance retained.
- `mesh_color_channels.json` and `assets/data/mesh_color_channels.json`: original channel[3] metadata and normalization divisor. Only Stealth_Glass_mesh has colors; UNorm8 white255 must normalize once. Other meshes have no original vertex colors.
- `material_bindings.json`, `placement_oracle.json`: direct original object references, not name-based inference. Root scales: minion freeze1.079477787, hero freeze0.877192974, taunt1, sleep1. Original Actor.LoadSpell attaches below identity Spells parent preserving local transform.
- `trigger_config_selected.json`: selected original TagVisualConfiguration entries, with enum names resolved from actual assembly constants. Full config remains in `tag_visual_config.json`.
- `code/`: exact CIL for lifecycle, tag gate dispatch, IsAsleep, hide/show, CurveFloat and iTween easing; original assembly hashes.
- `reachability_manifest.json`: current-pool inclusion/exclusion and verified absence of status spell overrides in all30 CardDefs.

## Trigger and clear semantics

FROZEN260 changes from zero to positive invoke type14 Birth1; positive to zero invoke Death5. Frozen minion uses Card_Play_Ally_SpellTable81be4c58f5a9d454e815f1b0703d8179 → guid30dfeba50160a49888aa75e91fddb9e0. Base hero uses Card_Play_Hero_SpellTablec7908ae61ab34412aa7f5a9bf3c89cf2 → guid173ef382e0e354aa0b8590d8be21f977. Minion Birth follows normal/non-Mercenary CheckIfMerc→EnableIce; hero Birth selects Regular Frame. Neither has a serialized Idle event. Death hides ice, emits breakup particles, stops lingering particles and retains a3s tail before None. SpellFinishAction at Death entry is not the visual tail duration.

Sleep is type52 → Card_Play_Ally_Zzz guid734e352ca20a1494e8ec18226bf49f4c. NUM_TURNS_IN_PLAY271 rechecks IsAsleep for Birth/Death, CONTROLLER50 rechecks Birth. EXHAUSTED is43, not50; exhausted does not mean asleep. IsAsleep checks turns-in-play, attacks-this-turn, Charge and modern out-of-scope exceptions. For the current pool, fresh non-charge minions sleep until no longer fresh; no current-side check exists in this predicate. Birth sets particle playbackSpeed0.5, immediately enters Idle. Death fades1s then clears/stops. Global Hide/Unhide Zzz is called by forced mulligan visibility, not normal enemy turns.

TAUNT190 added invokes ActivateTaunt only when !ShouldShowImmuneVisuals; removed calls DeactivateTaunt. Current ordinary non-stealth cards choose type8 → guid2230bb169367d4c92b909c02f33a01a4. Birth waits0.600000024, scales over0.400000006, runs1s gleam, then persists. Death waits1.200000048 then hides/None. Current minion pool has no charge/stealth/immune/premium/starship alternatives.

Tag-change dispatch is gated by CanShowActorVisuals: not loading assets, actor exists, actor shown. Summon-complete callbacks call ActivateStateSpells after showing/resetting actor, so state visuals can begin after the summon sequence. Actor show/hide/release and status Death/None are distinct lifecycle operations. Preserve this distinction for transform, death and cleanup.

## Explicit exclusions

No current card has deathrattle. The original type34/35 table entries are recorded but not exported or enabled. Corruption is reachable but its CS2_063e CardDef has empty play/lifetime/death effect bindings. The finite skull belongs to the CS2_063 cast impact already recovered in v32; no persistent deathrattle/skull mark has been verified. Do not substitute a generic deathrattle marker. Frozen heroes are reachable despite no hero-attack gameplay path.

## Timing caveats

Zero-time PlayMaker transitions are frame-quantized. Taunt CurveFloat calculation4 is not raw AnimationCurve output: with unset time it computes from + curve(t)*(to-from)*(t/endTime); the present values are from1,to0,endTime0.199999988. CurveFloat terminal completion is deferred one update after final assignment. iTween ease27 is easeOutBack (s1.7015800476); ease30 is easeOutElastic. CIL is included.

## Root placement and auxiliary components

`root_placement_semantics.json` closes the taunt offset chain: preserve its original root local position (-0.483978271484375,0.095947265625,0). TAUNT uses Actor.ActivateTaunt/ActivateSpellBirthState without assigning Source. Although Spell.OnBirth attempts location2 placement, Source is null, so SetPositionFromLocation returns false and does not zero the prefab offset. Actor.LoadSpell explicitly preserves local transform. Exact32-method proof is in code/root_placement_and_hybrid_methods.json.

`auxiliary_component_semantics.json` resolves all three ParticlePlaybackSpeed components (assignment, not multiplication), two disabled SetRenderQue components, and the sleep sortingOrder increment1. SetRenderQue.queue is sortingOrder, not material renderQueue. Hero frozen contains a hybrid legacy Birth SpellState, but it has no animation clip and targets a Transform-only GameObject with no ParticleSystem. Its original GetComponent particle lookup is nonrecursive; it is a verified visual no-op, not an instruction to play child particles.

Shader DXBC analysis/portable shader adaptation is owned separately in `shader_analysis/`; this recovery alone is not proof that every native material/component/action has been implemented or visually validated.

## Hidden actors and death phases

`hidden_actor_semantics.json` separates temporary Hide/Show, normal keyword removal, minion/hero death, actual Actor release, and actor-path replacement. Temporary hide keeps the same status FSM running and only changes renderer visibility; it does not synthesize Death/Birth or restart audio. The four root FSMs remain enabled outside Actor.RootObject, and the original PlayMaker Update wrapper has no visibility gate. Ordinary minion keyword Death follows body-death activation by Card.m_keywordDeathDelaySec (default 0.30000001192092896); hero death does not use that delay. Actual actor-path replacement has an explicit hidden taunt-Death callback exception, which must not be guessed from cardID changes. Exact source methods and prefab ownership are under code/hidden_*.

## Current-pool Polymorph closure

`polymorph_actor_semantics.json` provides all thirteen exact current-minion → CS2_tk1 mappings. They reuse the existing normal Card_Play_Ally actor: the original OnChangeEntity update/restart predicates remain false. The synchronous CardDef callback refreshes the existing actor, then original tag deltas clear frozen/taunt through normal Death (and the recovered audio), with no death-presentation 0.3-second delay. The asleep predicate is unchanged by the current transform rule, so its same instance/serial/timeline continues. No replacement-only taunt callback is needed and the independent CS2_022 presentation is not delayed. The earlier generic warning is now resolved for this exact card pool, not broadened to future cards.

## Cached status reapplication and interrupted tails

`reapply_lifecycle_semantics.json` closes the same-object Birth/Death/None boundary. Actor-owned status Spell/FSM objects remain cached after Death and None; reapplication interrupts the current state on the same object. Exited Wait/tween completions must not mutate the new activation, while already-fired particles and audio follow their original component lifetimes. AudioPlaythrough and AudioPlayClip have no OnExit stop. Frozen playback reuses its original AudioSource slot on a later Death; taunt generated sources are independent.

Do not conflate Spell finished with Spell state or FSM state. Frozen Death's immediate SpellFinishAction does not set the Spell state to None. The direct hero Death-tail→Birth sequence therefore has no blanket renderer reset: its two ice shells stay disabled until an actual None→Birth container-enable transition (or another independently authorized original visibility operation). Minion Birth explicitly enables its three ice objects. This source asymmetry must not be hidden by inserting a synthetic None or constructing a new prefab.

The audit also records exact ParticleSystem culling values, native managed Stop(bool)→StopEmitting semantics, source action OnExit behavior, and nine particle-component fields. Native particle culling/RNG/integration remains a portable-renderer compatibility boundary, separate from the proven FSM clock. `reapply_static_validation.json` verifies the recovered configuration and `reapply_evidence_sha256.json` records its source files.

An actual Spell.Hide→Show edge is distinct from direct state reapplication: Show invokes the same container-enable helper whenever the Spell state is non-None, even during a Death tail. It does not restore saved individual renderer flags or restart the FSM. If the hidden FSM reached None, Show leaves the container disabled. This exact conditional is recorded in both lifecycle reports.
