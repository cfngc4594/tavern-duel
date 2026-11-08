# Classic match flow: rules, timing, and source boundaries

Checked 2026-10-17. Target: ordinary 2013 beta / 2014 constructed Hearthstone, rather than current Standard, tutorial encounters, Arena, or the 2021 Classic client. This is a research record, not a claim that every item below has already been implemented or visually matched.

## Most important implementation decisions

- Use **75 seconds** for a normal turn, including the opening turns. Do not import the modern shortened opening turns into a 2014 reconstruction.
- Mulligan replacement must exclude the **rejected card instances**, not every card with their card IDs. Return the rejected instances to the deck only after drawing replacements.
- Coin is a 0-cost spell, gives one temporary mana, and does not permanently increase maximum mana. For the classic ruleset, available mana must not exceed 10.
- A full hand holds 10 cards. A draw from a nonempty deck removes the card even when the hand is full. An empty deck is not itself defeat: a failed draw causes increasing fatigue.
- The exact 2014 mulligan timeout, idle-shortened turn duration, rope onset, and rope animation have **not been authenticated from period footage in this pass**. An untimed local mulligan is a disclosed prototype choice, not historical behavior.

## Evidence levels

**Period / explicit historical statement** means archived 2014 data, a period developer statement, or a later developer statement explicitly describing the earlier behavior. **Later primary corroboration** means official documentation, an actual replay example, or original technical research from another date; it is useful but does not independently prove the 2014 implementation. **Unverified** means a conventional implementation target or a research lead that must not be marketed as frame-accurate original behavior.

## Decks and opening

### Deck legality

