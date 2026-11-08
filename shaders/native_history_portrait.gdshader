shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back, fog_disabled;
// Original history portrait source, see qa/history-source/portrait-shader.
// Original One/Zero, ZWriteOn, LEqual, CullBack; texture alpha is NOT coverage.
// Original vertex output COLOR*_Color, fragment output texture*vertex output.
uniform sampler2D _MainTex : source_color, filter_linear, repeat_enable;
uniform vec4 _MainTex_ST=vec4(1.0,1.0,0.0,0.0);
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

// Original Custom/HistoryTilePortrait -1208607894637808160, DXBC 1/3.
// Source UV=(UV+Offset)*Scale*ST.xy+ST.zw, vertex COLOR*_Color.
// Serialized legacy _Transistion/_ValueRange are NOT used by this shader.
uniform float _Scale=1.0;
uniform float _OffsetX=0.0;
uniform float _OffsetY=0.0;
uniform vec4 _Color=vec4(1.0);
varying vec2 history_uv;
void vertex() {
 vec2 flipped=vec2((UV.x+_OffsetX)*_Scale,1.0-(1.0-UV.y+_OffsetY)*_Scale);
 history_uv=flipped*_MainTex_ST.xy+_MainTex_ST.zw;
 source_lit_color=COLOR*_Color;
}
void fragment() {
 vec4 result=texture(_MainTex,history_uv)*source_lit_color;
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
}
