// Source build37 globalgamemanagers.assets; exact compiled DXBC equations.
// Explicit destination composition preserves original separate RGB/alpha blend.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _DestinationTexture : filter_linear, repeat_disable;
// Shader49: pass0 One/Zero; pass1 OneMinusSrcAlpha/SrcAlpha, alpha Zero/One.
uniform int _Pass = 0;
uniform float _Desaturation = 1.0;
void fragment(){
 vec4 s=texture(_BlitTexture,UV);
 if(_Pass==0){COLOR=vec4(dot(s.rgb,vec3(0.212599993,0.715200007,0.0722000003)),0.0,0.0,0.0);}
 else{vec4 d=texture(_DestinationTexture,UV);COLOR=vec4(vec3(s.r)*(1.0-_Desaturation)+d.rgb*_Desaturation,d.a);}
}
