# Additional active ordinary summon shaders

Source build 37.0.0.255130.254477. Follow-up analysis from final ordinary Small/Enemy actual strong renderer references, not from material-name guessing. Original bytecode and full states: `supplemental_shader_evidence.json`. Candidate source checksums: `candidate_checksums.json`.

## Small and enemy particle references

`small_enemy_material_refs.json` records complete GameObject ancestor paths, material keys and shader keys.

- Ordinary `Card_Hand_Ally_SummonOut/GameObjectContainer/FX_BlueRays`, ordinary PlayActor EdgeMotes, ordinary SummonIn EdgeMotes/EdgeLandMotes, and opponent SummonIn EdgeMotes/EdgeLandMotes all use `GenFX_BlueMotes_Grave`, material `cab-3563ba8b89db13ca6eb196aa111591f1:-1115434679259150774`.
- `Card_Hidden_SummonOut/FX_RedRays` uses `FX_RedMotes`, material same CAB `6387253272923546146`.
- Both materials strongly reference original `Hero/Additive/Additive`, shader `cab-3563ba8b89db13ca6eb196aa111591f1:-666151408197827071`. This is already translated by `native_summon_scroll`, with the renderer's subsequently GPU-verified additive coverage bridge. No new ordinary small-particle algorithm is needed.
- The similarly named `GameObjectContainer_Diamond/FX_BlueRays` is different, `Hero/Particle/Particle Additive` path ID 240134070624251049. It is outside this ordinary branch scope and is not silently substituted.
- Blue and red motes share original `GenFX_moteB`, Repeat U/V, one mip, bilinear effective filtering, so `_MainClamp=false`.

## Hidden Glow

Material `FX_CardHidden_Glow_Large`, key `cab-3563ba8b89db13ca6eb196aa111591f1:1589732984300187321`.
Shader `cab-c394926ba464822396a05cbfae08a8b3:-230275896195282385`, original name `Hero/Particle/Particle Additive + 1`.
Bytecode and binding metadata: `Hero_Particle_Particle Additive + 1/`.
Candidate: `candidates/native_summon_hidden_glow.gdshader`.

Define `G=saturate(1.05499995*pow(abs(vec3(unity_SHAr.w,unity_SHAg.w,unity_SHAb.w)),0.416666657)-0.0549999997)`.
Original main vertex UV passes UV0 through unchanged. **No `_MainTex_ST` is read by the main pass.**
Original vertex RGBA: `V=vec4(mix(1,G,_LightingBlend),1)*C*_Color*_ColorMul`.
Original fragment RGBA: `F=sample(_MainTex,UV0)*V`.

Main state: SrcAlpha/One for RGB and alpha, Add, ZWrite Off, ZTest LEqual, Cull Off, RGBA mask, original queue `Transparent+99`.
GlowTransparent second pass is the shared original formula from main README. Current material `_GlowIntensity=0` makes it zero. This second pass does use MainTex_ST, unlike the main pass.
Selected original texture `GenFX_HiddenCard_Echo`: Repeat, one mip. Material `_LightingBlend=0` means unknown scene SH does not affect this selected instance. `_ColorMul=2`; initial `_Color=(1,0.4156862497,0.4156862497,0)`.

Candidate outputs original source RGBA. Production should reuse the already independently GPU-verified additive coverage bridge instead of copying over another shader's modified production output block.

## Shadow

Material `CardShadow_Ability`, key `cab-3563ba8b89db13ca6eb196aa111591f1:-8971777006715196974`.
Shader `cab-c394926ba464822396a05cbfae08a8b3:-2557555604182605517`, `Effects/FX_Transparent_ColorAsAlpha`.
Bytecode/bindings: `Effects_FX_Transparent_ColorAsAlpha/`.
Candidate: `candidates/native_summon_shadow.gdshader`.

Vertex: usual UV0 with MainTex_ST, position transform. No vertex COLOR input.
Let `T=sample(_MainTex,transformedUV)` and `lum=dot(T.rgb,vec3(0.300000012,0.589999974,0.109999999))`.
Exact original RGBA: `F=vec4(T.rgb*_Color.rgb,lum*_AlphaIntensity)*_Intensity`.

Original blend is **One/OneMinusSrcAlpha in both RGB and alpha**, Add, NOT DstColor/multiplicative blending. ZWrite Off, ZTest LEqual, Cull Off. No lighting, no `_Color.a`, no texture alpha, no vertex COLOR influence.
Selected source values `_Color.rgb=0`, `_AlphaIntensity=1`, `_Intensity=0.5` give source RGB zero and source alpha `0.5*lum`. Therefore the destination is multiplied by scalar `1-0.5*lum`, even though saved `_Color.a=0`. Do not discard this layer just because material alpha is zero.
Texture `Card_Hand_Ability_Shadow`: Repeat U/V, one mip.

