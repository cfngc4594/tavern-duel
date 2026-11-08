# Remaining combat shaders, fixed Windows build

Source build: **37.0.0.255130.254477**. This work uses restored original serialized shaders, original Windows DXBC, original material properties and texture metadata. It does not run the original client. v30/v31 were not changed.

## Coverage and production routes

The restored combat closure contains **38 shader identities**, not 38 distinct currently used effects. **32 identities have material references**, representing **28 unique path IDs/formula families**. Five Hero/Additive/Additive identities in different bundles have the same path ID and exactly identical serialized shader-data SHA256. Existing combat translations cover 11 families; the 17 new main shaders below cover the rest.

**All 126 material objects were instantiated through the current production NativeCombatAssets.material constructor. All 126 return ShaderMaterial; StandardMaterial/untranslated fallback list is empty.** See `production_material_route_audit.json` and `.log`, independently corroborated by `TavernDuel/references/combat_v32/runtime_material_audit.json`. This is material binding coverage, not a statement that disabled renderers should be enabled, that every effect has a visible result, or that original scene pixels match.

`remaining_shader_coverage.json` enumerates every identity, every material, exact translated path, source-reference sites and compatibility label. Six identities have no material references in this closure: Universal Render Pipeline/Particles/Unlit, Utility/HearthstoneFallbackDiffuse, two bundle copies of Hidden/Universal Render Pipeline/FallbackError, and two copies of Hidden/Core/FallbackError. These are retained source dependencies, not current fallback materials needing invented output.

## Artifacts and original state

- `remaining_shader_routes.json`: 17 exact source identities to production Godot shader paths; original RGB/alpha blend values and property-controlled blend names, LightMode and multiply-route flag.
- `remaining_shader_evidence.json`: complete original parsed shader properties, subshaders/pass states, shader binding metadata, selected material values/keywords and texture metadata. Per-shader directories retain original DXBC, SHA256 and decoded instruction listings.
- `recovered_uniform_defaults.json`: 74 applied original numeric property defaults across the new main/RT shaders. Defaults are not guessed from a conventional shader name. For example, R2TAdditive Color is (.5,.5,.5,.5), Intensity is 2; AlphaClip Cutoff is 15 and is an exponent.
- `capture_source_pass_tags.json`: exact original pass tags and blend/depth states for all 38 source identities.
- `secondary_shader_routes.json`: original AreaEffect GlowAdditive pass 1, separately preserved and excluded from ordinary RTT.

Main textures use the existing project's Y-conjugated texture/UV convention. Main texture sampling is linear/repeat unless the original active texture requires clamp; RampTex is clamp. Selected active textures are single-mip, so the serialized negative mip bias has no further mip level to select. Original sampler/texture records remain in the evidence rather than asserting generalized Unity/Godot sampling equivalence. The original RT sampler defaults/read-write color path are separately qualified below.

## Main formulas

Notation: C is vertex RGBA, T is sampled MainTex, P is Color, I is Intensity, A is Alpha. ST applies only where present in the original instruction stream. sat clamps all indicated components to [0,1]. H is source spherical-harmonic/main-light input combined using the exact source gamma expression, not Godot's lighting implementation. Multiplication of a varying happens at the source vertex stage when the original did so.

