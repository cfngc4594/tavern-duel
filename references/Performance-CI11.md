# Windows runtime profiling and CI11

The user clarified the target: smooth **Win11 native desktop** gameplay, not a
claim about phone performance. Tests use the user's i9-13900HX / RTX 4060 Laptop,
Godot 4.7.1 OpenGL Compatibility, 1600x900. Diagnostic windows are offscreen,
VSync disabled, unlimited FPS and Dummy audio. This isolates rendering/CPU work;
it is not a subjective user playtest or a guarantee for every display/device.

## Evidence before this change

Native desktop is materially different from forced phone layout. The idle desktop
board had no active ambient particle instances; the earlier PHONE eight-emitter
benchmarks must not be presented as desktop environmental costs.

A first run, excluding initial loading and 180 warmup frames, found:

| Scene | P50 ms | P95 ms | P99 ms |
|---|---:|---:|---:|
| Idle | 17.115 | 17.825 | 18.265 |
| Play Senjin | 17.525 | 25.734 | 472.228 |
| Attack taunt | 21.046 | 53.182 | 611.929 |
| Archer battlecry | 28.081 | 71.604 | 874.287 |

Each action was its first use in that process. Counts include synchronous action
calls. Subsequent runs had warmer caches and much smaller worst spikes, so those
cold-versus-warm numbers cannot be attributed to a code optimization. No driver
cache was cleared. Resource miss instrumentation found 20-40ms of first texture
load work per action, but the hot battlecry still had substantial lag. Manifest
and route JSON were already loaded during setup. Shader compilation was a
hypothesis, not a proven explanation for the initial hundreds-of-ms spikes.

Corrected dynamic instrumentation identified hot battlecry costs, averaged over
180 frames: summon particle seek 8.834ms, combat particle seek 4.816ms,
transmission 4.335ms, status 1.771ms, spatial sync 0.810ms. Nested method times
must not be summed. An earlier instrumentation attempt using inherited particle
scripts disabled their base-script optimization guards and was explicitly rejected.

## Desktop draw work

Repeated 2D world drawing cost about 6ms, including repeated fixed hand shadow
triangulation. Changes preserve layer count, order, exact float32 vertices,
triangle indices, colors and transforms:

- Cache the fixed card surface base; multiply by the live factor per call.
- Cache up to 64 immutable StyleBox resources by full style parameters.
- Use five retained ArrayMeshes only for exact `lift == 0` hand shadows.
- Nonzero lift (including tiny nonzero values) uses the original polygon path.
  The general dynamic mesh-cache experiment was rejected because its misses cost
  more than the original path.

Same-process, alternating real world draw calls on identical frozen inputs:
static P50 **5.946 -> 4.169ms**. All cards changing lift: **5.970 -> 5.986ms**,
within noise. These are draw-command CPU costs, not total frame times.

40 graphical comparisons (default canvas and production premultiplied shader,
static/dynamic/mixed hover states) had **zero differing image bytes**. The
headless regression tests 1011 scale factors, caller-array isolation, 130 styles,
cache bounds, mesh vertices/indices and exact-zero branch behavior.

Manual pixel regression requires a graphical renderer:

    godot --path . --script tests/desktop_hand_shadow_pixel_test.gd

Headless geometry/cache regression:

    godot --headless --path . --script tests/desktop_draw_cache_test.gd

## Constant summon integration

The BlueRays emitter was spending most of its particle work re-reading constant
velocity, speed, limit and rotation modules at every 1/120-second step. The new
path recognizes only constant and random-between-constants signatures per seek.
Each particle retains its original random mix; every full integration step and
its arithmetic order are preserved. Fractional steps use the original integrator.
Unsupported curves, separate-axis limits, nonzero drag, rotation-by-speed and
subclass overrides retain the original path. Rewind and live parameter changes
are checked. No particles, curves, effects or time steps are removed.

All 16 source emitters were compared using identical seeds/times, exact particle
dictionaries, RNG state and every mesh-array channel. The longer alternating
1/60 pressure benchmark measured the BlueRays source at 10.690 -> 6.853ms/seek
(-35.9%). All 16 high-count sources together were 201.21 -> 169.16ms; this is a
synthetic simultaneous stress case, not the actual game's frame time.

A graphical fixed-main-visual-step comparison used the same 180 frames / 3
simulated seconds for the warm battlecry. Events happened on identical frames
and times, and draw P50/P95 stayed 422/446:

| Metric | Original integration | Constant path |
|---|---:|---:|
| Wall frame P50 | 34.936ms | 32.188ms |
| P95 | 54.481ms | 52.525ms |
| P99 | 79.578ms | 79.023ms |
| Frames >33.33ms | 61.67% | 44.44% |
| Frames >50ms | 18.33% | 9.44% |

Both windows end with one remaining summon tail; this is the same bounded
workload, not a claim all effects have expired. Rules/action assertions pass.
The actual variable-delta run had a different simulation-time window after the
optimization, so its percentile changes are not treated as equal-work evidence.

Reproduction, separate graphical processes, same resolution/driver, compare the
second round (VSync off and unlimited FPS are set by the diagnostic):

    godot --path . --resolution 1600x900 --audio-driver Dummy --script tests/windows_summon_graphics_benchmark.gd -- --reference
    godot --path . --resolution 1600x900 --audio-driver Dummy --script tests/windows_summon_graphics_benchmark.gd

Add `--real-delta` after `--` for a normal-variable-delta observation. The benchmark
writes only its own temporary instrumented scripts under `user://`; it requires
a source checkout and never modifies production source files.

Strict correctness and optional longer synthetic benchmark:

    godot --headless --path . --script tests/summon_constant_step_test.gd
    godot --headless --path . --script tests/summon_constant_step_test.gd -- --benchmark

## Remaining limit

Windows battlecry long frames are **not eliminated**. P99 still approaches 80ms
in this fixed-step scene. Further work should isolate remaining particle/color/
mesh and combat costs, plus first-use stalls. No claim of universally smooth
Windows or Android behavior is supported by this stage.

Final local validation: all 26 workflow regressions passed, including the default
summon test within its 120-second per-test limit. The self-contained graphical
benchmark also completed both action rounds with exit 0 and no errors; its second
warm battlecry P50 was 33.58ms in that separate validation run. This is additional
proof of remaining stutter, not a paired before/after measurement.
