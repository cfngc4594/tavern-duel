shader_type canvas_item;
render_mode unshaded,blend_mix;
uniform float source_color_alpha=1.0;
uniform vec2 aa_offset;
uniform float aa_edge=0.5;
uniform vec4 upper_color=vec4(1);
uniform vec4 lower_color=vec4(1);
void fragment(){
 vec4 center=texture(TEXTURE,UV);
 float alpha=texture(TEXTURE,UV+aa_offset).a+texture(TEXTURE,UV-aa_offset).a;
 alpha+=texture(TEXTURE,UV+vec2(aa_offset.x,-aa_offset.y)).a+texture(TEXTURE,UV+vec2(-aa_offset.x,aa_offset.y)).a;
 vec4 tint=mix(upper_color,lower_color,UV.y);
 COLOR=vec4(center.rgb,alpha*aa_edge*source_color_alpha)*tint;
}
