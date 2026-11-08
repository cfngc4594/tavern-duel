shader_type canvas_item;
render_mode blend_premul_alpha;
// The spatial framebuffer stores emitted/accumulated C, not straight RGBA.
// Its independent RGB transmission target stores T. The preceding BackBufferCopy
// must run AFTER the game's pre-spatial CanvasItem and BEFORE this CanvasItem.
// Original 2D commands retain their existing SrcAlpha/OneMinusSrcAlpha result.
uniform sampler2D transmission_texture : filter_linear, repeat_disable;
uniform sampler2D background_texture : hint_screen_texture, filter_nearest, repeat_disable;
varying float source_is_accumulated;
void vertex() {
 source_is_accumulated=COLOR.a>1.5?1.0:0.0;
 if(source_is_accumulated>0.5) COLOR.a=1.0;
}
void fragment() {
 if(source_is_accumulated>0.5) {
  vec3 transmission=texture(transmission_texture,UV).rgb;
  vec3 background=texture(background_texture,SCREEN_UV).rgb;
  COLOR=vec4(COLOR.rgb+transmission*background,1.0);
 } else {
  COLOR.rgb*=COLOR.a;
 }
}
