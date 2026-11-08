# Native text-role probe — completed

Actual Unity6000.3.10f1(e35f0c77bd8e), Apple M3, Metal; first execution succeeded exit0. Input package size7121645 SHA25635f83f256294147b599b5ed4c2e89eab6e19c62cf47916e22e0adcd26e8456d6. Source reviewed; no source changes, no compatibility fixes needed. All previous title results untouched.

body: BlizzardGlobal40 Normal,115 requested characters,113 visible glyphs all available/nonempty,197 actual TextMesh measurements, atlas512x512; four diagnostic screenshots nonempty. Space available advance11 with no ink; newline unavailable as an individual CharacterInfo and is excluded from missing-visible-glyph failure. For any available=false entry all returned metric/UV values must be treated as undefined, including newline advance40. Bold material runs retained in request.actual.json, all TextMesh richText=false/FontStyle.Normal, not a rendered original bold shader.

belwe_digits65:12 available nonempty glyphs,2 measurements,atlas256x256 and one nonempty full-digit screenshot. glei_digits74:12 available nonempty glyphs,2 measurements,atlas256x256 and one nonempty full-digit screenshot. Candidates remain separate; no claim identifying the final game digit font.

Each font SHA matches supplied preparation evidence. Actual importer size/spacing/padding/rendering/legacy/round/fallback checked against request. Original unknown ascent mode NOT overridden, actual imported mode1 for all roles. Per-role final bulk request precedes delayed UV/metrics/atlas export, no role atlas mixing; validation checks each visible glyph's UV region has nonzero alpha. All197 body IDs/text/anchor/lineSpacing and both digit text sets verified against request. Renderer geometry remains actual bounds with no fabricated mesh.

layout-basis-validation.json computes height(|newline|)-2*height(|) separately for matching anchor/lineSpacing groups and includes raw measurements. Empty text included as measured, not substituted for missing mesh.

Camera RTTs are new diagnostic cameras, not original game cameras:1024x256 ARGB32Linear depth16 MSAA1, transparent clear, layer30, HDR/MSAAoff; orthographic size=max(3,boundsYextent*1.2,boundsXextent/4*1.2),aspect4, position(bounds.center.x,bounds.center.y,-10),identity rotation,near0.1 far100. Exact per-image position/size in glyphs.json. Native font.material and white vertex color used.

Each role includes font.ttf/meta, glyphs.json, RGBA/alpha atlas, validation and redacted execution log. Global redacted log retains actual runtime warnings; no compiler errors or probe failure. Unity's normal background license/config behavior is outside the offline script; no manual licensing/account changes or software installs. This is exploratory native Editor Font/TextMesh sampling, not original Hearthstone/UberText/client fidelity certification.
