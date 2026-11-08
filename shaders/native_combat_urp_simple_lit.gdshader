shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
// Output-merger compatibility input, not part of the original shader formula.
// Same-build default camera and RTT use LDR/UNorm; explicit float targets may disable.
uniform bool _SourceTargetUNorm = true;
// Original URP Particles/Simple Lit ForwardLit blobs 4/61, shader 7761990499585583733.
// Variant _ADDITIONAL_LIGHTS + _SURFACE_TYPE_TRANSPARENT + _EMISSION.
// Surface math is recovered; original per-draw lighting/global keyword state is not.
uniform sampler2D _BaseMap : source_color, filter_linear, repeat_enable;
uniform sampler2D _EmissionMap : source_color, filter_linear, repeat_enable;
uniform vec4 _BaseColor = vec4(1.0);
uniform vec4 _EmissionColor = vec4(0.0);
uniform float _Surface = 1.0;
// Neutral lighting defaults are explicit compatibility inputs, not recovered scene state.
uniform vec4 _UnitySHAr = vec4(0.0,0.0,0.0,1.0);
uniform vec4 _UnitySHAg = vec4(0.0,0.0,0.0,1.0);
uniform vec4 _UnitySHAb = vec4(0.0,0.0,0.0,1.0);
uniform vec4 _UnitySHBr = vec4(0.0);
uniform vec4 _UnitySHBg = vec4(0.0);
uniform vec4 _UnitySHBb = vec4(0.0);
uniform vec4 _UnitySHC = vec4(0.0);
uniform vec4 _MainLightPosition = vec4(0.0,1.0,0.0,0.0);
uniform vec4 _MainLightColor = vec4(0.0);
uniform float _UnityLightDataZ = 1.0;
// Upload selected per-object light list in unity_LightIndices order, maximum eight.
uniform int _SourceAdditionalCount = 0;
uniform vec4 _AdditionalLightsPosition[8];
uniform vec4 _AdditionalLightsColor[8];
uniform vec4 _AdditionalLightsAttenuation[8];
uniform vec4 _AdditionalLightsSpotDir[8];
uniform mat4 _GodotToSourceWorld = mat4(1.0);
varying vec2 source_uv;
varying vec4 source_rgba;
varying vec3 source_position;
varying vec3 source_normal;
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

vec3 source_sh(vec3 n) {
 vec4 normal4=vec4(n,1.0);
 vec3 sh_a=vec3(dot(_UnitySHAr,normal4),dot(_UnitySHAg,normal4),dot(_UnitySHAb,normal4));
 vec4 cross_terms=n.yzzx*n.xyzz;
 vec3 sh_b=vec3(dot(_UnitySHBr,cross_terms),dot(_UnitySHBg,cross_terms),dot(_UnitySHBb,cross_terms));
 vec3 sh=sh_a+sh_b+_UnitySHC.rgb*(n.x*n.x-n.y*n.y);
 vec3 high=1.05499995*pow(abs(sh),vec3(0.416666657))-vec3(0.0549999997);
 return mix(high,sh*12.9232101,lessThanEqual(sh,vec3(0.00313080009)));
}
void vertex() {
 source_uv=UV; // Original pass does not transform UV by BaseMap_ST.
 source_rgba=COLOR;
 source_position=(_GodotToSourceWorld*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 source_normal=normalize(mat3(_GodotToSourceWorld)*MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec4 base=texture(_BaseMap,source_uv)*_BaseColor*source_rgba;
 vec3 n=normalize(source_normal);
 vec3 light=source_sh(n)+clamp(dot(n,_MainLightPosition.xyz),0.0,1.0)*_MainLightColor.rgb*_UnityLightDataZ;
 for (int i=0;i<8;i++) {
  if (i>=_SourceAdditionalCount) break;
  vec4 pos=_AdditionalLightsPosition[i];
  vec4 att=_AdditionalLightsAttenuation[i];
  vec3 delta=pos.xyz-source_position*pos.w;
  float d2=max(dot(delta,delta),0.0000610351562);
  vec3 direction=delta*inversesqrt(d2);
  float range_factor=max(1.0-(d2*att.x)*(d2*att.x),0.0);
  float spot=clamp(dot(_AdditionalLightsSpotDir[i].xyz,direction)*att.z+att.w,0.0,1.0);
  float attenuation=range_factor*range_factor/d2*spot*spot;
  light+=clamp(dot(n,direction),0.0,1.0)*_AdditionalLightsColor[i].rgb*attenuation;
 }
 vec4 result=vec4(base.rgb*light+texture(_EmissionMap,source_uv).rgb*_EmissionColor.rgb,_Surface==1.0?base.a:1.0);
 // D3D UNorm clamps source RGBA before blend factors, not after premultiplication.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