A March 2013 [quoted Blizzard reply](https://www.engadget.com/2013-03-26-roundup-of-hearthstone-blue-posts-from-the-last-few-days.html) gives 30-card decks, two copies per non-Legendary, one per Legendary. Its [original forum URL](https://us.battle.net/hearthstone/en/forum/topic/8414571441) could not be fetched. This is a period quotation preserved by another publisher, not a currently retrievable Blizzard page.

Class-or-neutral eligibility and the same construction limits are also described in the authors' rules model in [Hoffmann, Lynch, and Winslow, section 2.1, page 920](https://andrewwinslow.com/papers/hearthstone-jip20.pdf). That paper studies the Boomsday era, not 2014. Construction limits do not forbid in-match card generation from creating additional copies.

### First player and initial cards

Ordinary-match implementation target: randomly assign first/second with equal probability; give first player three deck cards and second player four deck cards; second player also receives Coin. Both players draw on their own first turn. Do not silently force the human to go first.

[Blizzard's Opening Moves: Mulligans, 2018-01-24](https://hearthstone.blizzard.com/en-us/news/21363040/opening-moves-mulligans) directly confirms 3/4 opening cards, Coin for second player, and the first player's turn-one draw. It does not specify the random-selection algorithm or exact animation timing. Fair random assignment is the conventional model; its server RNG implementation was not established here.

The first-turn draw is separate from the opening hand. Thus, before playing anything, first player normally has four cards at turn one; second player has five including Coin before their turn, then six after their first draw.

### Mulligan algorithm

1. Deal the opening deck cards. Keep Coin out of the selectable replacement set.
2. Record selected **instance identities** and set those cards aside.
3. Draw the same number of replacement cards from the remaining deck.
4. Put the set-aside instances back into the deck and shuffle before ordinary drawing begins.
5. Each player gets one selection/confirmation, not repeated redraw rounds.

The important period evidence is [Ben Brode's 2014-11-26 tweet](https://twitter.com/bbrode/status/537460645289930753), preserved in an embedded Twitter quotation in [this Blizzard forum post](https://us.forums.blizzard.com/en/hearthstone/t/so-game-mechanics-are-not-random/6584/11). The embedded statement distinguishes another copy during replacement from the rejected card appearing again on turn one. The live tweet could not be independently fetched; the surviving onebox includes its original URL and timestamp. The surrounding forum author's algorithm explanation is not itself a Blizzard statement.

[HearthSim's simulator author, 2015-08-25](https://hearthsim.info/blog/one-year-of-placing-fires/) describes replacement before shuffling the rejected cards back. This is primary documentation of an emulator implementation, useful corroboration rather than the original server source.

**Presentation versus internal state:** showing or animating Coin after mulligan confirmation is reasonable, but do not assert the server first creates it then. The [actual replay example in the HSReplay specification](https://hearthsim.info/hsreplay/) creates Coin in the second player's hand before the mulligan state. Its game date/build are unspecified. UI selectability and visible reveal order cannot be inferred simply from entity creation order.

## Hero health, mana, Coin, and ordinary drawing

### Exact 2014 data

The archived build 1.0.0.5834 [CardDefs.xml](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml) has SHA-256 `e0a50c4be89d3c9fe99145488a76be4202e36cad87109ad7d7248fccfa307c3a`.

- [Jaina HERO_08, lines 28667–28692](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L28667-L28692): HEALTH=30, CLASS=4, CARDTYPE=3.
- [Garrosh HERO_01, lines 28485–28511](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L28485-L28511): HEALTH=30, CLASS=10, CARDTYPE=3.
- [Coin GAME_005, lines 28384–28417](https://github.com/HearthSim/hsdata/blob/f1f95c620ce6e103c5974e169cac3bf7410281ae/CardDefs.xml#L28384-L28417): CARDTYPE=5; cost unset/zero; English text "Gain 1 Mana Crystal this turn only." It is an uncollectible spell, not one of the 30 selected deck cards.

The [HearthSim protocol documentation](https://hearthsim.info/docs/gamestate-protocol/) explains the zero/unset tag convention. Its protocol description is later than 2014.

### Mana and hand model

Ordinary rule target: start with zero permanent crystals before the first own turn; at each own turn add one permanent crystal, capped at 10, then refill usable crystals. Draw one deck card at turn start. Coin's temporary resource does not carry into the next turn and does not advance permanent crystal progression.

Later primary corroboration: [the research paper's section 2.1–2.2](https://andrewwinslow.com/papers/hearthstone-jip20.pdf) describes crystal gain/refill, seven minions per player, and ten-card hands. The [HSReplay example](https://hearthsim.info/hsreplay/) includes both players' MAXHANDSIZE=10 and MAXRESOURCES=10, as interpreted by the [HearthSim GameTag definitions](https://github.com/HearthSim/python-hearthstone/blob/master/hearthstone/enums.py). These are not date-authenticated 2014 traces.

The 10-mana cap is important: [Blizzard patch 29.0, 2024-03-11](https://hearthstone.blizzard.com/en-gb/news/24064735/29-0-patch-notes) explicitly changed temporary mana so it could exceed maximum mana. That newer behavior must not be backported to classic. At 10 available mana, Coin provides no eleventh usable mana; after spending mana it can replenish one, capped at 10. Card-play/spell triggers still matter even when no additional mana can be gained.

### Fatigue, burning cards, and result handling

[Blizzard's fatigue guide, 2018-12-24](https://hearthstone.blizzard.com/en-us/news/22819074/endgame-moves-finessing-fatigue) confirms that failed draws deal 1, then 2, then 3 damage, increasing each time. Maintain separate counters for each player. An empty deck alone does not end a match.

At the hand cap, a drawn nonempty-deck card is lost instead of entering the hand; it must not remain on top of the deck for another try. The [research paper, page 922](https://andrewwinslow.com/papers/hearthstone-jip20.pdf), explicitly uses hand overflow/burning in its construction. This is later primary corroboration.

Normal result target: hero at zero or below loses; if both die in the same resolved damage/death event, report a draw rather than awarding the winner according to array iteration order. The [protocol document's end-of-game section](https://hearthsim.info/docs/gamestate-protocol/) confirms hero death is processed through a deaths pass and one or both heroes may die. Exact 2014 simultaneous-death ordering and the conventional turn-limit draw were not independently replay-tested here. The paper mentions an 89-turn limit for its later ruleset; this alone is insufficient to authenticate 2014 turn-limit timing.

## Timers and forced end of turn

| Item | Target / finding | Confidence |
| --- | --- | --- |
| Normal turn | 75 seconds, before any animation allowance | Explicit historical developer statement |
| First turns in 2014 | Same normal baseline, not modern shortened opening turns | Historical statement plus later change note |
| Animation allowance | Extra allowance existed; exact algorithm not reconstructed | Developer confirmed, approximation required |
| Rope appears | Conventional final 20 seconds | Not authenticated to period in this pass |
| Rope direction | Conventional burn front moves left to right, toward the right-side end-turn button; remaining rope is ahead/right of the flame | Not visually verified in this pass |
| Mulligan timeout | Often described as 75 seconds including intro, roughly 65 seconds usable | Not authenticated; do not claim an exact historical timer |
| Subsequent idle turn | Often described as roughly 7 seconds, restored by player activity | Not authenticated to period |

### Why 75 seconds, not 90 or 45

[Ben Brode, 2015-06-19](https://www.reddit.com/r/hearthstone/comments/3agk6v/comment/cscn32h/) explicitly states that 90-second alpha turns became 75 seconds before beta and had not changed since. He also explains extra "slush time" based on the previous player's actions. This is stronger period evidence than later wiki prose claiming beta turns were 90 seconds.

[Blizzard patch 10.2, 2018-02-06](https://hearthstone.blizzard.com/en-gb/news/21507224/hearthstone-update-10-2-february-6-ranked-play-update) announces shorter first two turns. Do not apply that later change to 2014.

A local strict 75-second wall-clock countdown is a deterministic approximation. Pausing all animation time, adding arbitrary slush, or freezing the timer under menus is not proven historical behavior. UI stalls should not prevent a forced turn transition.

### Target selection at timeout

No authenticated 2014 clip or server trace was found establishing what the client does if the timer expires while a targeted battlecry is being aimed. The [HearthSim input-loop documentation](https://hearthsim.info/docs/gamestate-protocol/) describes server options, targets, and a complete SendOption action, but does not establish every client cursor/timeout case.

Safe local engineering policy: keep an unsubmitted card/attack provisional until all mandatory targets are chosen; at timeout cancel that incomplete intent and end the turn. If the local implementation already deducted mana or removed a card provisionally, roll back consistently. Do not invent a random legal target and call that verified classic behavior. Fully committed effects must finish resolving before the next player becomes actionable. This policy prevents a targeting modal from deadlocking the turn; it is a disclosed implementation choice.

## Visual reference audit

No new opening/mulligan/rope frames were successfully observed in this research pass. The available cloud browser reached YouTube watch pages, but the selected player stayed black/loading even at 360p. A media-download action was cancelled. No login, access-warning bypass, or protected press-kit retrieval was used.

- [Blizzard's 2013-11-25 tournament video hub](https://hearthstone.blizzard.com/en-us/news/11738828) is an official period source. Its [Day9/Reckful playlist](https://www.youtube.com/playlist?list=PLEFn_PVNSM6gntr-rMPQ-7omKN1sWib_m) currently reports that it does not exist.
- [TiddlerCelestial versus Firebat, 2014 World Championship final](https://www.youtube.com/watch?v=6iWjx4piaZE) remains an identifiable official Hearthstone-channel upload, duration 47:24. A chapter/description locates game one at **09:10**; comments suggest **20:00** and **31:10** for later games. These are seek leads, **not inspected frame intervals**.
- [2013 Priest versus Hunter candidate](https://www.youtube.com/watch?v=DG4qNXLgxC4), published 2013-11-09 by gamezplay, is an uninspected third-party reupload despite "official" in its title.
- [2013 Reckful broadcast candidate](https://www.youtube.com/watch?v=1ECFzfGfIzU) and [mulligan-timer candidate](https://www.youtube.com/watch?v=0lDFzFhLm3g) are uninspected leads. The timer candidate's relevant client era was not authenticated.
- The currently available local period clip covers only **02:17.5–02:21.5** (`hearthstone_reference_research/reference-from-v14-comparison-137p5-141p5-960x540.mp4` in the shared workspace). It cannot establish opening or full-rope timing. Earlier board-readiness findings do not automatically verify these other flows.

Do not describe the rope or mulligan layout as footage-matched until a suitable sequence can actually be viewed. The prior Gamespress/Blizzard press-kit 401 was not bypassed.

## Original named timer audio

Five unchanged archive WAVs were researched and retrieved. The v19 source package retains only the three used cues in `assets/audio/flow/`; the two unused button cues are omitted to stay below the delivery size limit, with their source records retained. Their hashes, archive metadata, URLs, and measured PCM durations are in `licenses/audio/flow_timer_provenance.json`.

Provenance is the same public archival chain already used for the project's Charge study: [hearthsounds repository](https://github.com/mtimkovich/hearthsounds), [the checked source's archive base URL](https://github.com/mtimkovich/hearthsounds/blob/1479994b696cde168345fb68cf67aef3af5f0d9a/hearthsounds.py#L22), and [the maintainer's raw-filename explanation](https://github.com/mtimkovich/hearthsounds/issues/4#issuecomment-456666577). The [public object listing](https://storage.googleapis.com/hearthsounds?prefix=turn) supplied these exact names.

| Original filename | Duration | Format | Likely role from name only |
| --- | ---: | --- | --- |
| `turn_timer_fuse_unravels.wav` | 0.8490625 s | 48 kHz stereo PCM16 | Rope deploy/start |
| `turn_timer_fuse_burns.wav` | 4.6429478 s | 44.1 kHz mono PCM16 | Fuse burning texture |
| `turn_timer_end_turn_button_explodes.wav` | 1.9162500 s | 48 kHz stereo PCM16 | Timeout/button burst |
| `turn_timer_end_turn_button_flips_over.wav` | 1.0123333 s | 48 kHz stereo PCM16 | Turn button flip |
| `turn_timer_end_turn_button_opens.wav` | 0.6311458 s | 48 kHz stereo PCM16 | Turn button opening |

All five downloads match the archive's MD5/ETag and have separately recorded SHA-256 hashes. Their archive LastModified timestamps are 2018-11-29, not proof of a 2014 extraction. WAV chunks contain `fmt ` and `data`, with **no embedded loop metadata**. Repeating the burn texture is an implementation choice, not a verified original loop boundary. Subjective listening and original-client event-binding verification were not performed; exact named-archive identity is what has been established.

These are original named assets rather than synthesized or unrelated substitute sounds. They have not been transcoded, cropped, mixed from gameplay, or modified. Public archival access is not a redistribution license: game audio remains copyright Blizzard Entertainment and relevant holders; the project's use remains private unpublished study.

