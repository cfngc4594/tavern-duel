# Charge readiness audio research

Checked 2026-10-16, 10:39–10:41 UTC. Research only; no gameplay scripts, existing audio, or per-card voice mappings changed.

## Initial source pass (superseded by successful independent-source lookup)

This initial pass did not find a separate original Charge/readiness/landing cue. A later independent-source lookup found `Charge_Summon.wav`; see `CHARGE-KEYWORD-AUDIO.md` and `licenses/audio/charge_keyword_provenance.json`. The shipped v7 uses that unchanged exact-named original source, not a relabeled effect. This does **not** establish that Hearthstone has no such sound; it means the checked sources do not identify and provide one reliably.

## Checked sources

1. The existing [Hearthstone General Sound Effects archive](https://sounds.spriters-resource.com/pc_computer/hearthstone/asset/396767/) was inspected in full locally. It contains 204 ZIP entries: one directory, 202 OGGs, and a README. Its SHA-256 is `f638589633ed00e2bb624f648eae2f60fcef77d949e676042c516ca5d8d53fae`, matching `licenses/audio/source_proofs.json`.
   - No entry name contains `charge`, `ready`, or `exhaust`.
   - `General SFX/FX_MinionSummon01_DrawFromHand_01.ogg` names a hand-to-board summoning transition, not a verified Charge readiness or landing sound.
   - `WoW_whirlwindshort.ogg`, `Shared_Physical_Start_Vox.ogg`, and `collection_manager_drop_card.ogg` cannot be identified as Charge cues from this archive. No one has been copied or reassigned as Charge.
   - The README credits Thecheat's Disunity extraction and Hearthstone's developers. This is a community archive's provenance claim, not independent authentication against a Blizzard client.
2. The previously downloaded [Wolfrider page](https://www.hearthpwn.com/cards/174-Wolfrider) explicitly maps its Play, Attack and Death controls to rider voices and separate wolf sound layers. It exposes no distinct Charge/readiness event. The exact links and hashes are already recorded in `licenses/audio/card_audio_downloads.json`.
3. The [Charge spell page](https://www.hearthpwn.com/cards/646-chargem) was checked with an ordinary anonymous GET: HTTP 200, zero HTML audio elements. HTML SHA-256 at the time was `90cffa9910fdebe7bd7fed13e54ce50718fa6532a0220b3c0c209c4fd496c950`. A spell named Charge would in any case need separate verification before its audio could be assigned to the minion keyword.
4. Existing local HearthSFX metadata lists empty sound arrays for `CS2_103`, `VAN_CS2_103`, and `CS2_124`; it provides no global keyword event mapping. Public search produced no verified exact filename for the requested global cue. No blocked source was retried.

## Verified nearby asset, not a Charge cue

- Existing project path: `assets/audio/cards/CS2_124/SFX_CS2_124_Wolf_EnterPlay_00.ogg`
- Original identity: Wolfrider (`CS2_124`) wolf entry sound layer; HearthPwn's `soundPlay2`.
- Source page: https://www.hearthpwn.com/cards/174-Wolfrider
- Direct original media link: https://media.hearthpwn.com/audio/card-sounds/sound/SFX_CS2_124_Wolf_EnterPlay_00.ogg
- SHA-256: `f5b2bc2f74daf50e66565261a97e02e6f815340b39f1a4577c9274daaed4463b`
- Appropriate use: retain with Wolfrider's existing English rider entry VO, `VO_CS2_124_Play_01.ogg`. It must not be presented as a universal Charge cue or reused for other minions' Charge state.
- Verification limit: card/action mapping and unchanged source bytes were established in the earlier download audit. Exact 2014 client identity, complete original mix, and a distinct Charge layer have not been established.

## Access and rights boundary

Previously denied Firestone CDN, wiki, Card Sound Effects, HearthSFX S3, and Out of Games download routes were not retried or bypassed. No guessed media paths, proxying, credential changes, synthesis, extracted gameplay mixes, or substitute effects were used. Existing English per-card voice files remain unchanged. Original-game audio remains copyright of Blizzard and other rights holders; this research does not establish public redistribution rights.
