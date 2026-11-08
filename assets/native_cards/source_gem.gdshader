shader_type spatial;
// Selected source shader 9099378368919310605, Hero/Diffuse/DiffuseAlphaMaskScroller.
// Translation of exported Metal pass, NOT native Unity runtime.
// Opaque output: source MainTex alpha is effect mask, never coverage.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D main_tex : source_color, filter_linear, repeat_enable;
uniform sampler2D scrolling_tex : filter_linear, repeat_enable;
uniform vec4 main_st = vec4(1.0,1.0,0.0,0.0);
uniform vec2 scroll_scale = vec2(1.0);
uniform vec2 scroll_speed = vec2(5.0,0.2);
uniform vec3 effect_tint = vec3(1.0);
uniform vec4 tint_color = vec4(1.0);
uniform vec3 fade_rgb = vec3(1.0);
uniform float intensity = 1.0;
// Source _Time.x is Unity t/20; caller provides deterministic capture time.
uniform float unity_time_x = 0.0;
// LightingBlend=0 makes this exactly vec3(1). Other values need actual SH/main-light globals.
uniform vec3 source_lighting_factor = vec3(1.0);
void fragment() {
    // Imported mesh UV is flipped to top-left. Reconstruct source UV before transforms.
    vec2 source_uv = vec2(UV.x,1.0-UV.y);
    vec2 muv = source_uv*main_st.xy+main_st.zw;
    vec2 suv = source_uv*scroll_scale+unity_time_x*scroll_speed;
    vec4 main = texture(main_tex,vec2(muv.x,1.0-muv.y));
    float noise = texture(scrolling_tex,vec2(suv.x,1.0-suv.y)).r;
    ALBEDO=(main.rgb + noise*effect_tint*main.a*1.5*intensity)*fade_rgb*tint_color.rgb*source_lighting_factor;
    // Do not write ALPHA: shader stays in opaque pipeline (source One/Zero).
}
