shader_type spatial;
render_mode unshaded, depth_draw_always, cull_back, fog_disabled;
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(1.0);
uniform float _LightingBlend = 0.0;
// Neutral compatibility defaults ONLY. Actual original scene global values are not recovered.
uniform vec3 _UnitySHW = vec3(1.0);
uniform vec3 _MainLightColor = vec3(0.0);
uniform bool _SourceTargetUNorm=true;
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
// Source Custom/Card/UnlitDesat, -477307002458744689, DXBC blobs 1/3.
// Original spelling _Transistion is intentional. Source One/Zero RGBA, CullBack,
// ZWrite On, ZTest LEqual. MainLightColor.w participates in the vertex alpha.
uniform float _MainLightAlpha=1.0; // Compatibility default; original live value unknown.
uniform float _ValueRange=1.0;
uniform float _Transistion=0.0;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 source_vertex_color=mix(COLOR,vec4(source_sh_gamma(),1.0)+vec4(_MainLightColor,_MainLightAlpha),_LightingBlend);
}
void fragment() {
 vec4 t=texture(_MainTex,source_main_uv);
 float gray=0.300000012*_ValueRange*(t.r+t.g+t.b);
 vec4 result=mix(t,_Color*gray,_Transistion)*source_vertex_color;
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 // Keep opaque depth/sorting: no ALPHA write. Use separate alpha capture if needed.
}
