// Source build37 globalgamemanagers.assets; exact compiled DXBC equations.
// Explicit destination composition preserves original separate RGB/alpha blend.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _DestinationTexture : filter_linear, repeat_disable;
// Shader42: DstColor/OneMinusSrcAlpha, alpha Zero/One. No procedural mask.
uniform sampler2D _MaskTex : filter_linear, repeat_enable;
uniform float _Amount = 0.0;
void fragment(){vec4 d=texture(_DestinationTexture,UV);float mask=texture(_MaskTex,UV).r;COLOR=vec4(d.rgb*(mask*_Amount+1.0-_Amount),d.a);}