Independent numerical verification: `enemy_formula_validation.json`, 512 randomized cases each for HiddenGlow and Shadow. Shader arithmetic and constant/UV mapping versus original decoded SM4 instructions. Maximum absolute error 4.44e-16 and zero, respectively. This is not a GPU/raster parity claim.

## Ordinary hand Highlight

GameObject `Card_Hand_Ally/CardStateMgr/Highlight/Highlight_Card_Plane`, source `cab-69c88b234dfa427e02d1fcee9337ae34:-5364447331335434985`.
Material `GenFX_HighlightGreen`, key `cab-3563ba8b89db13ca6eb196aa111591f1:-3606623552978795584`.
Shader same CAB `-1327719733717699995`, `Custom/Selection/Highlight`.
Original bytecode/bindings: `Custom_Selection_Highlight/blob1.asm.txt`, `blob3.asm.txt`, `metadata.json`.
Candidate: `candidates/native_summon_highlight.gdshader`.

This algorithm is not AddMultiply and must not be replaced by it. It uses the red channel of the runtime MainTex silhouette and the red channel of FlareTex; neither texture's alpha is used.

Exact source-coordinate formula:

- `u0=UV0*MainTex_ST.xy+MainTex_ST.zw`.
- `u1=UV1*the same MainTex_ST.xy+the same MainTex_ST.zw`.
- `x=mix(u0.x,u1.x,_TexCoordTwoWeight)`.
- `r=C.r`, `phase=_Seed+_ShaderTime`.
- `b=sample(_MainTex,u0).r*_Intensity*1.20000005`.
- `flare_uv=vec2(x*_UflareScale+phase*0.0500000007,b*_VflareScale+phase*_VflareSpeed)`.
- `f=sample(_FlareTex,flare_uv).r`.
- `k=2*(f*r+b)*b*_FlareIntensity`.
- `F.rgb=(_Color.rgb+k*(_HiColor.rgb*k-_Color.rgb))*_ColorIntensity*_Colorize.rgb`.
- `F.a=(1+_ColorAlphaWeight*(r-1))*k*_Colorize.a`.

There is no explicit shader saturate. `_Color.a`, `_HiColor.a`, COLOR.gba, `_FlareTex_ST`, and the saved Uscale/Vscale/Vspeed/Mote properties are not read in this compiled program.

Main state: RGB and alpha SrcAlpha/OneMinusSrcAlpha, Add, ZWrite Off, ZTest LEqual, Cull Off. Serialized queue is Transparent; original runtime's HighlightRender assigns 3050 (separate recovered runtime evidence). Candidate retains original source RGBA for renderer coverage bridging.

`_ShaderTime` is a distinct original UnityPerFrame global. Its producer has now been recovered independently in `source_code/shader_time_runtime.cil.txt` from the original assembly: ShaderTime.UpdateShaderAnimationTime, method 0x06015547, accumulates `m_time += Time.deltaTime / 20` while enabled; if greater than `m_maxTime`, subtract maxTime once; if <=0, set 0.0001; write SetGlobalFloat("_ShaderTime",m_time). Constructor 0x06015549 sets maxTime=65535 and enabled=true, initial time zero. Disabled updates set time=1; Shutdown 0x06015545 writes zero. Bind this global service lifecycle, **not a per-summon elapsed timer** and not a claim that the shader reads built-in `_Time.x`.

HighlightState.Setup 0x0601528C stores UnityEngine.Random.value in m_seed, and ChangeState 0x06015293 writes `_Seed`. Preserve one seed for the source HighlightState lifecycle; do not re-randomize every frame. Candidate uniform default `_ShaderTime=0` is merely the pre-bind initial value; renderer must supply the recovered service output.

MainTex serialized default is `GenFX_Black32x32`, but the ordinary hand's recovered runtime binding is static `Card_InHand_Ally_Silhouette` (`cab-cfdc5301ac0b17c5a76ad477fba38b57:-3103092934676384505`). Recovered original CIL is `RenderSilouette`, token 0x06015297, IL00B5 `set_mainTexture`; dynamic RT is used only when static/override are absent. See `assets/original_summon_v31/data/ordinary_hand_texture_highlight_bindings.json` and the corresponding source-code evidence. Do not render the default black texture and call the highlight restored.

The recovered static mask is Repeat U/V, bilinear, one mip. FlareTex `GenFX_Lines` is Repeat and one mip. Native UVs are Y-flipped; candidate undoes that conjugation only for the generated flare sample coordinate. Both UV channels must exist.

`highlight_formula_validation.json`: 512 randomized cases with both texture coordinates affecting the analytic sampler, two UV channels, ST, C.r, colors, intensities and phase; independent formula versus original instruction interpreter. Maximum absolute discrepancy 4.44e-16. GPU comparisons are recorded separately in the final QA report.
