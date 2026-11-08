shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source: Windows 37.0.0.255130.254477, Hearthstone_Data/resources.assets.
// Raw render-target samples: intentionally no source_color/sRGB texture hint.
// Offsets are in SOURCE UV convention. _SourceYSign=-1 conjugates source Y to Godot Y.
uniform sampler2D _MainTex : filter_linear, repeat_disable;
uniform float _SourceYSign = -1.0;
vec2 source_offset(vec2 p) { return p * vec2(1.0, _SourceYSign); }
// resources.assets:169 Hidden/R2TBlur; :187 Hidden/R2TAlphaBlur.
// One/Zero Add, ZTest Always, ZWrite Off, Cull Off.
uniform vec4 _MainTex_TexelSize = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 _BlurOffsets = vec4(0.0);
uniform bool _AlphaOnly = false;
void fragment() {
 vec2 delta = source_offset(_MainTex_TexelSize.xy * _BlurOffsets.xy);
 vec2 center = UV - delta;
 vec4 c = texture(_MainTex, center);
 vec4 result = c + texture(_MainTex, UV) + texture(_MainTex, center - delta)
  + texture(_MainTex, center + delta * vec2(1.0, -1.0))
  + texture(_MainTex, center - delta * vec2(1.0, -1.0));
 result *= 0.200000003;
 // Original alpha-only path keeps RGB at shifted center, NOT UV.
 if (_AlphaOnly) { result.rgb = c.rgb; }
 COLOR = result;
}
