shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;
// Output-merger compatibility input, not part of the original shader formula.
// Same-build default camera and RTT use LDR/UNorm; explicit float targets may disable.
uniform bool _SourceTargetUNorm = true;
// Source cab-c394926ba464822396a05cbfae08a8b3:3820996852777312374 Hero/Unlit/Unlit_Fresnel; original serialized state in remaining_shader_evidence.json.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(0.5, 0.5, 0.5, 1.0);
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
uniform float _FresnelWidth=0.75;
uniform vec4 _FresnelColor=vec4(1.0, 0.0, 0.0, 1.0);
uniform float _FresnelIntensity=1.0;
uniform vec3 _SourceCameraObject=vec3(0.0,0.0,1.0); // Original world camera transformed into THIS object's space.
uniform mat4 _GodotToSourceObject=mat4(1.0);
varying vec4 source_fresnel;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 // Original lerps vertex COLOR towards lighting; it does not multiply COLOR by lighting.
 source_vertex_color=mix(COLOR,vec4(source_sh_gamma()+_MainLightColor,1.0),_LightingBlend)*_Color;
 vec3 p=(_GodotToSourceObject*vec4(VERTEX,1.0)).xyz;
 vec3 n=mat3(_GodotToSourceObject)*NORMAL;
 float nd=clamp(dot(n,normalize(_SourceCameraObject-p)),0.0,1.0);
 float f=clamp((_FresnelWidth-nd)/_FresnelWidth,0.0,1.0);
 source_fresnel=0.5*f*f*(3.0-2.0*f)*_FresnelColor*_FresnelIntensity;
}
void fragment() { vec4 result=texture(_MainTex,source_main_uv)*source_vertex_color+source_fresnel;

 // D3D UNorm clamps source RGBA before blend factors, not after premultiplication.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
}
