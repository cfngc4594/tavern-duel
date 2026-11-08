shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;
// Original Windows build37.0.0.255130.254477 globalgamemanagers.assets:26
// Hidden/ScreenEffectsMask pass5 GlowPrepass: original output RGBA=(0,0,0,0).
// One/Zero, ZWrite On, LEqual, Cull Back. ScreenEffectsPass overrideMaterialPassIndex=5.
// Godot opaque target alpha is coverage1, so RGB/depth are exact formula intent;
// original zero alpha must be supplied by the separate scalar-alpha target.
void fragment() { ALBEDO=vec3(0.0); }
