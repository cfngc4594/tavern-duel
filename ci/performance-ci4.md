# Windows particle optimization checkpoint (2026-11-09)

Baseline: 99af4d8. This is not a claim that Windows or Android is stutter-free.

## Accepted change

Summon particles reuse seek-local immutable UV corners for the existing 1x1/2x2 cases. A guarded constant-module fractional Euler step avoids redundant dynamic module sampling. All other signatures and subclasses retain the original path. The simulation step, particle counts, RNG, curves, mesh output and animation timing are unchanged.

32 regression scripts passed locally (the Android workflow lists the complete set). New tests compare all particle state, RNG and mesh arrays across 16 source systems, runtime changes, rewind/stop and subclass fallbacks; UV tests include 2024 exact samples. Nonfinite constant inputs retain the old integration path.

## Formal Release measurement

Godot 4.7.1 official release template, i9-13900HX / RTX4060 Laptop, Compatibility renderer, 1600x900, VSync off, Dummy audio. Existing practice scenario with fixed visual dt 1/60, two rounds. The second round is the warm comparison. No other performance tests or native compilation ran concurrently.

Both arms use the same PCK and raw resources; reference disables only the two new flags. Reference therefore includes their small branch overhead. 2026 raw source files matched from an empty project without source fallback. PCK SHA256: F7322413EAB5B7A6EDE4C5F9BD84B88C6CD0AFB4AD92923514AB46036BC72074.

| Warm phase | Reference mean ms | Candidate mean ms | Reference P95 ms | Candidate P95 ms |
|---|---:|---:|---:|---:|
| Idle | 10.93 | 11.03 | 11.48 | 11.78 |
| Play Senjin | 12.29 | 12.24 | 15.69 | 15.85 |
| Attack taunt | 16.22 | 16.32 | 22.63 | 23.17 |
| Archer battlecry | 24.00 | 23.77 | 32.08 | 30.66 |

Battlecry P99: 51.02 -> 50.71 ms. Prior isolated same-algorithm A/B runs in both orders saved 0.55 and 0.77 ms; the final run saved only 0.23 ms. This is a modest repeatable local gain, not a solution to the remaining spikes. Eight phase outcomes/draw statistics and both 17-event traces were identical. Both exits 0, stderr empty.

Local evidence: build/release-bench-bin/final-snapshot-{reference,optimized}.log; build/final-snapshot-verify.log; build/*.next32.log. Ignored build files are not release requirements.

## Rejected candidate / next investigation

A separate two-worker GDScript numerical candidate preserved outputs but slowed the warm battlecry from 24.02 to 25.07 ms (335 task batches / 73992 particles); not merged. Copy/scheduling cost cannot be assumed to pay off merely because work is parallel.

Profiler evidence motivates an isolated native numerical-kernel experiment. It is NOT part of this commit. No quality reduction, native library, toolchain dependency or system setting change is included here.
