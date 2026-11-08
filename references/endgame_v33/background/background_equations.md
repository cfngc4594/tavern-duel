# Original result background shader transcription

Source: client37.0.0.255130.254477, `globalgamemanagers.assets`, SHA256 `13cad47e8890d9e125f3a7b8ea22133d86f0aeb3c5232f988e33ac2435d34c4f`. Pipeline renderer2 -> renderer7801 -> perspective FullScreenEffectsFeature7824. These are not old ScreenEffectsMgr glow shaders.

- Shader49 Desaturation pass0 emits `(dot(scene.rgb,(.2126,.7152,.0722)),0,0,0)` with One/Zero. Pass1 emits luminance RGB and alpha `_Desaturation`, blends OneMinusSrcAlpha/SrcAlpha, and preserves destination alpha. At current blurred preset completion `_Desaturation=(1-.5)^3=.125`, not .5.
- Shader42 Vignetting emits `(mask.r,mask.r,mask.r,1)*_Amount`. RGB DstColor/OneMinusSrcAlpha, alpha Zero/One. Therefore `destination.rgb*(mask.r*amount+1-amount)` with destination alpha preserved. Amount is `1-(1-.4)^3`. Actual mask is original Texture2D18,128²RGB24, recovered from same-build resS at offset2861776,49152bytes, not a procedural approximation.
- Shader33 Blur has four diagonal sample offsets `(±1,±1)*sourceTexelSize*(_BlurOffset+.5)`. Sum RGBA and multiply `_Brightness*.25`; One/Zero. Actual three callbacks use offsets1,1.15,1.3 and Brightness1, not unused preset .5. RenderGraph targets long edge2048 then half size, RGBA8 UNorm and bilinear filter. The third pass writes scene-sized target when blend1, otherwise2048 target followed by original blend.
- Shader36 Blend emits source RGB and alpha `_Amount`, RGB SrcAlpha/OneMinusSrcAlpha, alpha Zero/One. Adapter explicitly computes the original destination equation rather than relying on Godot premultiplied canvas semantics.
- Shader40 optional BlendToColor is recovered but inactive in the scoped ordinary result preset.

Compiled source blobs, DXBC, disassembly and parsed pass metadata are retained beside this report. 6144 independently interpreted source fragment cases match high-level equations exactly. Vertex diagonal offsets separately traced from compiled VS. This proves arithmetic, not full client pixel identity.

Godot adaptation uses real-time shared World2D canvas capture followed by separate SubViewport passes and result C+RGB_T*background composition. No CPU snapshot, no invented Gaussian or exposure adjustment. Source camera/HDR configuration and original native GPU runtime remain distinct; actual GUI and pass lifecycle need their separate QA results.
