# Independent targeting silhouette audit

Source build `37.0.0.255130.254477`. Only this analysis directory is edited. No original client, login, GPU, or production edits.

## Findings

The three scalar shaders use the same vertex coordinates: center UV from TEXCOORD1, with four offsets `uv + _MainTex_TexelSize.xy * _BlurOffsets.xy * [(1,1),(-1,-1),(1,-1),(-1,1)]`. There is **no center sample** in the blur. `HighlightMultiSample` returns the four red samples' sum times 0.25. `HighlightMultiSampleBlend` returns the maximum of that average and `_BlendTex.r` at the center. `HighlightMaskBlend` returns `saturate(0.300000012 * sum4(_MainTex.r) - 0.300000012 * sum4(_BlendTex.r))`. All four channels are copies of this scalar. The mask's blend samples use the **main texture's** offset even when its dimensions differ.

All three scalar passes and White/LightGrey/Grey/DarkGrey/BlackOverlay replacement shaders use One/Zero RGBA, ZTest Always, ZWrite Off, Cull Off, ZClip On, ColorMask RGBA. Replacement constants are 1, .75, .5, .25, 0 respectively with alpha1. Original surface texture alpha is not sampled or clipped. `Custom/UnlitColor` is distinct and is **not** a substitute for these replacement shaders: its state has CullBack and ZWriteOn.

