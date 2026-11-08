shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source constant replacement passes: CullOff/ZTestAlways/ZWriteOff.
// CPU maps source ortho clip coordinates to canvas pixel coordinates and clips Z.
// RGBA8 red storage substitutes source R8; keep numeric data, never source_color.
uniform float constant_value = 0.25;
void fragment() { COLOR=vec4(vec3(constant_value),1.0); }
