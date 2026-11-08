// Original Unlit_Transparent2uvScrollMaskScroll: vertex blob1 + pixel blob3.
// MainTex ST applies to all routes, UV2 green mask, RGB mask channels independent.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
uniform sampler2D _MainTex : source_color,filter_linear,repeat_enable;
uniform sampler2D _MaskTex : filter_linear,repeat_enable;
uniform vec4 _MainTex_ST=vec4(1,1,0,0);
uniform vec4 _Color=vec4(1);
uniform vec3 _UnitySHW=vec3(1);
uniform vec3 _MainLightColor=vec3(0);
uniform float _SourceTime=0.0;
uniform float _Intensity=1.0;
uniform float _ScrollMainX=0.0;
uniform float _ScrollMainY=0.0;
uniform float _UVOffsetMainU=0.0;
uniform float _UVOffsetMainV=0.0;
uniform float _ScaleMainX=1.0;
uniform float _ModIntensity=1.0;
uniform float _ScrollModX=0.0;
uniform float _ScrollModY=0.0;
uniform float _ScaleModX=1.0;
uniform float _ScaleModY=1.0;
uniform float _ScrollGMaskX=0.0;
uniform float _ScrollGMaskY=0.0;
uniform float _MaskModIntensity=1.0;
uniform float _UVOffsetModMaskU=0.0;
uniform float _UVOffsetModMaskV=0.0;
uniform float _ScrollMaskX=0.0;
uniform float _ScrollMaskY=0.0;
uniform float _ScaleMaskX=1.0;
uniform float _ScaleMaskY=1.0;
uniform float _LightingBlend=0.0;
uniform float _Seed=0.0;
varying vec2 uv_green;
varying vec2 uv_red;
varying vec2 uv_blue;
varying vec2 uv_main;
varying vec4 source_vertex_tint;
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
 float t=_SourceTime/20.0;
 vec2 uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 uv_green=UV2*_MainTex_ST.xy+_MainTex_ST.zw+t*vec2(_ScrollGMaskX,_ScrollGMaskY);
 uv_red=uv*vec2(_ScaleModX,_ScaleModY)+t*vec2(_ScrollModX,_ScrollModY)+vec2(_Seed);
 uv_blue=(uv+vec2(_UVOffsetModMaskU,_UVOffsetModMaskV))*vec2(_ScaleMaskX,_ScaleMaskY)+t*vec2(_ScrollMaskX,_ScrollMaskY)+vec2(_Seed);
 // Compiled source uses ScaleMainX for BOTH axes; serialized ScaleMainY is not read.
 uv_main=uv*_ScaleMainX+t*vec2(_ScrollMainX,_ScrollMainY)+vec2(_UVOffsetMainU,_UVOffsetMainV);
 vec3 sh=clamp(pow(abs(_UnitySHW),vec3(0.416666657))*1.05499995-vec3(0.0549999997),vec3(0),vec3(1));
 source_vertex_tint=COLOR*_Intensity*_Color*vec4(mix(vec3(1),sh+_MainLightColor,_LightingBlend),1);
}
vec2 tex_uv(vec2 uv){return vec2(uv.x,1.0-uv.y);}
void fragment(){
 float a=texture(_MaskTex,tex_uv(uv_blue)).b*_MaskModIntensity*texture(_MaskTex,tex_uv(uv_green)).g*texture(_MaskTex,tex_uv(uv_red)).r*_ModIntensity;
 vec4 result=vec4(texture(_MainTex,tex_uv(uv_main)).rgb,a)*source_vertex_tint;
 result=clamp(result,vec4(0),vec4(1));
 ALBEDO=source_backend_inverse(result.rgb);ALPHA=result.a;
}
