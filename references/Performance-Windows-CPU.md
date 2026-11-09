# Windows CPU performance: measured findings

## Scope

Measurements below use Windows 11, i9-13900HX, RTX 4060 Laptop GPU (NVIDIA 592.82), Godot 4.7.1 official Release, GL Compatibility, a hidden offscreen 1600×900 window, vsync disabled, unlimited FPS, and Dummy audio. Desktop layout is used, not forced phone layout.

The intended Windows deliverable is x86_64 using GL Compatibility. These are Windows measurements, not Android performance conclusions.

The game visual clock is fixed at 1/60 while rendering remains real. Each full run includes loading/warmup followed by two rounds of idle (120 frames), playing Senjin, attacking a taunt minion, and an Archer battlecry (180 frames per action). Normal animations and timed action calls remain enabled. Tables report the second, warmed round. These diagnostic frame times are not a guarantee of user-visible FPS with vsync enabled.

## Locating the baseline cost

An isolated copy of the current base scripts was instrumented, not a subclass that could disable solver fast paths. Sampling one complete frame in every 16 gave these **ranking measurements**, including instrumentation overhead:

- Warm idle: `_process` 6.621 ms, including transmission synchronization 4.243 ms; `_draw_world` 3.717 ms. Its unit drawing, mana and decks contributed about 1.597, 0.924 and 0.624 ms respectively.
- Warm attack: `_process` 13.034 ms, including transmission 4.010, combat effects 3.887 and death synchronization 2.179 ms. Summon particles were not the main attack cost.
- Warm battlecry: `_process` 18.106 ms, including summon 5.790, combat 4.056, transmission 3.686 and death synchronization 1.875 ms.

Parent totals include their children: **do not add these overlapping buckets**. The idle baseline remained substantial when no summon particles were active.

A separate 120-frame idle transmission probe sampled seven frames and isolated the dominant cost:

| Transmission bucket | Accumulated µs | ms per sampled frame |
| --- | ---: | ---: |
| Total synchronization | 30,304 | 4.329 |
| All material work, outer calls | 26,476 | 3.782 |
| BaseMaterial storage-property copying | 18,509 | 2.644 |
| Metadata and render priority | 3,347 | 0.478 |
| Geometry excluding material work | 2,998 | 0.428 |
| Shader uniform polling/comparison/update | 2,159 | 0.308 |
| Geometry property synchronization | 1,055 | 0.151 |
| Shader record setup | 392 | 0.056 |

BaseMaterial, uniform and metadata costs are inside material totals; geometry properties are inside geometry totals. Nine `StandardMaterial3D` instances accounted for the expensive BaseMaterial copying. There were 43 unique materials and 75 mirrored geometries.

The two opaque card shaders comprised 13 materials with 31 uniforms each, or 403 uniform reads per sampled frame. However, **all shader uniform work combined was only 0.308 ms**. This evidence prioritized BaseMaterial copying rather than an opaque-shader shortcut.

### GPU versus CPU boundary

Independent warm-idle viewport timing medians (render-side CPU / GPU, ms) were approximately root 0.970 / 0.822, board 0.505 / 0.924, spatial objects 0.442 / 0.758, transmission target 0.344 / 0.360. These are per-viewport measurements, not total frame costs, and must not be summed: nesting, pipeline overlap and delayed timing results can overlap. Disabled capture viewports can retain old timing values; those were excluded.

In particular, transmission's approximately 4.2 ms **GDScript synchronization** was distinct from its approximately 0.36 ms viewport GPU median. This supported optimizing CPU work without removing the transmission pass or changing visual quality.

## BaseMaterial storage synchronization change

The candidate caches the storage-property names and retains the last **source** values, polling current values and assigning target properties only when they change. It must continue observing direct external setters. It does not use target values as the source cache: the transmission target deliberately overrides shading, emission and albedo. Property-list changes and scripted-material fallback are covered by the implementation/tests; unreliable material `changed` notifications are not used to suppress value reads.

