# Win11 long-frame checkpoint

## Conclusion

This checkpoint targets measured long frames, not just average particle time.
A bounded strong cache of **original loaded Shader resources** reduces warm
attack/battlecry tail latency. It preserves the loaded object's `resource_path`;
materials, uniforms, textures, effect state and RNG remain separate. It is enabled
on develop. This is **not** a claim of stutter-free 60 fps: first-use stalls and
warm worst frames above 16.7 ms remain. Main and the existing stable Release are
not changed.

## Formal Release A/B

Godot 4.7.1 official Windows Release, Forward+ Vulkan, RTX 4060 Laptop/i9-13900HX,
1600x900, VSync off, fixed game action clock, same PathBenchmark EXE/PCK. Serial
order: reference, cache, cache, reference. No concurrent benchmarks, compilation
or tests. Profiling switches were off. Both arms used the separate hidden-geometry
candidate; this comparison isolates shader retention, not their combined benefit.
Measured PCK SHA256: C2CE8A01E8E2434285E1EF69DFF3CE32253235D0C6B2772B85723C1EE42969FA.
Warm second rounds (milliseconds):

| Phase/metric | Reference / cache | Reverse reference / cache |
|---|---:|---:|
| Attack mean | 14.43 / 13.93 | 14.26 / 13.95 |
| Attack P99 | **59.78 / 38.10** | **60.61 / 37.60** |
| Attack maximum | **74.93 / 54.02** | **73.58 / 53.05** |
| Battlecry mean | 20.48 / 19.96 | 19.95 / 19.84 |
| Battlecry P99 | **55.80 / 45.80** | **58.82 / 45.77** |
| Battlecry maximum | **61.27 / 49.49** | **61.87 / 49.24** |

All four runs exit 0 with empty stderr. Both complete action traces match exactly
across all runs; phase outcomes also match. Structured frame measurements and
traces are in `ci/long-frame-results.json`. Local raw logs are
`build/renderer-branch/path-final-*.log`.

The mean benefit is small, but the tail benefit is repeatable in both orders.
First-use shader/material initialization remains expensive; retaining resources
cannot remove their first creation. No unmeasured mobile benefit is claimed.

## Evidence chain

Default-off instrumentation records game `_process` stages, individual effect
stages and particle setup stages, only when `--profile-sources` is requested.
These profile runs are separate from the formal A/B.

1. Hidden EdgeMotes has up to 399 live particles. Its summon seek consumes about
   296 ms over a warm battlecry phase, more than visible BlueRays (~271 ms).
2. Skipping hidden **geometry only** saves roughly 3–5% of phase mean, but does
   not solve P99. Emission, RNG, simulation/checkpoints, counts and lifetime remain.
   This candidate stays opt-in (`--skip-hidden-geometry`), not enabled normally.
3. Long-frame stage timing finds warm battlecry combat around 33.5 ms and an
   attack death-sync around 60.5 ms. The initial summon-only particle counter did
   **not** include the separate combat/death particle implementation.
4. Further decomposition finds warm death schedules ~47 ms, separate particle
   sampling ~14 ms; the schedule starts 11 systems including recursive templates.
   Warm Archer capture synchronization consumes ~19 ms in a long frame.
5. Particle setup identifies repeated material creation, e.g. source
   `:1553132337749309241`: warm material creation ~10.62 ms without retention,
   ~0.153 ms with original Shader retention. Runtime material parameters and
   per-instance material creation are unchanged.

A first generated-code-only cache was rejected as the explanation: it saw only
2 creations, about 0.13 ms total and zero cache hits in this scene, with no
repeatable tail improvement. The useful addition is the original-path cache.
The helper retains both limited caches for explicit immutable-resource ownership.
CPU load timers are not a GPU compilation profiler; the measured result is
reduced material-creation and end-to-end frame latency, not an invented GPU
compile-time number.

## Ownership and bounds

`immutable_shader_cache.gd` keeps at most 64 generated-code entries and 64 original
path entries, each LRU. It holds only Shader objects, not Material/Texture objects
or effect nodes. `source_bytes` counts source text, **not GPU memory usage**.
Returned shaders must remain immutable, including default texture parameters.
The current Release assets are fixed; tools replacing files at runtime must clear
the cache or explicitly reload them. Clearing drops only the cache's references
and does not invalidate live materials. The older weak/local caches remain.

The shader cache is now on by default. `--no-retain-shaders` restores the reference
in the benchmark; `--retain-shaders` explicitly enables it. The GPU-resident
BlueRays experiment remains off by default and is not part of these timings.

## Validation and remaining work

- Hidden-geometry regression: 16 sources, local/world modes, 480 exact state
  comparisons, including 176 hidden/live cases; restored visible mesh arrays,
  RNG and lifecycle match. Rewind, stop, source/ancestor hide and renderer switches
  are covered.
- Cache unit and material integration tests exercise exact source/path identity,
  LRU bounds, independent uniforms/metadata and live-material safety after clear.
- All 33 existing CPU regressions pass with the final cache enabled. The new
  integration test checks 9 material pairs, 10 captures and 19 isolated uniforms.
- Actual-game capture attack frame45 and battlecry frame60 are byte-identical.
  Other samples have small previously observed run-to-run variation: mean absolute
  byte-channel differences 0.01494 (battlecry120), 0.02098 (idle60), 0.02229
  (play90). Both battlecry120 frames were visually inspected. This is not a claim
  of deterministic whole-game pixels.

Still outstanding: cold first-use stalls; death-system initialization and repeated
first-frame mesh construction; separate combat/death particle work; possible
preparation during the existing loading stage. None is silently removed or
reordered here. No source copies/worktrees or security changes were made.
