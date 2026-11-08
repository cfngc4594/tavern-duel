shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
// Original Hidden/TextAntialiasing PathID3442879436887144160 selected Metal equation.
// Final name-curve pass: RGB center; alpha four diagonals *0.5; NO center alpha/clamp.
uniform sampler2D title_rt : filter_linear, repeat_disable;
uniform vec2 aa_offset;
uniform vec4 tint : source_color = vec4(1.0);
vec3 mask_backend_inverse(vec3 c) {
 vec3 target=pow((c+vec3(.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0); vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++){vec3 m=(lo+hi)*.5;vec3 y=m*(m*(m*.305306011+.682171111)+.012522878);vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);}
 return mix((lo+hi)*.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}
void fragment(){
 vec4 center=texture(title_rt,UV);
 float alpha=texture(title_rt,UV+aa_offset).a;
 alpha+=texture(title_rt,UV-aa_offset).a;
 alpha+=texture(title_rt,UV+vec2(aa_offset.x,-aa_offset.y)).a;
 alpha+=texture(title_rt,UV+vec2(-aa_offset.x,aa_offset.y)).a;
 ALBEDO=center.rgb*tint.rgb;
 ALPHA=0.5*alpha*tint.a;
 // Verified Gamma backend correction; exactly once after source RGB equation.
 ALBEDO=mask_backend_inverse(clamp(ALBEDO,vec3(0.0),vec3(1.0)));
}
