# Cold effect and mesh preparation checkpoint

2026-11-09. develop; baseline 287aab1. Win11 i9-13900HX / RTX 4060 Laptop / NVIDIA 592.82, Godot 4.7.1 official release template, Forward+ Vulkan, 1600x900, VSync disabled. No source copies/worktrees. Same exported pack, serial runs in order base/full/both/glyph/full/base. All timings below exclude captures and source profiling. GPU-resident compute remains OFF; these improvements do not rely on GPU simulation.

## Changes

- Cache immutable source mesh surface arrays per particle renderer. Invalidate on source replacement, changed signal, or surface-count change. Particle transforms, colors, UVs, ordering and RNG are unchanged. Low-level RenderingServer writes without Resource.changed are not supported by this cache contract.
- Retain the original damage glyph Shader through the existing bounded Shader cache. Still create separate materials with the same parameters.
- Prepare 50 material jobs during the Windows Forward+ loading screen, one per frame: 40 reachable source materials, eight selected capture variants and two real glyph configurations. Prepare 42 transmission variants via the existing material path, without creating transmission viewports or playing effects. Do not warm unrelated font records or entire manifests.
- Dispose temporary objects both on completion and interrupted/failed loading. Missing optional material jobs warn and finish rather than blocking readiness. Loading does not charge player turn time. Extra loading frames can shift the continuously animated board background's initial phase; they do not change combat event times.

## Same-pack frame times (ms)

Numbers are forward/reverse order runs. `max` is the slowest recorded frame, not an average FPS claim.

| Scene | Baseline P99 | Full P99 | Baseline max | Full max |
|---|---:|---:|---:|---:|
| First attack | 114.33 / 113.86 | 45.03 / 45.33 | 155.55 / 147.59 | 45.61 / 46.26 |
| First Archer battlecry | 86.71 / 91.63 | 56.15 / 58.66 | 95.41 / 95.94 | 61.74 / 65.17 |
| Warm attack | 38.53 / 37.54 | 26.74 / 26.74 | 53.80 / 53.14 | 37.76 / 38.90 |
| Warm Archer battlecry | 45.71 / 47.57 | 45.78 / 46.43 | 51.85 / 55.60 | 47.47 / 50.19 |

Warm battlecry mean is NOT improved: baseline 20.64/20.81 ms versus full 21.05/21.11 ms. No claim of stutter-free operation. First attack worst frame falls about 69–71%; warm attack worst frame about 27–30%.

Isolation: mesh + basic 41-job preparation leaves first attack max 107.94 ms; adding glyph retention alone still 108.17 ms. Adding the source damage/transmission preparation yields 45.61 ms. Glyph retention improves warm attack P99 from 38.91 to 26.27 ms. Previous mesh-only and preparation-only arms separated mesh's warm-attack benefit from cold preparation (see raw logs on build host).

## Costs and remaining hotspots

Full preparation takes 517–518 ms wall time in the loading stage, 426–438 ms summed CPU work; it moves cost before interaction, not removes all work. Total startup measured 5.49/5.55 s versus baseline 5.31/4.90 s; host/OS variance prevents treating one difference as the intrinsic cost. Initial reported video memory is 694.16 MiB vs 673.61 MiB (20.55 MiB eager resources). This is a monitor observation, not a leak measurement.

A separate source-profile run before extended preparation located cold attack transmission_sync ~45 ms plus whole damage_sync ~35 ms; do not attribute that entire latter value to glyph shader loading. Remaining warm battlecry has significant particle CPU work and card action setup. Further work must profile those real scenes rather than assume renderer switching fixes them.

## Reproduce and scope

`Windows Renderer Benchmark` uses the production game with a fixed 1/60 clock, eight phases (idle, play, attack, Archer, twice). Default new switches are on. Reference switches:

```
--no-cache-mesh-surfaces --no-prepare-effect-materials --no-retain-damage-shader
```

`--no-prepare-transmission-materials` restricts enabled preparation to the basic 41 jobs. Explicit enable switches remain available. Do not compare capture-mode timings. Compare action event names/time and relative frame offsets, not absolute engine frame numbers after different loading lengths.

This checkpoint is develop only, not a new stable Windows release or evidence of mobile performance. main and the existing released build remain unchanged.

## Validation

- All six A/B runs exited 0 with empty stderr. Combat health/hand/unit outcomes and action names, simulation times and relative event frame offsets match across arms.
- A separately re-exported final-default pack completed all eight phases with the 50-job path enabled and empty stderr (smoke only, not another timing sample).
- Mesh cache test: 96 exact geometry comparisons plus changed/rebuilt/replaced/empty/null/disabled paths.
- Preparation test: 41/basic and 50/full jobs, one job per advance, material/glyph settings, unchanged RNG/damage state, no scene/viewports, observer disconnection, normal and interrupted disposal, fail-open negative fixtures.
- Five actual rendered snapshots captured per arm separately. Attack and pre-impact Archer snapshots are pixel-identical. The other three have small differences (mean absolute 8-bit channel difference 0.014–0.023); full-frame identity is not claimed. Viewed the matching impact frames: same board, units, damage glyph and effect composition. Preparation shifts initial board phase; particle/render repeat variance also exists independently. No shader math or particle-count reduction is introduced.

- Existing 33 CI regressions passed on the final source defaults. A remaining first Senjin play spike is still 104.65 ms (baseline 117.53 ms); warm play max is 44.67 ms. This checkpoint does not resolve every first-use/card setup stall.
