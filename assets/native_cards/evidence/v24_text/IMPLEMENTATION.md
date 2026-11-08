# v24 Unity-sampled full-title input

Active input: assets/unity_middle_sample/glyphs.json and atlas_rgba.png (104 requested glyphs, no missing; 512x1024 atlas), Unity6000.3.10f1 / Apple M3, exact original GLEI00M_t_Outline font SHA, request size46. Older23-glyph UpperLeft sample is retained separately in assets/unity_glyph_sample for provenance. This is a new Unity font sample, NOT an original client captured atlas; target source client6000.3.11f1 differs. Atlas RGB is black; original nine-tap equation uses only alpha.

All title strings with full sampled coverage use native CharacterInfo quads. Missing sampled characters trigger explicit per-title Godot fallback. Title bounds width comes from real summed advances; same-font single-line height4.626953125 derives from native measured bounds and agrees with font hhea metrics. These bounds are not ink-union bounds.

Each glyph uses minX/maxX/minY/maxY plus cumulative advance. Four separately named CharacterInfo UV corners preserve rotated atlas entries. PNG V is inverted once. Original title RTT300x47/44 and original name-curve mesh remain unchanged. Glyph pixel-to-local scale is characterSize*.1 (.005 at source .05).

MiddleCenter/Center baseline no longer uses ad-hoc ink centering. Original TTF hhea: unitsPerEm1024, ascent900, descent-124, lineGap6. At font46:
linebox =46*(900+124+6)/1024*.1 =4.626953125.
baseline =-46*900/1024*.1 + linebox/2 =-1.7294921875 at charSize1.
At source charSize.05 baseline=-.086474609375. Horizontal origin=-sumAdvance*.1*charSize/2.
Independent registration to two native MiddleCenter Unity screenshots fitted dy=-1.7295914/-1.7294107, agreeing within .00010world (<.0043pixel at sample camera). This establishes an evidence-backed baseline equation but is NOT a native vertex export: MeshFilter is absent in Unity TextMesh.

Race/body/number text still uses existing v23 path; no claim of full-text native-atlas replacement. No original-client same-condition screenshot is available. No pixel identity claim. Original managed shader equation and rendering compatibility boundaries from v23 remain applicable.
