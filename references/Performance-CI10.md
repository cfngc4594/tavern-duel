# CI10: avoid rebuilding unrelated board geometry for mana

This is a small, measured, visually unchanged CPU optimization, not a claim that
Android stutter has been solved. No Android device was attached (`adb devices -l`
was empty); no phone installation or data changes were performed.

## Kept change

Mana synchronization used `Layout.recovered_items(0, 0, options)` twice per frame,
then discarded everything except `friendly_mana`. That rebuilt the entire board's
hero/play/end-turn geometry and hit polygons unnecessarily.

The original mana calculation is now a `recovered_mana_items(options)` helper.
The complete layout also calls this same helper. No cross-frame state cache,
animation changes, reduced effects, particle counts, or resolution changes.

On the same Windows graphical phone-layout practice probe (Godot 4.7.1,
1600x900, 7 cards and 4 minions), sequential before/after samples:

- Mana synchronization P50: 1.698 -> 1.377 ms; P95: 1.810 -> 1.476 ms.
- All spatial synchronization P50: 2.793 -> 2.457 ms.
- Draw calls: P50 351 and P95 353 in both runs.
- Frame interval P50: 17.478 -> 16.963 ms. This single-run desktop observation
  is noisy and must not be interpreted as a phone FPS guarantee.

180 parameter combinations matched the previous full layout exactly. The
committed regression compares the mana-only helper against complete layout
across aspects, permanent/temporary counts and tray states.

Reproduce the isolated layout work comparison (not total mana or frame time):

    godot --headless --path . --script tests/mana_layout_cpu_benchmark.gd

The alternating 240-sample helper benchmark measured mean 221.38 -> 83.50 us per call (P50 217.7 -> 81.6 us), with equality checked outside timing.

## Rejected experiments

- Conservative particle screen-size projection bound: exact output tests passed,
  but CPU time worsened (10.78 -> 11.44 ms). Fully reverted.
- Additional transmission geometry/property caches: same-process improvement
  only about 0.06 ms (~1.8%), not worth the added state/cache complexity. Reverted.
  Useful dynamic BaseMaterial and geometry regression coverage was retained.

- Avoiding particle-array replacement until expiry: exact state/mesh tests passed,
  but only 11.121 -> 11.039 ms (~0.74%) aggregate improvement. Reverted.

## Validation boundary

The CI regression suite now includes the seven existing mana/layout tests, plus
expanded transmission material/property tests. Actual-device frame timing,
CPU/GPU attribution and thermal behavior still need the user's phone model,
reproducible lag scenario, a USB-debugging connection, and permission to install
or launch a test build. Windows improvements cannot establish that a phone is
now smooth.
