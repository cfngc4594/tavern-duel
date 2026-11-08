# Verified Hearthstone targeting and placement reference

## Scope and source

Observed source: the locally supplied official Blizzard gameplay video, `Classic-PriestVsHunter.mp4` (1280×720, 29.97 fps, 537.003 s). Existing provenance record identifies the BlizzCon 2013 press-kit item **Hearthstone-PriestVsHunter enUS**:

https://blizzard.gamespress.com/BlizzCon-2013-Hearthstone-Press-Kit

The 2013 clip is evidence for this particular historical client, not a claim about every current client/version. I inspected actual extracted video frames, including dense 10–12 fps sequences around player-controlled spell targeting. Times below are approximate source-video positions, not instrumented input-event timings. No mouse-button log is available, so “commit” is inferred from card consumption / mana changes / subsequent resolution.

## Most useful observed findings

### Targeted card: Holy Fire, 03:42.2–03:44.6

Evidence: `holyfire_detail_01.jpg`, `spell_free.png`, `spell_lock.png`.

- 03:42.2–03:42.6: hovered hand card is enlarged and green-outlined.
- Around 03:42.7–03:42.9: card becomes smaller as it is picked up.
- Around 03:42.95–03:43.28: the picked-up card stays near the lower hand/hero area while a red targeting pointer moves across the field. It is not necessary for the full card to follow the pointer all the way onto the target.
- Over empty board the visible pointer has a red triangular arrowhead. The shaft is made of substantial separated rectangular red pieces, with thickness/bevel/shading, rather than a thin line or dots. Their positions vary across the continuous frames, giving a flowing/animated ribbon impression.
- At about 03:43.37, on the enemy minion, the endpoint becomes a red circular reticle. This is normal valid-target feedback; red is not itself an invalid-state color.
- Warm gold outlines appear on potential characters during targeting. In this case both heroes and the two enemy minions are outlined. The pointer identifies the currently selected target in addition to these eligibility outlines.
- Around 03:43.2–03:43.6, the held card gains a strong cyan/white treatment and dissolves. The red shaft/reticle briefly persists, then disappears before the damage/effect resolves.
- The card title is **Holy Fire**, not Mind Control. The frame around 03:43.1 is useful for the free arrowhead; 03:43.5 is useful for the locked reticle.

### Friendly targeted cards: Divine Spirit and Inner Fire, 07:18–07:24

Evidence: `spell_detail_01.jpg` (10 fps), `spell_innerfire_01.jpg` (10 fps), `friendly_spell_lock.png`.

- Divine Spirit repeats the same card-pickup → target mode → cyan/white card consumption sequence at roughly 07:18.3–07:19.6.
- The three friendly minions shift from green readiness outlines to warm gold targetability outlines during aim. There are no enemy minions in this scene, so it does not independently prove a friendly-only targeting rule.
- A short red shaft leads to the red circular reticle over the chosen friendly minion. At this short distance, some frames show mostly the reticle and little shaft; this must not be mistaken for an entirely different targeting style.
- Inner Fire at roughly 07:22.7–07:23.9 repeats the same visual language.

### Attack aiming: 06:30.5–06:34.5

Evidence: `late_spells_01.jpg`, `attack_lock.png`, `attack_target_06m31_500.png`.

- Around 06:31–06:32 the attacking friendly minion is the shaft’s origin.
- The red shaft uses thick spaced 3D-looking pieces, ending in the same circular red target reticle.
- Enemy characters receive warm gold eligibility outlines. The chosen enemy minion has the red reticle over it.
- The subsequent lunge/contact and damage occur after aim. This is a clearer player-side aim example than the earlier 03:34–03:38 opponent-side attack.

### Minion placement: Ironfur Grizzly and Scavenging Hyena, 02:17.5–02:27.5

Evidence: `summons_01.jpg`, `summons_02.jpg`, `placement_drag.png`, `placement_outline.png`.

- Ironfur Grizzly: enlarged green hover card → smaller dragged card with offset shadow → blue/cyan card-shaped landing treatment → oval minion, then localized bright impact/sparks.
- Hyena: around 02:24.2–02:25.0, the actual smaller card is dragged to the friendly row, and the existing minion slides to make insertion space. The row reflows as part of the placement interaction.
- The stronger translucent cyan full-card silhouette around 02:25.25–02:26.0 belongs to the landing/transformation portion. It is not proven to be a pre-drop empty-slot preview.
- No separate insertion arrow / chevron glyph, no red attack-style arrow, and no full-width placement rectangle are visible in these verified placement sequences.
- A bespoke insertion chevron could be a reasonable implementation choice, but must not be presented as an observed original Hearthstone element.

### Untargeted spell control: Holy Nova, 04:12–04:15

Evidence: `later_spell_01.jpg`.

The card is lifted onto the field, then disappears into the area effect. No target-selection arrow is visible. This helps distinguish “any card drag gets an arrow” from “the card requires a character target.”

## Invalid targeting / cancellation: evidence limit

I did not verify an invalid-target release or an intentional cancel in the inspected official video sequences. The sparse full-match scan is useful for locating events, but it cannot prove the absence of a very brief invalid action anywhere in the whole recording.

The “Not quite what was planned” speech bubble near 05:05 follows the Secret interaction. It must not be used as evidence of illegal targeting rejection.

External original-gameplay candidate located:

https://www.youtube.com/watch?v=q7NGyGZiH5E

Title: **[Hearthstone Science] I must attack the Minion with Taunt! (Immune vs Taunt)**. Creator: Patashu. Published June 27, 2015. Description explicitly identifies patch 2.7.0.9166. Public page/player metadata was retrieved (34-second video); playable video frames were not obtained in this pass. Therefore no rejection timing, animation, or on-screen wording from this video is claimed as observed. It documents a specific Immune/Taunt interaction and should not be assumed to represent generic invalid-spell handling without watching it.

## Implementation implications (recommendations, not observations)

- Keep green readiness, gold eligible-target outlines, and red aim/reticle as different concepts.
- Separate the free triangular tip from the on-target circular reticle. Do not color all valid aim green just because green commonly means “valid” in other UI.
- Differentiate targeted-spell aim, minion row placement, untargeted card play, and minion attack states.
- For rejection/cancel behavior, it is safe as a product requirement to preserve the hand card, mana, attacks remaining and board state until legality is confirmed. Showing a brief reason at invalid release and returning the card home are sensible choices, but their exact animation, colors, audio and timing are not visually established by this research.
- Do not claim a source-accurate rejection wobble, red X, gray arrow, shake amplitude, or duration without further original footage.

## Artifact guide

- `Verified-Targeting-Reference.png`: six full-resolution source frames with descriptive labels, covering placement, free spell pointer, locked spell pointer, attack pointer and friendly spell targeting.
- `holyfire_detail_01.jpg`: 12 fps continuous source sequence, ~03:42.2–03:44.7.
- `spell_detail_01.jpg`: 10 fps continuous source sequence, ~07:17.8–07:19.8.
- `spell_innerfire_01.jpg`: 10 fps continuous source sequence, ~07:22–07:24.
- `summons_01.jpg`, `summons_02.jpg`: 4 fps, 02:16–02:29.
- `attacks_spells_*.jpg`: 3 fps, 03:25–04:00.
- `late_spells_*.jpg`: 2 fps, 06:20–06:55.
- `later_spell_*.jpg`: 2 fps, 04:08–04:26.
- `final_spells_*.jpg`: 2 fps, 07:10–07:35.
- `scan_complete_*.jpg`: coarse 5-second locator frames across the full gameplay.

No game code or assets were edited.
