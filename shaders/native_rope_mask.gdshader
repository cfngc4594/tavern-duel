// 37.0.0.255130.254477, 3043880362771032956 Hero/MaskUV2PanUV1Alpha.
// Direct transcription of VS blob1 and PS blob3. Used by BOTH Wick and WickShadow.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D _Diffuse : source_color, filter_linear, repeat_enable;
uniform sampler2D _Mask : source_color, filter_linear, repeat_disable;
uniform vec4 _Diffuse_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Mask_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(1.0);
uniform float _Amount = 1.0;
uniform float _Xamount = 0.10000000149011612;
uniform float _LightingBlend = 1.0;
uniform float _GlobalMipBias = 0.0;
// Runtime globals, NOT recovered scene values. Replace these compatibility defaults.
uniform vec3 _UnitySHW = vec3(1.0);
uniform vec3 _MainLightColor = vec3(0.0);

// Transport options, not part of the source shader. UV/UV2 and ST are ORIGINAL
// Unity values by default. Flip only at PNG sampling; never conjugate ST twice.
uniform bool _InputUVIsFlipped = false;
uniform bool _UseCompatibilityColorBridge = true;
uniform bool _SourceTargetUNorm = true;
// 0 = source RGB; 1 = source framebuffer alpha captured in RGB. See README.
uniform int _CaptureMode = 0;
varying vec2 source_diffuse_uv;
varying vec2 source_mask_uv;
varying vec3 source_lighting;

vec2 source_uv(vec2 uv) {
    return _InputUVIsFlipped ? vec2(uv.x, 1.0 - uv.y) : uv;
}

// Existing native-combat Compatibility backend bridge, kept separate from DXBC.
vec3 source_backend_inverse(vec3 c) {
    vec3 target = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
    vec3 lo = vec3(0.0);
    vec3 hi = vec3(1.0);
    for (int i = 0; i < 20; i++) {
        vec3 m = (lo + hi) * 0.5;
        vec3 y = m * (m * (m * 0.305306011 + 0.682171111) + 0.012522878);
        vec3 take = step(y, target);
        lo = mix(lo, m, take);
        hi = mix(m, hi, take);
    }
    return mix((lo + hi) * 0.5, vec3(0.0), lessThanEqual(c, vec3(0.0)));
}

void vertex() {
    // VS 0168; VS 0179-0198 + PS 0077. The doubled UV2 is intentional.
    source_diffuse_uv = source_uv(UV) * _Diffuse_ST.xy + _Diffuse_ST.zw;
    source_mask_uv = 2.0 * (source_uv(UV2) * _Mask_ST.xy + _Mask_ST.zw)
        + vec2(_Xamount, 0.0);
    vec3 sh = clamp(pow(abs(_UnitySHW), vec3(0.416666657)) * 1.05499995
        - vec3(0.0549999997), vec3(0.0), vec3(1.0));
    // VS 0259-0282. The source ignores mesh COLOR and interpolated NORMAL.
    source_lighting = vec3(1.0) + _LightingBlend * (sh + _MainLightColor - vec3(1.0));
}

void fragment() {
    vec4 d = texture(_Diffuse, vec2(source_diffuse_uv.x, 1.0 - source_diffuse_uv.y), _GlobalMipBias);
    float m = texture(_Mask, vec2(source_mask_uv.x, 1.0 - source_mask_uv.y), _GlobalMipBias).r;
    vec4 t = d * _Color;
    // PS 0050-0104. No cutoff, discard, time, _Brightness or _XSpeed.
    vec4 result = vec4(t.rgb * (2.0 * source_lighting + vec3(1.0)), t.a * m * _Amount);
    if (_SourceTargetUNorm) { result = clamp(result, vec4(0.0), vec4(1.0)); }
    vec3 out_rgb = _CaptureMode == 1 ? vec3(result.a) : result.rgb;
    ALBEDO = _UseCompatibilityColorBridge ? source_backend_inverse(out_rgb) : out_rgb;
    ALPHA = result.a;
}
