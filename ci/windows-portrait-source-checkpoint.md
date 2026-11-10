# Windows portrait-source startup checkpoint

## Decision

Keep `PortraitSourceImages.enabled = false`. This experiment preserves pixels,
but did not demonstrate a stable reduction in complete startup or whole-scene
hitch tails. It is **not a shipped stutter fix**. Board-bundle, highlight-array
and combat seek-context experiments also remain off. No UI architecture,
particle/mesh count, image resolution, shader quality or effect timing changed.

These measurements concern the current **Windows desktop UI**. The phone uses
the distinct source-phone UI; desktop results do not establish Android visual
equivalence or performance. This checkpoint does not resolve that UI difference.

## What the cold-start diagnostic found

A separate real Forward+ editor/debug diagnostic, all candidates off, measured
54 unique portrait sources across 58 slots. The portrait span was 535.711 ms:

| Observed CPU/wall operation | Sum across unique portraits |
| --- | ---: |
| Imported texture load | 251.962 ms |
| Circular mask | 180.862 ms |
| `get_image` | 47.097 ms |
| Existence checks | 19.510 ms |
| RGBA8 conversion | 18.401 ms |
| Raw/cropped texture creation | 7.503 ms |
| Image duplicate | 0.207 ms |

GPU readback alone is not the dominant observed portrait cost. Per-ID timing
and metadata are opt-in with `--startup-timing`; logging is deferred until all
portraits are processed. Disabled instrumentation performs no diagnostic clocks,
cache queries or per-ID metadata allocation.

The same diagnostic observed `_ready` at 3,522.270 ms, effect setup at
1,782.492 ms, and source-manifest loads at 852.138 ms. Of 23 manifest requests,
12 were uncached and 11 cached. Ten DAG decodes totaled 407.234 ms; 20 streamed
hash operations totaled 306.897 ms. These are **nested debug spans**, not costs
that can be added together or substituted for Release measurements. Existing
source integrity checks were retained.

## Candidate and fidelity

The optional Windows-only path decodes existing raw PNG/WebP files into CPU
Images instead of temporarily loading an imported Texture2D and reading it back.
It is pinned to the reviewed Godot 4.7.1 engine/importer. A separate export step
compares all approved decoded images with actual imported images, including
alpha-edge processing, native format, dimensions and exact bytes.

Runtime checks source size/SHA256, decoded-image SHA256, dimensions and format.
Source-tree runs also check the importer configuration. Unsupported, missing,
changed or corrupt inputs fall back to the original texture path. No persistent
image/texture cache is introduced. Texture creation, RGBA conversion, masking,
slot order, per-ID aliasing, missing placeholders and owner-local textures remain
unchanged. The exported candidate needs no source `.import` files.

The verified policy contains 54 entries and is 20,835 bytes. The existing raw
assets total 9,929,457 bytes and were already in the pack. Only benchmark exports
receive the policy; normal Windows/Android releases do not receive an additional
image bundle or the policy. Both export paths exclude a stale policy at its
generated path. Normal Windows pack verification asserts policy absence and
default-off state. Small implementation bytecode is not claimed to have zero size.

## Validation

- 5,351 source correctness checks: all production native/raw/cropped bytes,
  58 slots/54 IDs, three WebP fallbacks, real alpha edges, non-square inputs,
  unsupported format, missing/repeated slots, independent textures, corrupt
  policies/sources and failed/closed/short-read I/O.
- Existing portrait instrumentation regression: 2,337 checks.
- Real RTX 4060 Forward+ GPU atlas parity: two fresh loader lifecycles, all 116
  raw/cropped slots, 1600x900, exact full-frame bytes with no tolerance. Each
  atlas had 733,118 pixels differing from its background, while the root window
  stayed opaque black. This is portrait-render parity, not whole-game parity.
- Actual exported PCK mounted in an empty fixture: all 54 source images matched
  the packed imported baseline exactly. No source-tree fallback.
- 11 ABBA analyzer tests, 10 benchmark verifier tests and 11 renderer/export
  policy tests. Phase timestamps now validate durations, continuity, finite
  nonnegative values, section ordering and boot boundaries.
- Formal standalone runs reject external source-policy overrides and startup
  diagnostic timing. Policy load/hit counters must be complete at boot and stay
  identical through all later phases, so costs cannot be silently deferred.

## Complete Release comparison

Godot 4.7.1 `a13da4feb`, Win11, i9-13900HX, RTX 4060 Laptop, Vulkan Forward+,
1600x900, VSync off, Dummy audio. Runs used never-switched isolated desktops and
the privacy mask. The mask can change culling/overdraw; these are not unobstructed
visible-game FPS. The scenario uses its existing fixed 1/60 visual clock while
measuring actual wall-clock frame intervals. Cold means a fresh process, **not**
cleared OS/driver caches. Thermal/background conditions were not independently
controlled. No other owned builds, capture or Godot tests overlapped.

