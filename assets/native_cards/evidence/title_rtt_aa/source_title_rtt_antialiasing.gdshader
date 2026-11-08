shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Compatible algebra translation of original Hidden/TextAntialiasing 3442879436887144160.
// Not original Unity runtime. Curve mesh UV is already Y-flipped for Godot.
// Source is an RTT, not imported sRGB art; do not apply source_color a second time.
uniform sampler2D source_rt : filter_linear, repeat_disable;
uniform vec4 source_main_st = vec4(1.0,1.0,0.0,0.0);
uniform vec4 text_color : source_color = vec4(1.0);
uniform vec2 rt_texel_size = vec2(1.0/570.0,1.0/90.0);
uniform float offset_texels = 0.5;
uniform float edge = 0.5;
uniform float source_mip_bias = 0.0;
vec2 rt_uv(vec2 unity_uv) {
 vec2 u=unity_uv*source_main_st.xy+source_main_st.zw;
 return vec2(u.x,1.0-u.y);
}
void fragment() {
 vec2 u=vec2(UV.x,1.0-UV.y);
 vec2 o=rt_texel_size*offset_texels;
 float a=texture(source_rt,rt_uv(u+o),source_mip_bias).a;
 a+=texture(source_rt,rt_uv(u-o),source_mip_bias).a;
 a+=texture(source_rt,rt_uv(u+vec2(o.x,-o.y)),source_mip_bias).a;
 a+=texture(source_rt,rt_uv(u+vec2(-o.x,o.y)),source_mip_bias).a;
 vec4 tint=COLOR*text_color;
 ALBEDO=texture(source_rt,rt_uv(u),source_mip_bias).rgb*tint.rgb;
 ALPHA=a*edge*tint.a;
 // No center-alpha sample, no explicit clamp, no smoothing function in original.
}
