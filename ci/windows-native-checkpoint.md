# Windows native-profiler and whole-scene checkpoint

## Decision

The highlighter readback-deferral candidate remains **disabled by default**.
It improves aggregate frame cost, but does not consistently improve the user's
first/warm battlecry and reset/recovery hitch tails. It is not a shipped stutter
fix. The earlier combat seek-context experiment also remains disabled.
No particle, mesh, shader, resolution, source timing or visual-quality reduction
was used. Main, phone testing and published releases are unchanged.

Latest remote develop `1f2e9f4` was merged in place with the existing local
benchmark work, preserved first in `a0a061f`, then merged in `a35eccb`. No worktree
or project copy was used. The two pre-existing shader import edits were never
staged or changed (their before/after SHA256 values are in the result JSON).

## Real renderer and privacy scope

Godot 4.7.1 official `a13da4feb`, Windows 11, i9-13900HX, RTX 4060 Laptop,
Forward+ Vulkan, 1600x900, VSync disabled, Dummy audio, fixed 1/60 visual clock.
Each graphics process ran on a separately created desktop without calling
SwitchDesktop; the user's active desktop stayed Default before/after every run.
The feature-gated black mask stayed active, and production scenes stayed visible
and processing beneath it. The mask can affect culling/overdraw and adds work:
these are **privacy-mode measurements**, not unobstructed visible-game FPS.

The harmless preflight passed three opaque-black pixel checks including resize
and popup coverage. The first ordinary exec attempt to create a private desktop
returned OS access denied before a process started; the normal authorized
execution route succeeded. There was no visible-desktop fallback or security
setting change. Headless imports initially encountered an editor-settings safe
save error; the same authorized route imported cleanly without changing settings.

## Native attribution, separate from formal timing

`tests/native_profiler_receiver.gd` uses Godot's loopback TCP remote-debug protocol
and captures real `servers`/`visual` profiler frames, function signatures and the
final accumulated profile. It explicitly enables native-call inclusion. Merely
passing `--profiling` was not treated as native function evidence.

The first graphical capture overflowed the engine's default 256 timestamp slots
and is rejected as a clean timing baseline. An editor-feature-only override raises
capacity to 4096 before RenderingDevice initialization. Exported Release was
verified to remain non-editor/non-debug with capacity 256. The clean capture has
2,386 server frames, 2,384 Visual Profiler frames, a final total, zero hard errors
and 185 separately classified warnings. Captures are instrumented attribution,
never formal performance measurements. Receipt-order phase assignment and GPU
latency mean boundaries are approximate.
The override applies to every run using the editor binary, even without the
`--editor` flag; it does not apply to standard exported templates.

Warm normal battlecry has zero pipeline compilation deltas but still has long
frames. First-use battlecry has canvas +1, draw +4, specialization +8, surface +7.
These are counts, not compilation durations or proof of synchronous stalls.
The enclosing same-frame Render Viewports begin/end spans have GPU means
5.985/6.258 ms and P95 8.901/9.327 ms for first/warm normal battlecry. These are
matched spans, not sums of per-viewport percentiles.

Native wrapper self-time can include inherited work: source timers confirm
Archer `super_sample` dominates skin work. Warm frame 113 has 68.860 ms wall,
59.064 ms game, including combat 25.737, summon 15.186, transmission 5.417,
death sync 3.729 and highlight sync 3.167 ms. Warm frame 89 has 50.093 ms wall
and summon 31.895 ms; its 28.662 ms particle timer is nested, not additional.

### The ~600 ms reset hitch has a concrete different cause

In every formal setup/reset, the worst frame is sample index 1, with production
game processing around 576–621 ms; the synchronous action call is only 33–52 ms.
The clean native startup/reset frames show board advance 662.556/661.165 ms:

`original_board_bridge.advance` -> `_build_probe` -> `board_probe._ready` ->
`board_probe.build_scene`.

The bridge waits two ready-cache host frames before constructing the probe
synchronously. Same-frame native costs include 97 JSON parses ~304 ms,
97 string-file reads ~68 ms and 16 PNG decodes ~108 ms. They are contained in
the build/material totals and must not be added again. Native signatures can be
aggregated under the last script context; they do not prove every parse originated
in that one named script. The next hitch-specific investigation should target
this repeated board build and immutable source/resource work, not assume the
steady-state highlighter candidate fixes it.

## Formal Release ABBA

Same EXE/PCK, serial reference/candidate/candidate/reference, no profiler, capture,
build, test or download overlap. Both normal first/warm rounds and full-board
survivor/lethal cases repeated three times per case are included. Each run has
30 complete phases and 5,640 frames, including setup and recovery. All processes
exited 0 with clean logs. Environment, gameplay state, event order and relative
event timings match. The PCK hash remained:

