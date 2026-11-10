# Board source bundle: measured checkpoint, not a shipped hitch fix

## Decision

The board source bundle remains **OFF by default**. Only Windows
`renderer_benchmark` exports contain it. Normal Windows and Android releases do
not acquire its 49,700,372-byte payload. The earlier highlight/readback and
combat seek-context candidates remain off too. No image format, dimensions,
mipmaps, particle count, shader, resolution, gameplay clock or bridge timing was
reduced or changed.

The candidate cuts repeated board rebuild peaks substantially, but first/warm
combat and recovery tails do not improve consistently. This is a validated
experiment and a better diagnostic baseline, not a claim that stutter is fixed.
The next major startup target is synchronous `game._ready`, separately identified
below. The original two shader `.import` edits were preserved and not staged.
No stash, reset, worktree or project copy was used locally.

## What changed

The build-time compiler records exact Godot-parsed JSON Variants and original
PNG-decoded bytes for the desktop board dependency closure: 102 JSON documents,
19 images, and 34,586,624 image bytes. This includes later pumpkin mesh swaps.
Each probe still owns its mutable data, nodes, ArrayMesh, ShaderMaterial and
ImageTexture objects. Reads deep-copy JSON and create fresh Image objects.
Nothing compiles during gameplay; Android and phone boards retain the raw path.

An exported bundle is a closed source generation with version, dependency
hashes, byte digest, entry counts and validated image layout. Missing or invalid
bundles safely use the original path. Explicit `clear_cache()` invalidates future
probes; existing probes retain their own snapshot. Source/editor tests explicitly
select a freshly compiled bundle. There is no unverified persistent editor cache.

Export compiles from current source, never a checked-in blob. Both automatic file
export and the raw-asset scan exclude any stale file at the generated bundle path.
A deliberate stale-file collision test passed against the actual exported PCK.
The compiler logs errors on failure; export gates must reject ERROR/SCRIPT ERROR,
require the success marker for benchmark builds, and verify the pack. An export
process exit code alone is insufficient.

## Measurement

Godot 4.7.1 official Release, Windows, RTX 4060 Laptop GPU, Vulkan Forward+,
1600x900, uncapped, VSync off, Dummy audio. Four separate processes ran serially
in R,C,C,R order from one identical PCK. No capture, source profiling, build or
parallel test overlapped timed runs. Every run had 30 measured phases and 5,640
phase frames: normal first/warm Archer actions plus three repetitions each of
full-board survivor/lethal actions, including every setup and recovery.

The original privacy guard stayed opaque black in an independent, never-switched
Windows desktop. All active-desktop before/after checks remained Default.
These are **privacy-mask measurements**, not unobstructed visible-game FPS:
the mask can change culling/overdraw and adds work.

The new BOOT_LOAD trace starts before game construction and includes synchronous
add_child/_ready and all initial-loading frames. Constructor, add_child and total
loading times are separately recorded. External process sampling covers launch
to exit and Windows memory counters at approximately 250 ms intervals.
Both candidate runs loaded one generation once, served 873 JSON and 144 image
reads across nine board constructions, and had no raw reads, misses or errors.
All subsequent phase audits are checked, not merely startup. Game states, event
order and relative event timing were identical across all four runs.

## Results and acceptance limits

All values below are milliseconds. Detailed phase metrics, both paired directions,
threshold counts, memory summaries, pixel hashes and provenance are in
[windows-board-bundle-results.json](windows-board-bundle-results.json).

- First measured start-match settle maximum: reference 603–628, candidate 381–392.
- Regular warm reset maximum: reference 593–623, candidate 228–238. Pooled maximum
  reduction is 61.75%; all eight measured setup/reset maxima improve both ways.
- Complete initial load plus start-match settle: 9,715.693→8,454.214 in the forward
  pair and 8,811.861→8,536.903 in the reverse pair. No observed simple transfer of
  removed reset work into an earlier unmeasured loading section.
- However, `startup_settle` is **after** a first board build inside BOOT_LOAD.
  The actual first board-load interval (sample 273) remains 743.592–749.888 for
  the candidate versus 747.787–792.446 reference. Cold board loading is not fixed.
- Boot alone is mixed: 6,414.683→5,865.970, but 5,750.578→5,802.356 in the reverse
  pair. The ~2.6-second first interval remains in both arms.
- Phase-only aggregate mean: 24.989→24.546 (-1.77%); P99 117.709→120.659 (+2.51%).
  Phase-only maximum drops 637.273→392.013. Including boot, the worst interval
  is essentially unchanged: 2,679.584→2,672.271. Do not report 392 ms as the whole
  application's new maximum.
- Warm Archer maximum regresses in both directions: 41.434→44.600 and
  41.118→44.665. First/warm Archer means, warm Senjin mean/P95/P99/max, first
  Archer recovery P99/max, and some stress tails also regress both ways.

These regressions are retained, not hidden behind the reset improvement. They
justify keeping the candidate disabled. Their precise cause has not been proved.

