// 37.0.0.255130.254477, 5920048614804823613 Obsolete/Pegasus/DiffuseMaskUV2PanAlpha.
// Supported source variants: blobs3/13 (_ADDITIONAL_LIGHTS) and 5/15
// (_ADDITIONAL_LIGHTS_VERTEX), WITHOUT source main-light shadow-map sampling.
// Shadowed variants remain a documented gap; do not silently label this full parity.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;

uniform sampler2D _Diffuse : source_color, filter_linear, repeat_enable;
uniform sampler2D _Mask : source_color, filter_linear, repeat_disable;
uniform vec4 _Color = vec4(1.0);
uniform float _Xamount = 0.0;
uniform float _YSpeed = 0.0;
uniform float _UnityTimeX = 0.0; // Original Unity _Time.x, i.e. source seconds / 20.
uniform float _GlobalMipBias = 0.0;
// _Diffuse_ST, _Mask_ST, _Amount and all sampled alpha are absent from DXBC math.

// Runtime globals. Defaults are neutral transport values, not recovered lighting.
uniform vec3 _MainLightColor = vec3(0.0);
uniform float _UnityLightDataZ = 1.0;
// Original shaders select at most eight per-object indices from 256 global lights.
// Bind these arrays already gathered in unity_LightIndices order, not global order.
uniform int _SourceAdditionalCount = 0;
uniform vec4 _AdditionalLightsPosition[8];
uniform vec4 _AdditionalLightsColor[8];
uniform vec4 _AdditionalLightsAttenuation[8];
uniform vec4 _AdditionalLightsSpotDir[8];
uniform bool _AdditionalLightsVertex = false;
uniform mat4 _GodotToSourceWorld = mat4(1.0);

uniform bool _InputUVIsFlipped = false;
uniform bool _UseCompatibilityColorBridge = true;
uniform bool _SourceTargetUNorm = true;
uniform int _CaptureMode = 0;
varying vec2 source_diffuse_uv;
varying vec2 source_mask_uv;
varying vec3 source_position;
varying vec3 source_normal;
varying vec3 source_vertex_irradiance;

vec2 source_uv(vec2 uv) {
    return _InputUVIsFlipped ? vec2(uv.x, 1.0 - uv.y) : uv;
}

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

vec3 source_additional_lighting(vec3 position, vec3 normal) {
    vec3 sum = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        if (i >= _SourceAdditionalCount) { break; }
        vec4 p = _AdditionalLightsPosition[i];
        vec4 a = _AdditionalLightsAttenuation[i];
        vec3 delta = p.xyz - position * p.w;
        float d2 = max(dot(delta, delta), 0.0000610351562);
        vec3 direction = delta * inversesqrt(d2);
        // Retain source division order (rather than inventing URP range falloff).
        float inverse_range = 1.0 / a.x;
        float attenuation = 1.0 / (1.0 + 25.0 * d2 / inverse_range);
        float spot = clamp(dot(_AdditionalLightsSpotDir[i].xyz, direction) * a.z + a.w, 0.0, 1.0);
        sum += _AdditionalLightsColor[i].rgb * attenuation * spot * spot
            * clamp(dot(normal, direction), 0.0, 1.0);
    }
    return sum;
}

void vertex() {
    // Source pass-through UVs, NOT material _Diffuse_ST=(0.5,1,0,0).
    source_diffuse_uv = source_uv(UV);
    source_mask_uv = source_uv(UV2);
    source_position = (_GodotToSourceWorld * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    source_normal = normalize(mat3(_GodotToSourceWorld) * MODEL_NORMAL_MATRIX * NORMAL);
    source_vertex_irradiance = _AdditionalLightsVertex
        ? source_additional_lighting(source_position, source_normal) : vec3(0.0);
}

void fragment() {
    vec3 base = texture(_Diffuse, vec2(source_diffuse_uv.x, 1.0 - source_diffuse_uv.y), _GlobalMipBias).rgb * _Color.rgb;
    vec2 mask_uv = source_mask_uv + vec2(_Xamount, _UnityTimeX * _YSpeed);
    float alpha = texture(_Mask, vec2(mask_uv.x, 1.0 - mask_uv.y), _GlobalMipBias).r;
    vec3 main_light = _MainLightColor * _UnityLightDataZ;
    vec3 additional = _AdditionalLightsVertex ? source_vertex_irradiance
        : source_additional_lighting(source_position, normalize(source_normal));
    // Source main light is NOT multiplied by N dot L in this shader.
    // PS15 adds vertex lighting AFTER albedo multiplication, unlike PS13.
    vec3 rgb = _AdditionalLightsVertex ? base * (vec3(1.0) + main_light) + additional
        : base * (vec3(1.0) + main_light + additional);
    vec4 result = vec4(rgb, alpha);
    if (_SourceTargetUNorm) { result = clamp(result, vec4(0.0), vec4(1.0)); }
    vec3 out_rgb = _CaptureMode == 1 ? vec3(result.a) : result.rgb;
    ALBEDO = _UseCompatibilityColorBridge ? source_backend_inverse(out_rgb) : out_rgb;
    ALPHA = result.a;
}
