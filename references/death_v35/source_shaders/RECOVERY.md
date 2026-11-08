# v35 original minion death shader recovery

Build: **37.0.0.255130.254477**. Input objects are the exact restored Windows bundle objects in `../source_death_assets/assets/manifest.json`, checked against the build's official install content hashes. `shader_evidence.json` includes source bundle provenance, CAB/path ID, material values, sampler state, keyword variants and constant-buffer maps. Every decompressed program entry is preserved as `entryN.bin`; executable D3D SM4 bytes are additionally `blobN.dxbc`, with decoded instruction text next to them. No original client, login or unknown software was run.

`formula_validation.json`: **24,576 cases passed** (4,096 each for six source shader classes), plus six serialized pass-state assertions and independent output-merger checks. This is arithmetic and binding verification against an independent DXBC instruction interpreter, not a screenshot/raster/GPU/client match. Source instruction operands retain encoded float32 constants, while the CPU verifier evaluates in float64. Maximum discrepancy is ordinary floating expression ordering (under 1e-13).

## Exact recovered equations

Let T be the sampled RGBA texel, C be interpolated mesh/particle vertex RGBA, K be material `_Color`, Q be `_TintColor`, b be `_LightingBlend`, and H(s)=saturate(1.05499995*abs(s)^0.416666657-0.0549999997) for the W coefficients of the three Unity SH vectors. Source shader samples use `_GlobalMipBias.x` except the Legacy particle shader.

1. **Custom/Card/UnlitDesat**, path -477307002458744689, blobs 1/3:
   - UV = UV0 * `_MainTex_ST.xy` + `_MainTex_ST.zw`.
   - V = mix(C, vec4(H(SH),1) + `_MainLightColor.rgba`, b).
   - g = 0.300000012 * `_ValueRange` * (T.r+T.g+T.b).
   - S = mix(T, K*g, `_Transistion`) * V.
   - Equal RGB weights are intentional, not Rec.601/709 luminance. The transition affects all four channels. The source typo `_Transistion` must be retained. Source `_Color` is *only* on the desaturated target, not a tint of the original full-color endpoint.
   - Material: ValueRange=1.2686567306518555, Transistion=0, LightingBlend=0, Color=white initially. Animation/controller must provide source transitions; no guessed curve is built into shader.
   - One/Zero RGB and alpha, ZWrite on, ZTest LEqual, Cull Back. This is opaque, not a fading transparent particle. `_MainLightColor.a` can affect V.a when b!=0; draft exposes `_MainLightAlpha` separately, whose initial value is a declared compatibility default.

2. **Custom/Card/SelfIlluminDiffuse**, path 4578800529589026196, unshadowed `_ADDITIONAL_LIGHTS` blobs 3/15:
   - **UV=UV0**, with no ST transform. Source `_MainTex` has no-scale-offset property flag.
   - World normal is normalized inverse-transpose transformed source normal. The fragment normal is normalized again.
   - L = H(SH) + mainColor * unity_LightData.z * saturate(dot(N,mainDirection)) + sum(additional diffuse).
   - For each additional light: delta=lightPosition.xyz-P*lightPosition.w; d2=max(dot(delta,delta),0.0000610351562); direction=delta/sqrt(d2); spot=saturate(dot(spotDir,direction)*attenuation.z+attenuation.w); contribution=lightColor/(1+25*d2*attenuation.x)*spot^2*saturate(dot(N,direction)).
   - S.rgb=T.rgb*K.rgb*(L+`_Illum`); S.a=T.a*K.a. It is **not** Hero/Self-Illumin_Diffuse's ambient-mix formula.
   - Material Illum=0.9469913840293884, Color=(1,0.9546998739242554,0.886274516582489,1).
   - One/Zero RGBA, ZWrite on, ZTest LEqual, Cull Back. Texture and color alpha are source target values, not fade factors. Vertex COLOR is not consumed by this shader.

3. **Legacy Shaders/Particles/Alpha Blended Premultiply**, path 1291840640910692172, SOFTPARTICLES_OFF blobs 2/6:
   - UV=UV0*ST.xy+ST.zw, V=C, S=T*C*C.a.
   - In particular S.a=T.a*C.a^2. Multiplying RGB by T.a would be wrong.
   - One/OneMinusSrcAlpha RGB, **ColorMask RGB (14)**, ZWrite off, ZTest LEqual, Cull Off. Destination alpha is never changed.
   - SOFTPARTICLES_ON blobs 3/7 are preserved and decoded: f=saturate(_InvFade*(1/(ZBufferParams.z*sampledDepth+ZBufferParams.w)-particleEyeDepth)); C.a is first multiplied by f, then the same T*C*C.a equation is used, so RGB gains f and alpha gains f^2. Scene depth/camera binding is not yet supplied by the draft.

