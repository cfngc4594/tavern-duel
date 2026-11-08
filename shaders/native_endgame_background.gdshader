shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Host-only affine composition. The filtered board is produced by the recovered
// FullScreenFX pass graph, and original result C/T is never blurred/desaturated.
uniform sampler2D _FilteredBackground : filter_linear, repeat_disable;
uniform sampler2D _ResultColor : filter_linear, repeat_disable;
uniform sampler2D _ResultTransmission : filter_linear, repeat_disable;
uniform bool _HasResult=false;
void fragment(){
 vec3 background=texture(_FilteredBackground,UV).rgb;
 if(_HasResult){background=texture(_ResultColor,UV).rgb+texture(_ResultTransmission,UV).rgb*background;}
 COLOR=vec4(background,1.0);
}
