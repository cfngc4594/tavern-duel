# Death initialization checkpoint

2026-11-09, develop after b94ab19. Win11 i9-13900HX / RTX4060 Laptop, Godot 4.7.1 official Release (a13da4feb), Forward+ Vulkan, 1600x900, VSync off. Same existing checkout, no worktree or source copies. Main and stable release unchanged.

## Accepted change: avoid an overwritten mesh, not simulation

The measured warm death start frame contained about 26–27 ms of death_sync. Roughly 21 ms belonged to scheduled initialization of 11 particle systems, including an initial seek that immediately precedes another seek in the same synchronous effect sample.

Only for the exact death adapter, only for top-level particles created inside that synchronous sample, skip the INITIAL geometry assembly/upload. Continue all particle births, RNG, numerical integration, subemitters, collision/lifetime bookkeeping and screen-clamp counting. The final ordinary seek in the same sample constructs the mesh before rendering. Do not delay the effect to another frame, drop particles or replace the initial state with a shortcut.

Independent setup, spawn/autoplay outside that sample, subemitter templates and unknown adapters keep eager rendering. Default `death_initial_geometry_defer_enabled=true`; benchmark `--no-defer-death-geometry` restores the reference. `--defer-death-geometry` explicitly enables it.

## Same-pack formal comparison

The accepted base/defer/defer-reverse/base-last samples come from one ParticleFinal EXE/PCK. Additional isolated dispatch candidates ran between the pairs; no tests, captures, builds or profiler runs overlapped timed samples. Both a forward and a reverse comparison are retained, not just the fastest candidate run.

| Attack/death measurement (ms) | Reference forward/reverse | Accepted forward/reverse |
|---|---:|---:|
| Cold death-start frame 129 | 46.51 / 42.29 | 40.04 / 39.49 |
| Cold phase maximum | 49.96 / 47.22 | 46.60 / 46.20 |
| Warm death-start frame 129 and phase maximum | 39.32 / 39.02 | 35.37 / 34.32 |
| Warm phase P99 | 26.38 / 26.08 | 26.46 / 26.92 |
| Warm phase mean | 13.31 / 13.07 | 13.11 / 12.99 |

The warm death-start hitch improves about 4–5 ms (10–12%), NOT all frames. Mean and P99 are essentially unchanged. Warm Archer maximum remains about 50 ms (reference 49.08/49.60 vs candidate 52.23/49.68). This checkpoint does not solve battlecry stutter or establish smooth 60 fps. No extra preload stage or persistent resource cache is introduced.

Full chronological frame samples and phase outcomes are in `death-initial-geometry-results.json`. Stats sorts its input; the final benchmark explicitly duplicates frame samples BEFORE computing statistics. Earlier exploratory WorkerDispatch trace fields were sorted distributions, not chronological traces, and are not used for frame attribution here. Existing percentile/max numbers from those exploratory runs remain distribution statistics only.

## What the profiler showed, and rejected changes

Added default-off, bounded particle seek profiling, including emission, subemitters, numerical state, geometry loop, upload and worker preparation/build/enqueue/wait/collect. Nested state time is inside loop time; subemitter rows can overlap parent rows. Instrumented timings are diagnostic, not formal A/B performance samples.

For a representative Archer source (ID ending 3582461507358044680), a diagnostic peak worker 4.82ms comprised wait 3.80ms, build 0.51ms, collect 0.23ms and enqueue 0.024ms. Waiting includes calculation AND scheduling, so this does not prove that thread submission is slow. GPU mesh upload was only about 0.06ms; observed clamp counts were zero. Another source's largest sample occurred below the 32-particle dispatch threshold, on its serial fallback.

Compared all-inline same-kernel execution, threshold 128, and same-kernel inline only below 32 particles, after strict state/RNG/mesh checks. No stable real-scene benefit was found; all new dispatch strategy parameters/code and their temporary test were removed. The original threshold 32 / 2–4 worker tasks remain. An existing hidden-geometry switch also failed to show a stable warm tail benefit and remains off. Do not conflate these experiments with the accepted death change.

## Correctness and scope

The focused death test checks 11 actual source systems, 482 recursive state/RNG comparisons and 214 exact mesh comparisons. It covers same-frame playback-speed changes, stop/destroy, coarse steps, rewind and fallback paths. All accepted formal runs have empty stderr and identical action names, simulation times and relative event-frame offsets. GPU-resident compute remains off. No mobile measurement or new stable release is claimed.

## Final validation

All 36 regression scripts passed using Godot 4.7.1 (the 33 workflow tests plus effect-material preparation, mesh-surface cache and the new death-initial-geometry test). A fresh Release export with the accepted switch enabled by default completed all eight benchmark phases with empty stderr; this smoke run overlapped regression work and is NOT a timing sample.

Captured nine corresponding frames per arm, including death-start frames 129 and 130. Two full frames are pixel-identical. The other frames differ slightly, including idle and pre-death frames; full-frame equality is not claimed. Death frame 129 has 14,937 changed pixels of 1,440,000, mean absolute channel difference 0.0130 on the 0–255 scale. Visual inspection of the paired death-start images found matching damage/death geometry with variation in green selectable-card highlights. Exact particle-state and mesh comparisons, rather than screenshot equality, establish the focused change's numerical equivalence. This is not a full manual gameplay session.