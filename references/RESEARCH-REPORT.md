# Original asset research, v14

## Ready for private research integration

1. **In-play UI**: `joust/assets/images/` contains source bytes from HearthSim/Joust commit `253e5770258f81ac9e7952f9a480e40a10f45d19`. Git blob identities and PNG decoding verified. The required ring, Taunt shield, hero socket, hero-power open/closed socket, mana crystal, sleep icon and classic state markers are present. `joust_manifest.json` holds exact URLs, checksums and sizes. `JOUST-COMPOSITING.md` records source component draw order, art rectangles and masks.
2. **Official-site Belwe Bold**: `fonts/Belwe-Bold-official-web.ttf`, source chain in `official_font_manifest.json`. Retrieved from the font URL referenced directly by the live official Hearthstone site's stylesheet. Internal metadata dates the font to 2016/2017. It is not the authenticated 2013/2014 client font.
3. **Cursor**: three 32×32 classic silver hand PNGs in `codepen_reference/`; source CSS hotspot (10,2). `CURSORS-PROVENANCE.json` includes downloaded-byte SHA256 and matching GitHub repository blob SHA1 for all three. Both public hosts are community copies; exact client version is unknown.
4. **2014 raw UI textures**: `exmex_reference/` includes 41 raw DDS files and direct RGBA decodes. Full inventory in `EXMEX-INVENTORY.json`; preview `exmex_reference/contact.jpg`. Key original-style ring, Taunt and power assets are present. Git file histories establish these files existed in October 2014, but do not authenticate original client build/extractor. These are mesh/UV textures, often packed or inverted relative to screen orientation; they should not be blindly used as flat sprites.
5. **Alternate Belwe**: `fonts/Belweb-2014-community.ttf` is Bitstream Belwe Bold BT, internal version 1999, present in the 2014 clone repository. Recorded for comparison only. Client extraction authenticity and redistribution license unverified.

## Pandaria: exact remaining gap

No verified public original clean Pandaria board, complete geometry/UV/material package, or assembled board-only render was obtained. No generative board was made.

- Joust has original-style in-play UI, but no decorative full board background.
- Sunwell is a card renderer; it lacks in-play rings/sockets and full board art.
- HearthSim/HearthAssets is also a card renderer; its `bg-*` images are card-set watermarks rather than game boards.
- The accessible 2014 clone board atlas `exmex_reference/1d9b3840.png` is visually Stranglethorn Vale: waterfall, jungle foliage and ruined stone structures. Companion tree/props atlases are also Stranglethorn. It is a raw packed texture, not a complete flat board.
- `exmex_reference/1d9b3700.png` is useful original-style tavern wood/blue-cloth surround material; it is not the Pandaria board.
- CodePen's `hearthstone-battlefield.jpg` is the Grand Tournament board with baked heroes, stats and mana. It is unsuitable for this target.
- Rymedy's four board/background images are later expansion boards and contain baked UI pieces; none is Pandaria.
- Search located a paid TurboSquid fan-created Pandaria/Orgrimmar model, not a verified Blizzard original. It was not downloaded or purchased.
- Hearthstone Wiki board page returned 403. No alternate route was used to evade it.
- 23 of 64 DDS requests from the 2014 community repository returned `Tunnel connection failed: 403 Forbidden`. Those files were not retried through an alternate route. Their exact URLs are recorded in the manifest. Therefore the unacquired subset cannot be visually ruled out; this is a partial inventory, not proof that the repository has no Pandaria asset.

The existing official 2013 Priest vs Hunter video remains the strongest provenance for the exact target board appearance. Any future frame-derived composite must be labeled as a video reconstruction and exclude baked live gameplay/UI. It would not establish possession of the original board geometry, materials, or exact texture files.

## Other gaps

- No verified original Franklin Gothic client font binary was obtained. Sunwell identifies the proprietary family; Joust references `franklin_gothic_fsMdCn` and `belwe_fsextrabold` but bundles only FontAwesome. The current official website uses Open Sans for body text and Belwe Bold for display; its retrieved CSS contains no Franklin Gothic.
- No separate, authenticated classic end-turn button texture was obtained. Joust uses a CSS/HTML button, not the game's art. Some raw UI atlas fragments remain functionally unidentified; do not label them as the end-turn button without verification.
- No installation, game-client download, login, paid download, CAPTCHA-solving or security bypass was performed.

## Rights and version provenance

Public availability and repository code licenses do not grant rights to publicly redistribute Blizzard art or proprietary fonts. Joust explicitly identifies Blizzard-owned textures; Sunwell's MIT code license also distinguishes its copyrighted assets. Official website font delivery is not a game embedding license. Keep these assets within the requested private research scope unless appropriate permission is separately established.

Joust's current in-play minion/Taunt files last changed 2016-02-20; hero power 2016-02-18; hero frame 2016-02-23. None is authenticated as a client 1.0.0.5834 extraction. The raw exmex texture repository does have an October 2014 commit, which is stronger date evidence but still lacks exact game-build attribution.

## Primary source links

- https://github.com/HearthSim/Joust/tree/253e5770258f81ac9e7952f9a480e40a10f45d19
- https://github.com/HearthSim/Joust/blob/253e5770258f81ac9e7952f9a480e40a10f45d19/src/styles/entities.less
- https://github.com/HearthSim/Joust/blob/253e5770258f81ac9e7952f9a480e40a10f45d19/src/components/game/visuals/InPlayCardArt.tsx
- https://hearthstone.blizzard.com/en-us/
- https://github.com/exmex/HS_Multilang/tree/0c73156969790fa46ebb3b65f0209a7ce104861b
- https://codepen.io/backstap/pen/ZoKzPy
- https://github.com/Rymedy/hearthstone-web/tree/8d831088f96ec5c2e47d969e998f63ebcc5d6d56
- https://github.com/HearthSim/Sunwell
- https://github.com/thomastuts/hearthstone-api/issues/5 (2014 archive classification: boards0 for board textures, gameobjects0 for much interface art)
