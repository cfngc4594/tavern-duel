# v32 combat implementation

The rules remain the historical build-5834 Mage/Warlock implementation. Its rules file is byte-identical to v31. Source presentation data comes from build 37.0.0.255130.254477, not a claim that its modern rules are copied.

## Production routes

- Normal minion attack uses the original ReadyAttack/FinishAttack curves, 0.12-second linear source movement, source-renderer AABB contact offset and original four impact tiers. Layout return is one second with source iTween default OutExpo. Aiming consumes elapsed readiness. Cancel uses original state4 FinishAttack. No old attack tween/lift/scale is stacked on the source pose.
- All 11 enabled start prefabs execute Birth before Action. Targeted hand spells preplay while an actual battlefield target arrow is active; targeted Fireblast starts on power selection. Untargeted spells start only on accepted drop. Release reuses the same prefab and waits only for remaining Birth: fire/ice/power one second, Polymorph/Arcane Missiles 0.1 second, six Warlock starts 0.5 second. Cancellation executes the original Cancel tail, and match reset immediately frees it.
- All 17 spells including Coin, both powers, Mirror generated tokens and same-entity sheep transformation use their source route. Only one caster-seat area variant is selected. Source AUTO means hero for spells and hero-power card for powers. NONE uses the declared fixed-board world registration; original root authoring coordinates are not a recovered board camera.
- Original prefab transforms, textures, meshes, clips, decoded PlayMaker states, material parameters, particle events and local lights are executed. Every action has a source key. Native audio actions are not played twice: the v30 router remains the one sound owner.
- RenderToTexture owns independent source RGB/alpha captures, source blur/bloom kernels and generated plane materials. C/T composition preserves colored destination multiplication. These are separate from the original source fragment equations and have GPU tests.
- Five original MonoBehaviour classes now run separately from FSM: RotateOverTime, Spinner, ScrollingUVs, SetRenderQue and ParticlePlaybackSpeed. The original disabled/inactive instances remain inactive. A separate logical quaternion preserves rotation during zero scale and after scale restoration. Sort order and original shader/custom render queue are compressed together without changing their ordering.
- Fifteen original TrailRenderer components have an independent ribbon compatibility player. Arcane heads that contain both MeshRenderer and TrailRenderer retain both renderers; no particle tail is counted as a trail replacement.
- Original streamed MinionShake cubic coefficients are sampled directly. Native Animator 2D weights/normalized transitions are an explicitly independent compatibility implementation, not an invented sine animation or a recovered native binary kernel.

## Rules and presentation ownership

Attack damage occurs at source contact. Single-target spell resolution is dispatched at the documented source gate in `atomic_compat_dispatch.json`. Source metadata callbacks and visual cleanup are independent.

Arcane Missiles calls the unchanged whole-spell rules function once. Its real targets, intermediate damage/death outcomes and generated units are recorded. The presentation-only replay shows those snapshots at each missile's arrival plus the original metadata delay. Later missiles start at the previous path arrival, not after its metadata wait. It never selects a second set of targets or changes the rules RNG. Damage numbers, death dust/ghosts, generated source summons and victory presentation are buffered with the snapshots. New match cancellation discards all snapshots and delayed callbacks.

Legacy cosmetic RNG consumption is retained where removed hand-drawn bursts formerly consumed it. Actual source particle/path/camera randomness has separate generators.

## Boundaries

- The existing fixed board, camera and lighting are registered compatibility inputs. Original shader formulas are retained, but this does not establish original scene lighting or camera equivalence.
- Native Unity particle integration, emitter frame scheduling, random sequences, blending/rasterization and Animator internals are not asserted to be bit-identical. Original zero-scale or sheared emitter matrices use bounded affine-column interpolation only where quaternion decomposition is invalid; regular rotated/scaled matrices retain the existing interpolation. No source scale or RNG is changed. Original 0.3-second CrossFade timing is applied with a documented linear property-weight compatibility blend.
- Source null properties, null animation-event targets, disabled modules and unreachable FSM states remain null/disabled/unreachable.
- All 54 source meshes have recovered vertex-color channel metadata. The five colored meshes use original UNorm8 channels and are normalized by 255 before Godot COLOR input; floating/HDR color values are not inferred from magnitude. The original exported source arrays are unchanged.
- All 97 original texture sampler states were checked: 96 are single mip. Seven clamp textures retain clamp on their actual shader bindings, and the sole seven-level Default-Particle texture uses the recovered original RGBA mip bytes. Integer LOD selection uses a derivative footprint because Compatibility GL has no textureQueryLod.
- Recovered URP quality assets use LDR; original fragment saturation is applied before blending. OffScreenRenderFX and the two Flamestrike Glow registrations retain their original camera/pass equations. They do not add a Nova glow.
- Runtime material audit loads 126 original materials with no untranslated fallback. This is shader-route coverage, not proof every material is visible.
- Historical source preview predates full R2T and the fixed None-to-Birth expiry ownership. It is not the final visual completion proof. Final integrated flight/impact/tail frames must be captured after the fixes.

## Verification status

See `action_coverage_in_progress.json` for current scope, unique original coverage ledger and boundaries. Headless rules/timing tests do not replace integrated GPU checks. The full-pool renderer remains under integrated QA until its current capture/composition changes pass.

## Component and sampler verification

The 86 source MonoBehaviour instances passed 357 source checks, with another 112 lifecycle/zero-scale/particle-speed checks. Original render sorting passed 403 checks over 25 tuples and 126 materials. Three Light animation tracks passed nine original keyframe values. Sampler GPU tests passed 170 checks, including out-of-range clamp UVs and the original seven mip levels. These are focused checks, not a substitute for final integrated visual/lifecycle/PCM validation. An intermediate lifecycle run exited with code137; final acceptance remains open until the new candidate is measured and passes.
