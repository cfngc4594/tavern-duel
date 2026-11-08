shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source Custom/Selection/HighlightMultiSampleBlend, decoded DXBC.
// All four offsets use main texture dimensions; blend sampled at center.
uniform sampler2D main_mask : filter_linear, repeat_disable;
uniform sampler2D blend_mask : filter_linear, repeat_disable;
uniform vec2 main_texel_size;
uniform float blur_offset = -1.25;
void fragment() {
 vec2 d = main_texel_size * blur_offset;
 float v = (texture(main_mask, UV+d).r + texture(main_mask, UV-d).r
          + texture(main_mask, UV+vec2(d.x,-d.y)).r
          + texture(main_mask, UV+vec2(-d.x,d.y)).r)*0.25;
 v=max(v,texture(blend_mask,UV).r);
 COLOR=vec4(v,v,v,1.0);
}
