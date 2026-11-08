shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;
// Output-merger compatibility input, not part of the original shader formula.
// Same-build default camera and RTT use LDR/UNorm; explicit float targets may disable.
uniform bool _SourceTargetUNorm = true;
// Source cab-c394926ba464822396a05cbfae08a8b3:4578800529589026196 Custom/Card/SelfIlluminDiffuse; original serialized state in remaining_shader_evidence.json.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float _Illum=1.0;
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
// Source unshadowed _ADDITIONAL_LIGHTS variant: blob3 vertex, blob15 fragment.
// Explicit source scene-light inputs. Defaults are compatibility values, not recovered scene lighting.
uniform vec4 _MainLightPosition=vec4(0.0,1.0,0.0,0.0);
uniform float _UnityLightDataZ=1.0;
uniform int _SourceAdditionalCount=0;
uniform vec4 _AdditionalLightsPosition[8];
uniform vec4 _AdditionalLightsColor[8];
uniform vec4 _AdditionalLightsAttenuation[8];
uniform vec4 _AdditionalLightsSpotDir[8];
uniform mat4 _GodotToSourceWorld=mat4(1.0);
varying vec3 source_position;
varying vec3 source_normal;
void vertex() {
 source_main_uv=UV; // Source no-scale-offset texture: no ST arithmetic in blob3.
 source_position=(_GodotToSourceWorld*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 source_normal=normalize(mat3(_GodotToSourceWorld)*MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec4 t=texture(_MainTex,source_main_uv)*_Color;
 vec3 n=normalize(source_normal);
 vec3 light=source_sh_gamma()+_MainLightColor*_UnityLightDataZ*clamp(dot(n,_MainLightPosition.xyz),0.0,1.0);
 for(int i=0;i<8;i++) {
  if(i>=_SourceAdditionalCount) { break; }
  vec4 p=_AdditionalLightsPosition[i];
  vec4 a=_AdditionalLightsAttenuation[i];
  vec3 delta=p.xyz-source_position*p.w;
  float d2=max(dot(delta,delta),0.0000610351562);
  vec3 direction=delta*inversesqrt(d2);
  // This older Hero/Diffuse family uses 1/(1+25*d2*a.x), NOT URP SimpleLit's range falloff.
  float distance_attenuation=1.0/(1.0+25.0*d2*a.x);
  float spot=clamp(dot(_AdditionalLightsSpotDir[i].xyz,direction)*a.z+a.w,0.0,1.0);
  light+=_AdditionalLightsColor[i].rgb*distance_attenuation*spot*spot*clamp(dot(n,direction),0.0,1.0);
 }
 vec4 result=vec4(t.rgb*(light+vec3(_Illum)),t.a);

 // D3D UNorm clamps source RGBA before blend factors, not after premultiplication.
 result=clamp(result,vec4(0.0),vec4(1.0));
 ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));
}
