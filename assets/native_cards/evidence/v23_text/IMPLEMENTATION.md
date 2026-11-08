# v23 source-equation title experiment

Changed only independent v23 title rendering and viewport-freeze lifecycle.

Implemented from managed source (see FINDINGS.txt and resolved-critical-il.txt):
- CalcTextureSize long edge 300, W=1.9/H=.3 or .28 -> 300x47/44. Normal-quality branch used explicitly; live original render-quality setting unavailable.
- Raster fontSize float32(40 * zhCN FontDefinition 1.15), truncated ->46. Locale modifier provisionally 1; separate locale overrides not verified.
- Character size starts .05; measured width is advance *.05*.1. Reduce character size by .95, at most40 iterations, not integer raster-font decrement.
- Equivalent centered orthographic 2D projection into RTT W/H; the original Unity camera matrix is documented but not executed by Godot.
- Original nine-tap outline algebra applies to the actual **Godot glyph atlas**, with outline offsets three atlas texels. It does not operate on the final card/title RTT. Default Godot outline disabled.
- Clear pass writes source outline RGB and alpha zero (blend_disabled), rather than black-transparent.

Boundaries: Font.get_string_size/get_height are Godot measurements, not original Unity TextMesh.bounds; glyph quad geometry, padding, hinting, alpha atlas, filtering/color space and potential locale overrides remain unverified. This shader port alone cannot establish equivalent outline clipping or pixel parity. Minimum character-size clamp is source serialized m_MinCharacterSize=1.0 × .01 = .01; see name-serialized-anchors.json (both normal name components). Native original name mesh/UV unchanged. No v22 files changed.

Lifecycle: pending weak references indexed by viewport instance ID, three process frames then UPDATE_ONCE; no suspended freeze coroutine survives renderer destruction.

Audit records update_mode/name and pending_redraw; frozen=true only when explicit DISABLED is observed, otherwise null (unknown). UPDATE_ONCE consumption cannot be established from a getter that still reports ONCE. This does not alter rendering.
