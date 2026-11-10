# Cloud battlecry CPU checkpoint

## Default-off experiment, not an accepted stutter fix

This pass adds measurement coverage and retains one small, **default-off** CPU
experiment for later hardware A/B. It is not enabled in normal gameplay.
For base combat
particle systems with **2–31 live serial particles**, calculate solver eligibility
and constant-zero velocity flags once per synchronous `seek`, instead of once per
particle. The original worker threshold, dispatch, numerical kernels, arithmetic,
RNG, source modules, particle counts, animation/event timing and geometry remain
unchanged. Worker-computed, zero/single-particle and subclass paths do not use it.

The flags expire before `seek` returns. Preparation is after subemitter work and
`ArrayMesh.clear_surfaces()` callbacks; mutations between calls or from that mesh
callback are observed. Particle-specific singular/nonfinite motion-basis checks
remain per particle. `CombatParticles.seek_context_enabled=false` restores the
reference, which remains the production default. Only
`--combat-seek-context` explicitly enables the candidate in the benchmark.

**The local CPU reduction was not accepted as a production optimization. It is
not a demonstrated reduction in whole battlecry frame time, P99, worst-frame hitches, or improved Windows/Android FPS.**
No particles or visual fidelity were removed to obtain the result.

## Reproducible evidence and limits

The independent cloud clone started from `develop`
`db5c1774244bea961821b4fd8b3c5c5c28fa98d4`, verified against the remote branch.
No Windows working-tree files or its uncommitted benchmark changes were copied.
The cloud used the official Linux Godot **4.7.1 a13da4feb**, downloaded from the
Godot release, on an exposed Intel Xeon Platinum 8573C / nine logical processors.
No GPU device or display server was exposed. The renderer was **headless dummy**.
These are editor/debug-runtime CPU samples, not Release-renderer measurements.
Archive hash, runtime hash, raw samples and all summaries are in
`cloud-battlecry-results.json`.

Each formal measurement used serial reference/candidate/candidate/reference
order twice, with no simultaneous Godot tests, builds or capture work. Untimed
source setup/warmup precedes sampling. The three real Archer source systems keep
their original modules, counts and lifetimes, with peak live counts 10, 14 and 16.
Each arm measures 3,600 `seek` calls; all eight arms total 28,800 samples.

| Serial sources, microseconds | Reference mean | Candidate mean | Reduction |
|---|---:|---:|---:|
| ABBA block 1 | 361.260 | 319.728 | 11.50% |
| ABBA block 2 | 368.463 | 341.377 | 7.35% |

This saves about **27–42 microseconds per sampled source update**, not that many
milliseconds per game frame. Tails are inconsistent: for example, one candidate
arm has P99 1,948 µs, versus references 1,198 and 1,094 µs around that block.
All per-arm P95/P99/max values, including worse results, remain in the JSON.

The broader real missile/impact `_sample` test is **inconclusive**. ABBA block 1
means were 7.048 / 5.721 ms (reference/candidate), but block 2 was 6.248 / 6.416 ms,
with the candidate **2.69% slower**. It cannot support a whole-effect speedup or
hitch claim. An earlier implementation's noisy broad run was exploratory. The
initial serial-fixture lookup failure produced zero samples and is explicitly
excluded, never treated as performance evidence.

Reproduce after normal Godot import:

```sh
godot --headless --path . --script res://tests/combat_seek_context_test.gd
godot --headless --path . --script res://tests/combat_seek_context_test.gd -- \
  --serial-source-benchmark --repeats=10
godot --headless --path . --script res://tests/combat_seek_context_test.gd -- \
  --benchmark --repeats=3
```

## Correctness and instrumentation

The new exact regression compares three seeds of real Archer missile/impact
sources, every sampled frame, fractional and reverse seeks, changed modules,
collision, worker boundaries, direct helpers, subclasses, stop/destroy, degenerate
motion guards and a real mesh-change callback. It passes **1,770 state comparisons
and 1,622 byte-exact mesh comparisons**, with 985 serial and 637 worker observations.
Events, RNG and source mesh output match the reference.

The expanded benchmark preserves the historical 12-phase default and adds optional
full-board survivor/lethal cases using actual card play, targeting, source
projectile damage and death. It records first/warm/repeated action metrics and
chronological samples, setup/recovery costs, pipeline compilation counts and
explicit environment scope. Headless GPU, rendering and pipeline counters are
unavailable, not fabricated zeros. See `renderer-stress-benchmark.md`.

The partial CPU-visual fixture constructs actual source card/effect geometry but
cannot bake/rasterize cards or execute GPU work. Its complete first/warm smoke
observes 11–22 particle systems, 2,388–3,066 particle vertices and 164 Archer skin
vertices per action. Those correctness smoke timings overlap regression work and
are **not performance evidence**. A subsequent three-repetition-per-case run in
each arm completed 19 phases and six real battlecries per arm, with identical
outcomes, event order and event-frame offsets. The original 12-phase default
scenario also passed.

Final validation on one frozen source snapshot: **all 40 headless regression
scripts passed**, including the new experiment and reporting tests. The experiment
test asserts the default is disabled before explicitly exercising both arms.
The offline verifier passes a valid fixture and rejects nine corrupted-log cases.
Raw records and source hashes are in `cloud-battlecry-results.json`.

A standalone headless `--profiling` trial exited successfully but emitted no
function-profiler records; it is not counted as native Profiler attribution.
GPU pipeline stalls, Visual Profiler timings, rendered pixel equivalence, actual
Windows RTX 4060 performance and mobile Forward+ behavior remain unverified here.
A hardware-rendered serial A/B run is still required before claiming smoother
battlecry gameplay. No third-party debugging add-on or security setting was needed
or changed for this CPU pass. Main was not merged.
