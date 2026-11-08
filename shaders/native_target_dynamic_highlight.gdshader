shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// Shader arithmetic transcribed from original 37.0.0.255130.254477 D3D11 SM4 bytecode.
// Godot GL backend translation, not the original Unity runtime.
// Mesh UV and ST are already Y-conjugated by native_summon_assets.gd.
// Dynamic HighlightRender m_CameraTexture has Clamp U/V/W. Static baked masks
// retain their original shared shader; _FlareTex remains authored Repeat.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_disable;
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 _Color = vec4(1.0);
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
// Exact Custom/Selection/Highlight, path ID -1327719733717699995.
// This source shader is NOT AddMultiply. MainTex.r is a runtime silhouette binding.
// Original RGB/alpha blend is SrcAlpha OneMinusSrcAlpha; apply the verified RT coverage bridge in production.
uniform sampler2D _FlareTex : source_color, filter_linear, repeat_enable;
uniform vec4 _Colorize = vec4(1.0);
uniform vec4 _HiColor = vec4(1.0);
uniform float _ColorIntensity = 1.0;
uniform float _Intensity = 1.0;
uniform float _FlareIntensity = 1.0;
uniform float _VflareSpeed = 1.0;
uniform float _UflareScale = 1.0;
uniform float _VflareScale = 1.0;
uniform float _ColorAlphaWeight = 1.0;
uniform float _Seed = 0.0;
uniform float _TexCoordTwoWeight = 1.0;
// Original ShaderTime.UpdateShaderAnimationTime: float32 deltaTime/20 and wrap65535.
// Application start phase remains a compatibility clock, not original client time.
uniform float _ShaderTime = 0.0;
varying float source_flare_x;
varying float source_vertex_red;
varying float source_phase;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec2 second_uv=UV2*_MainTex_ST.xy+_MainTex_ST.zw;
 source_flare_x=mix(source_main_uv.x,second_uv.x,_TexCoordTwoWeight);
 source_vertex_red=COLOR.r;
 source_phase=_Seed+_ShaderTime;
}
void fragment() {
 float base=texture(_MainTex,source_main_uv).r*_Intensity*1.20000005;
 vec2 original_flare_uv=vec2(source_flare_x*_UflareScale+source_phase*0.0500000007,
                            base*_VflareScale+source_phase*_VflareSpeed);
 float flare=texture(_FlareTex,vec2(original_flare_uv.x,1.0-original_flare_uv.y)).r;
 float k=2.0*(flare*source_vertex_red+base)*base*_FlareIntensity;
 vec3 rgb=(_Color.rgb+k*(_HiColor.rgb*k-_Color.rgb))*_ColorIntensity;
 float a=(1.0+_ColorAlphaWeight*(source_vertex_red-1.0))*k;
 vec4 result=vec4(rgb,a)*_Colorize;
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
