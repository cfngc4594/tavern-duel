# Pandaria static board restoration plate

## Deliverables
- `source_55s.png`: unchanged 1280×720 source frame extracted at exactly 55.000 seconds from the supplied `Classic-PriestVsHunter.mp4`.
- `pandaria_static_restored_imagegen_v2.png`: opaque generated restoration, 1672×941, full same-camera frame. Do not treat this as an authentic extracted game texture.
- `restoration_masks_1280x720.json`: Final source-coordinate masks. The shader is authoritative: 15 rectangular regions, two portrait-interior composites, two power ellipses, and two health ellipses.
- `restoration_candidate_01.png`: first attempt retained for audit; rejected because empty hero arches and two blue card-back shapes remained. Do not use this version as the final restoration.

## Runtime use
Sample source and restoration in normalized UV. For the final board, select original source pixels outside the explicit mask union and restoration pixels inside it. An optional three-source-pixel inward feather can soften the patch edge. Preserve clipped outer-image boundaries at full mask strength. Do not use the generated plate across the whole board if exact original pixels are the goal. No resizing or pixel compositing was performed on disk.

The top and bottom portrait interiors/power sockets, both hands and decks, mana counters, names, cursor, button and footer UI are removed. Final portrait masks preserve the physical board arches; independent live hero frames and portraits render above them. The original board is already empty of minions at this timestamp. A straight rail continuation behind the old turn button is inferred; the physical rail's central notch is preserved in the generated version. Render real turn controls above it.

## Provenance and limits
The input is an official-video screenshot supplied for this private study. Removal/restoration used the built-in imagegen edit tool twice. Hidden regions are inferred, generated artwork. This is not the actual client board texture, not an extracted 3D model, and not a claim of exact 1:1 fidelity. The original source pixels are retained at runtime only outside masks. Inside masks, color/geometry variation from the true unknown background is expected.

## Prompt set (built-in tool)

### First edit
Precise-object edit of source_55s.png for a static board clean plate. Keep the complete same-camera 16:9 framing, original composition, geometry, lighting, parchment cracks/seam, wood, cloth, stone rails, red/teal pagoda, blue-roof watermill/tree, golden instrument/flowers, and timber farm/pond. Remove top and bottom hands; hunter/priest portraits including arched frames, health badges and numbers; circular hero powers including metallic sockets/numbers; mana counters; two right-hand decks; entire enemy-turn button and socket; cursor; names/nameplates; friends/time overlay; settings gear; and numerical performance readout. Reconstruct continuing underlying rail, colored panel, wood and cloth; no empty portrait silhouette, ring or socket. Preserve original pixels outside removal areas as closely as possible. No text, numbers, cards, characters, cursors, game UI, cropping or reframing. Request opaque 1280×720 if available.

### Second targeted edit
Precise object-removal edit of restoration_candidate_01.png. Preserve the entire same-camera image. Remove the residual top-center gray upright arched portrait recess/frame and continue the red decorative rail panel across it. Remove the bottom-center gray upright arched recess/frame and continue the blue decorative rail panel across it. Neither may retain an arch, recess, portrait silhouette, gravestone, badge or socket. Remove both far-right narrow blue-backed card-shaped slots including their gold lines/rounded outlines and restore plain matching stone rail. Preserve architectural skulls and all other objects, wood, cloth, parchment and seam, corner buildings, lighting, shadows and framing. No text, numbers, cards, portrait holes, round buttons, minions, cursors, UI, cropping or zoom.

## Visual QA
Source 55s was visually inspected and selected over 65s (transitioning turn button) and 75s (large Your Turn overlay). Final image was visually inspected at native generated resolution. No hero/card/socket/UI ghosts were visible after the second edit. The final composite was validated in actual Godot Compatibility renders. Original source pixels remain outside masks, with inferred hidden regions and a few visible seam/color differences. Corners are static artwork; corner hover responses are procedural and do not reproduce the original interactive board animations.
