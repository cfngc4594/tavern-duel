shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source: Windows 37.0.0.255130.254477, Hearthstone_Data/resources.assets.
// Raw render-target samples: intentionally no source_color/sRGB texture hint.
// Offsets are in SOURCE UV convention. _SourceYSign=-1 conjugates source Y to Godot Y.
uniform sampler2D _MainTex : filter_linear, repeat_disable;
uniform float _SourceYSign = -1.0;
vec2 source_offset(vec2 p) { return p * vec2(1.0, _SourceYSign); }
// resources.assets:153 Hidden/R2TBloom; :173 Hidden/R2TBloomAlpha;
// :176 Hidden/R2TAlphaClipBloom. Passes: copy 0, threshold/max 1, four-tap 2.
// All passes One/Zero Add, ZWrite Off, Cull Off, ZTest disabled.
uniform sampler2D _Bloom : hint_default_black, filter_linear, repeat_disable;
uniform int _Pass = 1;
uniform int _BloomMode = 0; // 0: color, 1: alpha, 2: alpha-clip bloom.
uniform vec4 _OffsetA = vec4(0.0);
uniform vec4 _OffsetB = vec4(0.0);
uniform float _Threshold = 0.75;
uniform float _Intensity = 0.699999988079071;
uniform float _AlphaIntensity = 1.0;
uniform float _ColorIntensity = 1.0;
uniform float _Cutoff = 15.0;
vec4 source_clip(vec4 t) {
 return vec4(t.rgb * _ColorIntensity, pow(t.a * _AlphaIntensity, _Cutoff));
}
void fragment() {
 vec4 result;
 if (_Pass == 0) {
  result = texture(_MainTex, UV);
  if (_BloomMode == 1) { result = vec4(result.a + texture(_Bloom, UV).a); }
  else if (_BloomMode == 2) { result = source_clip(result); }
 } else if (_Pass == 1) {
  vec4 c = texture(_MainTex, UV);
  vec4 a = texture(_MainTex, UV + source_offset(_OffsetA.xy));
  vec4 b = texture(_MainTex, UV + source_offset(_OffsetA.zw));
  vec4 d = texture(_MainTex, UV + source_offset(_OffsetB.xy));
  vec4 e = texture(_MainTex, UV + source_offset(_OffsetB.zw));
  if (_BloomMode == 1) {
   // Original multiplies ONLY the center alpha before the five-way maximum.
   result = vec4(max(max(max(max(c.a * _AlphaIntensity, a.a), b.a), d.a), e.a));
  } else {
   result = max(max(max(max(c, a), b), d), e);
   if (_BloomMode == 2) { result = source_clip(result); }
  }
  result = clamp(result - vec4(_Threshold), vec4(0.0), vec4(1.0)) * _Intensity;
 } else {
  result = texture(_MainTex, UV + source_offset(_OffsetA.xy))
         + texture(_MainTex, UV + source_offset(_OffsetA.zw))
         + texture(_MainTex, UV + source_offset(_OffsetB.xy))
         + texture(_MainTex, UV + source_offset(_OffsetB.zw));
  if (_BloomMode == 1) { result = vec4(result.a); }
  else if (_BloomMode == 2) { result.rgb *= _ColorIntensity; }
  result *= 0.25;
 }
 COLOR = result;
}
