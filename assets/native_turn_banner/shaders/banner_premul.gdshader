shader_type canvas_item;
render_mode unshaded,blend_premul_alpha;
uniform float opacity=1.0;
void fragment(){COLOR=texture(TEXTURE,UV)*opacity;}
