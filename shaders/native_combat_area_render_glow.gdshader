shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;
// Source cab-c394926ba464822396a05cbfae08a8b3:-1499608994728766255 Custom/FX/FX_AreaEffect_Render; original serialized state in remaining_shader_evidence.json.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(0.5, 0.5, 0.5, 0.5);
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
// Original pass 1 LIGHTMODE GlowAdditive. Do not attach as ordinary next_pass.
// One/One RGB and alpha; source material FireAE_RenderPlane GlowIntensity=.75.
uniform vec4 _GlowColor=vec4(1.0, 1.0, 1.0, 1.0);
uniform float _GlowIntensity=0.0;
uniform float _GlowAddMul=0.0;
void vertex() { source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw; source_vertex_color=COLOR; }
void fragment() {
 vec4 q=2.0*source_vertex_color*texture(_MainTex,source_main_uv);
 vec4 result=0.25*dot(q.rgb,vec3(0.333000004))*vec4(q.rgb*_GlowColor.rgb,q.a*_GlowAddMul)*_GlowIntensity;
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=0.0;
}
