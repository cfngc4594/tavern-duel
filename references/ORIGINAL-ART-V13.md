# Original classic art assets, v13

## Delivered assets

This document and `ORIGINAL-ART-V13.json` retain the original v13 delivery manifest. The later normal-match extension adds three compact original-art WebP portraits alongside these PNGs; their separate hashes, artists, transforms and version limits are in `CLASSIC-FLOW-ART.json`. The Grizzly, Warden and Coin PNGs below are reused unchanged.

`assets/original_classic_v13/` contains 29 portrait PNGs,18 UI PNGs and 1 card back. Total 6,625,781 bytes. All files were decoded and SHA-256 checked.

- `art/{CARD_ID}.png`: 256×256 original card/power art; four heroes 384×384. Source lossless originals were 512×512. LANCZOS resizing only, no recolor, repaint, crop, synthetic replacement or baked stats.
- `ui/*.png`: original byte-for-byte Sunwell assets; exact commit recorded below.
- `cardback_classic.png`: classic blue-swirl back, 300×414, downsampled from 1000×1380 with transparency preserved.
- `ORIGINAL-ART-V13.json`: per-file source URL, raw/output checksum, resize operation, dimensions and archived5834 identity/artist evidence.
- `ORIGINAL-ART-V13-PLACEMENTS.json`: exact renderer layout, clipping polygons, draw order and text centers.

## Source and provenance

- [HearthstoneJSON image API](https://hearthstonejson.com/docs/images.html) documents original lossless card art by CardID. Retrieved 2026-10-16.
- [HearthSim/Sunwell at pinned commit](https://github.com/HearthSim/Sunwell/tree/e6c4dc118a76e5b15e65d1897625c4f266c4d44e) supplies the image assets and placement code. Raw bytes were checked against the Git tree blob SHA-1 values.
- [HearthPwn card-back guide](https://www.hearthpwn.com/guides/592-the-card-backs-of-hearthstone?page=17) labels the [downloaded back](https://media.hearthpwn.com/attachments/117/247/classic.png) “Classic”, the default card back.
- [Archived 5834 CardDefs](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml) independently verifies every portrait’s ID and localized name. The existing gameplay pin remains unchanged.

## Version limits and checks

These are original-game images from public community hosts, not newly generated illustrations. The image API/back are unversioned; do not claim they are authenticated client 1.0.0.5834 extraction. The neutral frame is the familiar standard non-golden card frame. The Jaina raw image visually shows the original pre-2019 bodice, but its extraction version is not independently authenticated.

Full Chinese renders were acquired for comparison only and are deliberately excluded from production: current Harvest Golem/Damaged Golem include the later Mech footer, and current mage spells include modern spell schools. Even the VAN_EX1_556 Classic-mode render retains Mech. Use original art and clean UI templates with the separately pinned historical text.

Extra fixture identity corrections: Holy Nova = CS1_112, Mogu’shan Warden = EX1_396. EX1_538 is Unleash the Hounds; EX1_405 is Shieldbearer. Neither mistaken candidate is included in production.

Sunwell’s hero-power-player/opponent PNGs are zoom/collection-card shells, not in-play power sockets. Sunwell does not include in-play minion rings, Taunt shields or hero sockets.

## Rights

Hearthstone card art, character art and UI remain copyright Blizzard Entertainment. Sunwell’s code license is MIT, but its README explicitly distinguishes Blizzard-copyrighted assets. Public retrieval and the API’s availability are not a grant of commercial/public redistribution rights. These files are for the requested private noncommercial study and must not be publicly published or represented as original authorship.

## Portrait index

| ID | English name in 5834 | Chinese name in 5834 | Artist credit in 5834 |
|---|---|---|---|
| CS2_179 | Sen'jin Shieldmasta | 森金持盾卫士 | Brian Despain |
| CS2_189 | Elven Archer | 精灵弓箭手 | Steve Prescott |
| EX1_015 | Novice Engineer | 工程师学徒 | Karl Richardson |
| EX1_556 | Harvest Golem | 麦田傀儡 | Brian Despain |
| CS2_124 | Wolfrider | 狼骑兵 | Dany Orizio |
| CS2_182 | Chillwind Yeti | 冰风雪人 | Mauro Cascioli |
| CS2_120 | River Crocolisk | 淡水鳄 | Daren Bader |
| skele21 | Damaged Golem | 损坏的傀儡 | Not present in archived record |
| CS2_024 | Frostbolt | 寒冰箭 | Steve Ellis |
| CS2_029 | Fireball | 火球术 | Ralph Horsley |
| CS2_023 | Arcane Intellect | 奥术智慧 | Dave Berggren |
| HERO_08 | Jaina Proudmoore | 吉安娜·普罗德摩尔 | Not present in archived record |
| HERO_01 | Garrosh Hellscream | 加尔鲁什·地狱咆哮 | Not present in archived record |
| HERO_09 | Anduin Wrynn | 安度因·乌瑞恩 | Not present in archived record |
| HERO_05 | Rexxar | 雷克萨 | Not present in archived record |
| CS2_034 | Fireblast | 火焰冲击 | Not present in archived record |
| CS2_102 | Armor Up! | 全副武装！ | Not present in archived record |
| CS1h_001 | Lesser Heal | 次级治疗术 | Not present in archived record |
| DS1h_292 | Steady Shot | 稳固射击 | Not present in archived record |
| CS1_112 | Holy Nova | 神圣新星 | Luca Zontini |
| EX1_396 | Mogu'shan Warden | 魔古山守望者 | Cole Eastburn |
| CS1_129 | Inner Fire | 心灵之火 | Steve Prescott |
| GAME_005 | The Coin | 幸运币 | Not present in archived record |
| CS2_236 | Divine Spirit | 神圣之灵 | Jim Pavelec |
| EX1_561 | Alexstrasza | 阿莱克丝塔萨 | Raymond Swanland |
| EX1_531 | Scavenging Hyena | 食腐土狼 | Jim Nelson |
| CS2_125 | Ironfur Grizzly | 铁鬃灰熊 | Lars Grant-West |
| CS1_113 | Mind Control | 精神控制 | Sean O’Daniels |
| NEW1_034 | Huffer | 霍弗 | Not present in archived record |
