# Residual Archer hitch: bounded investigation

This pass adds diagnostic coverage only, not another claimed performance gain. The last verified optimization remains the skinning checkpoint: warm maximum about 46–47 ms, not stutter-free 60 fps.

## Evidence

Same Win11, Godot 4.7.1, Forward+ Vulkan, 1600x900 fixed-clock Release scenario. `--profile-sources` additionally records bounded `SKIN_SETUP_PROFILE` rows. All eight phases completed and stderr was empty. Instrumented timings are attribution evidence, NOT a new uninstrumented A/B result.

Warm impact skin setup was 4.446 ms for the two original skinned meshes (70 and 12 vertices). Its components:

- JSON file reads: 0.344 + 0.164 ms.
- JSON parsing: 0.415 + 0.119 ms.
- Source mesh / instance setup: 0.037 + 0.021 ms.
- Materials: 0.097 + 0.088 ms.
- Bone/bind setup: 0.022 + 0.020 ms.
- First skin including cache preparation, weighted vertices and mesh upload: 3.002 ms.

The first-skin cost cannot all be removed: final visible geometry still has to be prepared. Caching file reads/parsing alone has only about a 1 ms gross ceiling here, before copying/invalidation overhead. No new global data cache was added on that evidence.

The preceding complete frame profiler found the warm impact CPU work was composed of visual initialization plus two event-boundary substeps, alongside summon particles, transmission, highlights and UI work. Damage/completion callbacks were only about 0.2 ms. Do not blame game rules or a single GPU upload for the entire remaining hitch.

## Investigated but not implemented

Deferring intermediate-substep particle geometry can theoretically avoid some overwritten vertices/uploads while retaining full simulation. However RTT collection calls seek again with a changed capture camera, captures read surfaces/material bindings, child emitters seek separately, and effects can be destroyed before a final substep. Full schedules, RNG, collision, clamp counts, trail history and cleanup must remain unchanged. The scope is substantially wider than skipping one function call; the measured numerical worker work cannot be skipped. The earlier source-level profile suggests only roughly 1–2 ms geometry-side headroom per relevant source, not the entire two-substep duration.

No such change, reduced visual quality, asynchronous event delay, extra resource pool, software installation or security change was made. Larger alternatives such as prepared scene/resource pools or native/GPU skinning require separate implementation and equivalence work; they are possibilities, not proven wins.

## Decision

Stop this bounded pass rather than retain speculative changes or repeat unsuccessful worker strategies. Keep the tested performance implementation and the new default-off diagnostic hook for future targeted work. This does not assert that the project cannot be optimized further.

Validation of this diagnostic-only change: exact skin-cache regression, Archer rule/lifecycle/cancellation regression, and battlecry release-sequence regression passed on Godot 4.7.1. The eight-phase profiled Release run had byte-identical printed action/event traces to the preceding default-enabled smoke run. The full 37-test suite belongs to the preceding implementation checkpoint; it was not rerun for this instrumentation-only pass.
