# Release light and particles v18

## Reference and limits

Preserved official 2013 Priest–Hunter excerpt, 02:17.500–02:21.500, recovered 960×540/30 fps derivative. The master remains unavailable; the previously verified official endpoint returned HTTP 401. No access bypass was attempted. This is visual reconstruction without original particle assets or shaders, not a strict overall 1:1 claim.

## Direct frame observations

- f58 / +1.933 s: brief full-card cyan-white flash.
- f59–66 / +1.967–2.200 s: irregular cyan/white surface flecks across face, text and edges, generally 1–4 native pixels. Most remain inside the silhouette, rather than a broad outgoing spray.
- +2.20–2.60 s: flecks soften into a bright frosted card, persisting until f89.
- f90 / +3.000 s: oval revealed abruptly against a nearly-white card-shaped envelope. The shell fades through about +3.20 s.
- +3.133–3.333 s: granular cyan oval ribbon, strongest lower/left.
- +3.30–3.433 s: upper/side white-to-pale-gold lobes, short irregular fragments and small sparks. Lower oval remains saturated cyan.
- From +3.467 s, original Coin hover occludes the lower effect. Visible upper particles fade toward +3.8 s; a complete source lifetime cannot be measured behind the occlusion.

Observed reference card/shell footprint is approximately x432–524,y224–360. Contact corona at +3.4 s is approximately x446–511,y242–318, with small outlying flecks. These are local observations, not an image similarity score.

## Implementation

`scripts/summon_release_fx.gd` is an actual additive CanvasItem layer. A deterministic absolute-age sampler builds irregular quads with short lifetimes, narrow edge drift, uneven rim ribbons and bounded warm-white perimeter lobes. The face uses a cold light modulation while preserving legible dark text/art. Reveal uses a bright card-shaped envelope with a portrait hole, instead of the former faint original-art crossfade. Its interior is translucent normal-alpha pale cyan with per-vertex center falloff; only the uneven bright lip/low-energy fringe is additive. This avoids clipping the warm board into a solid cream-colored panel. No video/image of original particles is played over the game.

The transient layer exists only for successfully committed summons. Held, affordable and attack-ready states are separate. Restart clears staged cards; help/settings suppress transient drawing. Existing shader/geometry shadows are untouched. Old summon RNG consumption is retained so the cosmetic change does not alter the later AI random stream; the new particles themselves never call that RNG.

## Preserved and remaining differences

The existing movement and events remain: reveal +2.900, contact +3.400, settlement +3.800 by the recording event clock. The actual first visible reveal in the captured frames is around +2.87–2.90, about 3–4 source frames early. This difference is explicitly retained to avoid shifting the calibrated shadow/motion sequence in a focused particle revision. The source and replacement art/medallions/oval size differ. Particle positions, granular textures, bloom and complete timing are reconstructed approximations; source particles are unavailable.

All 11 default card definitions and all 74 audio files are preserved. The comparison fixture's Priest/Hunter cards remain fixture-only.
