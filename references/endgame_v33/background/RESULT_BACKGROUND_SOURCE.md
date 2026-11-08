# Current ordinary result background: precise source contract

Source build37.0.0.255130.254477. Static original DLL and original assets only. No production modifications. This is a separate result-screen feature, not a proposed fix for the current bright Win37 image.

## Entry, lifetime and clock

EndGameScreen.Show06004cc9 IL00a2..00c6 selects BlurVignetteDesaturatePerspective when GameState exists and HasPetEndgame=false. Start occurs after terminal spells finish and GameEntity06005501 restores original time scale. ScreenEffectsHandle.StartEffect06015181→FullScreenFXMgr.AddEffect060151e2→ResolveEffects060151e5→FullScreenEffects.StartEffect060151d0. PassLocation1 selects the main-camera FullScreenEffects component, not the layer18 secondary camera.

Preset ctor06015175 IL0000..0035: Type7,PassLocation1,Time.5,EaseType19=easeOutCirc; Blur.Default=(Amount1,Brightness.5,Blend1), Vignette.Default=.4000000059604645, Desaturate.Default=.5, BlendToColor.None=(white,Amount0). Their ctors/cctors06015176..7d are in endgame_background_runtime.cil.txt.

StartEffect060151d0 stores Time.time and copies the existing current parameters to m_startParameters. DoToUpdate060151d2 interpolates only Blur.Blend,Vignette.Amount,Desaturate.Amount,BlendToColor.Amount using Ease19(start,target,Clamp01((Time.time-startTime)/Time)); uses scaled time. The initial None values are Blur(0,1,0),Vignette0,Desaturate0,BlendToColor(white,0). The final values persist; .5is the transition duration, not effect lifetime.

EndGameScreen.OnDestroy06004cc7 IL007b..0082 calls handle.StopEffect(null). FullScreenFXMgr.StopEffect060151e3 sets individual target parameters to None, marks Released, keeps the Time/Ease fields, marks stack dirty. A lone current effect consequently fades back through the same .5/Ease19 parameter interpolation; it is not a forced instant wipe. Scene/reset can independently release it. TWO DIFFERENT MANAGERS: TwoScoop.HideAll06004d9c calls ScreenEffectsMgr.SetActive(false), which060154e7 only disables ScreenEffectsRender (old glow chain). That is not FullScreenFXMgr and does not end this background preset.

## Exact restored resource chain

All material/shader payloads are already local in v32_work/source_assets/global_settings/globalgamemanagers.assets; original file SHA25613cad47e8890d9e125f3a7b8ea22133d86f0aeb3c5232f988e33ac2435d34c4f. These are built-player local file/path IDs, not fabricated GUIDs. Detailed raw offsets, source hashes and material fields: background_material_bindings.json; raw feature bytes: background_features_raw.json.

Perspective FullScreenEffectsFeature PID7824 is active1, renderPassEvent500:
- m_blurMaterial Material5 Mat_FullScreenFX_Blur→Shader33 Custom/FullScreen/Blur.
- m_blurBlendMaterial Material3 Mat_FullScreenFX_Blend→Shader36 Custom/FullScreen/Blend.
- m_desaturationMaterial Material6 Mat_FullScreenFX_Desaturation→Shader49 Custom/FullScreen/Desaturation.
- m_vignettingMaterial Material7 Mat_FullScreenFX_Vignetting→Shader42 Custom/FullScreen/Vignetting.
- m_blendToColorMaterial Material4 Mat_FullScreenFX_BlendToColor→Shader40 Custom/FullScreen/BlendToColor.

Orthographic feature7789 uses material12/10/13/14/11 respectively, but exactly the same five shaders; do not substitute this material set for perspective.

Low/Base7802,High7804,Medium7805 pipeline assets share renderer list[7803,7800,7801,7806]. Perspective renderer7801 contains feature7824 as feature index4. Main Camera's UniversalAdditionalCameraData.m_RendererIndex=2 therefore selects7801, not the default-index0 renderer7803. Exact quality source/renderer links are background_pipeline_refs.json. This does not infer the current user's quality setting from one bundle.

## URP graph, not the older blur algorithm

FullScreenEffectsFeature.Create0601629b sets FullScreenEffectsPass and ClearDepthPass renderPassEvent from the serialized500. AddRenderPasses0601629c binds the current camera's FullScreenEffects and queues the graph. Original graph/body and all9callbacks are endgame_background_pass.cil.*. Do not replace these shaders with old ScreenGlow.

RecordRenderGraph060162a7 uses activeColorTexture as the current scene target. Order:
1. Desaturation material pass0: scene→full-camera-size _DesatLuminance, same graphics format as camera, no depth, MSAA1. Then pass1 _DesatLuminance→scene. Set _Desaturation=1-d, but cube it when BlurEnabled: (1-d)^3. In current preset at final d=.5 this is.125, not.5. Shader blending determines the actual composite, to be recovered from the exact shader33/49etc, not guessed.
2. Vignetting material pass0 draws directly into scene. Set _Amount=v, but when BlurEnabled use1-(1-v)^3. At final v=.40000000596 this is approximately.784. No scene source texture is explicitly set by the vignette callback; its shader/Blend state owns this operation.
3. Blur material pass0: scene→_Blur1 with _BlurOffset1.0 and _Brightness1.0. This _Brightness is a hard-coded1 in callback060162ac, not the preset's unused Blur.Brightness.5. Do not darken the image using the latter.
4. Blur material pass0: _Blur1→_Blur2, _BlurOffset1.149999976158142.
5. Blur material pass0: _Blur2→scene when BlurBlend>=1, _BlurOffset1.2999999523162842. If BlurBlend<1, instead _Blur2→_Blur1 at that same offset, then blurBlend material pass0 _Blur1→scene with _Amount=BlurBlend.
6. BlendToColor optional last pass0, sets _Amount and _Color; current normal preset Type7 does not enable it.

All texture-reading callbacks explicitly bind their source as global _BlitTexture then DrawProcedural(identity,material,passIndex,topology0,vertexCount3). Vignette and BlendToColor callbacks draw without setting a source texture. Exact material Blend/ColorMask states and shader sampling are necessary; CIL alone does not establish their math.

CalcTextureSize060162a6 always sets the long dimension to2048, preserving source aspect via RoundToInt of the other dimension, even if this upsizes a smaller source. _Blur2 dimensions=max(1,RoundToInt(_Blur1Dimension*.5)). Both blur textures have graphicsFormat8=R8G8B8A8_UNorm, depth0, filterMode1=Bilinear; exact managed enum proof is background_rt_enums.json. Do not use source screen pixels as the blur kernel resolution. For1280x800 this yields2048x1280 then1024x640. The desaturation intermediate instead remains full current camera size/format.

## Remaining scoped work

The exact five shader payloads are already local and ready for resource-worker export/disassembly; their actual sampling/blend formulas have NOT been inferred from their names. Current board bridge captures only the perspective scene before result UI. This is an explicit viewport/composition adaptation, not evidence of pixel identity. No reason to modify rules or global exposure.
