shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Original Windows build37.0.0.255130.254477 globalgamemanagers.assets:45
// Hidden/ScreenEffectsGlow. One/Zero, Cull Off, ZTest Always, ZWrite Off.
// Raw render-target RGBA. No guessed Gaussian, threshold, or gamma transform.
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _BlurTex : hint_default_black, filter_linear, repeat_disable;
uniform vec4 _BlitTexture_TexelSize=vec4(1.0,1.0,1.0,1.0);
uniform float _BlurOffset=2.0; // Mat_ScreenEffectsGlow saved value; CIL sets1 then2.
uniform int _MipLevel=0;
uniform vec2 _GlobalMipBias=vec2(0.0);
uniform int _Pass=0; // 0 Blur; 1 GlowComposite; 2 original Debug copy.
void fragment() {
 vec4 result;
 if(_Pass==0) {
  vec2 d=(_BlurOffset+0.5)*_BlitTexture_TexelSize.xy;
  result=0.25*(textureLod(_BlitTexture,UV+vec2(-d.x,-d.y),float(_MipLevel))
   +textureLod(_BlitTexture,UV+vec2(-d.x,d.y),float(_MipLevel))
   +textureLod(_BlitTexture,UV+vec2(d.x,d.y),float(_MipLevel))
   +textureLod(_BlitTexture,UV+vec2(d.x,-d.y),float(_MipLevel)));
 } else if(_Pass==1) {
  result=texture(_BlitTexture,UV,_GlobalMipBias.x)+texture(_BlurTex,UV,_GlobalMipBias.x);
 } else { result=texture(_BlitTexture,UV,_GlobalMipBias.x); }
 COLOR=result;
}
