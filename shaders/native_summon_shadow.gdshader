shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;
// Shader arithmetic transcribed from original 37.0.0.255130.254477 D3D11 SM4 bytecode.
// Godot GL backend translation, not the original Unity runtime.
// Mesh UV and ST are already Y-conjugated by native_summon_assets.gd.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(1.0);
uniform float _LightingBlend = 0.0;
// Neutral compatibility defaults ONLY. Actual original scene global values are not recovered.
uniform vec3 _UnitySHW = vec3(1.0);
uniform vec3 _MainLightColor = vec3(0.0);
varying vec4 source_vertex_color;
varying vec2 source_main_uv;
vec3 source_sh_gamma() {
 return clamp(pow(abs(_UnitySHW),vec3(0.416666657))*1.05499995-vec3(0.0549999997),vec3(0.0),vec3(1.0));
}
// Reuse the existing native_cards verified GL color bridge, separated from original formula.
vec3 source_backend_inverse(vec3 c) {
 vec3 target=pow((c+vec3(0.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0); vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++) {
  vec3 m=(lo+hi)*0.5;
  vec3 y=m*(m*(m*0.305306011+0.682171111)+0.012522878);
  vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);
 }
 return mix((lo+hi)*0.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}
// Original Effects/FX_Transparent_ColorAsAlpha, path ID -2557555604182605517.
// Exact RGB/alpha blend: One, OneMinusSrcAlpha. NOT DstColor/multiply.
// No vertex COLOR, no _Color.a, no texture alpha, no lighting in this original program.
uniform float _Intensity = 1.0;
uniform float _AlphaIntensity = 1.0;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
}
void fragment() {
 vec3 texel=texture(_MainTex,source_main_uv).rgb;
 float lum=dot(texel,vec3(0.300000012,0.589999974,0.109999999));
 vec4 result=vec4(texel*_Color.rgb,lum*_AlphaIntensity)*_Intensity;
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
