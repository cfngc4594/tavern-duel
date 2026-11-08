# Original summon shader recovery

Build: **37.0.0.255130.254477**. Source: original Unity serialized Shader objects, their parsed pass state, their Unity6 `m_PlayerSubPrograms`, compressed platform 4 (D3D11) subprogram entries and embedded original SM4 DXBC. No shader algorithm below is inferred from a shader name.

## Deliverables

- `core_shader_evidence.json`: original bundle/CAB/path identity, compressed shader SHA-256, original material parameters, pass states, original DXBC SHA-256.
- `<shader_name>/blob*.dxbc`: unchanged embedded original Direct3D bytecode.
- `<shader_name>/blob*.asm.txt`: decoded signatures and instruction streams.
- `<shader_name>/metadata.json`: original pass/program constant binding metadata.
- `candidates/native_summon_{flash,rays,scroll,dust,portrait,addmultiply}.gdshader`: implementable Godot GL translations, not original Unity runtime programs.
- `formula_validation.json`: 256 randomized algebra/binding tests per shader for seven shaders, 1,792 total. Original SM4 instruction interpreter versus independent high-level formulas. Maximum absolute discrepancy < 4.45e-16 in float64. This is **not** a rendered equivalence test.

UnityPy's `.shader.txt` exporter omits Unity6 `m_PlayerSubPrograms`. Its output without the program bodies must not be interpreted as source shader code. The decoder uses Microsoft's official `D3D12TokenizedProgramFormat.hpp` opcode and operand definitions. Script/data operations only. Original client was not run.

## Exact common notation

`C` is original mesh/particle vertex RGBA, interpolated after vertex processing. No missing vertex stream is manufactured beyond the documented white default. `T` is a sample of `_MainTex`, and texture coordinates use the serialized `_MainTex_ST`. `G = saturate(1.05499995 * pow(abs(vec3(unity_SHAr.w,unity_SHAg.w,unity_SHAb.w)), 0.416666657) - 0.0549999997)`. `L = G + _MainLightColor.rgb`. `B = _LightingBlend`. `mix(a,b,t)` means `a+(b-a)*t`, with no implicit clamping.

The original compiled programs perform this gamma-like SH conversion explicitly. This does not, by itself, establish the complete original scene or framebuffer color-space setup.

## Out22

### FlashA — shader 4454903573088140019, Hero/Unlit/Unlit_TransparentColor

Vertex RGBA: `V = vec4(mix(1,L,B),1) * C * _Color`.
Fragment RGBA: `F = T * V`.
State: one pass, RGB/alpha `SrcAlpha OneMinusSrcAlpha`, Add; ZWrite Off, ZTest LEqual, Cull Back, RGBA color mask.

`_TintColor` is a stale saved material property and is **not** read by this compiled shader. Material `_Color.a` is initially zero; animation must drive the actual `_Color` channels, not tint or arbitrary opacity.

### ScryingRays-mat_raysA 2 — shader -8682043857861559096, Hero/AddMultiply/AddMultiplyFXScrolling

Main UV uses `_MainTex_ST` normally. Secondary UV is `uv0 * vec2(_ScaleX,_ScaleY) + _Time.x * vec2(_ScrollX,_ScrollY)`.
`_Time.x = elapsed_seconds / 20`, not seconds. `_FxTex_ST` is not read.

Vertex RGBA: `V = vec4(mix(1,L,B),1) * 2*C * _Intensity * _Color.a * _FxIntensity`.
Main-texture intermediate: `Q = vec4(T.rgb*_Color.rgb, T.a*(_Color.a-T.a))`.
Fragment RGBA: `F = saturate(texture(_FxTex, secondary_uv) * Q * V)`.
State: main pass RGB/alpha `One OneMinusSrcAlpha`, Add; ZWrite Off, ZTest LEqual, Cull Off. Additional GlowTransparent pass described below.

`_TintColor` is not read. In particular, replacing the unusual alpha polynomial by `T.a` is incorrect.