`818BB6D42FC9B2442DCF8073673AFC27110CCDF63D373ECEC2BF456F2ED6BCA3`

Godot's exported command-line API reported empty engine-argument arrays in these
runs. The same literal launch command in one serial loop, plus runtime renderer,
size and VSync observations, establishes the shared configuration. Do not treat
empty arrays as full proof of consumed engine flags. Subsequent harness logging
also records effective frame limit, time scale and physics rate. This reporting
addition does not alter the measured candidate logic or its default-off decision.

Pooled full-phase reference -> candidate:

- Mean: 25.050 -> 21.147 ms (-15.58%).
- P95: 43.393 -> 36.633 ms; P99: 120.276 -> 116.180 ms.
- Maximum: 633.354 -> 627.309 ms.
- Frames over 16.667 ms: 67.29% -> 45.11%; over 33.333 ms: 15.03% -> 6.47%.

Mean improvement is reproduced in both directions (-15.16% and -16.00%), but
pooling must not conceal regressions:

- First-use normal Archer P99 increases in both pairs: 36.727 -> 37.548 and
  36.539 -> 36.960 ms.
- Reverse warm Archer P99 increases 35.353 -> 37.434 ms, and mean increases 0.21%.
- Pooled startup maximum increases 615.365 -> 627.309 ms; reset P99 increases
  101.833 -> 106.068 ms.
- Warm Archer recovery P99/maximum increase 26.796/27.762 -> 29.126/31.814 ms.
- Stress setup and recovery contain further regressions retained in the JSON.
  All six pooled stress actions improve P95/P99/max, but forward lethal repeat 2
  P99 increases 46.904 -> 51.627 ms. A pooled win does not erase that result.

## Candidate correctness and pixels

Only native unscripted ArrayMesh surfaces with a valid vertex count may defer
array retrieval until after the existing signature test. No persistent geometry
cache is introduced. Unknown/scripted/primitive meshes retain eager reads.
Transforms, routes, visibility and attachments are rebuilt each refresh. The
existing same-RID geometry signature behavior is preserved, not repaired.

Focused CPU regression checks default-off behavior, exact selected geometry,
changed transforms/planes/resources, visibility, empty surfaces, route blockers,
scripted/primitive fallback and external attachment anchors.
The separate real RTX/Forward+ pixel test passes nine phases x ten actual
production GPU passes byte-for-byte. It rejects empty/all-black pass false
success, checks changed content after changes, stable content for fast hits,
render completion and a black root throughout. This is fixture GPU parity,
not a claim of whole-game screenshot identity or performance.

Twelve relevant headless scripts pass. Opening-highlight reports exit 0 and
`OPENING_HIGHLIGHT_FAILURES=0`; it predates the runner's `_PASS` naming convention
and was independently checked after that runner rejected its marker. Enabled
privacy-guard checks also pass. Python validation includes 11 export/policy tests,
6 log-verifier tests and 4 native-profiler decoder tests. The ABBA analyzer also
has 9 persistent tests for raw statistics, pooled samples, event timing, corrupted
logs and mismatched engine arguments. Receiver checks accept explicit CPU-only
completion and reject early shutdown or missing requested Visual Profiler frames.
Export/import, Release smoke and graphics checks
pass. Headless checks are not phone/device performance evidence.

## Reproduction

Use the existing checkout, pinned Godot and `Windows Privacy Benchmark` export.
`ci/run_windows_isolated.ps1` is an optional authorized Windows privacy launcher;
it never switches desktops. Do not substitute a visible unprotected window.
Reference/candidate flags are `--no-defer-highlight-arrays` and
`--defer-highlight-arrays`, with `--battlecry-stress=3` for the formal workload.
Use the same exported pack for all arms.

Run `tests/verify_renderer_benchmark.py` for individual logs and
`ci/analyze_windows_abba.py R1 C1 C2 R2 --output results.json` for comparisons.
For native attribution, start the headless receiver, launch the debug target with
`--remote-debug tcp://127.0.0.1:6019` and user flags
`--privacy-guard-test --native-profiler --profile-sources --profile-pipelines`.
Keep both processes alive in the same launch scope. Capture and timing runs must
remain separate. The analyzers retain raw evidence and caveats.

`windows-native-results.json` retains formal raw samples, all comparison results,
clean native summaries, GPU parity hashes, log hashes and validation metadata.
The large raw native packet streams remain under ignored local build output.
