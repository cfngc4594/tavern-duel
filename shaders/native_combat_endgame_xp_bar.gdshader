shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;
uniform bool _SourceTargetUNorm=true;
// Original Custom/FX/FX_XPBar cab-c394926ba464822396a05cbfae08a8b3:-5749398157059875989. See v33 source DXBC and uniform register maps.
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
uniform sampler2D _NoiseTex : source_color, filter_linear, repeat_enable;
uniform float _NoiseScale1=1.0;
uniform float _NoiseScale2=1.0;
uniform float _Uadd=0.0;
uniform float _Intensity=1.0;
uniform float _Percent=0.0;
uniform float _UnityTimeX=0.0;
varying vec2 source_secondary_uv;
varying vec2 source_noise1_uv;
varying vec2 source_noise2_uv;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 source_secondary_uv=UV2*_MainTex_ST.xy+_MainTex_ST.zw;
 vec2 st_offset=vec2(_MainTex_ST.z,1.0-_MainTex_ST.y-_MainTex_ST.w);
 vec2 u=vec2(UV2.x,1.0-UV2.y);
 vec2 n1=vec2(u.x*_NoiseScale1-_UnityTimeX*1.70000005-_Uadd,u.y*0.100000001-_UnityTimeX*0.150000006)*_MainTex_ST.xy+st_offset;
 vec2 n2=vec2(u.x*_NoiseScale2-_UnityTimeX*3.5-_Uadd,u.y*0.300000012-_UnityTimeX*0.449999988)*_MainTex_ST.xy+st_offset;
 source_noise1_uv=vec2(n1.x,1.0-n1.y);source_noise2_uv=vec2(n2.x,1.0-n2.y);
}
void fragment() {
 vec2 u=vec2(clamp(source_secondary_uv.x+0.5-_Percent,0.100000001,0.899999976),1.0-((1.0-source_secondary_uv.y)*0.0399999991-_UnityTimeX*0.400000006));
 vec4 ramp=texture(_MainTex,u);vec4 a=texture(_NoiseTex,source_noise1_uv);vec4 b=texture(_NoiseTex,source_noise2_uv);
 vec4 result=clamp((a+b*(b-a))*_Intensity*ramp.a+texture(_MainTex,source_main_uv),vec4(0.0),vec4(1.0));

 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
}
