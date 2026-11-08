shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back, fog_disabled;
// resources.assets:151 Custom/AlphaFillOpaque. One/Zero, LEqual, ZWrite On, Cull Back.
// Solid white replacement geometry pass; used only in the separate alpha capture RT.
void fragment() { ALBEDO = vec3(1.0); }
