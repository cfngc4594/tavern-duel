shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Original Custom/Selection/Highlight arithmetic, static hand silhouette.
// Original mesh registered to the existing card plane; verified Godot GL color bridge.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform sampler2D _FlareTex : source_color, filter_linear, repeat_enable;
uniform vec4 _Color = vec4(1.0);
uniform vec4 _Colorize = vec4(1.0);
uniform vec4 _HiColor = vec4(1.0);
uniform float _ColorIntensity=1.0;
uniform float _Intensity=1.0;
uniform float _FlareIntensity=1.0;
uniform float _VflareSpeed=1.0;
uniform float _UflareScale=1.0;
uniform float _VflareScale=1.0;
uniform float _ColorAlphaWeight=1.0;
uniform float _Seed=0.0;
uniform float _TexCoordTwoWeight=1.0;
uniform float _ShaderTime=0.0;
varying float vertex_red;
varying float flare_x;
void vertex(){
 vertex_red=COLOR.r;
 // CPU packs original UV2.x in green; original vertex red stays unchanged.
 flare_x=mix(UV.x,COLOR.g,_TexCoordTwoWeight);
 COLOR=vec4(1.0);
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
void fragment(){
 float base=texture(_MainTex,UV).r*_Intensity*1.20000005;
 float phase=_Seed+_ShaderTime;
 vec2 flare_uv=vec2(flare_x*_UflareScale+phase*0.0500000007,base*_VflareScale+phase*_VflareSpeed);
 float flare=texture(_FlareTex,vec2(flare_uv.x,1.0-flare_uv.y)).r;
 float k=2.0*(flare*vertex_red+base)*base*_FlareIntensity;
 vec3 rgb=(_Color.rgb+k*(_HiColor.rgb*k-_Color.rgb))*_ColorIntensity;
 float a=(1.0+_ColorAlphaWeight*(vertex_red-1.0))*k;
 vec4 result=clamp(vec4(rgb,a)*_Colorize,vec4(0.0),vec4(1.0));
 ALBEDO=source_backend_inverse(result.rgb); ALPHA=result.a;
}