4. **Hero/Particle/Particles_Transparent**, path 1610204260223125505, blobs 1/3:
   - S=T*(2*C*Q)*vec4(mix(1,H(SH),b),1)*vec4(_Intensity.xxx,_Alpha).
   - This shader does **not** add main-light RGB. The two selected non-Gold materials DustA/Rock3 resolve dynamic blend names to SrcAlpha/OneMinusSrcAlpha in RGB **and alpha**. Both have Intensity=Alpha=1.
   - ZWrite off, ZTest LEqual, Cull Off. Glow pass exists in the source, but both selected materials have GlowIntensity=0, so its contribution is zero.

5. **Hero/Additive/Additive**, path -666151408197827071, blobs 1/3:
   - S=T*(2*C*Q)*vec4(mix(1,H(SH)+mainLight.rgb,b),1).
   - The shader uses `_TintColor`, **not** `_Color`: the exact constant-buffer map identifies `_TintColor` at UnityPerMaterial byte16. GenFX_Wisps2 has Q=(0.12401384115219116,0.2524526119232178,0.501960813999176,0.0784313753247261), b=0. The serialized white `_Color` is not consumed.
   - SrcAlpha/One RGB and alpha, ZWrite off, Cull Off. Source glow intensity is zero.

6. **Hero/Unlit/Unlit_TransparentColor**, path 4454903573088140019, blobs 1/3:
   - S=T*C*K*vec4(mix(1,H(SH)+mainLight.rgb,b),1).
   - SrcAlpha/OneMinusSrcAlpha RGB **and alpha**, ZWrite off, Cull Back. Used by DeathSplatSkull.

For alpha blending the source framebuffer alpha is As*As+Ad*(1-As), not Godot blend_mix's standard alpha accumulation. Existing dual capture path must continue to handle this.

## Draft handoff

`drafts/native_death_materials.gd` exposes build(key,assets,texture_override=null), using the existing source asset and sampler adapters. Copy `shader_routes.json` to `res://references/death_v35/shader_routes.json`; copy draft shader files to `res://shaders/`. Three already-recovered routes reuse `native_combat_transparent`, `native_combat_additive`, and `native_combat_transparent_color`; no new visual approximation is needed for them.

Three new base shaders are `native_combat_death_unlit_desat`, `native_combat_death_self_illumin_diffuse` and `native_combat_death_legacy_premultiply`. Opaque shaders do not write Godot ALPHA, preserving source depth and sorting. Their separate alpha capture writes the recovered source alpha into RGB for downstream target-alpha reconstruction.

For Legacy ColorMaskRGB, use color capture with premultiplied RGB and As, and retain the existing destination alpha. Its alpha capture is **ALBEDO=0, ALPHA=0 with premul blend**, an identity operation. Its RGB transmission capture is **ALBEDO=0, ALPHA=As**, producing Tout=Tdst*(1-As). Do not confuse RGB transmission with source framebuffer alpha. `source_alpha_write=false` and `source_colmask=14` metadata identify this behavior.

## Sampling, transforms, and honest boundaries

- Every selected original death texture except Default-Particle has one mip level, Repeat U/V/W, Trilinear mode, anisotropy1, texture mip bias -0.5. With only one original level, ordinary bilinear sampling is equivalent with respect to mip choice. Do not generate new mips.
- Default-Particle has seven original mip levels, Bilinear mode, Repeat and bias0. Use the source asset worker's original mip export and current nearest-mip bilinear adapter. Derivative/LOD tie behavior remains a rasterizer compatibility boundary.
- The current adapter flips mesh UV Y and conjugates material ST Y. The shader drafts accept those adapter coordinates. No second Y flip belongs in these formulas. SelfIllumin does not use ST.
- Source mesh winding and normals must use the existing Unity-to-Godot handedness transform before CullBack is meaningful.
- Original **live** SH W values, main light direction/color/alpha, additional lights and per-object light selection are not recovered. Draft defaults are compatibility defaults, not observed original scene values. The SelfIllumin implementation accepts up to eight resolved per-object additional lights.
- Source SelfIllumin shadow/soft-shadow variants and vertex-additional-light variants are preserved as original programs; the draft implements the unshadowed per-pixel additional-light variant. Actual original enabled global keywords have not been established. Do not claim pixel parity for those missing variants.
- Legacy soft-particle shader is decoded but the draft selects the no-soft-particle variant because original live keyword/camera depth has not been established. Do not infer this choice from shader name or initial renderer enabled state.
- Same-build normalized-target handling and the preexisting Godot compatibility color bridge are retained, clearly separate from source shader algebra. HDR, framebuffer quantization, depth precision, interpolation, texture decoding, transparent ordering and GPU backend parity were not proven by these CPU tests.
- Default-Particle is genuinely reachable: FX_RockEmitter starts with renderer disabled, but the source t=0.5 SetVisibilityRecursiveAction(includeChildren=true, resetOnExit=false) unconditionally reenables it. Original seven mip levels were exported by the asset worker, 21,844 bytes, not regenerated. The death texture CAB differs from the old hardcoded loader key, so integration must load by files.rgba8_mips.
- No GPU test was started by this worker and no production file was modified. Integration and GPU rendering QA remain with their assigned workers.
