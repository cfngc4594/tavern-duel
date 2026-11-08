# Verified 2014 card roster

## Selected version

Every card in `assets/data/classic_cards_5834.json` is pinned to **Hearthstone 1.0.0.5834**, the HearthSim archive commit dated **2014-06-30**:

- [Exact patch commit](https://github.com/HearthSim/hsdata/commit/f1f95c620ce6e103c5974e169cac3bf7410281ae)
- [Archived CardDefs.xml](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml)
- [Same-commit numeric card ID manifest](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/manifest-cards.csv)
- [Same-commit targeting requirement definitions](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/PlayErrors.xml)
- [HearthSim explanation of the extracted game-data archive](https://hearthsim.info/docs/cards/)

The archive is primary datamined game data, not Blizzard's current card-library balance data. Current official card pages were used only to corroborate card identities. Their dynamic card contents were not available to the text reader and must not be treated as historical evidence. Each selected collectible entry links its verified current official page. The Damaged Golem token page could not be verified and is intentionally omitted.

### Why 5834 instead of 5832?

[Blizzard's 20.0 notes](https://hearthstone.blizzard.com/en-gb/news/23642550) call the later Classic mode's target “1.0.0.5832”. The retrievable historical HearthSim commit and its XML root explicitly say **5834**. This prototype should display its actual data source as **2014 经典卡池 · 1.0.0.5834** rather than treating 5832 and 5834 as the same archived file.

As an independent era-consistency check, the same selected fields were extracted from [1.0.0.5506, dated 2014-05-28](https://github.com/HearthSim/hsdata/commit/6aea709553ed3e8c788634589798bb9603d0a71b). The eleven selected cards have **zero differences** in stats, localized names/text, tribe, collectible status, source set/rarity, keywords, or targeting requirements. See `5506-to-5834-selected-diff.json`.

## Original practice roster

Values are mana / attack / health; spell entries show mana only.

| Card ID | zhCN name | Values | Exact displayed zhCN ability |
|---|---|---|---|
| CS2_179 | 森金持盾卫士 | 4 / 3 / 5 | 嘲讽 |
| CS2_189 | 精灵弓箭手 | 1 / 1 / 1 | 战吼：造成1点伤害。 |
| EX1_015 | 工程师学徒 | 2 / 1 / 1 | 战吼：抽一张牌。 |
| EX1_556 | 麦田傀儡 | 3 / 2 / 3 | 亡语：召唤一个2/1的损坏的傀儡。 |
| CS2_124 | 狼骑兵 | 3 / 3 / 1 | 冲锋 |
| CS2_182 | 冰风雪人 | 4 / 4 / 5 | Empty |
| CS2_120 | 淡水鳄 | 2 / 2 / 3 | Empty; 野兽 tribe |
| CS2_024 | 寒冰箭 | 2 | 对一个角色造成3点伤害，并使其冻结。 |
| CS2_029 | 火球术 | 4 | 造成6点伤害。 |
| CS2_023 | 奥术智慧 | 3 | 抽两张牌。 |
| skele21 | 损坏的傀儡 | 1 / 2 / 1 | Empty; non-collectible token |

Stormwind Champion is intentionally excluded from the practice mini-roster to avoid introducing an incompletely implemented aura. The original eleven records remain unchanged. The practice roster represents Taunt, Charge, targeted Battlecry, draw Battlecry, and Deathrattle; the normal-match extension below supplies enough distinct collectibles for legal decks.

## Implementation-critical distinctions

- Elven Archer's archived requirements are `REQ_NONSELF_TARGET` (9) and `REQ_TARGET_IF_AVAILABLE` (22). Its Battlecry may hit a friendly or enemy hero/minion, but not itself. It must not be implemented as enemy-only. It is not affected by Spell Damage.
- Frostbolt and Fireball have only `REQ_TARGET_TO_PLAY` (11) among their printed targeting requirements. Both can hit friendly or enemy characters; Taunt does not limit these effects.
- Novice Engineer draws exactly one card when played. Summoning a minion by another effect does not activate its Battlecry.
- Harvest Golem creates `skele21` for its controller when it dies, subject to board space. The token is 2/1, is not collectible, and should not enter ordinary deck generation.
- Harvest Golem and Damaged Golem have **no Mech tribe** in this June 2014 archive. Do not mix in the later 机械 tag. River Crocolisk does have the Beast tag.
- No formal spell-school tags existed in this build; do not import modern Fire/Frost/Arcane school metadata.
- Empty printed ability text is truly empty, not an invitation to insert flavor-like rules text.
- `text_raw` preserves the archived `<b>` markers and `$` damage markers. `text` removes just these display markers, retaining canonical wording.
- Archived entity `ID` attributes are zero; actual numeric IDs are recovered from the same-commit `manifest-cards.csv`.
- The CardDefs file supplies card data and client Power GUIDs, not runnable authoritative server code. The JSON's `implementation` object expresses the intended rules to implement from those data, rather than claiming the full original server implementation was recovered.

## Files and reproduction

- `classic-data.json`: implementation-ready normalized mini-roster with exact per-card source lines.
- `selected-CardDefs-1.0.0.5834.xml`: original selected entity blocks.
- `CardDefs-1.0.0.5834.xml`, `CardDefs-1.0.0.5506.xml`: exact complete historical source files.
- `PlayErrors-1.0.0.5834.xml`, `manifest-cards-1.0.0.5834.csv`: same-build supporting data.
- `source-manifest.json`: origin URLs, exact byte counts, SHA-256 values, and verified Git blob SHA-1 values.
- `5506-to-5834-selected-diff.json`: machine-readable zero-difference comparison.
- `prototype-migration.json`: captured pre-change prototype values and required changes.
- `build_research.py`: deterministic extractor and hash validation. Run `python build_research.py` in this directory.

All files were retrieved and checked on 2026-10-16. The HearthstoneJSON per-build endpoints for 5834 were inaccessible in this environment, so the reproducible GitHub archive was used instead. No modern stats were substituted. Card identities/text remain Blizzard Entertainment intellectual property; this research does not confer art, audio, branding, or commercial reuse rights.

## Normal-match extension, verified 2026-10-17

Five additional neutral, non-legendary collectibles allow a thirty-card Mage deck with exactly two copies of each of fifteen distinct cards. The generated Coin is additional to the deck. The original eleven practice records are retained byte-for-byte at the normalized record level; their canonical SHA-256 and the six added original XML entity blocks are stored in `CLASSIC-FLOW-SOURCE.json`.

| Card ID | Archived zhCN name | Mana / attack / health | Ability and historical tribe | Exact source lines |
|---|---|---|---|---|
| CS2_125 | 铁鬃灰熊 | 3 / 3 / 3 | 嘲讽; 野兽 | [6639–6699](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L6639-L6699) |
| EX1_396 | 魔古山守望者 | 4 / 1 / 7 | 嘲讽; no tribe | [21828–21884](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L21828-L21884) |
| CS2_172 | 血沼迅猛龙 | 2 / 3 / 2 | Empty ability; 野兽 | [7609–7653](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L7609-L7653) |
| CS2_200 | 石拳食人魔 | 6 / 6 / 7 | Empty ability; no tribe | [8328–8368](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L8328-L8368) |
| CS2_186 | 作战傀儡 | 7 / 7 / 7 | Empty ability; no tribe | [7916–7959](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L7916-L7959) |
| GAME_005 | 幸运币 | 0 / — / — | 在本回合中，获得一个法力水晶。; non-collectible spell | [28384–28417](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L28384-L28417) |

War Golem's archived Chinese name is **作战傀儡**, and it has no Mech tribe in this build. The Coin has no explicit COST, CLASS, COLLECTIBLE or RARITY tags; cost 0, neutral class and non-collectible status are normalized defaults, while its absent source rarity is recorded as null. The Coin's temporary mana is interpreted from its printed effect, not presented as recovered server code.

The exact complete 5834 XML was retrieved again through GitHub's blob API and matched both the existing SHA-256 `e0a50c4be89d3c9fe99145488a76be4202e36cad87109ad7d7248fccfa307c3a` and Git blob SHA-1 `724498fbfca492b8b1d8c3fa5c239f908ed6fe99`. Numeric IDs again come from the same-commit manifest. The earlier 5506-to-5834 comparison covers the original eleven only; this extension does not claim a separate 5506 comparison.

`scripts/classic_flow_cards.gd` exposes fresh normal-match definitions and a fresh thirty-card recipe. All additions use already implemented Taunt or plain minion behavior. It does not alter the practice definitions. The Coin and Damaged Golem are excluded from deck generation.

The existing Grizzly, Warden and Coin portraits are reused at indices 30, 24 and 26. New original paintings use indices 33–35 for Raptor, Ogre and War Golem. `CLASSIC-FLOW-ART.json` records source/output hashes, artist credits and the precise 512→256 LANCZOS/WebP-quality-100 conversion. The three new portraits total **116,182 bytes**. The images remain unversioned community-hosted original art, not authenticated 5834 client extraction; no synthetic replacement is used. No new character audio is synthesized or substituted.

Verification:

- `python3 tests/classic_flow_provenance_test.py`: original-record hash, added records against retained XML entities, legal recipe, portrait hashes and compact-art budget.
- `godot --headless --path . --script res://tests/classic_flow_cards_test.gd`: 57 checks covering runtime definitions, archived stats and tribes, generated-card exclusion, independent recipes, and image decoding.
