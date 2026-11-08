# v25 direct sampled glyph rendering

Race: source font40*zhCN1.15=46, characterSize3.5*.01=.035, outline3 atlas texels, original outline RGB and .85x.17 box. Direct XY glyphmesh attached to original label transform, no RTT, billboard or Label3D. Uses real Unity104-character sample, four-corner rotated UV and font hhea MiddleCenter baseline. GUI verified both Demon/Beast tags.

Body pipeline now uses supplied native BlizzardGlobal font40 sample (115 characters): original5834 rich_desc_base from verified CardDefs, <b> mapped to separate material/surface; no keyword-generated bold and no user rules changed. Exact eight-tap bold uses four .6 diagonal plus four cardinal samples, excludes center, alpha .230000004*sum*tint.a, no shader clamp. Normal mode uses atlas alpha. Source outline=false is respected; does not use title nine-tap.

Body layout uses fixed font40 raster, initial characterSize.05 and repeated*.95 down to.01, max40 steps. No raster-font shrinking. Chinese token rules preserve punctuation and digit/slash clusters; Underwear forbidden regions and UpperCenter temporary measurement equations follow source CIL. Bounds use a hhea/advance model independently verified against 197 native TextMesh bounds (maximum error4.58e-6world) and four diagnostic images (MSE2.97–3.25e-7). They are not freshly captured per-iteration native calls; this scope distinction remains explicit.

Numeric pipeline uses verified zhCN GLEI route, font65*1.15 truncated74, source character sizes/colors/outline2.5. Source numeric ResizeToFit=0: no box-based shrinking. Belwe65 is not the selected zhCN route. Native cost update rebuilds glyph geometry and uses green/red/white per base/current comparison. Fallback remains explicit when sampled characters unavailable.

Unity6000.3.10f1 samples differ from source-client6000.3.11f1. No original client same-condition screenshot exists. Source transform/shader equations and native font samples do not establish pixel identity.

Race ResizeToFitAndGrow is enabled in original serialized component: non-wrap ratio=min(H/boundsY,W/boundsX), lower clamp.01; native sample linebox/advance used. Numbers original ResizeToFit=0, no generic shrink.

Title final curve now executes original Hidden/TextAntialiasing sample equation: center RGB; sum of four half-texel diagonal alphas times.5; no center alpha/no shader clamp. Original Metal archived in ../title_rtt_aa/. CullBack is now matched with name-only triangle winding conversion, verified by independent front/back GUI coverage. Remaining render-state difference: original RGB/alpha SrcAlpha/OneMinusSrcAlpha; Godot blend_mix has alpha ONE/ONE_MINUS_SRC_ALPHA, so alpha blending is not yet identical. Coin true neutral atlas recovered, no blue-frame compatibility exception remains in v25.

Native role inputs are assets/unity_body_sample and assets/unity_number_sample. Schema and requested font sizes verified; numeric selected dataset is glei_digits74, not Belwe65 comparison. Original Mac reports/capture source/request retained alongside this document. Actual GUI validation is recorded separately by QA.

Final audit snapshots are deep-copied so later dynamic cost updates do not mutate earlier recorded colors. Full GUI inspected:30 titles,30 numeric sets,25 nonempty descriptions,6 races use sampled glyph inputs; four additional old practice titles remain declared fallback.
