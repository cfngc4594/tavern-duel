# Windows summon constant-plan checkpoint (2026-11-09)

Baseline: abfb643. This change does not make every scene stutter-free.

A seek-local immutable numeric plan parses eligible mode 0/3 particle parameters once instead of repeating Dictionary and string-to-number work for each particle. It retains float64 scalars, float32 Vector3 operations, original 1/120-second repeated additions, lerp/matrix/pow order, RNG, particle counts and mesh output. Unknown subclasses and dynamic signatures retain the original solver. Plans are cleared before preparation and after the seek; direct position sampling cannot reuse stale parameters.

The four original integration/velocity functions remain unchanged and are the reference path. New exact tests cover all 16 source systems, 3 seeds, world/local simulation, world-space additive velocity, mode 3 multiplier/rotation, dynamic module edits, rewind/stop, public position helper and nonfinite signature rejection. Disabled malformed dampen is tested only at plan.setup: the old solver's independent input validation behavior is not changed.

## Formal Release A/B

Same conditions as performance-ci4.md: official Godot4.7.1 Windows Release, RTX4060 Laptop/i9-13900HX, 1600x900 GL Compatibility, VSync off, fixed visual dt1/60, two-round practice scenario. No competing performance tests/compilation/downloads. All 2026 baseline raw files matched in a source-free mounted pack.

PCK SHA256: C1D89AD2E83103BE3F11DC257F7D03BD0CAB57DA21A57F8296DABB4DC098E872.

| Warm phase | Reference->candidate order: reference / candidate mean ms | Candidate->reference order: reference / candidate mean ms |
|---|---:|---:|
| Idle | 11.27 / 10.91 | 11.07 / 11.84 |
| Play Senjin | 12.15 / 12.04 | 12.11 / 12.21 |
| Attack taunt | 16.47 / 16.85 | 16.31 / 17.02 |
| Archer battlecry | 24.62 / 22.61 | 23.60 / 23.10 |

Battlecry P95: 35.88 -> 30.45 ms in the first pair; 31.70 -> 31.16 ms in reverse. P99: 52.90 -> 49.55; 50.32 -> 50.27 ms. Report the range, not only the best pair. Idle/attack controls show system variability; this targets summon work, not the unchanged attack path. Four runs exited0 with empty stderr; each pair's eight outcome/draw summaries and both17-event traces matched exactly. Both arms include the minimal new null-dispatch checks, with the plan disabled in reference.

The final helper additionally skips reading disabled dampen and adds comments; active-input math is unchanged from the measured candidate. Exact production tests are rerun after this defensive guard.

Evidence: build/release-bench-bin/constant-plan*.log, build/constant-plan-verify.log and build/*.next33.log (local ignored artifacts). The full33 regression suite is enumerated in Android CI.

## Explicit non-delivery

An isolated C++ numerical prototype compiled but Windows application control blocked its DLL with error4551. It was not successfully loaded or tested; no native performance claim is made. The DLL, SDK dependencies and ABI glue are NOT included in this commit or release. No security policy or system environment was changed. A GDScript worker experiment also regressed timing and was not merged.
