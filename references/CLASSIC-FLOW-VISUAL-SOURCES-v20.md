# Classic Hearthstone flow visual sources — v20

## Result

All four requested phase categories now have inspected **March 2014 original-client pixels**. The strongest source is Gamereactor's own March 3, 2014 broadcast, downloaded from its public native video player. The recording is 1920×1080 at 25fps, with presenter overlays confined to the lower corners and a publisher watermark at upper right. The underlying game fills the frame. No UI was reconstructed for these evidence images.

Source: [Gamereactor, Hearthstone + Movie Talk livestream replay, March 3, 2014](https://www.gamereactor.gr/video/161134/Hearthstone+Heroes+of+Warcraft+Movie+talk+-+Livestream+Replay/). Public player media URL and exact SHA-256 values are recorded in `CLASSIC-FLOW-VISUAL-SOURCES-v20.json`. This is period gameplay, not an official Blizzard demonstration. The official [October 2, 2013 patch notes](https://hearthstone.blizzard.com/en-us/news/11144301/hearthstone-closed-beta-patch-notes-10-2-2013) independently date the addition of the second-player coin-to-card effect.

## How to use coordinates and timestamps

- Coordinates below are source pixels in the 1920×1080 full frame, unless stated otherwise. For 1600×900, multiply BOTH axes and sizes by 5/6. Normalized positions are x/1920, y/1080.
- Game board frame is approximately x280–1665, y0–1030; this is a visible irregular frame, not a cropped game viewport. Hero center is x960. Do not crop away the surrounding table before normalizing.
- Pixel measurements are manual approximations, generally ±4–8 source pixels. Soft glows have no unique hard boundary.
- Explicit still filenames, native-25fps sequences and `*-exact-contact.jpg` use explicit source times, with up to one 40ms frame of sampling uncertainty. Early coarse `fps=1` / `fps=5` search sheets have sampling-phase offsets of up to half their interval; use them for finding scenes, not exact timing. The later exact sheets supersede their labels.
- These are observed playback timings from one match. Server waits, voice timing and input choices are not fixed animation contracts. No mouse-event telemetry exists, so a commit is defined visually.

## 1. Initial deal and mulligan

Reference clip: `opening-mulligan-coin-2014-946-972.mp4` (source 946–972s, 15:46–16:12).

### Initial three cards

- 946.8–947.2: large versus portraits shrink/dock into the upper and lower hero sockets.
- Around 947.32: first card back emerges from the RIGHT-side player deck. At 947.40 it is edge-on; face visible at 947.44.
- Second starts around 947.52–947.56; third around 947.72–947.76. Approximately 0.20s stagger.
- The cards follow leftward/upward flights from around (1740,650), turning from a card-back/edge view into their fronts. Their fronts are initially tilted counterclockwise, then ease toward upright. At 947.60, the first card center is approximately (1045,560), tilted about −25°.
- At 948.4, the cards still have a small settle/overshoot. By about 948.6–948.8 the first three occupy the first three positions of the eventual FOUR-card row: centers approximately (580,512), (836,512), (1092,512). This is not a three-card row centered independently and later reflowed.
- Front face size is approximately 228×320 pixels, excluding a little mana-gem protrusion and selectable glow. Card positions normalized: (.3021,.4741), (.4354,.4741), (.5688,.4741). Fourth slot (.7021,.4741).

Evidence: `deal-onset-25fps.jpg`, `deal-path-full-frame.jpg`, `deal-exact-contact-00.jpg`, `deal-exact-contact-20.jpg`; full-resolution samples `deal_exact/*.png`.

### Initial gold token and fourth card

- Around 949.0–949.4, a golden curved trail forms a loop on the right, accompanied by orange rays and “You get an extra card”.
- About 949.6–950.4, the gold coin turns/spins and settles. Its center is approximately (1344,548), diameter 158px. Normalized (.7000,.5074), diameter .1463×frame height.
- The token is visible beside the three cards. The fourth card flies from the right deck around 951.0–951.8 into center (1348,512), approximately covering the token's stage location.
- After the informational text and hero greeting finish, the background dims further. Around 953.4–954.0 the actual selectable mulligan UI is visible: parchment “Starting Hand” banner, blue aura, yellow subtitle, green outlines, blue Confirm. Player immediately marks the fourth card, so this recording does not provide a long clean four-unselected-card hold.

Stable source frame `opening_stills/954.00.png`:
- Banner full soft-blue extent approximately (675,105)–(1248,255).
- Confirm center approximately (965,856), visible body approximately 170×87. Normalized (.5026,.7926).
- Four card centers x≈580,836,1092,1348, faces y≈350–673.
- End Turn socket is blank during opening/mulligan.
- The period three-card Fen Creeper screenshot has the same ribbon/blue-aura banner and icy-blue beveled Confirm. Its 1503×1080 aspect ratio differs; do not distort its proportions by independently scaling x/y.

### Confirm, replacements, gather

- Around 960.2–960.5, Confirm is clicked. Banner/green outlines disappear; Confirm bursts into white/blue particles. Selected card fronts turn edge-on and fly back right. At exact 960.50, the second slot is already empty and the fourth is turning away; red “REPLACED” labels briefly remain.
- Kept cards stay in their original slots. The gold token is visible again in the vacant fourth-slot region.
- Replacement cards arrive from the right around 964–965s; by about 965.6–966.8 the four final cards are displayed.
- At 966.8 the four are still in the row; around 967.0 they are descending/shrinking together into the lower hand; by 967.2 the hand is essentially assembled.
- **The four cards gather BEFORE the gold token turns into the Coin card.** This is the main choreography correction established by the source.

## 2. Lucky Coin grant and Coin played

### Grant after mulligan

Use `coin-transform-exact-contact.jpg` and the opening clip.

- Gold token remains at center-right (1344,548), not at screen center. At exact 967.40 it is completely unobstructed; suggested reference crop approximately x1264–1424, y469–627. It is a round gold coin with a faceted hexagonal emblem, not a full-size card yet.
- 967.6–967.8: its center brightens blue; white specks begin extending around/downward from it.
- 968.0–968.2: white/blue particles define a card-shaped volume under/around the coin.
- 968.4: translucent blue card silhouette is obvious.
- 968.6: luminous cyan card-border linework resolves.
- 968.8–969.0: bright cyan-white flash reveals the Coin card.
- 969.2–969.4: normal illustrated Coin card is held at right-stage, center approximately (1330,650), face dimensions around 300×430; total bounds about314×450 including its top mana gem. The token has become the illustration near its top, so card center is LOWER than token center.
- 969.6–970.0: Coin card scales down and moves diagonally down/left into the hand's right end. At 970.0 it is in the hand and the board has brightened.

Full-resolution requested phase stills: `opening_stills/947.00.png`, `951.00.png`, `953.00.png`, `954.00.png`, `960.50.png`, `966.50.png`, `967.40.png`, `968.40.png`, `969.20.png`, `970.00.png`.

### Coin played and mana crystal

Reference clip: `coin-play-mana-2014-1072-1079.mp4` (17:52–17:59).

The player drags the Coin above the lower hero toward right-center board. It has a cyan outline while held. The play location is player-chosen; do not encode it as a forced center-stage point.

Native-frame visual commit t0 = **1073.96s**, the first wireframe frame after last solid card at 1073.92. Actual mouse-up is not logged. Relative observations:

| Source time | Relative | Observed pixels |
|---|---:|---|
| 1073.96 | 0.00s | Solid art becomes luminous outline/wireframe |
| 1074.04–1074.12 | +0.08–0.16s | Brief faint/absent outline, then builds again |
| 1074.36–1074.48 | +0.40–0.52s | Full white card-shaped flash |
| 1074.52–1074.60 | +0.56–0.64s | Translucent luminous card outline |
| 1074.64 | +0.68s | Card shatters into pale blue-white flecks |
| 1074.88 | +0.92s | Flecks largely faded; no intact card |
| 1075.36 (first sampled) | +1.40s | Numeric mana changes 3/3→**4/3** |
| 1076.20 | +2.24s | Existing three gems glow cyan-white; purple seed at right |
| 1076.56–1076.68 | +2.60–2.72s | New blue gem appears tilted below tray with pink-purple flare |
| 1076.92 | +2.96s | Fourth gem upright in its rightmost slot |
| 1077.76–1078.12 | +3.80–4.16s | Purple-white pulse on extra gem; other gems still glow |
| about1078.36 | +4.40s | Glow receding; four crystals remain visible |

The denominator is the permanent maximum: **4 available / 3 permanent**, with four visible filled gems. Never infer 4/4 from gem count. By 1084, after a 4-mana Swipe, it is 0/3 with only three empty ordinary gems; the temporary extra gem has already gone. Unspent end-of-turn removal is not established by this sequence.

Evidence: `coin-release-25fps-00.jpg`, `coin-release-25fps-25.jpg`, `coin-mana-25fps-sampled.jpg`, `coin-mana-form-25fps-sampled.jpg`; native full frames in `coin_play_exact/`.

## 3. Rope height, introduction and burn

Reference: source2394–2412s (39:54–40:12). Clip `rope_button_details/rope-button-2394-2412.mp4`.

- Introduction around2399.1–2399.9: a coiled loop rolls/unfurls **RIGHT→LEFT from the button**, leaving a stretched rope behind.
- Once present, the rope burns **LEFT→RIGHT**. Intact rope is to the right of the ember; consumed rope disappears. A thin existing board seam remains, which is not charred rope.
- Brown twisted body ≈14–18px thick at1080p, with soft shadow beneath (total footprint nearer30px).
- Centerline ≈(399,505)→(1465,493), with slight upward slope to right. Button face center≈(1556,489). Thus rope reaches housing about4px below face center; left end is about16px below. It terminates at LEFT socket, not across the button face.
- Normalized endpoints (.2078,.4676)→(.7630,.4565); button (.8104,.4528).
- At1600×900 these become (332.5,420.8)→(1220.8,410.8); button center(1296.7,407.5); body about12–15px.
- Bright yellow/orange flare with pale core, small flecks, dark smoke drifting upward/behind. Measured ember x≈492 at2402,600 at2404,703 at2406 (~52–54px/s).
- Manual End Turn at2406.32 clears it before full burn. A ~20s full burn is only extrapolation; full expiry is unverified.

Evidence: `rope_button_details/rope-intro-12fps.jpg`, `rope-burn-coordinate-grid.jpg`, `observations.txt`.

## 4. End Turn states and transition

- Yellow/gold END TURN while actions remain; vivid green END TURN and animated green aura when ready to end; muted gray ENEMY TURN.
- Green starts around2404.8 BEFORE pointer arrives around2405.5. It is readiness, not a hover effect.
- During approximately0.8s hover, no clear face enlargement, translation or new independent hover hue is resolved. Subtle treatment cannot be ruled out at broadcast quality.
- On click around2406.32, green aura extinguishes by2406.36. Inner plate rotates around a **horizontal center axis**: visible rotation2406.40, vertically foreshortened2406.44–.48, nearly edge-on2406.52, gray reverse readable2406.60, settled2406.68. About0.3s.
- Outer housing remains fixed. This is not a crossfade or whole-button scale animation. No distinct sustained press-depression was resolved before flip.
- Independent Golem March14,2014 review shows enemy→player flip47.50–47.80, with edge-on around47.60. This corroborates the reverse direction.

Evidence: `rope_button_details/three-states.jpg`, `button-flip-25fps.jpg`, `button-flip-quarter-speed.mp4`. Golem alternate: `button-flip-timed.png`, `button-enemy-to-player-2014-46p8-48p3.mp4`.

## Evidence boundaries and provenance

- The inspected 2014 replay covers all four categories. Exact full rope timeout, an isolated subtle hover shader, sustained pressed depression, and unspent Coin-crystal expiry remain unverified.
- March2013 alpha demonstrations predate the officially introduced October2013 coin-to-card event. They are not substituted for this grant motion.
- The later2019 rope still and static older screenshot sources remain in the source ledger for provenance, but 2014 motion supersedes them for implementation.
- No 401/403/login/private-video restrictions were bypassed. Unavailable/private YouTube leads were abandoned. The successful sources were native public publisher media and public image attachments.
- Excerpts and screenshots are evidence derivatives, not original exported Blizzard UI textures or a claim of asset redistribution rights. Any extracted UI crop must be labeled as source-pixel extraction; separately generated/vector artwork must not be described as original assets.

## Files and integrity

`CLASSIC-FLOW-VISUAL-SOURCES-v20.json` includes source page URLs, observed media URLs, publication dates, dimensions, durations, exact source and excerpt hashes. The audit workspace `SHA256SUMS` records all audit files; excerpt hashes are also in the JSON ledger. Do not package the entire1GB broadcast when a short clip/still suffices. No game code was edited by this audit.


## v20 extracted plate pixels

Three cursor-free native frames are used: yellow2404.40, green2405.00, gray2407.20. The common rectangular crop is source(x1480,y450) to(x1626,y530), exclusive lower/right bound,146×80px. `end-turn-STATE-plate-rgb.png` retains exact decoded RGB values. `end-turn-STATE-plate-masked.png` adds a documented manual contour alpha mask; RGB is unchanged. It retains the front silver rim as part of the flipping plate and removes the outside fixed beige housing approximately. The matching `interior-rgb.png` variant is a deliberately tight fully housing-free rectangle.

The gray source has no cursor over the plate. No repainting, generated detail, recoloring, resizing or sharpening was used. These are compressed broadcast pixels, not original UI source textures. Derivation entries in the JSON ledger include native times, exact crop boxes, contour vertices and file hashes. Artifacts are supplied in the audit workspace `plate_pixels` directory for integration; the integration owner must separately verify final asset paths and release membership.

## Additional same-replay first-seat check (3148s /52:28)

A later match in the same March3,2014 replay directly verifies the first-player three-card mulligan layout. At3148s the settled card centers are approximately(620,512),(963,512),(1307,512), with about344px spacing at1920×1080. Uniform height scaling to1600×900 gives approximately(517,427),(803,427),(1089,427), spacing286.7px. Manual coordinate tolerance is about6px native. This is wider than the four-card row's256px native/213.3px logical spacing.

At3144s the three cards remain in a tighter left-side row while a gold1 marker and “You go first” label occupy the right stage. By3148s the cards have spread and centered.3146s is an intermediate frame. Detailed reflow timing was not measured. A build that deals directly into the final three-card slots is therefore a simplified trajectory, even if its settled layout matches.

Local full-resolution still: `v20_corrected_review/source-firstseat-3148.png`. Source excerpt: `first-seat-opening-2014-3140-3160.mp4` (3140–3160s,1080p25fps,no audio). These use the same original source hash and URL above. Clip SHA256: `39db8e0b1fe0d554e9a7e378ed2518d72ea898d4cb04591a5bf21b83cfdc05b3`. Still SHA256: `aae711b232b52ecfc298a2269df2261f670ab58f123b885af471654e2c339a21`.
