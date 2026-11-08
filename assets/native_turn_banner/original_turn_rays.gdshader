shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;
// Original Hero/AddMultiply/AddMultiplyFXRotation. Re-extracted original OSX platform14 Metal; see rays_evidence/platform14_0.txt.
// Unity original blend One / OneMinusSrcAlpha; preserve nonzero RGB at alpha zero.
uniform sampler2D main_tex : filter_linear, repeat_enable;
uniform sampler2D fx_tex : filter_linear, repeat_enable;
uniform vec4 original_color = vec4(0.4339999855,0.4130842984,0.1690682769,1.0);
uniform float elapsed_seconds = 0.0;
uniform float intensity = 1.0;
uniform float fx_intensity = 1.0;
uniform float rotation_speed = 5.0;
uniform vec2 rotation_pivot = vec2(0.0,-0.2700000107);
uniform vec2 fx_scale = vec2(1.0);
varying vec4 original_vertex_color;
void vertex(){original_vertex_color=COLOR*(2.0*intensity)*original_color.a*fx_intensity;}
void fragment(){
 // Mesh UV is deliberately ORIGINAL Unity UV; flip only at PNG sampling.
 vec2 p=(UV-(vec2(0.5)+rotation_pivot))*fx_scale;
 float angle=elapsed_seconds*0.05*rotation_speed;
 float c=cos(angle),s=sin(angle);
 vec2 uv1=vec2(p.x*c+p.y*s,-p.x*s+p.y*c)+vec2(0.5);
 vec4 m=texture(main_tex,vec2(UV.x,1.0-UV.y));
 vec4 f=texture(fx_tex,vec2(uv1.x,1.0-uv1.y));
 ALBEDO=f.rgb*m.rgb*original_color.rgb*original_vertex_color.rgb;
 ALPHA=f.a*m.a*(original_color.a-m.a)*original_vertex_color.a;

}
