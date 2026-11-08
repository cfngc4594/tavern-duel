// Source build37 globalgamemanagers.assets; exact compiled DXBC equations.
// Explicit destination composition preserves original separate RGB/alpha blend.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _DestinationTexture : filter_linear, repeat_disable;
// Shader36 SrcAlpha/OneMinusSrcAlpha; original output alpha is Amount, destination alpha retained.
uniform float _Amount = 0.0;
void fragment(){vec4 s=texture(_BlitTexture,UV);vec4 d=texture(_DestinationTexture,UV);COLOR=vec4(s.rgb*_Amount+d.rgb*(1.0-_Amount),d.a);}