Validation before graphical testing:

- 450 strict regression comparisons passed after the final target-script fallback guard was added (449 passed before that boundary case), including external mutations and transmission overrides.
- The pre-existing transmission synchronization/cache regression also passed.
- A nine-material, same-process alternating headless synthetic measurement reported about 3.825 → 0.481 ms. This measures that isolated workload, **not** a game frame or FPS.

### Actual same-PCK Release A/B

Reference and optimized runs used the **same PCK**. Only reference set `base_storage_cache_enabled=false` immediately after constructing the transmission object, before setup. Other game and particle behavior remained unchanged. This PCK does **not** contain the later unit-shadow candidate.

#### Order A: reference → optimized

| Warm phase | Reference mean / P95 / P99 (ms) | Optimized mean / P95 / P99 (ms) | Mean reduction |
| --- | --- | --- | --- |
| Idle | 13.984 / 14.726 / 15.031 | 11.185 / 11.713 / 12.237 | 2.799 ms / 20.01% |
| Play Senjin | 15.115 / 18.890 / 24.460 | 12.527 / 15.935 / 22.034 | 2.588 ms / 17.12% |
| Attack taunt | 19.798 / 26.346 / 49.012 | 16.461 / 22.241 / 42.204 | 3.337 ms / 16.85% |
| Archer battlecry | 27.581 / 35.689 / 50.427 | 24.091 / 32.711 / 49.514 | 3.490 ms / 12.65% |

#### Order B: optimized → reference

Columns still show reference first to make comparisons consistent.

| Warm phase | Reference mean / P95 / P99 (ms) | Optimized mean / P95 / P99 (ms) | Mean reduction |
| --- | --- | --- | --- |
| Idle | 14.094 / 14.720 / 14.979 | 11.133 / 11.619 / 11.867 | 2.961 ms / 21.01% |
| Play Senjin | 15.291 / 18.861 / 25.142 | 12.633 / 16.186 / 22.816 | 2.658 ms / 17.38% |
| Attack taunt | 19.468 / 25.363 / 43.785 | 17.190 / 22.724 / 41.760 | 2.278 ms / 11.70% |
| Archer battlecry | 26.554 / 35.407 / 48.603 | 24.187 / 32.584 / 48.738 | 2.367 ms / 8.91% |

Both orders establish a meaningful improvement in this scene. They do not establish universal stability: reverse-order battlecry P99 slightly worsened (48.603 → 48.738 ms). Attack/battlecry still exceed the 16.67 ms frame budget, especially in tail frames. **Stable 60 FPS has not been achieved or demonstrated.**

### Behavior and artifact checks

All four processes exited 0 with empty stderr. Every phase matched reference health, hand count, unit count, busy state and median draw calls. Each round's 17-event sequence included actual summon, attack contact and battlecry damage in the same order; no actions were removed by Release assertion stripping.

The exported PCK was independently mounted from a directory without source-resource fallback. All **2026 raw runtime files** matched source bytes; missing 0, different 0. Same-PCK SHA256:

`835E5A9B36FF505D52A612D6938F9D54B6C10BEB55B4A51DEF975605D827E804`

Local ignored evidence resides in `build/release-bench-bin/`:

- `transprofile-full.log/.err`: transmission component ranking and material inventory.
- `idleprofile-full.log/.err`: process/draw and viewport rankings.
- `base-reference.log/.err`, `base-optimized.log/.err`: order A.
- `base-reverse-optimized.log/.err`, `base-reverse-reference.log/.err`: order B.

## Rejected directions

- **Small summon draw snapshot:** only about 1.63% improvement in the longer synthetic check; insufficient evidence to retain extra code.
- **Typed summon state:** synthetic improvement did not translate to the full Release scene. Warm battlecry mean was 26.357 → 26.723 ms; first-round improvement was only 0.461 ms / 1.73%. It failed the practical retention threshold and was rejected without extending the experiment.
- **Direct Mobile/Vulkan renderer switch:** startup and action/state validation passed, but actual screenshots failed visual equivalence. The scene became gray, cards/minions darkened, battlecry glow/masking changed, and the hero-damage effect showed extra rectangular artifacts. The same visual PCK and deterministic action frame sequence were used. No performance conclusion justifies that visible change, and the production renderer was not switched.

