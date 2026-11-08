shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source Custom/Selection/HighlightMaskBlend, decoded DXBC.
// Both textures use offsets derived from main texture, not blend dimensions.
// This is 0.3 * DIFFERENCE OF SUMS, not difference of means.
uniform sampler2D main_mask : filter_linear, repeat_disable;
uniform sampler2D blend_mask : filter_linear, repeat_disable;
uniform vec2 main_texel_size;
uniform float blur_offset = -0.8;
void fragment() {
 vec2 d = main_texel_size * blur_offset;
 vec2 a=UV+d;vec2 b=UV-d;vec2 c=UV+vec2(d.x,-d.y);vec2 e=UV+vec2(-d.x,d.y);
 float main_sum=texture(main_mask,a).r+texture(main_mask,b).r+texture(main_mask,c).r+texture(main_mask,e).r;
 float blend_sum=texture(blend_mask,a).r+texture(blend_mask,b).r+texture(blend_mask,c).r+texture(blend_mask,e).r;
 // Source mul(blend,.3), then mad(main,.3,-scaledBlend). Backend FMA
 // contraction/precision is independently checked at the GPU capture boundary.
 float v=clamp(main_sum*0.30000001192092896 - blend_sum*0.30000001192092896,0.0,1.0);
 COLOR=vec4(v,v,v,1.0);
}
