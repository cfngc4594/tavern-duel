# v16 — Full-card hovering / staged-placement shadow

Scope: the rectangular/card-frame shadow before the minion appears. The v15 minion oval projection, descent deformation, contact shadow, animation durations, card rules and all art/audio assets are unchanged.

## Evidence and method

Reference: the official 2013 Priest-versus-Hunter excerpt, 02:17.500–02:21.500. The readable input is the 960×540, 30 fps derivative recovered from the earlier comparison. The full-resolution master was not recovered; the official endpoint returned 401 previously and was not bypassed.

The original, v15 and v16 were inspected at +1.20, 1.50, 1.80, 2.00, 2.30, 2.60 and 2.80 seconds. Stable held-card frames (+1.50, +1.80) and full-face staged frames (+2.30, +2.60, +2.80) drive geometry calibration. The source and reproduction move/transform at visibly different intermediate times around +1.20/+2.00, so those differences were not compensated with a false static shadow displacement.

All source measurements use the same full-frame 960×540 scale. Shadow darkening is measured against each renderer’s own pre-action board, in a fixed unobscured shadow region. Card/cursor/hero occlusion is excluded. A visible-region centroid is not a complete silhouette centroid or an overall image-fidelity score. Edge-width estimates include source compression/resampling and are not claimed as measurements of the unavailable original shader.

## Changes

- Retained the actual card-frame alpha silhouette; it is not an oval or a video-pixel decal.
- Applied a height-dependent oblique table projection: approximately 0.91 vertical scale while held, 0.84 during the higher full-face stage; moved the projected footprint down and slightly right.
- Applied live in-plane rotation before projection, with projected roll reduced on the board. Motion-driven shear follows the real card spring velocity and decays when it stops; no persistent lean is applied to every held frame.
- Changed the full-card penumbra from only outward dilation to symmetric inward/outward layers, preserving a full-opacity interior. This widens the edge transition without a large hard rectangular core.
- Reduced board-card opacity from 0.245 to 0.240. Unit opacity and geometry did not change.

## Local pixel measurements

At +2.60 s, the shadow crown is y287 (reference), y263 (v15), y286 (v16). Visible-shadow centroid is (385.55, 343.20) in the reference and (386.48, 343.13) in v16; the corresponding v15 error is approximately 12.5 pixels. Edge 10–90% width is approximately 6.02 (reference), 2.8 (v15), 5.89 (v16) pixels. Interior luminance darkening is 19.83% in the reference and 19.93% in v16.

At +1.50 s, the shadow crown is y301 in the reference, y290 in v15, and y302 in v16; the visible centroid differs from reference by less than 0.8 pixels. At +1.80 s, v16’s crown remains approximately 2 pixels high and visible centroid differs by approximately 1.4 pixels. A 1–2 pixel lateral boundary bias and crown-hump shape differences remain; source resolution and occlusion limit further claims.

## Actual rendering and reproducibility

The final game code was rendered in Godot 4.6.3 Compatibility on the cloud X11 desktop with Mesa llvmpipe. tests/v16_held_shadow_recording.gd uses the existing live input/gameplay fixture, with additional held-phase screenshots. It records 120 excerpt frames after 60 warmup frames at 30 fps. The cursor stays parked outside the hand after release. The source cursor is untouched.

All six event dictionaries equal the v15 diagnostic recording, including reveal 2.900 s, contact 3.400 s, settlement 3.800 s. Only full-card shadow rendering changed in production. Unit projection/drawing functions remain byte-identical to v15.

The delivered silent comparison shows both entire viewports at 960×540, then identical 320×220 regions enlarged 2×. It runs 4 seconds normally, then the same 4 seconds at quarter speed. Original later Coin occlusion remains visible. No reconstructed shadow pixels, generated reference frames, or frame substitutions were used.

## Limits

This corrects a specific pre-minion shadow mismatch. Earlier card trajectory, card art/frame/text layout, blue transformation effects, background repairs, and other scene details still differ. The original 2013 geometry/light/effect shaders remain unavailable. There is no overall 1:1 claim.