The next optimization should target measured CPU work while preserving visuals. These findings do not justify lowering quality, removing effects, skipping animation, or claiming Android device validation.

## Unit-shadow geometry reuse, with BaseMaterial optimization retained

A second candidate reuses the exact settled unit-shadow meshes instead of reconstructing their layered ellipse geometry each draw. The fast path is restricted to the supported settled shape/scale/lift; other poses keep the original path. BaseMaterial optimization stays enabled in both arms. Reference changes **only** `unit_shadow_mesh_enabled=false`.

Before full-scene measurements, the geometry/eligibility test passed for 12 meshes. Forty real OpenGL comparison scenes, including the production premultiplied path, had **zero byte differences** between reference and candidate screenshots. The existing desktop draw-cache regression (1011 shape cases plus 130 style cases) also passed. These controlled pixel tests are distinct from a claim that every possible gameplay scene was exhaustively tested.

### Order A: unit reference → unit optimized

| Warm phase | Base-only mean / P95 / P99 (ms) | Base + unit mean / P95 / P99 (ms) | Incremental mean reduction |
| --- | --- | --- | --- |
| Idle | 10.982 / 11.649 / 12.212 | 9.382 / 10.019 / 10.216 | 1.600 ms / 14.57% |
| Play Senjin | 12.256 / 15.322 / 21.698 | 10.516 / 13.711 / 19.336 | 1.741 ms / 14.20% |
| Attack taunt | 16.403 / 22.330 / 40.981 | 14.608 / 21.067 / 40.936 | 1.795 ms / 10.94% |
| Archer battlecry | 23.847 / 31.424 / 47.670 | 21.967 / 30.048 / 47.901 | 1.881 ms / 7.89% |

### Order B: unit optimized → unit reference

| Warm phase | Base-only mean / P95 / P99 (ms) | Base + unit mean / P95 / P99 (ms) | Incremental mean reduction |
| --- | --- | --- | --- |
| Idle | 11.080 / 11.763 / 11.911 | 9.433 / 9.973 / 10.116 | 1.647 ms / 14.87% |
| Play Senjin | 12.658 / 16.514 / 23.682 | 10.701 / 13.934 / 20.517 | 1.957 ms / 15.46% |
| Attack taunt | 17.087 / 23.602 / 41.820 | 14.486 / 20.428 / 40.594 | 2.601 ms / 15.22% |
| Archer battlecry | 24.203 / 32.904 / 48.883 | 22.010 / 30.094 / 47.549 | 2.193 ms / 9.06% |

The combined optimized state measured idle around 9.4 ms, playing around 10.5–10.7 ms, attack around 14.5–14.6 ms, and battlecry around 22 ms. These are the observed combined results, not sums of independently measured speedups. Battlecry still exceeds the frame budget; attack P95/P99 also remain above it. Order A's battlecry P99 slightly worsened. **Do not claim stable 60 FPS or elimination of first-use hitches.**

Both orders used the same exported PCK, with all 2026 raw files byte-verified. All four processes exited 0 with empty stderr. Eight phase records per run matched health, hand/unit counts, busy state and draw-call medians; both round event sequences matched. No geometry/effect was skipped to obtain the improvement.

Unit A/B PCK SHA256:
`D6465FEFEF36C0F998B97FF52C5826E3472F4706CC5CD5D7A158403081A1A17B`

Local evidence: `build/release-bench-bin/unit-reference.log/.err`, `unit-optimized.log/.err`, `unit-reverse-optimized.log/.err`, and `unit-reverse-reference.log/.err`. These are isolated diagnostic exports, not a separate user-facing release.
