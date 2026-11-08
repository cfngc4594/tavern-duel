shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D rgb_rt:filter_nearest,repeat_disable;
uniform sampler2D mask_rt:filter_nearest,repeat_disable;
void fragment(){COLOR=vec4(texture(rgb_rt,UV).rgb,texture(mask_rt,UV).r);}
