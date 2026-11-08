# v15 landing-shadow calibration

## Reference and limits

Blizzard's official BlizzCon 2013 Priest vs Hunter clip, 02:17.500–02:21.500. The original public press-kit URL is https://blizzard.gamespress.com/BlizzCon-2013-Hearthstone-Press-Kit . It returned HTTP 401 in this pass; no restriction was bypassed. The previous v14 comparison was recovered from the user's existing Library and its untouched left viewport supplied a 4-second, 960×540, 30fps derivative of the original footage. This is not a freshly retrieved 1280×720 master. Compression and one-frame input inference limit precision.

## Observed behavior and implementation

- While held over the board, the card casts a recognizable lower-left silhouette with a narrow soft edge. In v14, the held-card shadow pointed down-right and the staged-card shadow used a fixed offset. v15 transitions from the existing hand lighting into the board projection and carries the source height across release.
- During the cyan full-card hold, the projected shadow follows the card's live location, angle, scale and increasing height.
- At oval reveal, the rectangular shadow ends. The visible minion owns the only ground projection; the dissolving blue shell casts no duplicate dark shadow. The ownership test covers every staged phase and hidden minions.
- The raised minion has a compact vertical oval shadow, separated substantially to the lower left. The source shadow stays left through early descent, narrows on its short axis and turns before contracting into contact. A nonlinear projected-height curve models this separately from the visible body's unchanged drop animation.
- At zero lift, the shadow returns to a close offset, a tighter penumbra and slightly greater opacity. Ordinary attack recoil retains a linear projection and does not inherit the summon-only narrowing/turn.

The flat core uses 12 low-alpha silhouette layers with normalized total opacity, rather than a large fuzzy blob. This is a screen-space model fitted to observed footage, not recovered original shadow meshes or shaders. No card rules, art, sounds, summon duration, body drop trajectory or impact particles were changed.

## Matched-frame measurement

All three images are at the same full-frame 960×540 scale. At excerpt +3.10s (source 02:20.60), a fixed board region x320–453/y270–390 is compared with each renderer's own pre-drop background. The largest connected component with 8–40% luminance decrease isolates the raised shadow from unrelated UI changes. Bounds below are threshold footprints, not exact physical object boundaries.

- Original: 66×77px footprint; weighted centroid (377.43,336.64); median luminance decrease 19.5%.
- v14 fresh baseline: 83×81px footprint; centroid (408.12,323.87); decrease 12.7%.
- v15 final: 63×77px footprint; centroid (380.98,334.07); decrease 20.1%.

This demonstrates a specific improvement in footprint, direction and darkness. It is not a whole-screen similarity metric or a claim that all remaining animation/UI mismatches are resolved. In particular, the original cyan effect, body details and Coin-hover timing still differ visibly.

## Verification artifacts

The delivered comparison uses the complete reference viewport and complete final Godot viewport at equal scale. Normal speed is followed by half speed. The clip is silent so it serves only the requested visual comparison; all 74 source audio files are separately SHA256-verified unchanged.

The reference fixture runs live game hover, drag, release, mana payment, summon and sleep checks. The separate diagnostic keeps the pointer parked after release to expose descent/contact without the Coin-hover occlusion; it is not substituted into the synchronized comparison. A natural full-match GUI driver runs the unchanged default practice game at normal engine speed and reaches a terminal outcome without editing health/mana/decks/boards after initialization.

Strict 1:1 remains unachieved. See FIDELITY-GAPS-V14.md for missing original 2013 assets and remaining broader differences.
