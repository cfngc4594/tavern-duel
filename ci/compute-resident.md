# GPU-resident BlueRays checkpoint (develop)

## Result and scope

The earlier synchronous readback prototype was not a useful real-time design.
This experiment uses the official global RenderingDevice path: persistent GPU
state, render-thread dispatch, and Texture2DRD consumed directly by a vertex
shader. There is **no submit/sync or CPU readback in the runtime path**. Validation
has a separate, explicit readback helper; timed runs never call it.

Only the real, visible BlueRays source
`cab-69c88b234dfa427e02d1fcee9337ae34:6590410617251757833` is migrated. CPU retains
original RNG/emission, size/color curves, camera basis, billboard rotation and
small display parameters. GPU retains full-step integration checkpoints, computes
the fractional display position and exposes render attributes in a float texture.
A fixed indexed quad mesh reads that data. This is not a claim that all particle
work or all of TavernDuel now runs on GPU.

The feature remains **off by default** and benchmark-only opt-in with
`--gpu-resident`. CPU fallback remains for unsupported renderer, source signature,
capacity/lifetime limits and initialization/upload failure. No main merge or
stable release is implied. Existing Forward+ versus Compatibility color/blend
differences remain a separate issue.

## Formal Windows Release measurements

Godot 4.7.1 official Release, Forward+ Vulkan, RTX 4060 Laptop / i9-13900HX,
1600x900, VSync off, same exported EXE/PCK and deterministic game clock.
CPU / resident / resident / CPU run order, two rounds per run. Warm second rounds:

| Phase | CPU / resident mean ms, first pair | CPU / resident mean ms, reverse pair |
|---|---:|---:|
| Idle | 9.29 / 10.42 | 9.93 / 9.16 |
| Senjin play | 9.62 / 10.17 | 9.88 / 9.82 |
| Taunt attack | 14.18 / 14.73 | 14.68 / 14.33 |
| Archer battlecry | **21.02 / 19.02** | **21.24 / 19.98** |

The migrated source is used in battlecry, not the other three phases. Differences
outside that phase are variance, not compute benefits. Battlecry improvement is
about **2.00 ms (9.5%) and 1.26 ms (5.9%)**. P95 changes 30.71 -> 28.25 ms and
31.98 -> 31.34 ms. P99 remains roughly 57 ms: **this is not yet stutter-free or a
stable 60 fps result**. Do not compare absolute times with older runs from a
different machine-load/clock state; use the paired controls here.

Worst frames do not improve: warm maxima are 60.27/60.82 ms on CPU versus
68.19/66.44 ms resident; first-round battlecry maxima are 91.80/93.02 ms CPU
versus 97.85/98.12 ms resident. This checkpoint is not a stable-release upgrade.

All four timed runs exit 0, with empty stderr, identical action traces and phase
outcomes. Captures, readback tests and regression tests were excluded from timed
runs. CPU display preparation/upload scheduling still costs 121.1/122.2 ms over
the 180-frame warm battlecry phase (122 resident updates). It uploads 19200 bytes
of spawn state once and 1952000 bytes of display attributes over that phase,
plus small global parameters. Further opportunities remain in those CPU curves
and parameter packing.

A separate `--resident-profile-gpu` run collects global RD timestamp pairs,
without CPU synchronization. Its warm phase captured 85 pairs totaling 1.986 ms
(about 23.4 microseconds per captured dispatch interval). This is a **sampled
subset**, not all 122 updates or a whole-frame GPU total. Engine frame-query
latency/lifecycle means not every update is observed. Timestamp instrumentation
is excluded from the paired frame-time runs. Four viewport CPU/GPU counters are
also logged; asynchronous viewport percentiles must not be summed as one frame.

Measured PCK SHA256:
`48B2FF1AEC57C822E5DEAB2F7CC316037F311CD2877591D6EDD0A23ED3A9E5C7`.
Structured measurements: `ci/compute-resident-results.json`.
Ignored raw logs: `build/renderer-branch/resident-final-*`.

## Correctness and visual validation

- 29225 live-particle comparisons across three seeds, forward time and rewind:
  full-step clocks, velocities and displacements exactly match CPU. World centers,
  reconstructed quad vertices and original RGBA8 mesh colors exactly match.
- Stop, visibility, GPU -> CPU -> GPU transition, forced GPU failure fallback,
  conservative bounds containment and cancellation immediately after setup are
  exercised. CPU fallback reconstructs from the original birth state, not stale
  GPU-side checkpoints.
- Dedicated render regression compares static isolated CPU/GPU images at times
  0.4 and 1.0: both are byte-identical. This catches material mistakes that numeric
  tests alone cannot see.
- Final actual game capture at battlecry frame60 (the migrated source is visible)
  and attack frame45 are byte-identical. Other captures retain the already-known
  small run-to-run rendering variation, including phases without resident work;
  no claim of deterministic full-game rendering is made.
- Source-free exported PCK verification checked 2028 raw resources, including both
  GLSL files: zero missing and zero byte differences.
- All 33 existing CPU regressions pass when rerun. Compatibility with resident requested
  uses the exact CPU fallback, not a fake GPU pass.

Three real discrepancies were found and fixed rather than accepted as quality
loss: native GPU float sqrt rounding, the original ArrayMesh RGBA8 truncation,
and ShaderMaterial parameter reflection. FP64 sqrt then float32 narrowing matches
the CPU on the tested GPU. COLOR is quantized exactly as the original mesh.

Cloning a ShaderMaterial and changing its shader caused the original unhinted
vec4 `_TintColor` cache to revert to its default. Godot's material property-list
reflection checks Variant types; legacy assets supply Color to that vec4. The
new path snapshots parameters before reflection, constructs an independent
ShaderMaterial and restores the effective parameters. Color-to-Vector4 conversion
preserves Forward+'s implicit Color sRGB-to-linear upload. This is not an added
brightness adjustment. Independent static render hashes match exactly after the
fix. FP64 and bit equality are verified on this device, not promised universally.

The fixed quad mesh uses conservative dynamic bounds for culling/sorting instead
of a permanent origin-centered box. Pixel validation is still necessary because
matching state alone does not validate transparent draw order or material upload.

## Reproduce

```text
godot --path . --rendering-method forward_plus --rendering-driver vulkan --script tests/summon_resident_test.gd
godot --path . --rendering-method forward_plus --rendering-driver vulkan --script tests/summon_resident_render_test.gd
godot --path . --rendering-method gl_compatibility --script tests/summon_resident_test.gd -- --expect-fallback
godot --headless --path . --export-release "Windows Renderer Benchmark" build/renderer-branch/ResidentBenchmark.exe
ResidentBenchmark.exe --rendering-method forward_plus --rendering-driver vulkan --resolution 1600x900 --audio-driver Dummy
ResidentBenchmark.exe --rendering-method forward_plus --rendering-driver vulkan --resolution 1600x900 --audio-driver Dummy -- --gpu-resident
```

Use a separate fixed-fps capture run as documented in the renderer report. The
existing main-only CI still assumes Compatibility; this direct local export is
not represented as passing that separate Forward+-incompatible release pipeline.
No source copies, worktrees, security changes or new software installations were
used.

## Separate finding, not included in the A/B change

The previously examined EdgeMotes `:7435642337723423872` reaches 399 live particles
in Archer's scene but its renderer/mesh stay hidden. The original implementation
still simulates and builds its mesh. That is a separate potential CPU optimization,
not proof that every previous compute dispatch was hidden, and was deliberately
not mixed into this comparison. BlueRays is visibly rendered through frame118 of
the audited Archer sequence; its later hidden state is preserved.
