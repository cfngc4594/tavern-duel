# Held-card cyan contour v17

## Source and scope

The source is the preserved 960×540, 30 fps derivative of the official 2013 Priest-versus-Hunter excerpt at 02:17.500–02:21.500. The full master is not present. Its previously checked official press-kit endpoint returned HTTP 401; no access restriction was bypassed.

Compare the held card at excerpt +1.50 and +1.80 seconds and committed blue-face phases +2.30, +2.60 and +2.80 seconds. These actual pixels, rather than the current replacement frame's alpha silhouette alone, define this correction.

## Observed problem

The source's lifted card has a cyan/blue upper-and-side lip. Its mana corner is interrupted by the cost medallion and its lower sides dim into the attack/health badges. v16 reused both its affordable-hand 2D green bloom and the spatial green readiness mesh. That produced a wide, fully enclosed green shape even while dragging.

## Implementation

- Suppress both affordable-green draw sources while the card is held, while preserving affordable resting/hovered/returned hand states.
- Draw a separate, traced upper contour with tighter corners, narrower crown, blue penumbra, cyan body and nonuniform pale inner highlight. Per-vertex opacity fades near the mana medallion and lower sides.
- Use a distinct lower path following the stat medallion/drop silhouettes. It is barely lit while held and continuously brightens after release into the committed blue face; the same shape fades out during the remaining shell stage.
- The selected face has a small presentation-only width/height/position/roll correction to align with the source. Both the actual spatial face and 2D rim use that pose. Physical card position, hand spring, gameplay hit testing and the independently calibrated v16 ground projection are not edited.
- Non-minion held cards use a flat-topped contour without the minion crown or stat-badge outline.
- All default card data and all bundled original art/audio files are unchanged.

## Local pixel observations

At 960×540 and +1.80 seconds, the original bright vertical lip peaks lie at x466/x536, crown y254 and right shoulder y260. v17 matches those particular positions. v16's green lip peaks were x462/x541, crown y248 and right shoulder y254. At +1.50 seconds, v17 crown is y254 versus source y256, and right shoulder y260 versus source y261.

The rendered median bright-lip hue is approximately 183–187° in v17 versus 188–189° in the source, compared with roughly 93–95° green in v16. Codec, underlying art, white-core mixing and frame selection affect these local color readings. No global image-fidelity score is claimed.

Eight actual GUI checkpoints have identical pixels to v16 in the shared unobscured ground-shadow ROI [533,470,700,625] at 1600×900. Exact normalized input/summon event dictionaries match v16, including reveal 2.900s, contact 3.400s and settlement 3.800s. Eight shadow/hand production function bodies remain byte-identical to the shipped v16 code.

## Boundaries

This is a focused contour/state correction. It is not the original client's shader or mesh export. The source frame/font/art proportions, especially cost and attack/health badges, still differ. Interior transformation lighting/particles, earlier motion and other scene details remain approximations. A pointwise match at one held frame does not imply identical animation or strict overall 1:1.
