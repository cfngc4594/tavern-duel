// Target-specific UNorm bridge; original vertex/pixel arithmetic unchanged.
// Microsoft D3D11 Output-Merger Stage: preblend input range follows target format.
// Original framebuffer alpha captured in RGB, NOT coverage.
// Source alpha Blend 5/10. Clear RGB to vec3(source clear.a).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Output-merger compatibility input, not part of the original shader formula.
// Same-build default camera and RTT use LDR/UNorm; explicit float targets may disable.
uniform bool _SourceTargetUNorm = true;
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
uniform sampler2D _RampTex : source_color, filter_linear, repeat_disable;
uniform float _RampIntensity=1.0;
uniform float _Intensity=1.0;
uniform float _Alpha=1.0;
void vertex() { source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw; source_vertex_color=COLOR; }
void fragment() {
 float ramp_u=texture(_MainTex,source_main_uv).r*_RampIntensity;
 vec4 result=texture(_RampTex,vec2(ramp_u,0.5))*vec4(_Color.rgb*_Color.a,1.0)*_Intensity*_Alpha;

 // D3D UNorm clamps source RGBA before blend factors, not after premultiplication.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 // D3D UNorm output merger clamps source RGBA before applying blend factors.
 result=clamp(result,vec4(0.0),vec4(1.0));
 ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));
 ALPHA=result.a;
}
