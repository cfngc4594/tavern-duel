# CI13: final bounded per-seek size-sampling optimization

This is the final small-cache experiment in this profiling pass. Its advance
acceptance threshold was roughly 1ms or 3% of the entire fixed battlecry window,
not a flattering isolated subroutine percentage. It passed in both run orders.

SizeModule now uses the existing particle_size_sampler once per seek, not once
per particle. This preserves unweighted Hermite arithmetic and source endpoints.
Weighted, nonfinite and unsupported cases use the original sampler. No cross-frame
reuse is attempted: the helper's setup is not designed for repeated initialization.
Subclasses retain the original callback path; particle counts, timestep, RNG,
colors, materials and all other effects are unchanged.

## Exact tests

`tests/summon_size_snapshot_test.gd`: all 16 source emitters, exact particle
state/RNG/all mesh arrays, 1305 scalar size cases (modes 0-4, empty/single/repeated
keys, holds, weighted fallbacks and boundaries), runtime edits, three seeds,
partial steps/rewind and subclass fallback. Local duration: 20.36 seconds.

Synthetic all-source fixed-step A/B: aggregate 99.97 -> 87.98ms (-12%). This is
not an actual game frame and was not the acceptance criterion.

## Fixed graphical workload, both orders

Win11 i9-13900HX / RTX4060 Laptop, Godot 4.7.1 OpenGL Compatibility, 1600x900,
Dummy audio, VSync off, fixed main visual step 1/60. Both constant integration and
color snapshots are enabled in both variants. Compare second/warm rounds of the
same 180 frames / 3 simulated seconds.

| Run order | CI12 reference mean | Size snapshot mean | Improvement |
|---|---:|---:|---:|
| Reference then optimized | 31.673ms | 30.599ms | 1.075ms / 3.39% |
| Optimized then reference | 31.706ms | 30.278ms | 1.428ms / 4.50% |

Reverse-order P50: 29.977 -> 28.725ms; P95: 43.080 -> 40.780ms;
P99: 59.518 -> 58.040ms. These are diagnostic runs, not a formal confidence interval.

Both pairs have identical action event frames/times, health/rule results and draw
P50/P95 of 422/446. Both windows end with one active summon tail; neither variant
is being credited for omitting the tail. Initial resource/driver cache costs are
not explained away by these warm-run measurements.

Reproduce in each order (graphical):

    godot --path . --resolution 1600x900 --audio-driver Dummy --script tests/windows_summon_graphics_benchmark.gd -- --size-reference
    godot --path . --resolution 1600x900 --audio-driver Dummy --script tests/windows_summon_graphics_benchmark.gd

Strict headless regression:

    godot --headless --path . --script tests/summon_size_snapshot_test.gd

## Stop condition and remaining work

This pass does not establish stable 60fps. Battlecry long frames remain near
58ms P99 in this scene. Further small curve caches have a low demonstrated upside:
most integration already follows the constant path. The remaining work includes
GDScript per-particle loops, dictionary/vector operations and mesh assembly.

Before any broader rewrite, profile billboard preparation, packed-array assembly,
integration and mesh submission separately on the current version. A possible
next experiment is an optional emitter-wide native mesh batch that preserves
existing RNG/curves/integration/materials, with the old implementation as fallback.
Count packing and boundary overhead in the benchmark and compare all output
arrays. Windows has a C++ compiler available; Android NDK/build integration is
not currently present. No native extension or new toolchain has been installed
or implemented by this change, and Android performance has not been measured.

Final local validation: all 28 workflow regressions passed (exit 0, no ERROR); git diff --check passed.
