shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back, fog_disabled;
// Source143677912420122213 Hero/Unlit/Unlit_Texture, DXBC blob1/blob3.
// Original One/Zero, ZWriteOn, LEqual, CullBack; texture alpha is NOT coverage.
// Original vertex output mix(vertexCOLOR, vec4(SHgamma+mainlight,1),LightingBlend).
// Original fragment output texture*vertex output. Scene light globals remain compatibility inputs.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST=vec4(1.0,1.0,0.0,0.0);
uniform float _LightingBlend=0.0;
uniform vec3 _UnitySHW=vec3(1.0);
uniform vec3 _MainLightColor=vec3(0.0);
varying vec4 source_lit_color;
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

void vertex(){
 vec3 sh=clamp(pow(abs(_UnitySHW),vec3(0.416666657))*1.05499995-vec3(0.0549999997),vec3(0.0),vec3(1.0));
 source_lit_color=mix(COLOR,vec4(sh+_MainLightColor,1.0),_LightingBlend);
}
void fragment(){
 vec4 result=texture(_MainTex,UV*_MainTex_ST.xy+_MainTex_ST.zw)*source_lit_color;
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
}
