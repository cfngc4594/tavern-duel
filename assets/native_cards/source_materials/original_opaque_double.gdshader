// Compatibility transcription of verified same-build original Metal, not official runtime.
// Opaque RGB and numerical-alpha-mask passes: never assign ALPHA (would change Godot pipeline).
// Original One/Zero overwrites RGBA. RGB pass alpha is intentionally discarded at final dualRT merge.
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, fog_disabled;
uniform int original_shader_kind = 0; // 0 banner/race,1 frame,2 portrait,3 second_texture,4 gem,5 back
uniform bool alpha_mask_pass = false;
uniform sampler2D main_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D main_tex_repeat : source_color, filter_linear, repeat_enable;
uniform bool main_repeat = false;
uniform sampler2D second_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D second_tex_repeat : source_color, filter_linear, repeat_enable;
uniform bool second_repeat = false;
uniform sampler2D scrolling_tex : filter_linear, repeat_enable;
uniform sampler2D scrolling_tex_clamp : filter_linear, repeat_disable; // Original gem uses MAIN sampler state
uniform vec4 main_st = vec4(1.0,1.0,0.0,0.0);
uniform vec4 second_st = vec4(1.0,1.0,0.0,0.0);
uniform vec4 original_color = vec4(1.0);
uniform vec4 second_tint = vec4(1.0);
uniform float blend_intensity = 0.0;
uniform float lighting_blend = 0.0;
uniform float enable_dual_class = 0.0;
uniform float middle_value = 0.5;
uniform vec4 tint_color = vec4(1.0);
uniform vec3 scroll_tint = vec3(1.0);
uniform vec3 fade_rgb = vec3(1.0);
uniform float intensity = 0.0;
uniform vec2 scroll_scale = vec2(1.0);
uniform vec2 scroll_speed = vec2(0.0);
uniform float unity_time_x = 0.0; // Unity _Time.x = elapsed/20, not Godot TIME
// Explicit original-light inputs, NOT recovered scene values. Only used when lighting_blend != 0.
uniform vec3 unity_sh_w = vec3(0.0);
uniform vec3 main_light_color = vec3(1.0);
// Back lighting cannot claim parity until Unity SH coefficients and actual main light are bound.
uniform vec3 back_ambient = vec3(1.0);
uniform vec3 back_light_direction = vec3(0.0,0.0,1.0);
uniform vec3 back_light_color = vec3(0.0);
uniform float back_light_data_z = 1.0;
varying vec4 original_vertex_color;
varying vec2 uv_main;
varying vec2 uv_second;
varying vec2 uv_scroll;
varying vec3 world_normal;
vec3 mask_backend_inverse(vec3 c) {
 vec3 target=pow((c+vec3(.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0); vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++){vec3 m=(lo+hi)*.5;vec3 y=m*(m*(m*.305306011+.682171111)+.012522878);vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);}
 return mix((lo+hi)*.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}
void vertex(){
 uv_main=UV*main_st.xy+main_st.zw;
 uv_second=UV2*second_st.xy+second_st.zw;
 uv_scroll=UV*scroll_scale+unity_time_x*scroll_speed;
 vec3 lit=clamp(1.05499995*pow(abs(unity_sh_w),vec3(.416666657))-.0549999997,vec3(0.0),vec3(1.0))+main_light_color;
 original_vertex_color=mix(COLOR,vec4(lit,1.0),lighting_blend);
 if(original_shader_kind==2 || original_shader_kind==3) original_vertex_color*=original_color;
 if(original_shader_kind==4) original_vertex_color=mix(vec4(1.0),vec4(lit,1.0),lighting_blend)*tint_color;
 world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
 vec4 t=(main_repeat ? texture(main_tex_repeat,uv_main) : texture(main_tex,uv_main));
 vec4 result=t*original_vertex_color;
 if(original_shader_kind==1){
  vec4 other=(second_repeat ? texture(second_tex_repeat,uv_main) : texture(second_tex,uv_main));
  result=(uv_main.x<=middle_value?t:mix(t,other,enable_dual_class))*original_vertex_color;
 } else if(original_shader_kind==2 || original_shader_kind==3){
  vec4 s=(second_repeat ? texture(second_tex_repeat,uv_second) : texture(second_tex,uv_second))*second_tint*blend_intensity;
  vec4 q=mix(t,t*s,s.a);
  if(original_shader_kind==2) q.a=1.0;
  result=min(q,(q+vec4(.150000006))*original_vertex_color);
 } else if(original_shader_kind==4){
  float scroll=(main_repeat ? texture(scrolling_tex,uv_scroll).r : texture(scrolling_tex_clamp,uv_scroll).r);
  vec3 rgb=(t.rgb+scroll*scroll_tint*t.a*1.5*intensity)*fade_rgb;
  result=vec4(rgb,1.0)*original_vertex_color;
 } else if(original_shader_kind==5){
  float ndl=clamp(dot(normalize(world_normal),back_light_direction),0.0,1.0);
  vec3 light=back_ambient+back_light_color*back_light_data_z*ndl;
  result=vec4(light*t.rgb*original_color.rgb,t.a*original_color.a);
 }
 // Clamp only to emulate final UNORM render-target storage. No original shader clip/discard.
 ALBEDO=alpha_mask_pass ? mask_backend_inverse(vec3(clamp(result.a,0.0,1.0))) : mask_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
}
