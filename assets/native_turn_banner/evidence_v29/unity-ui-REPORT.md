# Native turn-text probe — completed

First run successful exit0; Unity6000.3.10f1(e35f0c77bd8e), Apple M3, Metal. Existing isolated project/font reused, only new TurnTextProbe.cs added. No other game project, software installation, login or manual license settings changes. Previous probe outputs untouched.

Group57: 你的回合, font57 Normal, requested characterSize0.007099999785423279; actual Unity float reads0.007099999580532312, recorded without pretending decimal equality; independently characterSize1. Group36: 结束回合 / 对手回合 / 等待, font36 Normal, characterSize0.07 (runtime float0.07000000029802322) and independently characterSize1. All lineSpacing1, MiddleCenter/Center, identity transform, richTextfalse.

All8 Renderer bounds were directly read after deferred update; no scaled prior data substituted. Raw center/extents in glyphs-bounds.json; validation separately compares measured scaled bounds with measured unit-size bounds, residuals below1e-6.

Each group saves complete CharacterInfo advance/minmax/widthheight/four-cornerUV and final atlasRGBA preserving alpha, plus alpha visualization and font.meta, BEFORE any next-size request. Both role sets completely available, all UV regions nonempty. Same dynamic Font is reused sequentially, so group36 atlas may retain earlier-size glyphs; only its own JSON UVs correspond to that saved atlas. Never use font57 JSON UVs with font36 atlas. Existing import16/spacing1/padding4/Smooth/legacytrue/roundtrue/ascentmode1/emptyfallback preserved. GLEI SHA256b540fd60e6f44d3263c971861ebfec2b79788b20b94b2c753431b4480108e3e5 verified.

No optional camera screenshots were generated. Output is native font sampling and actual bounds only, not original Hearthstone rendering or strict original-version proof. Full source, actual version, validation and redacted runtime log included.
