# Forward+ compute checkpoint experiment (develop)

## Decision

This is a real Vulkan compute implementation, but **not an accepted speedup**.
It is disabled by default, and only the renderer benchmark opts in with
`--gpu-compute`. The normal game keeps its CPU simulation. `main` is unchanged.
No particles, effects, timing, quality or random samples were removed.

The experiment uses the existing develop checkout directly: no source copies or
worktrees. It does not use the previously blocked native DLL or alter Windows
security settings.

## Scope and correctness

The profiler identified CPU summon-particle integration as a hotspot. The kernel
moves only eligible constant full 1/120-second integration steps to a local
RenderingDevice. CPU retains emission/RNG, fractional steps, curves, mesh building
and materials. VelocityModule-enabled systems remain on CPU. This is not a
GPU-resident particle renderer and not GPUParticles.

FP64 scalar clocks/rotation and explicit float32 Vector3 arithmetic preserve the
original repeated-step order. Each buffer record is 80 bytes; workgroups contain
64 lanes with a count guard. Whole-batch readback validation occurs before any
particle checkpoint changes. Unsupported devices/compile failures, nonfinite
inputs, long seeks and non-advancing extreme clocks fall back without partial
writes. FP64 support is required; this was tested on RTX 4060 Laptop, not all GPUs.

The opt-in entrypoint shuts down the local device explicitly. Shader source is
included raw by the existing export plugin because runtime compilation uses
FileAccess, not just Godot's imported SPIR-V resource.

Tests: strict checkpoint, RNG and full mesh byte equality over 16 real source
systems, three seeds, forward/rewind/stop, batch boundaries 1/2/63/64/65/127/399,
and high absolute clocks. The full source suite passed 2695 comparison groups,
484 actual dispatches and 249376 particle checkpoints. Compatibility fallback
passed 168 groups with zero dispatches. All 33 existing CPU regressions passed.
An additional extreme-clock refusal test was added after the measured runs and
passed both the 175-group focused suite and a repeated full 2695-group suite, without changing normal-scene arithmetic.

## Formal Windows A/B

Godot 4.7.1 official release export; i9-13900HX / RTX 4060 Laptop; Forward+ Vulkan;
1600x900; VSync off; same EXE/PCK, resources and deterministic action clock.
Serial CPU, GPU, GPU, CPU order. Each run contains two rounds; table uses warmed
second rounds. All four exit 0, empty stderr, exact same 17-event action traces
and phase outcomes. No screenshot saves occurred during timing.

| Phase | CPU / GPU mean ms, first pair | CPU / GPU mean ms, reverse pair |
|---|---:|---:|
| Idle | 11.51 / 11.21 | 11.29 / 11.49 |
| Senjin play | 11.96 / 12.11 | 11.56 / 11.61 |
| Taunt attack | 16.86 / 16.65 | 17.03 / 16.33 |
| Archer battlecry | **23.85 / 24.59** | **23.70 / 24.98** |

Only battlecry dispatches eligible work in this scenario. Its P95 CPU/GPU is
34.46/37.17 ms and 35.74/36.66 ms. Compute makes the measured mean approximately
3.1% and 5.4% worse. Changes in non-dispatching phases are run variance, not a
compute improvement.

Warm battlecry (180 frames, 83 dispatches, 17782 particle checkpoints):

| Cost, summed over phase | First GPU run ms | Reverse GPU run ms |
|---|---:|---:|
| Pack CPU state | 72.17 | 72.62 |
| Buffer allocation/upload | 0.76 | 0.78 |
| Submit + CPU fence wait | 65.15 | 67.70 |
| Readback API CPU wall time | 45.08 | 55.23 |
| Validate/unpack | 27.06 | 27.04 |
| Entire bridge CPU wall time | **215.44** | **228.60** |
| GPU timestamp dispatch interval | **1.79** | **1.84** |

