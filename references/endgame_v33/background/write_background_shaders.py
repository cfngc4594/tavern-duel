from pathlib import Path
p=Path('v33_work/TavernDuel/shaders')
header='''// Source build37 globalgamemanagers.assets; exact compiled DXBC equations.
// Explicit destination composition preserves original separate RGB/alpha blend.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D _BlitTexture : filter_linear, repeat_disable;
uniform sampler2D _DestinationTexture : filter_linear, repeat_disable;
'''
body={
'desaturation':'''// Shader49: pass0 One/Zero; pass1 OneMinusSrcAlpha/SrcAlpha, alpha Zero/One.
uniform int _Pass = 0;
uniform float _Desaturation = 1.0;
void fragment(){
 vec4 s=texture(_BlitTexture,UV);
 if(_Pass==0){COLOR=vec4(dot(s.rgb,vec3(0.212599993,0.715200007,0.0722000003)),0.0,0.0,0.0);}
 else{vec4 d=texture(_DestinationTexture,UV);COLOR=vec4(vec3(s.r)*(1.0-_Desaturation)+d.rgb*_Desaturation,d.a);}
}
''',
'vignette':'''// Shader42: DstColor/OneMinusSrcAlpha, alpha Zero/One. No procedural mask.
uniform sampler2D _MaskTex : filter_linear, repeat_enable;
uniform float _Amount = 0.0;
void fragment(){vec4 d=texture(_DestinationTexture,UV);float mask=texture(_MaskTex,UV).r;COLOR=vec4(d.rgb*(mask*_Amount+1.0-_Amount),d.a);}
''',
'blur':'''// Shader33 VS: diagonal offsets are (BlurOffset + .5) * source texel size.
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
''',
'blend':'''// Shader36 SrcAlpha/OneMinusSrcAlpha; original output alpha is Amount, destination alpha retained.
uniform float _Amount = 0.0;
void fragment(){vec4 s=texture(_BlitTexture,UV);vec4 d=texture(_DestinationTexture,UV);COLOR=vec4(s.rgb*_Amount+d.rgb*(1.0-_Amount),d.a);}
''',
'blend_to_color':'''// Shader40 optional, inactive current preset. SrcAlpha/OneMinusSrcAlpha; alpha Zero/One.
uniform vec4 _Color = vec4(1.0);
uniform float _Amount = 0.0;
void fragment(){vec4 d=texture(_DestinationTexture,UV);COLOR=vec4(_Color.rgb*_Amount+d.rgb*(1.0-_Amount),d.a);}
'''
}
for n,s in body.items():(p/('native_endgame_bg_'+n+'.gdshader')).write_text(header+s)
print('wrote',list(body))