- `native_combat_unlit_color.gdshader`, Custom/UnlitColor: output Color, opaque One/Zero, depth write. This restores the Frost Nova wipe-mask material rather than substituting a transparent textured plane.
- `native_combat_black.gdshader`, Utility/Black: (0,0,0,1), opaque One/Zero, depth write. Used by Hellfire's original mask.
- `native_combat_dissolve_single.gdshader`, Effects/AddMulDissolveSingleTex: V=(C.rgb*P.rgb*A*I,C.a); sat(T.r*min((T.r+C.a-1)*DissolveIntensity,1)*V). One/OneMinusSrcAlpha.
- `native_combat_colorize_mask.gdshader`, Effects/ColorizeMask: V=(2*C.rgb*P.rgb,C.a*A)*I; (V.rgb,T.r*V.a). SrcAlpha/OneMinusSrcAlpha.
- `native_combat_board_color.gdshader`, FX_AE_BoardColor: d=min((DissolveTex.r-1+Dissolve)*DissolveIntensity,1); (2*T.rgb*P.rgb*A,T.r*A)*I*d. The original board color is supplied by runtime action; recovered shader arithmetic is not a claim that the original board-light sample exists.
- `native_combat_area_render.gdshader`, FX_AreaEffect_Render: RampTex(T.r*RampIntensity,.5)*(P.rgb*P.a,1)*I*A.
- `native_combat_mobile_additive.gdshader`, Mobile/Particles/Additive: T*sat(C), SrcAlpha/One.
- `native_combat_particle_addmultiply.gdshader`, Particle_AddMultiply: sat((T.rgb*P.rgb,T.a*(P.a-T.a))*2*I*C*H). MainTex ignores ST in this source variant.
- `native_combat_addmultiply_world.gdshader`, AddMultiplyFXWorld: previous form multiplied by FxTex and FxIntensity. Fx UV uses original **clip.xy without a perspective divide**, times Scale plus `_Time.x*Scroll`. Explicit `_SourceViewProjection`, `_GodotToSourceWorld`, `_UnityTimeX` inputs.
- `native_combat_hero_mask.gdshader`, FX_HeroMask_VertColorOnly: **vertex** F=1+C.a*(C-1), then interpolate F. Original Zero/SrcColor RGB multiply, depth write and Cull Back. Requires the separately owned destination-transmission route; do not replace with grayscale alpha or move the product after interpolation.
- `native_combat_additive_vertex.gdshader`, FX_AdditiveVertColor: 2*C*P. No texture contribution.
- `native_combat_holy_render.gdshader`, FX_HolyRender: Q=2*T.r*P.rgb*P.a+T.g*Color2.rgb*Color2.a; output (Q,Q.r*A)*I*A. Output alpha uses the newly composed Q.r, not original T.r.
- `native_combat_common_fx.gdshader`, FX/CommonFX current material keyword variant: ST UV, then interpolate with swapped xy by SwapUV, then with clamped UV by ClampUV. c=C*P; V=(2c.rgb,1-sat(2max(c.rgb)-1))*c.a*AlphaMul; F=((T.rgb+ColorAdd)*max(T.r,PremultipliedRGBTexture)*ColorMul,T.r)*V. All three current materials resolve property-controlled blend to One/OneMinusSrcAlpha. Their selected original variants [5,8,11,18,21] and optional24 SECONDROTATION have byte-identical relevant vertex/fragment code. Dormant texture/keyword families were not invented as active paths.
- `native_combat_color_as_alpha.gdshader`, Particles_Transparent_ColorAsAlpha: V=C*TintColor*I*H; RGB=2*V.rgb, alpha=sat(dot(T.rgb,(.300000012,.589999974,.109999999))*AlphaIntensity)*V.a.
- `native_combat_fresnel.gdshader`, Unlit_Fresnel: V=mix(C,(gammaSH+MainLight,1),LightingBlend)*P. f=sat((FresnelWidth-sat(dot(inputNormal,normalize(CameraObject-position))))/FresnelWidth); add .5*f*f*(3-2f)*FresnelColor*FresnelIntensity. The source does not normalize the object-space input normal for this dot. CameraObject is explicitly bound per object.
- `native_combat_diffuse.gdshader` and `native_combat_diffuse_color.gdshader`, Hero/Diffuse: unshadowed `_ADDITIONAL_LIGHTS` blob3 vertex/blob15 fragment. World-space interpolated normal is normalized. Ambient gammaSH plus main light and up to eight indexed additional lights. Each additional attenuation is **1/(1+25*distanceSquared*attenuation.x)**, multiplied by squared saturated spot factor and saturated N·L. This is not URP SimpleLit's falloff. DiffuseColor additionally multiplies T by Color. Scene light inputs are explicit compatibility bindings.

## Additional source glow pass

`native_combat_area_render_glow.gdshader` is exact original FX_AreaEffect_Render pass1 **LightMode GlowAdditive** (not GlowTransparent). q=2*C*T; F=.25*dot(q.rgb,(.333000004,.333000004,.333000004))*(q.rgb*GlowColor.rgb,q.a*GlowAddMul)*GlowIntensity. Original blend is One/One. GenFX_FireAE_RenderPlane has GlowIntensity=.75, so this is not dismissed as a universally zero pass.

The original ordinary RenderToTexture pass selection explicitly excludes this pass. It is therefore not attached as a Godot next_pass. Its separate scene glow-camera/renderer scheduling is not established by the RTT trace. The standalone formula and shader are preserved for that original route, not substituted into the ordinary capture.

## RTT source-alpha capture

`native_combat_capture_materials.gd` provides `color_material(source, light_mode="")`, `alpha_material(source, light_mode="")`, `sync(source, target=null)`, and `clear()`. `alpha_material` caches 33 generated source-formula shaders and synchronizes source uniforms/render priority every frame. Unsupported entries include the original source material key. This does not read Godot's coverage alpha as original framebuffer alpha.