One immutable EXE/PCK was used in R,C,C,R order from 11:11:49 to 11:21:56 UTC on
2026-11-10. Each process completed 30 phases, 5,640 phase frames plus 346 boot
intervals, including two normal rounds and three full-board survivor/lethal
repetitions. All four exited 0. Gameplay states, event order and relative event
times matched. Candidate runs served all 54 images once, with zero fallbacks or
errors. Other candidates were off.

| Run | Boot wall | Boot peak | Boot + initial match settle |
| --- | ---: | ---: | ---: |
| Reference A1 | 6,224.205 ms | 2,661.484 ms | 9,511.403 ms |
| Candidate B1 | 5,872.522 ms | 2,609.247 ms | 9,038.122 ms |
| Candidate B2 | 5,747.557 ms | 2,626.282 ms | 8,869.624 ms |
| Reference A2 | 5,842.895 ms | 2,564.191 ms | 8,836.145 ms |

The first pair's startup improvement did not survive the reverse-order
complete-load comparison. The roughly 2.6-second initial spike remains.
Across all measured phase frames, pooled mean was 25.116 -> 25.337 ms (+0.88%),
P95 43.257 -> 43.387 ms (+0.30%), P99 120.205 -> 122.325 ms (+1.76%). Both
pair directions showed worse phase mean and P99. These observations are not
statistical proof of causality, but they do not justify enabling the candidate.

First Archer battlecry max improved 54.210 -> 49.789 ms in one pair but regressed
50.333 -> 52.206 ms in the reverse pair. Warm Archer P99 increased in both pairs
(34.952 -> 35.042 and 35.698 -> 36.294 ms). Reset peaks were mixed
(641.838 -> 599.349, but 592.338 -> 605.208 ms). Pooled phase max alone improved
659.567 -> 622.758 ms; that does not resolve complete startup or repeat hitches.
Full per-phase/repetition results, including regressions, are in the JSON.

## Memory and lifecycle

Peak node count was 13,771 and final measured node count 13,357 in every run.
Resources after boot were 368 in all runs; final counts were 422/423/422/419 in
R,C,C,R order. The sampled Godot video-memory monitor peaked at the same
1,479.455 MiB in all four runs. This is an engine allocation monitor, not a
guarantee about physical VRAM residency. Phase-end snapshots peaked at only
716.994 MiB and must not be substituted for the within-phase peak.

Observed lifetime peak working set was 1,529.043 / 1,422.559 / 1,414.316 /
1,382.340 MiB. Observed peak commit was 3,486.477 / 3,372.594 / 3,361.688 /
3,163.605 MiB. The sequential downward drift prevents attributing these
differences to the candidate. No candidate-specific lifecycle growth is shown;
this is not proof of zero memory cost. OS sampling is every 250 ms and can miss
short peaks/final intervals; teardown samples are not gameplay final memory.

## Reproducibility and exclusions

- EXE SHA256: `04baf75cc1d69dd93eb709533ecab4fd7770bb8a530645717017a06a9d9809fc`.
- PCK SHA256: `9777d89364086966dddef0baa65daeff1afd73770b79295398bfa1525a79435b`.
- Policy SHA256: `daf7237ae73ef1c7035559161efb21c5e0758c39599ba0f2b77feb3b502da590`.
- Common flags: `--audio-driver Dummy --rendering-driver vulkan
  --rendering-method forward_plus --resolution 1600x900 --windowed --single-window
  -- --battlecry-stress=3 --no-board-source-bundle --no-defer-highlight-arrays`.
  Only `--portrait-source-images` / `--no-portrait-source-images` differed.
- `ci/analyze_windows_abba.py ... --candidate-field portrait_source_images`
  validates all four logs. The result JSON includes launches, hashes, sampled
  memory summaries, diagnostic spans and full derived comparisons.
- An initial attempt with a relative log path exited with 0xc0000005 before a
  game/performance log. It is excluded. An absolute-path smoke test succeeded;
  the launcher now resolves log/metrics paths before launch. All four accepted
  runs used absolute paths. No visible-desktop fallback occurred.
- Generated binaries, raw logs and capture images remain ignored under build/.
  Two original shader-import edits and the separate video worker's files remain
  untouched/uncommitted. No stash, reset, worktree or project copy was used.

The next startup target remains the measured manifest/effect setup work, not an
assumed repeated texture upload. Integrity and complete-load accounting must be
preserved in any follow-up. Exact-commit CI is checked separately after push.
