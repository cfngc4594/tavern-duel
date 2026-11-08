shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
// Exact build37.0.0.255130.254477 DXBC45632884066622321 vertex/fragment.
// UV/ST conjugation, GL color bridge and RTT coverage are Godot compatibility.
uniform sampler2D _Diffuse : source_color, filter_linear, repeat_enable;
uniform sampler2D _Mask : source_color, filter_linear, repeat_enable;
uniform vec4 _Diffuse_ST=vec4(1.0,1.0,0.0,0.0);
uniform vec4 _Mask_ST=vec4(1.0,1.0,0.0,0.0);
uniform vec4 _Color=vec4(0.301960796,1.0,0.215686306,0.298039198);
uniform float _ErodeTile=1.0;
uniform float _Amount=1.0;
uniform float _power=5.0;
uniform float _Strength=0.0;
uniform float _Brightness=3.544972897;
uniform float _YSpeed=0.10000000149;
uniform float _XSpeed=2.0;
uniform float _XSpeedDiffuse=0.0;
uniform float _YSpeedDiffuse=-0.5;
uniform float _OffsetX=0.0;
uniform float _UnityTimeX=-1.0;
uniform bool _SourceTargetUNorm=true;
varying vec2 source_diffuse_uv;
varying vec2 source_mask_uv;
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
 vec2 d=UV*_Diffuse_ST.xy+_Diffuse_ST.zw;
 vec2 m=UV2*_Mask_ST.xy+_Mask_ST.zw;
 source_diffuse_uv=vec2(d.x,1.0-d.y);
 source_mask_uv=vec2(m.x,1.0-m.y);
}
void fragment(){
 float tx=_UnityTimeX>=0.0?_UnityTimeX:TIME/20.0;
 float ty=tx*20.0;
 vec2 m=vec2(2.0*source_mask_uv.x+_OffsetX*_XSpeed,2.0*source_mask_uv.y+ty*_YSpeed)*_ErodeTile;
 float mask_value=texture(_Mask,vec2(m.x,1.0-m.y)).r;
 float eroded=min(pow(mask_value,_Amount),_Amount);
 vec2 d=source_diffuse_uv+vec2(tx*_XSpeedDiffuse,ty*_YSpeedDiffuse)*0.5;
 float combined=eroded*texture(_Diffuse,vec2(d.x,1.0-d.y)).r;
 vec3 rgb=_Color.rgb*_Brightness*(combined+1.0);
 float alpha=(combined*_power-_Strength)*_Color.a;
 if(_SourceTargetUNorm)rgb=clamp(rgb,vec3(0.0),vec3(1.0));
 ALBEDO=source_backend_inverse(rgb);
 ALPHA=clamp(alpha,0.0,1.0);
}