## Memory

The payload's serialized size is not its decoded heap usage. Release static
allocation tracking is unavailable, so zero values are explicitly unavailable.

- Observed peak working set: reference 1,409–1,549 MiB; candidate 1,494–1,512 MiB.
- Observed peak process commit: reference 3,407–3,499 MiB; candidate 3,276–3,508 MiB.
- All runs share maximum sampled nodes 13,771 and final recovery 13,357. Repeated
  survivor/lethal setups settle to the same 13,419/13,358 nodes in either arm.
- Resources grow in both arms: 390→420/421 reference and 390→421/422 candidate,
  largely leveling near 419–422. The final recovery GPU-memory monitor snapshot
  reaches the same ~712.4 MiB plateau. Within-phase raw samples peak at
  1,479.455–1,479.458 MiB; endpoint/plateau values are not peaks, and this Godot
  allocation monitor is not a guarantee of physical VRAM residency.
- Private memory grows/fluctuates in both arms, with late elevated periods in B2
  and A2. This is not evidence of a candidate-specific leak or memory-free caching.
  Final process samples are teardown, not gameplay. OS/engine time alignment is
  approximate; sampling can miss short private-memory peaks and the last interval.

This finite test does not prove absence of all leaks. Full chronological traces
and process samples remain in ignored build output rather than being committed.

## Correctness and privacy verification

- 283 bundle checks: exact JSON/PNG content, malformed layouts, corruption,
  schema, missing data, source changes and explicit invalidation.
- 120 isolation checks: all 97 initial JSON and 16 image reads replaced, exact
  mesh arrays/material/texture data, independent mutable resources, six new-match
  lifecycles with stable node counts.
- RTX GPU parity: 98 states across two full board lifecycles. Actual 1600x900 board
  pixels match byte-for-byte, with nonblack content and root-black checks. Door,
  lamp, arch, water, kite, pumpkins, flowers and particles were exercised through
  source controllers; repeated-cycle hashes matched. This is the port's board
  fixture, not a claim of original-client or whole-game screenshot equivalence.
- Original PNG regression: 18 images. Phone lighting: 541 checks, plus phone
  environment-particle and layout headless tests. No phone was connected or run.
- Python analyzer/verifier: 23 tests. Renderer/export policy: 11 tests.
- Real privacy preflight: black pixels, popup and resize checks passed again.
- Actual benchmark pack verified from an empty fixture without source fallback,
  including freshness despite a deliberately stale local generated file.

## Remaining startup bottleneck

The new Release trace shows add_child/_ready takes 2,551.807–2,677.229 ms;
construction itself takes only 56–68 microseconds. The earlier clean native Godot
capture already contains this startup, so no extra recording was required to
identify the split: engine frame 0 wall 4,118.493 ms, game._ready inclusive
3,761.688 ms, load_source_dictionary 22 calls /988.249 ms, _load_portraits
692.066 ms, combat_assets.setup 669.739 ms, decode_dag 10 calls /553.407 ms.
These are nested, instrumented Debug measurements: **do not add them or compare
them directly with Release timings**. Source inspection confirms synchronous
portrait/effect setup in game._ready and dictionary DAG reconstruction.
The manifest loader already caches by normalized path: 22 calls do not prove
22 disk loads. The capture lacks path arguments. First access still validates
source/cache hashes and reconstructs/freezes the DAG. Portrait setup obtains
Images from imported Texture2D resources, converts/copies, applies the existing
circle mask and creates textures; there is no explicit resize or raw PNG decoder
in this function. Future changes must preserve validation and exact pixels.
Per-path startup timing should distinguish cache hits, I/O and decoding first.

A separate possible board follow-up is to compile 72 static mesh PackedArray
inputs rather than retain raw mesh Variant trees. Their public channels/indices
are structurally about 986 KB versus 6.39 MB source JSON and ~81,565 leaf arrays.
This is not a RAM or speed measurement. Earlier _build_mesh self time was only
~26 ms; its ~94–97 ms inclusive time contains JSON work already replaced here.
It cannot be claimed to remove the remaining 238 ms or fix combat regressions.

## Reproduction and evidence boundaries

Use the Windows Privacy Benchmark preset and ci/run_windows_isolated.ps1. Add
`--battlecry-stress=3 --no-defer-highlight-arrays`, varying only
`--no-board-source-bundle` versus `--board-source-bundle`. Analyze R,C,C,R with
`ci/analyze_windows_abba.py --candidate-field board_source_bundle --output ...`.
Raw logs are named reference-a1, candidate-b1, candidate-b2 and reference-a2 under
ignored build/board_source. The JSON report records their hashes and the exact
measured executable/PCK identities. No PCK, EXE, generated bundle, image dump or
video is committed. Export gating was narrowed to benchmark-only after these
measurements; tested runtime behavior did not change. Normal-release exclusion
is additionally enforced by ci/verify_windows_pack.gd and the Windows CI gate.
