# CI8 performance work (2026-11-09)

This is a Windows CPU/rendering investigation, **not Android device verification**.
ADB reported no attached devices. Host: Intel i9-13900HX, RTX 4060 Laptop;
Godot 4.7.1, OpenGL compatibility, source phone layout enabled.

## Changes

- Reuse source phone geometry and projected hit polygons while their inputs are
  unchanged. Invalidate for unit count, insertion gap, mana/tray animation, turn,
  aspect/viewport/offset and camera movement. Camera shake still reprojects.
- For eligible environmental particle batches of 1–128, use the existing numeric
  kernel in place instead of repeating module work (small batches) or copying
  dictionaries and dispatching/joining worker threads (larger batches). Empty
  batches return immediately; >128 retains the existing threaded path.
- No particle count, timestep, seed, texture, animation or render-resolution reduction.

## Reproducible measurements

`godot --headless --path . --script tests/phone_cpu_benchmark.gd`
prints per-stage CPU microbenchmarks, not FPS. Empty hand/board is intentional:
it isolates the always-running environment and layout cost.

Same machine, 200 samples after 10 warmup calls:

| Stage | Before mean | After mean |
|---|---:|---:|
| Layout refresh | 1.93 ms | 0.36 ms |
| Unchanged projection | 0.53 ms | 0.003 ms |

`godot --headless --path . --script tests/phone_particle_batch_test.gd`
compiles a reference with the prior dispatch branch and alternates old/new calls
in one process. Eight real phone environment emitters, fixed seeds, 120 warmup
frames then 240 measured frames at dt=1/60:

- Combined old seek: **15.90 ms/frame**; new: **11.80 ms/frame** (25.8% less CPU).
- Checks counts/RNG/numeric state and exact output mesh arrays every 15 frames,
  plus rewind, stop tails, empty batches and a 160-particle threaded fallback.
- Individual timings vary with load; the threshold is not claimed optimal on all phones.

## Rendering evidence and remaining limits

A real Win11 phone-mode practice scene at 1600x900, seven hand cards and four
minions recorded 351–352 draw calls and ~53k primitives. There are three main
render targets: scenery (72 draw calls), scene (136), RGB transmission (136).
The transmission pass cannot simply be disabled: both hero power shadows use
colored multiply even at idle and the pass also provides opaque occlusion.
A single measured transmission GPU pass was ~0.65 ms on the RTX 4060, not total
frame GPU time. Do not extrapolate these numbers to mobile hardware.

`phone_layout_cache_test.gd` compares fresh source geometry and projection against
cached output through rule changes, animated tray, resize and shake. Existing
interaction/animation tests and environment activation/tail tests remain CI gates.
Actual phone CPU/GPU/thermal profiling is still required to judge the remaining
bottleneck and the user's perceived improvement.
## Same-script desktop rendering recheck

One before/after particle-optimization run, identical phone-mode scene and probe,
120 frames each (both already include the layout cache): frame interval P50
28.844 -> 22.164 ms; P95 31.434 -> 23.618 ms. Median draw calls stayed 351.
This is a single desktop sample, not a fixed-CI7 comparison or Android FPS claim.