The recovered CIL 0x0601527A establishes the 10-pass order and R8 format16, temporary FilterMode1, clear-to-zero, source-size offsets, and truncating float32 size factors. It matches `assets/data/eligibility_bindings.json::silhouette_pipeline`. All target writes need R8 quantization before they become later inputs. Canonical D3D conversion is `floor(saturate(value)*255 + .5)`. The [Microsoft D3D11 specification](https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm#FLOATtoUNORM) permits 0.6 integer ULP in FLOAT→UNORM conversion, so a canonical CPU reference is not a source-GPU bit-identity claim. The shader math contains no sRGB conversion.

`BlendBlit` negates the supplied positive blur value; resulting offsets are -1.25, -1.25, -1, -1.5 and -.800000011920929. RT sizes are base × .30000001192092896, .5, 1 and .9200000166893005 with truncation. Orthographic sizes are base minus .20000000298023224*renderSize, minus .25*renderSize, minus .009999999776482582*renderSize, plus .05000000074505806*renderSize and plus .10000000149011612*clipSize. **No horizontal aspect multiplier** is used: both ortho axes are [-size,+size]. The view is inverse TRS of the render-plane position plus optional offset, rotation `plane.rotation * Euler(90,180,0)`, scale `(1,1,-1)`.

## Current actor surfaces and projection

Source CIL accepts **any nonempty** `Material.GetTag("Highlight",false)` string, not only the literal "true". It checks enabled renderers, a valid MeshFilter/sharedMesh, and submeshes limited by the smaller of mesh/material counts. The highlight plane disables itself during rendering. Default source minion visibility yields only the main portrait+frame renderer, both submeshes. Attack/health gems do not have the Highlight tag. TierShield and Bacon cost have inactive ancestors; dragon banner is disabled. Details and all source IDs are in `minion_surface_eligibility.json`.

The source rechecks renderer visibility or an explicit force. A runtime port must also cover dynamically attached state meshes and changed material bindings; this static prefab inventory is not proof of live state inclusion.

The adapter draft's view, root-relative snapshot, square ortho and signed camera-depth range `[-(1+renderScale), -(1-renderScale)]` match the current positive-uniform source hierarchy. Source `GetWorldScale` multiplies componentwise localScale through all ancestors. Draft `basis.x.length()` is equivalent for current positive-uniform hierarchies, but not for arbitrary signed/nonuniform rotated hierarchies. Root translation cancels between view and mesh transforms.

## Tests and files

- `verify_highlight_formulas.py`: independent scalar and canonical R8 image pass functions, validated against source decoded instructions. 6,144 randomized shader cases plus 1,800 sampled image cases pass with zero error. It also checks five replacement outputs/states.
- `formula_validation.json`: full results.
- `audit_actor_surfaces.py`: reconstructs minion source hierarchy/material/tag eligibility.
- `compare_pass_captures.py`: read implementation PNGs named dark, grey, blend1, light1, blend2, light2, blend3, blur, clip, silhouette. Compares five postprocess outputs against observed inputs under ideal/fixed8 bilinear and clamp/repeat options.

## Remaining boundaries

No source GPU comparison or triangle coverage test occurred here. Native Unity temporary/final RenderTexture wrap defaults were not recovered: HighlightRender and RenderTextureTracker set no wrap mode. The CPU adapter currently uses clamp as an explicit compatibility choice. The oracle supports both modes so actual black-border captures can establish whether this matters for the selected actor. Source final R8 missing channels are irrelevant because the highlight material reads only red. The targeting worker subsequently recovered `_ShaderTime` in `../shader_time_runtime.cil.txt`: enabled time advances by float32 deltaTime/20 with the source single-wrap behavior, while the disabled shader value is1. Raw wall-clock seconds are not equivalent.

The production highlight material uses a Godot GL color bridge and default blend_mix. The original blend uses source-alpha for both RGB and alpha, so a transparent-target source-alpha bridge is still required for source alpha identity. This audit does not equate the scalar silhouette test with that final compositing proof.


## Actual adapter fixture verification

The minion adapter's ten exported pass images were read independently. All five scalar postprocess outputs match the separate Godot CPU precision model **byte for byte** (`capture_cpu_passes.json::godot_cpu_precision`). An ideal float64/source-equation reference has only single-byte differences: blend2 4 pixels, blend3 37, blur 134 and final silhouette 1 pixel; blend1 is exact. The differences disappear when modeling float32 Vector2 coordinates and red texel reads plus double scalar interpolation, establishing the implementation's precision source rather than hiding it behind a large tolerance. Clamp and repeat references are identical for this fixture; all borders remain clear.

`projection_validation.json` comes from a headless Godot 4.6.3 matrix-only test, with no GPU renderer. It uses the actual source plane quaternion and actual `Basis.from_euler` order. Source plane vertex `(+.499875,0,-.499875)` projects to image UV approximately `(0,0)`, matching the existing once-flipped Godot UV. An extra Y flip would be wrong for this adapter.

GLES3 mask color behavior was checked against official [Godot 4.6.3 texture storage](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/drivers/gles3/storage/texture_storage.cpp): `Image::FORMAT_R8` is uploaded as GL_R8/GL_RED/unsigned byte. The local saved shader compiler and material binding source confirms the low-end texture call has no source-color decoding wrapper. Thus retaining `_MainTex : source_color` on this current R8/GLES3 route does not introduce sRGB decoding. A dedicated non-color sampler is clearer for future backends, but no present GL bug was established, and the global shader was not changed.

`hero_surface_eligibility.json` adds the hero's full source ancestor chains and all 13 renderers. Only `Card_Play_Hero/RootObject/Mesh` contributes by default: frame submesh0 and portrait submesh1, with exact original mesh and material identities. No other recovered hero renderer has a nonempty Highlight tag. Root's authored 1.11 scale is normalized away during silhouette creation; mesh local scale .909909069538, position `(0,.044500000775,0)` and original Y-half-turn quaternion remain. Neither this evidence nor a clone proves the legacy on-board hero image is the same live source actor.

## GPU draft review and separate actual-GPU gate

`gpu_static_review.json` hashes the reviewed GPU draft and records the static findings. The source schedule, shader math, nested viewport dependency order, no-half-pixel/no-extra-flip mapping, numeric canvas output, highp defaults and RGBA8 red storage were checked against original source and official Godot4.6.3 code. An important engine distinction was found: opaque no-HDR viewports internally use **RGB10_A2**, while transparent no-HDR viewports use **RGBA8**. All ten draft viewports now explicitly choose the latter, with no MSAA or pixel snapping. MaskBlend preserves separate .3 products; source float32 ortho constants are explicit.

`GPU_CAPTURE_SPEC.md` and `gpu_capture_manifest.template.json` define the actual-GPU evidence contract. `compare_gpu_pass_captures.py` reads QA's ten PNG targets, checks dimensions/uniforms/format/generation, and independently evaluates the five scalar outputs from their actual input targets. It deliberately does not use CPU-byte equivalence as GPU proof. `gpu_harness_selftest.json` records seven **synthetic, non-GPU** parser/comparison tests. Actual GPU pixels, triangle raster coverage, dynamic attachments, frame freshness, lifecycle and final composition remain QA gates until captures arrive. Official engine source files and hashes are in `godot_source/index.json`.

Actual captures subsequently arrived: `gold-second-capture/RESULT.md` records the independent audit of80 targets. All40 constant images match source levels. All40 scalar images are exactly reproduced by the independently implemented Mesa25.0.7 backend model, including its8.8 fixed sampler and per-axis UNorm8 rounding; final MaskBlend matches balanced addition, consistent with compiler reassociation. This backend result is distinct from original D3D bit identity: the original ideal-reference reports, including final≤1byte differences, remain preserved. The frozen unit changes all10targets while unchanged actors retain identical outputs. Hero/ice masks touch borders, so addressing matters. The parent's exact-API Unity6000.3.10f1 Metal/Gamma probes were independently verified: final ClampUVW and temporary ClampUV, with temporaryW unmeasured. `source_addressing_evidence.json` attaches that measured provenance to all8 rechecked captures. `dynamic_final_sampler_review.json` verifies the separate final-RT clamp shader leaves old baked routes and flare repeat unchanged.
