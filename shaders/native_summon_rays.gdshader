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
uniform sampler2D _FxTex : source_color, filter_linear, repeat_enable;
uniform float _Intensity = 1.0;
uniform float _FxIntensity = 1.0;
uniform float _ScrollX = 0.0;
uniform float _ScrollY = 0.0;
uniform float _ScaleX = 1.0;
uniform float _ScaleY = 1.0;
uniform float _UnityTimeX = -1.0; // explicit original _Time.x, or default Godot elapsed seconds/20
varying vec2 source_fx_uv;
// Original One OneMinusSrcAlpha. The alpha polynomial is NOT ordinary texture alpha.
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec2 original_uv=vec2(UV.x,1.0-UV.y);
 float tx=_UnityTimeX>=0.0?_UnityTimeX:TIME*0.05;
 vec2 fxuv=original_uv*vec2(_ScaleX,_ScaleY)+tx*vec2(_ScrollX,_ScrollY);
 source_fx_uv=vec2(fxuv.x,1.0-fxuv.y);
 vec4 lighting=vec4(mix(vec3(1.0),source_sh_gamma()+_MainLightColor,_LightingBlend),1.0);
 source_vertex_color=lighting*(2.0*COLOR*_Intensity*_Color.a*_FxIntensity);
}
void fragment() {
 vec4 main=texture(_MainTex,source_main_uv);
 vec4 fx=texture(_FxTex,source_fx_uv);
 vec4 q=vec4(main.rgb*_Color.rgb,main.a*(_Color.a-main.a));
 vec4 result=clamp(fx*q*source_vertex_color,vec4(0.0),vec4(1.0));
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
