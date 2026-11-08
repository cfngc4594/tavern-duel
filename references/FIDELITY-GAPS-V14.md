# Reference fidelity: ranked audit and stopping point

Acceptance target was strict 1:1 against the official 2013 Priest-vs-Hunter video, not merely Hearthstone-like styling. This target remains unmet.

## Ranked gaps, v13 to v14

1. **Board artwork / spatial identity.** v13 used an entirely generated painting. v14 retains the source video's original static board pixels outside explicit UI-removal masks and uses imagegen restoration only behind removed objects. This substantially closes the dominant full-frame mismatch. Hidden portions remain inferred; board mesh, lighting response and animated/interactable corners remain unavailable and unmatched. The background is a static reconstructed plate, not extracted original 3D assets.
2. **In-play frames and sockets.** Procedural ring, Taunt shield, hero frame and power sockets were replaced with public HearthSim/Joust textures. Their modern-ish provenance is bounded to 2016; they are not authenticated 2013 exports. Thickness, lighting and some portrait framing still differ.
3. **Card typography and composition.** Website Belwe Bold replaces substitute display type, titles curve, and the card body, banner, race and gems are repositioned. Exact 2013 font version/body typeface and native card-layout behavior remain unresolved; card art/frame placement is still visibly different. Chinese fallback remains Noto.
4. **Glow, summon and material motion.** Sharp contour spikes were removed and green hover light softened. Held-card offset/scale, pause, full-face cyan hold, oval reveal and shield timing are measured against the source. Source particles, additive light, depth/normal maps and original shader timings remain approximations. Mouse-button time is inferred within roughly one frame.
5. **Hand and UI geometry.** Eight/nine-card resting fan scale, centers, angles and live overlap hit tests were fit to multiple source cards; cursor has a sourced image. Turn button, mana crystals, deck appearance and small HUD widgets retain visible differences. Source history pixels are used only for unverified initial fixture icons, with actual new game actions replacing them.

## Exact missing evidence/assets

No authenticated 2013 Pandaria board texture/mesh/animation bundle; no original summon, lighting or particle shader stack; no authenticated 2013 font package or exact card-body font. Public retrieval yielded some historical DDS but not a verified Pandaria asset. Twenty-three requests returned 403 and were not bypassed. Publicly hosted 2016 UI, current website font, unversioned card portraits and cursor copies are source-qualified, not proof of 2013 byte identity. Public access is not a license grant.

## Scope and validation limit

The interactive game remains the supported eleven-entity Classic Mage practice pool with its prior rules and 74 unchanged original audio files. The Priest/Hunter fixture is a bounded same-visible-state live Grizzly summon test, not full support for those classes or all game modes.

The comparison shows the actual 15:40 UTC render. Final fan/hit-test, smaller health numbers, deck-edge width, initial source-history and final pointer corrections were made afterward and validated headlessly, but the final GUI rerun was denied by an execution safety check. That visual verification remains open; the video is explicitly revision-labeled. See FINAL-PREVIEW-SCOPE-V14.md.
