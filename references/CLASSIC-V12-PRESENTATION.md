# v12 full-board presentation

Reference: Blizzard's official BlizzCon 2013 Hearthstone press kit, Classic-PriestVsHunter.mp4 (1280×720, 8:57).
https://blizzard.gamespress.com/BlizzCon-2013-Hearthstone-Press-Kit

Observed gameplay frames around 90, 120, 210, and 360 seconds informed the scene layout. Card draw around 131.5 seconds and attack/contact around 216 seconds informed the motion review. The reference is not included in the source archive.

## Composition

- Fixed nearly top-down view, 16:9.
- Field seam near 46% of height; arena at the seam approximately x19–81% of width.
- Hero portraits near horizontal center, y18% and76%; hero powers to their lower right.
- Friendly/enemy rows around y55%/38%; four-unit horizontal pitch approximately7.2% of width.
- Broad blue side gutters, narrow ivory rails, asymmetric themed corner scenery.

## Implementation

The game rules stay in scripts/game.gd. scripts/classic_spatial.gd renders independent real minion/card meshes in a transparent orthographic SubViewport registered to the logical screen. A card's face is rendered once into a texture; its body and bevel are physical geometry. Minions have clipped image planes, separate rounded collars, recessed grooves, and shield geometry. Their animation uses the live game dictionaries and collision/damage APIs.

The painted background is drawn once at screen coordinates. It is not projected onto a tilted table. Heroes, text, numbers, state effects, targeting, contact/death effects and shadows use 2D presentation. Staged card-to-minion transformation retains the established 2D transition while the resulting minion is an actual independent mesh.

New board and card surface assets were generated with imagegen using the official composition as a visual reference. They are substitute artwork, not extracted client assets. Procedural collars and shields approximate the shape; neither geometry counts nor automated tests establish visual fidelity. See screenshots/video for the actual result.

Default practice mode, original audio inventory, card definitions and gameplay limitations remain documented in README.md.
