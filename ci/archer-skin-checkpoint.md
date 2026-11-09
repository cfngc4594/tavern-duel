# Archer skinning checkpoint

## Environment and scope

Win11 i9-13900HX / RTX 4060 Laptop, Godot 4.7.1 a13da4feb, Forward+ Vulkan, 1600x900, VSync off and the fixed-clock production-game benchmark. Existing develop checkout; main unchanged. GPU resident compute and hidden-geometry skipping remain off. No mobile performance claim or new stable release.

## Corrected profiler attribution

Generic effect profiling missed the Archer subclass's skin setup, post-sample CPU skinning and impact callbacks. New default-off bounded rows cover those operations. Outer totals include nested operations and must not be summed together.

A warm diagnostic impact frame recorded 23.203 ms in Archer advance: 13.722 ms impact dispatch and 9.467 ms across two simulation substeps. Impact itself spent 13.503 ms in the original visual impact path and only about 0.2 ms in damage/completion callbacks. Impact spawn was 7.408 ms, including 3.339 ms skin setup. A later missile sample recorded 6.848 ms skin work versus 0.106 ms generic effect sampling. Mesh clear/add can include render-server/driver costs: these numbers do not establish that all skin time is arithmetic.

## Accepted implementation

Cache per-instance immutable source vectors, float64 weights, integer bone indices and surface-array templates; calculate the common inverse once. Preserve original weighted accumulation and matrix multiplication order. Retain geometry only when serialized bone-matrix bytes are exactly equal, while reapplying material bindings. No approximate pose comparison, reduced geometry, dropped particle, changed simulation, or new preload stage.

Source Resource.changed invalidates templates; replacing the source object reconnects its observer and invalidates. Parsed JSON data is immutable after setup unless its owner explicitly calls invalidate_inputs(). The tests explicitly emit changed after source mutation; this is not a promise that every ArrayMesh mutation API emits it automatically. Baseline execution clears old pose stamps so runtime fallback toggles cannot retain stale geometry. Both cache_inputs and skip_unchanged default to true; benchmark flags --no-archer-skin-inputs and --no-archer-skin-unchanged restore the original path.

## Formal same-pack comparison

Four isolated Release runs in order reference / accepted / accepted / reference. No profiling, captures, tests or builds overlapped timed samples. Same EXE/PCK, resources, resolution, actions and simulation clock. Timings in milliseconds:

| Archer battlecry | Reference forward/reverse | Accepted forward/reverse |
|---|---:|---:|
| Cold mean | 20.19 / 20.44 | 18.47 / 18.23 |
| Cold maximum | 61.34 / 57.50 | 54.35 / 50.29 |
| Warm mean | 21.23 / 21.73 | 19.15 / 19.21 |
| Warm P99 | 39.52 / 40.57 | 36.71 / 36.49 |
| Warm maximum / impact frame | 50.24 / 51.85 | 46.30 / 46.72 |

Warm mean improves about 10–12%, and the worst impact frame about 4–5 ms (8–10%). It is still well above 16.7 ms: this does NOT establish stutter-free 60 fps. Cold maxima vary; all paired results are shown instead of selecting the best run. Unrelated attack/death maximum is 35.84 / 36.99 ms reference and 38.24 / 36.32 ms accepted; no improvement is claimed there.

Full chronological traces and phase outcomes are in archer-skin-results.json. A later fallback-toggle correctness guard only affects explicit runtime switching into the baseline path, not the accepted timed path.

## Rejected candidate

A collision-worker candidate reused the existing guarded randomized-force context, retaining exact integrator/collision/fractional-step order. It passed 3,840 exact cases, including 1,786 actual-collision cases and invalid-input fallback guards. But its standalone warm Archer mean was 20.64 ms versus 20.67 / 21.50 ms references, without repeatable tail evidence. The candidate, its benchmark switches and its temporary test were removed from the project; correctness alone is not a performance result.

## Verification

Focused skin tests compare full surface-array bytes for both real Archer roots and all four cache/skip modes, including repeated and transformed poses, negative scale, explicit input invalidation, source replacement, changed UV data, material bindings, observer cleanup and cached A / baseline B / cached A switching.

Formal runs had empty stderr, eight completed phases each and byte-identical printed action/event traces (including event frame/time). A fresh default-enabled Release export completed all eight phases with empty stderr after the fallback-toggle guard; this overlapped regression work and is not a timing sample.

Nine matching capture times per arm were inspected/compared. Two entire frames are pixel-identical; other frames show small highlight variation, including idle/pre-effect frames. Archer impact frame 120 differs in 13,685 of 1,440,000 pixels, mean absolute channel difference 0.0122 on the 0–255 scale. Visual inspection found matching impact geometry with green selection-highlight variation. Do not claim complete screenshot equality; exact mesh tests establish the scoped numerical equivalence. This is not a full manual gameplay test.

All 36 existing workflow/checkpoint regression scripts passed, and the new skin regression passed on the final implementation (37 total). Its initial runtime-toggle fixture incorrectly saved already-mutated shared bones; correcting unique-node snapshot/restore fixed the test without relaxing byte equality or changing production code.
