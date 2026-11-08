shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
// Hero/Unlit/Unlit_Dissolve -3072726488366958506, blob1/3 + parsed CB offsets.
// LightingBlend=0 in native coin material. No guessed scene light is introduced.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform sampler2D _DissolveTex : source_color, filter_linear, repeat_enable;
uniform sampler2D _EdgeDetailTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST=vec4(1.0,1.0,0.0,0.0);
uniform vec4 _Color=vec4(1.0);
uniform vec4 _EdgeColor=vec4(1.0,0.0,0.0,1.0);
uniform float _ScrollX=0.0;
uniform float _ScrollY=0.0;
uniform float _Scale=1.0;
uniform float _Dissolve=1.0;
uniform float _EdgeIntensity=1.0;
uniform float _EdgeSize=0.1;
uniform float _DarkenSize=1.0;
uniform float _DarkenIntensity=1.0;
uniform float _Cutout=40.0;
uniform float _UnityTimeX=0.0;
varying vec2 main_uv;
varying vec2 edge_uv;
varying vec4 vertex_color;
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

void vertex() {
 main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec2 source_uv=vec2(UV.x,1.0-UV.y);
 vec2 edge=(source_uv+_UnityTimeX*vec2(_ScrollX,_ScrollY))*_Scale;
 edge_uv=vec2(edge.x,1.0-edge.y);
 vertex_color=COLOR;
}
void fragment() {
 vec4 main_sample=texture(_MainTex,main_uv);
 vec3 base=main_sample.rgb*_Color.rgb+vec3(_DarkenIntensity);
 float base_alpha=main_sample.a*_Color.a;
 float noise=texture(_DissolveTex,main_uv).r;
 float delta=noise-_Dissolve;
 float alpha=base_alpha*(1.0-pow(clamp(1.0-noise+_Dissolve,0.0,1.0),_Cutout));
 float darken=clamp(_EdgeSize*_DarkenSize+delta,0.0,1.0);
 float edge_factor=clamp(2.0*_EdgeSize+delta,0.0,1.0);
 vec3 lit=darken*base-vec3(_DarkenIntensity);
 float detail=texture(_EdgeDetailTex,edge_uv).r;
 vec3 glow=_EdgeColor.rgb*_EdgeIntensity*detail;
 vec3 rgb=(edge_factor*(lit-glow)+glow)*vertex_color.rgb;
 ALBEDO=source_backend_inverse(clamp(rgb,vec3(0.0),vec3(1.0)));
 ALPHA=clamp(alpha*vertex_color.a,0.0,1.0);
}