### GenFX_AllyInHand_ScryLines — shader -666151408197827071, Hero/Additive/Additive

Vertex RGBA: `V = vec4(mix(1,L,B),1) * 2*C*_TintColor`.
Fragment RGBA: `F = T*V`.
State: main pass RGB/alpha `SrcAlpha One`, Add; ZWrite Off, ZTest LEqual, Cull Off. GlowTransparent pass below.

The factor 2 applies to alpha too. Do not premultiply F.rgb by F.a in the shader, because the source blend factor already does that.

## In24

### FX_AllyInPlay_SummonRing_Med

Uses the exact same Additive shader algorithm. Its CAB differs from ScryLines, but original DXBC and compressed shader are identical. Source shader path ID is the same. Preserve original CAB identity in the manifest.

### GenFX_DustA_2x2 — shader 1610204260223125505, Hero/Particle/Particles_Transparent

Vertex RGBA: `V = vec4(mix(1,G,B),1) * 2*C*_TintColor`. This particular shader uses SH only, with **no** `_MainLightColor` addition.
Fragment RGBA: `F = T*V*vec4(_Intensity,_Intensity,_Intensity,_Alpha)`.
State: blend is driven by material `_RgbSrcBlend`, `_RgbDstBlend`, `_AlphaSrcBlend`, `_AlphaDstBlend`; the selected Dust material has 5,10,5,10 = `SrcAlpha OneMinusSrcAlpha` in RGB and alpha. ZWrite Off, ZTest LEqual, Cull Off. GlowTransparent pass below.

Selected material has `_LightingBlend=1`, so exact appearance requires original SH scene globals. They were not contained in the selected material/prefab extraction. Candidate shader's neutral SH default is explicitly a compatibility assumption, not recovered scene evidence.

## GlowTransparent common second pass

Applicable to Additive, AddMultiplyFXScrolling and Particles_Transparent. State is RGB/alpha `One One`, Add; ZWrite Off, ZTest LEqual, Cull Off, `LightMode=GlowTransparent`.
Vertex passes original C and the main texture UV. Fragment:

1. `Q=2*C*T`.
2. `R=Q.a*Q*_Color.a`.
3. `R.rgb *= _GlowColor.rgb`; `R.a *= _GlowAddMul`.
4. `F=0.25*dot(Q.rgb,vec3(0.333000004))*R*_GlowIntensity`.

All five selected Out22/In24 materials have `_GlowIntensity=0`, so their pass output is identically zero. Candidate main-pass shaders can omit this zero-output pass for those current values. That does not authorize omitting it for nonzero future animated GlowIntensity or other materials. The original renderer's scheduling/routing of the custom light mode and postprocessing remain outside this recovered shader scope.

## PlayActor

### Portrait — shader 6322982158558142423, Custom/Card/Unlit_Desaturate_2Texture2uv

Main uses UV0 and second texture uses original UV1, both with their own ST. Geometry must populate Godot UV2 with original uv1, Y-conjugated just like UV0.

Vertex RGBA: `V=mix(C, vec4(G+_MainLightColor.rgb*unity_LightData.z,1),B)*_Color`.
Fragment:

1. `S=sample(_SecondTex)*_SecondTint*_BlendIntensity`.
2. `Q=mix(T,T*S,S.a)`.
3. `lum=dot(Q.rgb,vec3(0.300000012,0.589999974,0.109999999))`.
4. `D=lum*(_Color-_DarkColor)+_DarkColor` (all RGBA components).
5. `Q=mix(Q,D,_Desaturate)`.
6. `Q=mix(Q,_AvgLum,_Contrast)` (all RGBA components).
7. `F=min(Q,(Q+vec4(0.150000006))*V)*_Intensity`.