The 33 `native_combat_capture_alpha_*.gdshader` variants retain original vertex/pixel formulas and replace only final output with a scalar stored in RGB. Given original source output alpha a and destination scalar d:

- SrcAlpha/OneMinusSrcAlpha: a*a+d*(1-a).
- SrcAlpha/One: a*a+d.
- One/OneMinusSrcAlpha: a+d*(1-a).
- Zero/SrcAlpha (the alpha portion of Zero/SrcColor): d*a.
- One/Zero: a.

The RGB bridge is the project's separately identified GL color compatibility encoder. Fixed-point capture can clip; this is not an HDR guarantee. The runtime uses opaque background RGB=clear.a for this scalar target, then merges its red channel with separately captured original RGB. All 19 serialized RT components currently have RenderMeshAsAlpha=false, OpaqueObjectAlphaFill=false and no AlphaObject, so no extra AlphaCamera is invented for them.

## Original pass selection

`RenderCommandLists.AppendRenderCommands` 0x060154a6, `.cctor` 0x060154a7, `source_code/render_command_lists.cil.*`: scan shader passes and retain only the first pass for each of **SRPDefaultUnlit, UniversalForward, LightweightForward**, in that category order. A missing tag becomes SRPDefaultUnlit. Draw commands use the selected passIndex. Glow/Alpha/depth/shadow passes are excluded, in both ordinary and mode5 bloom capture. Every ordinary source shader here has at most one candidate under this whitelist. The capture helper audits/rejects a future multiple-selected-pass material rather than flattening it into one pass.

FX/CommonFX serializes tag value `SRPDEFAULTUNLIT` in uppercase. Managed code compares ShaderTagId equality; exact native tag-string case normalization is being checked separately. The original casing is preserved in route evidence; it is not silently rewritten to claim an exact runtime result.

## Verification and limits

- `verify_remaining_formulas.py`: **16,384** independent original-DXBC arithmetic cases passed across 17 families, max absolute error 1.78e-15. Diffuse loops exercise 0–8 indexed lights and original raw integer instructions, not an assumed generic lighting equation.
- `verify_area_glow_formula.py`: **2,048** vertex+fragment DXBC cases passed, max error 8.89e-16.
- `verify_r2t_formulas.py`: **17,409** cases passed; see `R2T-SHADER-RECOVERY.md` for all bloom/blur/combine taps and interfaces.
- Parser tests: **59** new/capture shader resources load with uniforms in Godot 4.6.3 (51 remaining/capture including glow, plus eight RTT). The helper's sync (including cleared overrides and changed source shaders) and whitelist/exclusion/multiple-pass behavior also passes. Uniform names come from source declarations, avoiding an empty first-frame reflection cache. Use writable HOME/XDG dirs as in `test_home` for headless parsing.
- `capture_alpha_gpu_test.gd` is the independent 13-case real-GPU scalar-alpha recurrence oracle, output `TavernDuel/qa/v32/capture-alpha-gpu-result.json`. Initial execution passed 12; the opaque-black case exposed an oracle-seed sorting problem: its UnlitColor seed retained original ZTest Always and could overwrite the opaque test afterward. The seed only was changed to normal depth; production source shaders were not changed. Rerun is pending; do not call the initial failed artifact an all-pass.
- `production_uniform_binding_audit.json`: all 126 constructor materials, **716** original supported float/color/texture/ST comparisons and **686** fresh scalar-clone comparisons pass. Unsupported saved properties are listed separately rather than guessed as live shader inputs. These comparisons do not prove later runtime mutations preserve values. The actual Nova GUI dump showed its source wipe-mask Color changed from original black to white after construction, so that visual defect remains tracked with the runtime owners rather than attributed to 8-bit saturation.
- Original scene SH/main/additional-light values and camera transforms are absent. Runtime binds actual current FixedBoard/capture camera inputs as explicit compatibility, not recovered original scene globals. Shadow variants and inactive keyword branches are not claimed as executed.
- `RenderTextureTracker.CreateNewTexture` passes width/height/depth/format/readWrite to the original constructor, depth=16 and readWrite=0. No explicit filter/wrap setter was found. Project GraphicsSettings tier HDR flags do not prove the active URP asset's HDR setting/actual RT format. Original HDR, gamma, intermediate quantization and complete scene glow routing remain qualified.

Reproduction order if regenerating (do not regenerate over ongoing runtime work): write the new main/RT shader sources, apply `apply_recovered_uniform_defaults.py`, then generate capture variants. Do not rerun the old baseline `write_combat_shaders.py`. Preserve route enrichment and production owner's bindings.
