// Original framebuffer alpha captured in RGB, NOT coverage.
// Source alpha Blend 5/10. Clear RGB to vec3(source clear.a).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Output-merger compatibility input, not part of the original shader formula.
// Same-build default camera and RTT use LDR/UNorm; explicit float targets may disable.
uniform bool _SourceTargetUNorm = true;
// Same-build Windows DXBC formula. Capture color space is a runtime input, not inferred here.
uniform sampler2D _MainTex : filter_linear, repeat_disable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float _LightingBlend = 0.0;
uniform vec3 _UnitySHW = vec3(1.0);
uniform vec3 _MainLightColor = vec3(0.0);
varying vec2 source_uv;
varying vec4 source_vertex_color;
vec3 source_sh_gamma() {
 return clamp(pow(abs(_UnitySHW),vec3(0.416666657))*1.05499995-vec3(0.0549999997),vec3(0.0),vec3(1.0));
}
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
// resources.assets:160 Hidden/R2TAlphaClip. SrcAlpha/OneMinusSrcAlpha, LEqual, Cull Off.
// _Cutoff is an EXPONENT, not a clip/discard threshold.
uniform float _Cutoff = 15.0;
uniform float _Intensity = 1.0;
uniform float _AlphaIntensity = 1.0;
void vertex() {
 source_uv = UV * _MainTex_ST.xy + _MainTex_ST.zw;
 source_vertex_color = COLOR * _Color * vec4(mix(vec3(1.0), source_sh_gamma()+_MainLightColor, _LightingBlend), 1.0);
}
void fragment() {
 vec4 t = texture(_MainTex, source_uv);
 vec4 result = vec4(t.rgb * _Intensity, pow(t.a * _AlphaIntensity, _Cutoff)) * source_vertex_color;
 // D3D UNorm clamps source RGBA before blend factors, not after premultiplication.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));
 ALPHA=result.a;
}
