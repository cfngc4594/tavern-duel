shader_type canvas_item;
render_mode unshaded, blend_mix;
// Original Custom/Selection/Highlight arithmetic, static hand silhouette.
// 2D projected original mesh; canvas color backend is a compatibility port.
uniform sampler2D _MainTex : filter_linear, repeat_enable;
uniform sampler2D _FlareTex : filter_linear, repeat_enable;
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
void fragment(){
 float base=texture(_MainTex,UV).r*_Intensity*1.20000005;
 float phase=_Seed+_ShaderTime;
 vec2 flare_uv=vec2(flare_x*_UflareScale+phase*0.0500000007,base*_VflareScale+phase*_VflareSpeed);
 float flare=texture(_FlareTex,vec2(flare_uv.x,1.0-flare_uv.y)).r;
 float k=2.0*(flare*vertex_red+base)*base*_FlareIntensity;
 vec3 rgb=(_Color.rgb+k*(_HiColor.rgb*k-_Color.rgb))*_ColorIntensity;
 float a=(1.0+_ColorAlphaWeight*(vertex_red-1.0))*k;
 COLOR=clamp(vec4(rgb,a)*_Colorize,vec4(0.0),vec4(1.0));
}
