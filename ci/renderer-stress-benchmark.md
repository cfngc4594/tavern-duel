# Renderer and full-board battlecry diagnostics

The default `tests/windows_renderer_benchmark.tscn` scenario is unchanged: two
rounds of idle, Senjin, attack and Archer (eight historical comparison phases),
plus startup, reset and two recovery phases (12 total). Existing phase names,
frame counts, gameplay actions and capture points stay intact.

## Optional stress runs

Append `-- --battlecry-stress=5` to run five repetitions **per case** after the
normal scenario. Add `--battlecry-stress-only` to skip the normal two rounds and
make the first stress Archer the first Archer action in that process. Supported
repetition counts are 2–100. Three or more cover first, warm and repeated actions.

Each case starts with six friendly and seven opposing minions. A real Archer
card play and target-selection commit fill the friendly board, then the source
projectile damages either a surviving Senjin or a one-health opposing Archer.
The lethal case includes normal damage and death effects. The harness only
constructs initial board state; it does not directly call damage or substitute a
synthetic effect. Every action checks card/mana consumption, target damage,
hero health, board counts, completion, and identical outcome/event order across
repetitions. Event frame offsets remain in the log: original source timing can
differ between the first and subsequent plays, so those offsets are not silently
forced equal. Each setup (180 frames), action (240), and recovery (180) is timed.
Recovery verifies no remaining summon, Archer or combat/death effects before reset.

`BATTLECRY_STRESS_ACTION_PASS` identifies first-case-use, warm or repeated actions
and whether this was actually the first Archer in this process. First use does
**not** mean a cleared OS/driver shader cache. The lethal case follows a survivor
case and therefore never claims a wholly cold Archer. `BATTLECRY_STRESS_PASS`
reports per-action and pooled frame mean/P95/P99/max with chronological raw
samples. Pooled action tails include first use, exclude setup/recovery, and must
not replace reporting the separate per-action and setup/recovery tails.

## Environment and unavailable metrics

`BENCHMARK_ENVIRONMENT` records engine/build, OS/processor, display server,
renderer/driver/adapter, command-line switches and measurement scope. Each
`MONITOR_PHASE` retains the original fields and adds chronological `raw_samples`,
synchronous `action_usec`, scope, context, and optional pipeline counters. The
`game_process_ms` samples time the actual fixed-clock production `_process` call,
excluding the harness mesh inspection. Because `process_frame` emits before
`Node._process`, this is the last completed game frame, not an exactly aligned
measurement of the current wall interval. Wall `frame_ms` intervals include that
inspection and all other work between process-frame boundaries. Summary
calculation no longer sorts the raw arrays in place. Percentiles retain the old
zero-based `sorted[floor(n*p)]` convention for compatibility.

Headless runs normally execute **logic only**, skipping production visual paths.
They are not GPU or whole-game FPS measurements. Renderer metrics are explicitly
unavailable, with empty raw arrays and no fabricated zero means or percentiles.
Viewport timings observed only as zero are also unavailable. Engine process and
physics monitors may update more slowly than frame sampling; they are attribution
signals, not substitutes for wall-clock intervals or synchronized frame timings.

`--headless-cpu-visuals` enables a separate, explicit **partial CPU visual fixture**.
It creates the normal spatial/effect machinery after headless startup, as the
existing source effect tests do. It synchronously builds the real source card
geometry for every definition before discarding the raster-bake completion
queue, which cannot finish on a dummy renderer. Normal turn UI, completed card baking/startup and all
GPU/raster work remain absent. Each stress action must observe actual particle
systems with nonempty particle mesh vertices and source Archer skinned vertices.
Those per-frame checks add diagnostic overhead. This fixture can compare CPU
changes within identical conditions; it is never a rendered-device substitute.

Example correctness/CPU-fixture invocation (after normal project import):

```sh
godot --headless --path . res://tests/windows_renderer_benchmark.tscn -- \
  --battlecry-stress=3 --battlecry-stress-only --headless-cpu-visuals
python3 tests/verify_renderer_benchmark.py build/run.log
```

Save stdout and stderr together to the indicated log. The verifier requires
complete phases/PASS records, rejects engine errors, recomputes summaries from
raw samples, checks headless unavailable labeling, and optionally compares two
logs' deterministic action outcomes/event order. It does not certify graphics,
pixel equivalence, GPU speed, or process exit status; check exit status separately.

## Pipeline and CPU attribution

`--profile-pipelines` discovers available `Performance.PIPELINE_COMPILATIONS_*`
constants dynamically for Godot 4.6/4.7. It records cumulative before/after/per-frame
counts and phase deltas. A missing or reset counter yields no fabricated delta.
Headless and Compatibility renderers explicitly report the RenderingDevice
counters unavailable. These are **counts, not compilation milliseconds**. Updates
can lag the sampled process frame, so overlap with a long frame is attribution
evidence, not proof of a synchronous compilation stall. Pipeline and source
profiling/capture runs should stay separate from formal uninstrumented A/B.

The CPU seek-context candidate is **disabled by default** because whole-effect
benefit was not reproduced. Its experimental switch is exposed as `--combat-seek-context`
and `--no-combat-seek-context`. Use the same engine/build, workload, renderer,
profiling flags and pack for both arms. Run serial reference/candidate/candidate/
reference with no overlapping builds, imports, tests or benchmarks. Retain all
raw logs and report both orders, including regressions and first-use/recovery
tails. Never infer Android or Windows GPU gains from a Linux dummy renderer.

Focused reporting unit test:

```sh
godot --headless --path . --script res://tests/renderer_benchmark_metrics_test.gd
```