One opaque pass, RGB/alpha One/Zero; ZWrite On, ZTest LEqual, Cull Back. Texture alpha is not transparency coverage. Candidate does not write Godot ALPHA, preserving opaque geometry; optional `_SourceAlphaMaskPass` writes source alpha numerically to RGB for a separate alpha render target.

### Frame — shader -4440234706065032223, Custom/Card/UnlitTexture

Color-pass vertex RGBA `V=mix(C,vec4(L,1),B)`. Fragment `F=T*V`. `_Color` is not read in this compiled color pass.
Color pass: `LightMode=UniversalForward`, One/Zero in RGBA, ZWrite On, ZTest LEqual, Cull Off. Existing native_cards `original_shader_kind=0` formula matches this bytecode and may be reused.
A separate original ShadowCaster pass has ColorMask 0, ZWrite On, Cull Off. Its actual shadow-map execution is a renderer responsibility, not copied by the main color shader.

### PlayActor summon glow — shader 3410991767739636778, Hero/AddMultiply/AddMultiply

Material `GenFX_AllyInPlay_SummonGlow_AddMult` strongly references this shader. Vertex `V=vec4(mix(1,L,B),1)*2*C*_Intensity`. Fragment `F=saturate(vec4(T.rgb*_Color.rgb,T.a*(_Color.a-T.a))*V)`. Unlike AddMultiplyFXScrolling, it has no FxTex and no additional `_Color.a` factor in V. One pass, One/OneMinusSrcAlpha in RGB and alpha, ZWrite Off, ZTest LEqual, Cull Off. Candidate `native_summon_addmultiply.gdshader` implements it.

## Godot integration and known limits

- Only candidate files were written in this analysis directory. Production integration is documented separately in IMPLEMENTATION.md.
- Source property names are preserved. Renderer already conjugates imported UV y and ST offset y. Rays reconstruct original UV before rolling the FxTex UV, then flips the sample coordinate back; do not double-invert.
- Bind `_MainTexClamp` to the same texture as `_MainTex`, and `_MainClamp=true` only for ScryLines (`GenFX_AllyInHandSummon` original Wrap=Clamp). Ring and other core textures are Repeat. Both samplers are provided because sampler wrap is not a per-uniform mutable shader state.
- Original core textures have one mip, trilinear source filter and -0.5 mip bias; with only one mip this reduces to bilinear filtering. No invented mip chain is needed.
- `_UnityTimeX` is optional deterministic time. A negative value uses Godot TIME/20. Original client's global time phase is not recovered.
- Scene globals `_UnitySHW`, `_MainLightColor`, `_UnityLightDataZ` have neutral compatibility defaults, not recovered original values. Zero LightingBlend makes most core effects independent of these unknowns.
- The candidate RGB bridge is copied from the existing project's `mask_backend_inverse` compensation for Godot GL's RGB transfer functions. It is kept distinct from original shader math. Godot engine reference sources are saved locally for exact backend behavior. Full original texture/framebuffer color-space parity is not claimed.
- Godot 4.6 GLES3 `blend_add` in the transparent pass is SrcAlpha/One, and `blend_premul_alpha` is One/OneMinusSrcAlpha, including alpha. These match Additive and Rays respectively.
- Godot `blend_mix` uses separate alpha One/OneMinusSrcAlpha for a transparent viewport, while Flash/Dust source alpha uses SrcAlpha/OneMinusSrcAlpha. RGB blend is equivalent; original transparent render-target alpha requires a separate numerical alpha target/compositor. Do not claim one-pass RGBA equivalence.
- Rendered parity, real scene lighting, original camera/light mode scheduling, original runtime property overrides and particle generation remain separate evidence requirements. Numerical bytecode tests only verify algebra/binding.

## References

- Microsoft tokenized shader format: https://github.com/microsoft/DirectX-Headers/blob/main/include/directx/D3D12TokenizedProgramFormat.hpp
- Godot 4.6 GLES3 blend implementation: https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/rasterizer_scene_gles3.cpp
- Godot spatial shader reference: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Unity built-in shader variables: https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
