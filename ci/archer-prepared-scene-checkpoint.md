# Archer one-shot prepared scenes

## Change and scope

On Windows Forward+, keep one **fresh, never-played** missile scene and one fresh impact scene ready. Preparation instantiates source assets and builds initial skin meshes without dispatching events, allocating effect serials, changing RNG, or starting particles. At the original spawn time, adopt the scene and install its skin only at the original skin setup point, after components and RTT setup. Pose-dependent geometry is refreshed. Materials remain per-instance. Staging is hidden, process-disabled and outside the spatial/transmission tree; it is hidden before reparenting.

This is a bounded one-shot inventory, not reuse of dirty effects. Empty or incompatible inventory falls back to original creation. After effects, damage, summon and interaction work are idle for two complete frames, refill at most one preparation stage per frame. No gameplay callback or visible effect is delayed. Other renderers/platforms retain the old path. CPU particles and skin fallback remain; GPU resident and hidden-geometry shortcuts remain disabled.

## Measurement

Godot 4.7.1.stable.official.a13da4feb, Win11 i9-13900HX / RTX 4060 Laptop, NVIDIA 592.82, Forward+ Vulkan, 1600x900, VSync disabled, uncapped. Same non-debug exported benchmark pack, default implementation toggled with `--archer-prepared-scenes` / `--no-archer-prepared-scenes`. Sequential order: baseline, candidate, candidate, baseline. No overlapping builds, tests or captures. Fixed-clock actions, real wall-clock frame intervals. Capture/test runs are separate and are not performance evidence.

| Run | Cold mean / P99 / maximum ms | Warm mean / P99 / maximum ms |
|---|---|---|
| Baseline | 17.90 / 37.25 / 55.68 | 18.38 / 34.87 / 47.31 |
| Prepared | 17.90 / 37.13 / 48.54 | 18.37 / 35.27 / 42.92 |
| Prepared reverse | 17.73 / 36.18 / 47.52 | 18.25 / 34.88 / 42.88 |
| Baseline reverse | 17.77 / 36.61 / 54.42 | 18.29 / 35.80 / 41.93 |

The first battlecry maximum improves by 7.14 and 6.90 ms (about 13%). Warm maximum is **not consistently improved**: one pair saves 4.39 ms, the reverse pair is 0.95 ms worse. Means/P99 barely change. Retain for demonstrated first-use benefit, not as a claim that warm combat or the whole game is stutter-free. The maximum occurs at the same impact frame in each comparison (cold 119, warm 113).

### No hidden refill gap

The benchmark now measures startup settle, round reset settle, and 180 recovery frames after each battlecry: 12 phases per run. Previously the reset wait was unmeasured. Every one of the candidate's 16 runtime preparation steps maps to a measured wall-clock frame interval. Recovery refill frames were 10.04–16.62 ms, with individual skin stages 2.50–4.81 ms. Before the two-quiet-frame grace, preparation sometimes stacked on disposal in ~19 ms frames; the grace avoids that overlap here, but is not a hard frame-time budget. Both candidate runs record four hits, zero misses and replenished inventory after both rounds.

The expanded coverage also exposes an existing synchronous match-reset frame of 594–619 ms in both arms. This is not fixed by the battlecry pool and is not concealed as idle time.

### Costs

Four additional loading preparation jobs (69 to 73), 16.28/16.59 ms measured CPU work for the initial stock. Total loading was noisy (5.58–5.93 seconds across runs), so no claim of zero loading cost. Full stock owns 38 attached nodes plus four detached skin MeshInstances; serialized skin surface arrays total 12,368 bytes, **not** total memory. Stable idle Godot video-memory accounting rose roughly 0.009 MiB, also not total CPU/GPU allocation. Inventory is bounded and disposable.

## Correctness and limitations

The focused real-route comparison checks events, RNG state, emission counts, particle bytes, renderer mesh surface bytes, visibility and RTT audits at ten sample points over 90 advances for each missile/impact route. It also checks no preparation RNG/serial consumption, concurrent capacity exhaustion fallback, cancellation, fresh refill, idle guards, grace reset, same-frame dedup and disposal. Across all four formal runs, normalized event frames and exact event times match after removing the loading-frame offset.

Visual sampling checked both sets of 19 captures, including cold impact frames 118–120 and warm spawn 89–91 / impact 112–114. No candidate-only early stock, duplicate model, missing effect or residue was observed. This is sampled visual validation, not every-frame/pixel identity. The default-enabled Release smoke completed all 12 phases with empty stderr, four hits, zero misses and full replenishment. The local fixed-scene Release EXE is a benchmark, not a newly published playable Windows release. Main and Android Compatibility CI are unchanged; no claim of Android testing or develop CI success.

## Alternatives assessed

Native prototype cannot currently be loaded: Windows App Control rejected its DLL (4551). No policy bypass or installation attempted. GPU skinning is not presented as a free substitute: continuous cached skin work was small in the earlier profile, while RTT/transmission require corresponding mirrored geometry and precise capture sequencing. This change targets measured initial construction instead. Remaining warm impact work still needs separate profiling/optimization; no reduced visual quality or altered animation timing was introduced.

Validation: all 33 existing Android-workflow CPU regressions plus material preparation, mesh surface cache, death initial geometry, Archer skin cache and prepared-scene tests passed on Godot 4.7.1 (38 total; exit 0, PASS markers, no SCRIPT ERROR/ERROR). These are headless correctness tests, not Android device validation.