GPU timestamp values are nanoseconds converted to milliseconds, queried after
sync. They include surrounding command barriers and are not the whole frame.
Submit/wait is CPU wall time, not GPU execution time. Bridge rows exclude some
bookkeeping, hence are not an exact decomposition of end-to-end. First-use device
initialization is an additional cold cost, excluded from the warm rows. The test
also records four viewport CPU/GPU counters; their percentiles are asynchronous
and must not be summed as a frame timeline. Performance.TIME_PROCESS is a window
maximum, not per-frame script duration.

The GPU arithmetic is tiny compared with per-batch GDScript packing, synchronous
round trips and readback. This experiment therefore falsifies the simple
"move the small integration loop to GPU and read it back each frame" approach.
It does not show that a GPU-resident simulation/rendering architecture cannot
help. Such an architecture must remove these transfers and port remaining
rendering/mesh behavior while preserving source visuals; that is a separate,
larger change, not evidence of a speedup here.

Measured PCK SHA256:
`3D854EC8B19C7373F836B0FC502CB03557451A38A8B6052EC8A02B6E7499E2F1`.
After the extreme-invalid-clock guard and EOF whitespace cleanup, re-exported PCK:
`936321C088903AF8B3219AA864DA558564C5C3E6BEE5949003EBB9E91CCEDF60`.
No ordinary measured input reaches that guard. Structured measurements are in
`ci/compute-prototype-results.json`; raw local logs are ignored under
`build/renderer-branch/compute-perf-*`.

## Reproduce

```text
godot --path . --rendering-method forward_plus --rendering-driver vulkan --script tests/summon_compute_test.gd -- --all-sources
godot --path . --rendering-method gl_compatibility --script tests/summon_compute_test.gd -- --expect-fallback
godot --headless --path . --export-release "Windows Renderer Benchmark" build/renderer-branch/ComputeBenchmark.exe
ComputeBenchmark.exe --rendering-method forward_plus --rendering-driver vulkan --resolution 1600x900 --audio-driver Dummy
ComputeBenchmark.exe --rendering-method forward_plus --rendering-driver vulkan --resolution 1600x900 --audio-driver Dummy -- --gpu-compute
```

Use a separate capture-only run with `--fixed-fps 60` and
`-- --capture-dir=C:/absolute/directory` (append `--gpu-compute` for GPU). This fixes
engine shader TIME as well as the game clock. Do not time screenshot runs.

This is a locally verified experimental export, not a newly published stable
Windows release. Existing main-only CI staging/verification still asserts
Compatibility; it has not been represented as a passing Forward+ release path.
Forward+ itself also retains the previously documented color/blending differences
versus Compatibility. This compute work does not claim to fix those differences.

## Capture validation

Separate fixed-fps captures were inspected at idle, play, attack and two battlecry
frames. Attack frame45 and battlecry frame60 are byte-identical CPU/GPU PNGs.
The other three are not pixel-identical; no new visible compute artifact was
observed. A second CPU-only capture has comparable residuals, so screenshot
variation cannot be attributed to compute alone. Strict particle/mesh comparison
is the stronger deterministic check here; entire renderer determinism is not
claimed.

| Frame | CPU/GPU changed pixels | CPU/CPU-repeat changed pixels | CPU/GPU mean absolute byte-channel delta |
|---|---:|---:|---:|
| Idle60 | 21635 | 23464 | 0.01910 |
| Play90 | 19075 | 20502 | 0.02228 |
| Attack45 | 0 | 0 | 0 |
| Battlecry60 | 0 | 0 | 0 |
| Battlecry120 | 13460 | 15087 | 0.01330 |

Each image has 1440000 pixels. Delta scale is 0..255, not normalized. Local capture
paths: `build/renderer-branch/compute-capture-{cpu,gpu,cpu-repeat}`. All capture
runs exit 0 with empty stderr. Final exported raw resource verification again
found 2027 resources, zero missing and zero byte differences, in a source-free
mount check. The final code also re-passed all-source GPU and GL fallback tests.
