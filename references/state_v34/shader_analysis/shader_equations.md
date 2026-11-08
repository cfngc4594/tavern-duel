# Frozen shader audit, source build 37.0.0.255130.254477

Evidence is the recovered shader's serialized parameter/state metadata and its D3D11 SM4 `blob1` vertex / `blob3` pixel instructions. No original client execution, login, or GPU was used. Source assets were already extracted by the asset recovery worker. The decoder uses the existing Microsoft opcode definitions and trusted v32/v33 local scripts.

## Shared values

- `H = (unity_SHAr.w, unity_SHAg.w, unity_SHAb.w)`.
- `G = saturate(1.05499995 * abs(H)^0.416666657 - 0.0549999997)` componentwise. These are the encoded float32 constants. This is **not** the piecewise sRGB conversion, and it takes the absolute value before the power.
- `L = vec4(G + _MainLightColor.rgb, 1)`. The main-light addition is **after** saturation and is not itself saturated.
- `V` is input mesh/particle vertex RGBA; `b = _LightingBlend`; `C = _Color` only where present.
- `uv = input_uv * _MainTex_ST.xy + _MainTex_ST.zw`. Both varyings use perspective-correct linear interpolation, verified from the `dcl_input_ps` token's interpolation mode 2.
- Pixel result uses `T = _MainTex.SampleBias(sampler0, uv, _GlobalMipBias.x)`.
- Matrix vertex position is the usual `unity_MatrixVP * unity_ObjectToWorld * vec4(P,1)`.

## Custom/Card/UnlitTextureTint, path -34040995226017085

Vertex varying: `Q = (V + b * (L - V)) * C`.

Pixel output: `S = T * interpolate(Q)`.

This mixes **all four** channels. At `b=1`, source vertex color and alpha disappear and `Q.a=C.a`. Do not replace this with `V * lerp(1,L,b) * C`. `_Glossiness`, `_ReflectionPower`, `_RimPower`, `_DiffuseColor`, `_RimColor`, and `_SpecularColor` saved on the minion material are not read by this shader.

State: `Blend One Zero` on RGBA, `ZTest LEqual`, `ZWrite On`, `Cull Off`, ColorMask RGBA, ZClip On, no discard, no alpha-to-coverage, no depth bias. Stencil comparison Always with Keep operations. Queue is default geometry because neither shader nor current materials override it. Shader tags include `RenderType=Opaque`, `CardAlpha=true`, `Highlight=true`, and `RenderPipeline=UniversalPipeline`.

Materials:
- `GenFX_Frozen-mat_frozenq`: LightingBlend 1; Color `(0.9686274528503418, 0.9686274528503418, 0.9686274528503418, 1)`; texture `GenFX_AllyInPlayFrozen_D`.
- `FrozenHeroShell-mat_FrozenHero`: LightingBlend 0; white Color; texture `HeroFrozen_D`.
- `FrozenHeroShell-mat_frozenq`: LightingBlend 0; white Color; texture `GenFX_AllyInPlayFrozen_D`.

## Hero/Unlit_Transparent, path -1939901832466623549

Vertex varying: `Q = V * (1 + b * (L - 1))`.

Pixel output: `S = T * interpolate(Q)`.

There is **no `_Color` parameter** and no tint multiplier. `Q.a = V.a` independently of LightingBlend.

State: `Blend SrcAlpha OneMinusSrcAlpha` for **both RGB and alpha**, Add operation, `ZTest LEqual`, `ZWrite Off`, `Cull Back`, ColorMask RGBA, ZClip On, no discard, no alpha-to-coverage, no depth bias, Stencil Always/Keep. Shader queue tag Transparent; current material custom queue -1.

Destination RGBA equation is `O = S * S.a + D * (1-S.a)`. In particular, `O.a = S.a*S.a + D.a*(1-S.a)`. This differs from Godot default alpha accumulation.

Material `GenFX_IceShards4`: LightingBlend 0; texture `GenFX_Ice_Shards4`; no saved colors.

## Source texture sampling

All relevant materials have ST `(1,1,0,0)`. All three textures serialize FilterMode 2 (trilinear), Aniso 1, MipBias -0.5, WrapU/V/W 0 (repeat), ColorSpace 1, and MipCount 1. Effective filtering is therefore bilinear at the only level; do not generate additional mip levels. Texture/shader mip bias cannot choose an absent level.

`audited_material_state.json` retains exact source keys, state values, material fields, texture files and source hashes.

## Portable files and explicit boundaries

- `native_status_card_unlit_tint.gdshader`
- `native_status_hero_unlit_transparent.gdshader`

These use the existing native combat GL color bridge. They expose `_UnitySHW`, `_MainLightColor`, and `_GlobalMipBias` explicitly. `_UnitySHW=(1,1,1)` and `_MainLightColor=(0,0,0)` are inherited scene compatibility defaults, **not recovered live original globals**. Required original values are exactly `unity_SHAr.w`, `unity_SHAg.w`, `unity_SHAb.w`, `_MainLightColor.rgb`, `_GlobalMipBias.x`. The original materials' LightingBlend values are preserved. This uncertainty affects minion ice because its blend is 1; the recovered hero shells and shards have blend 0.

The portable opaque shader omits `ALPHA` to retain Godot opaque sorting and depth. A separate alpha capture is required if preserving the original opaque target alpha matters. The transparent shader's Godot default destination alpha also differs; use the existing dual-target source-alpha path when rendering to an alpha-sensitive target. Source formula, source pass state and backend compatibility are kept separate.

`verify_status_formulas.py` exposes scalar `source_vertex_color`, `source_fragment`, and `source_output_merger` for independent downstream QA. Its test compares 8,192 randomized/edge cases against the recovered instruction stream, with named register bindings resolved from the shader metadata. It verifies algebra and pass-state values, not GPU sampling, rasterization, output quantization or original-client pixel equivalence.

Existing scene binding is in `TavernDuel/scripts/native_combat_effects.gd::_bind_scene_inputs`: `_UnitySHW` is `Color("e3e4e3").srgb_to_linear() * 0.33`, and `_MainLightColor` is `SoftWarmBoardLight.light_color.srgb_to_linear() * light_energy`. State rendering should reuse that binding, not silently rely on the shader's neutral fallback. The already recovered v32 globalgamemanagers GraphicsSettings/QualitySettings/PlayerSettings JSON was checked for ambient/main-light globals and contains no matching live scene values; it does not resolve the original-lighting boundary.
