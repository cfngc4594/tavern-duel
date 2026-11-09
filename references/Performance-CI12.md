# CI12: per-seek summon color gradient snapshot

This builds on CI11 without changing particle count, simulation timestep, source
curves, interpolation or color space. The existing particle_color_sampler and
particle_gradient_sampler already used by other migrated particle systems are
prepared once per summon seek, rather than rebuilding gradient keys for each
particle. There is no cross-frame cache. Runtime data edits are observed on the
next seek. Empty particle arrays skip preparation, and GDScript subclasses retain
the original callback path.

## Why this change

An instrumented CI11 fixed-step battlecry window found summon color sampling
accounted for 644ms across 180 frames, versus summon state integration 730ms.
The mesh upload itself was only 27ms; the remaining work was not evidence of a
GPU upload bottleneck. Per-particle instrumentation has overhead, so those
figures were used to locate work, not to advertise total-frame performance.

## Exact correctness

`tests/summon_color_snapshot_test.gd` compares the new color path with the original
sampler while keeping CI11 constant integration enabled on both sides:
- All 16 source emitters: exact particle dictionaries, RNG and all mesh channels.
- 2610 scalar color cases covering modes 0-4, empty/single/repeated keys, boundary
  samples and hold interpolation.
- Runtime raw edits, three seeds, and subclass fallback.

Final local test duration: 23.32 seconds. Same-process alternating synthetic
all-emitter test: 136.38 -> 100.43ms per aggregate seek (-26.4%). This simultaneous
16-source stress case is not an actual game frame.

## Real graphical comparison

Win11 i9-13900HX / RTX4060 Laptop, Godot 4.7.1 OpenGL Compatibility, 1600x900,
Dummy audio, VSync disabled, fixed main visual timestep 1/60. Compare the warm
second round, the same 180 frames / 3 simulated seconds. Constant integration
remains enabled on both sides; only the color snapshot flag differs.

| Battlecry metric | CI11 color path | Color snapshot |
|---|---:|---:|
| Wall frame P50 | 32.142ms | 30.019ms |
| P95 | 48.946ms | 42.584ms |
| P99 | 71.903ms | 59.797ms |
| Frames >33.33ms | 43.33% | 36.11% |

Both action traces occur on identical frames/times. Draw P50/P95 remain 422/446.
Rules and health assertions pass. Both windows still contain one active summon
tail at the end. This is the same bounded workload, not proof that all effects
have ended. The measured conditions are diagnostic, not a guarantee of smooth
performance in every game situation. Long frames remain.

Reproduce (graphical, separate processes, same machine/resolution):

    godot --path . --resolution 1600x900 --audio-driver Dummy --script tests/windows_summon_graphics_benchmark.gd -- --color-reference
    godot --path . --resolution 1600x900 --audio-driver Dummy --script tests/windows_summon_graphics_benchmark.gd

Headless exact test:

    godot --headless --path . --script tests/summon_color_snapshot_test.gd

## Rejected shortcut

A functional probe of this Godot version found ShaderMaterial.changed does NOT
fire for set_shader_parameter, null resets, textures, priority or next_pass.
Therefore a transmission dirty-cache based only on that signal would miss live
changes. It was rejected without modifying production code.

Final local validation: all 27 workflow regressions passed, exit 0, no ERROR. The color test remained below the per-test 120-second CI limit.
