shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source: Windows 37.0.0.255130.254477, Hearthstone_Data/resources.assets.
// Raw render-target samples: intentionally no source_color/sRGB texture hint.
// Offsets are in SOURCE UV convention. _SourceYSign=-1 conjugates source Y to Godot Y.
uniform sampler2D _MainTex : filter_linear, repeat_disable;
uniform float _SourceYSign = -1.0;
vec2 source_offset(vec2 p) { return p * vec2(1.0, _SourceYSign); }
// resources.assets:141 Hidden/R2TColorAlphaCombine; :152 ...CombineAdd.
// One/Zero Add, ZTest Always, ZWrite Off, Cull Off.
uniform sampler2D _AlphaTex : filter_linear, repeat_disable;
uniform bool _AddAlpha = false;
void fragment() {
 vec4 c = texture(_MainTex, UV);
 float a = texture(_AlphaTex, UV).r;
 COLOR = vec4(c.rgb, clamp(a + (_AddAlpha ? c.a : 0.0), 0.0, 1.0));
 // For non-add combine source does not clamp; R8 alpha input is already [0,1].
 if (!_AddAlpha) { COLOR.a = a; }
}
