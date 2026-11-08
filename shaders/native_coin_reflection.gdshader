shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;
// Original Custom/Card/UnlitTextureReflection, pathID2114911788129993780.
// Exact D3D11 blob1/blob3 arithmetic; Godot world/UV/color bridge is explicit.
// Opaque source pass: Src1 Dst0 ZWrite1 CullBack. No invented alpha/glow.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform sampler2D _SpecTex : source_color, filter_linear, repeat_enable;
uniform sampler2D _ReflTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST=vec4(1.0,1.0,0.0,0.0);
uniform float _ReflectionIntensity=1.2000000476837158;
uniform float _ReflectionRotation=0.4000000059604645;
uniform float _LightingBlend=0.0;
uniform float _UnityTimeX=0.0; // Unity _Time.x = elapsed/20, not _ShaderTime.
uniform float _GlobalMipBias=0.0; // Original scene value not recovered.
uniform mat4 _GodotToSourceWorld=mat4(1.0);
uniform vec3 _UnitySHW=vec3(1.0);
uniform vec3 _MainLightColor=vec3(0.0);
varying vec2 main_uv;
varying vec2 reflection_uv;
varying vec4 source_tint;
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
 vec4 source_position=_GodotToSourceWorld*MODEL_MATRIX*vec4(VERTEX,1.0);
 vec3 source_normal=mat3(_GodotToSourceWorld)*mat3(MODEL_MATRIX)*NORMAL;
 vec2 original_uv=vec2(UV.x,1.0-UV.y)*_MainTex_ST.xy+_MainTex_ST.zw;
 main_uv=vec2(original_uv.x,1.0-original_uv.y);
 vec2 refl=(source_position.xz-original_uv.x*source_normal.xz*0.300000012)*0.0700000003;
 refl=2.0*(refl+vec2(2.0*_UnityTimeX*_ReflectionRotation));
 reflection_uv=vec2(refl.x,1.0-refl.y);
 vec3 sh=clamp(pow(abs(_UnitySHW),vec3(0.416666657))*1.05499995-vec3(0.0549999997),vec3(0.0),vec3(1.0));
 source_tint=vec4(vec3(1.0)+_LightingBlend*(sh+_MainLightColor-vec3(1.0)),1.0);
}
void fragment(){
 vec4 spec=texture(_SpecTex,main_uv,_GlobalMipBias);
 vec4 reflection=texture(_ReflTex,reflection_uv,_GlobalMipBias);
 vec4 base=texture(_MainTex,main_uv,_GlobalMipBias);
 vec4 result=clamp(spec*reflection*_ReflectionIntensity*0.5+base,vec4(0.0),vec4(1.0))*source_tint;
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
}
