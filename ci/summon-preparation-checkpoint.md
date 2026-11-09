# Summon preparation checkpoint

2026-11-09, develop after 9df38bc. Win11 i9-13900HX / RTX4060 Laptop, Godot 4.7.1 official Release, Forward+ Vulkan, 1600x900, VSync off. Main/stable release unchanged.

## Diagnose before changing

Separate default-off source timings located the first Senjin action at 50.37 ms: visual construction 44.48 ms, including out-prefab instantiation 34.18 ms. Warm out-prefab instantiation still took 28.16 ms. The first post-action transmission sync was about 44 ms in the earlier profile. These are CPU resource/setup costs, not a claim that the GPU is saturated. Added bounded (128 rows) optional summon timing instrumentation, disabled in normal play and measured A/B.

## Accepted change

Retain original immutable `native_summon_*.gdshader` resources in the existing bounded path cache; materials remain independently constructed. During Windows Forward+ loading, prepare 19 additional reachable summon materials and their transmission variants. This covers hand_out small/medium/large/hidden, play_in small/medium/large/opponent, and spawn friendly/opponent effects. It does NOT precreate card actors, clone hand cards, consume highlight RNG, play effects or remove particles. Hidden card-back actor and dynamic hand highlight are not represented as covered by these 19 jobs.

The queue grows from 50 to 69 tasks, one per loading frame. It reuses the existing interruption cleanup and optional missing-resource fail-open behavior. `summon_enabled` and `retain_shader` are enabled on develop. Benchmark `--no-prepare-summon-materials` disables both for the reference; `--prepare-summon-materials` enables both.

## Controlled measurements

Same exported SummonDeath EXE/PCK for six serial runs: base, prep, both, both-reverse, prep-reverse, base-reverse. No tests, exports or captures overlapped this final sequence. Earlier exploratory first round may overlap a small headless test and is NOT used below. `both` includes a subsequently rejected death snapshot candidate. Accepted comparison is base versus prep. Raw phase and startup statistics: `summon-preparation-results.json`.

Milliseconds; each cell contains forward/reverse-order values:

| Scene | Reference P99 | Accepted P99 | Reference max | Accepted max |
|---|---:|---:|---:|---:|
| First Senjin play | 45.74 / 44.63 | 16.40 / 17.06 | 116.02 / 105.38 | 46.19 / 47.61 |
| Warm Senjin play | 25.26 / 26.20 | 16.67 / 15.43 | 45.28 / 45.26 | 16.71 / 16.08 |
| First Archer battlecry | 62.31 / 57.37 | 38.21 / 38.20 | 67.13 / 61.79 | 57.86 / 55.53 |
| Warm Archer battlecry | 46.28 / 46.09 | 36.42 / 35.24 | 50.85 / 48.60 | 56.84 / 49.12 |

Cold play worst frame improves ~55–60%, warm play ~63–64%. Warm battlecry P99 improves, but its MAXIMUM does not reliably improve (one accepted run is worse). Warm battlecry mean is essentially unchanged: 20.93/21.15 -> 21.07/20.53 ms. Warm attack/death max remains ~40–42 ms. This is not stutter-free gameplay or 60 fps throughout.

Preparation stage increases from 0.513–0.532 to 0.690–0.701 seconds, about 0.17–0.19 extra seconds. Reported initial video memory increases 694.16 -> 703.81 MiB, +9.65 MiB beyond the preceding checkpoint. Whole startup varies with host/OS (base 5.41–5.96s, prep 5.58–5.64s); use the explicit stage cost, not a cherry-picked whole-startup difference.

## Rejected death experiment

Death frame129 is mostly 11 particle setups: warm death_sync ~27ms, schedule/setup ~21ms, followed by particles ~5.4ms. A narrow exact-death-script path for size/color samplers and local-motion reuse passed 384 recursive state/RNG comparisons and 258 exact mesh comparisons across 11 real sources. However, same-pack scene comparison did not show stable tail improvement: prep-only warm attack max39.88/42.12ms, with candidate39.33/42.34ms. Candidate code and temporary test were removed, not enabled or committed. No setup seek/state transitions were skipped. Next worthwhile work must address actual initialization/simulation costs with equally strict state/visual checks.

## Validation / limitations

All six formal runs completed with empty stderr; action names/times and relative event frame offsets match. Loading lengths change absolute engine frames, which are not a correctness comparator. Final-default smoke/capture runs are separate and may overlap headless regressions, so their timings are not benchmark evidence. GPU-resident compute and hidden-geometry candidate remain off. No source copies or worktrees, no system/security changes, no mobile performance claims.

Five actual-game images per arm were captured outside timed runs. Attack and pre-impact Archer images are pixel-identical; idle/play/impact images show small whole-frame differences (mean absolute 8-bit channel difference 0.0135–0.0232), not a full-pixel equivalence claim. Both Senjin play frames were visually inspected with matching effects/actors. The final-default pack completes all eight phases and reports all 69 preparation jobs, empty stderr, and both action traces passed.

Final-source validation: all 33 existing CI regressions plus the updated preparation and mesh-surface tests pass (35 total). Preparation test verifies 69 jobs/19 summon materials, one per step, unchanged gameplay/highlight RNG and summon state, cleanup and negative cases.
