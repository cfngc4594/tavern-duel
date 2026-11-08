// Source build37 globalgamemanagers.assets; exact compiled DXBC equations.
// Explicit destination composition preserves original separate RGB/alpha blend.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _DestinationTexture : filter_linear, repeat_disable;
// Shader33 VS: diagonal offsets are (BlurOffset + .5) * source texel size.
// PS: four RGBA samples summed, times Brightness * .25. One/Zero.
uniform float _BlurOffset = 1.0;
uniform float _Brightness = 1.0;
uniform vec4 _BlitTexture_TexelSize = vec4(0.0);
void fragment(){
 vec2 px=_BlitTexture_TexelSize.xy;
 if(px.x<=0.0||px.y<=0.0){px=vec2(1.0)/vec2(textureSize(_BlitTexture,0));}
 vec2 o=px*(_BlurOffset+0.5);
 COLOR=(texture(_BlitTexture,UV+o)+texture(_BlitTexture,UV-o)+texture(_BlitTexture,UV+o*vec2(1.0,-1.0))+texture(_BlitTexture,UV+o*vec2(-1.0,1.0)))*(_Brightness*0.25);
}
