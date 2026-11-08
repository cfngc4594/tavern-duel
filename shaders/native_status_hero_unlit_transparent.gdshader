shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
// Output-merger compatibility input, not part of the original shader formula.
// Same-build default camera and RTT use LDR/UNorm; explicit float targets may disable.
uniform bool _SourceTargetUNorm = true;
// Shader arithmetic transcribed from original 37.0.0.255130.254477 D3D11 SM4 bytecode.
// Godot GL backend translation, not the original Unity runtime.
// Mesh UV and ST must already be Y-conjugated by the existing native asset adapter.
// Original texture state: trilinear, repeat U/V/W, mip bias -0.5, one mip only.
// Use bilinear without generated mip levels. _GlobalMipBias has no effect at one level.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform float _GlobalMipBias = 0.0;
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
// Hero/Unlit_Transparent, path ID -1939901832466623549.
// Source: SrcAlpha OneMinusSrcAlpha in BOTH RGB and alpha; ZTest LEqual,
// ZWrite Off, Cull Back. Godot blend_mix destination-alpha differs from source
// Aout=As*As+Ad*(1-As); transparent RT alpha equivalence requires dual RT.
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec4 lighting=vec4(mix(vec3(1.0),source_sh_gamma()+_MainLightColor,_LightingBlend),1.0);
 source_vertex_color=COLOR*lighting;
}
void fragment() {
 vec4 result=texture(_MainTex,source_main_uv,_GlobalMipBias)*source_vertex_color;
 // Output-merger UNorm conversion is separate from the recovered shader arithmetic.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
