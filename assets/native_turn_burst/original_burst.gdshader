shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Original Hero/Particles pass 0: SrcAlpha One. GlowIntensity=0 disables original pass 1.
uniform sampler2D main_tex : filter_linear, repeat_enable;
uniform vec4 original_color=vec4(1.0);
uniform float elapsed_seconds=0.0;
varying vec4 particle_color;
vec3 source_rgb_backend_inverse(vec3 c) {
 vec3 target=pow((c+vec3(.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0); vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++){vec3 m=(lo+hi)*.5;vec3 y=m*(m*(m*.305306011+.682171111)+.012522878);vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);}
 return mix((lo+hi)*.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}
void vertex(){particle_color=2.0*COLOR*original_color;}
void fragment(){
 vec4 value=texture(main_tex,UV)*particle_color;
 ALBEDO=source_rgb_backend_inverse(value.rgb);
 ALPHA=value.a;
}
