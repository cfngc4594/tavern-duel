// Source build37 globalgamemanagers.assets; exact compiled DXBC equations.
// Explicit destination composition preserves original separate RGB/alpha blend.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _DestinationTexture : filter_linear, repeat_disable;
// Shader40 optional, inactive current preset. SrcAlpha/OneMinusSrcAlpha; alpha Zero/One.
uniform vec4 _Color = vec4(1.0);
uniform float _Amount = 0.0;
void fragment(){vec4 d=texture(_DestinationTexture,UV);COLOR=vec4(_Color.rgb*_Amount+d.rgb*(1.0-_Amount),d.a);}
