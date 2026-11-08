shader_type canvas_item;
render_mode unshaded,blend_disabled;
// SOURCE_TEXT_SHADOW: original Hidden/TextShadow, OSX globalgamemanagers.assets PathID44.
// Original DstColor / OneMinusSrcAlpha replay against explicit pre-shadow RGB/alpha stage.
uniform sampler2D destination_texture:filter_nearest,repeat_disable;
uniform vec2 shadow_offset;
uniform vec4 shadow_color=vec4(.1,.1,.1,.627451);
void fragment(){
 float s=texture(TEXTURE,UV+shadow_offset).a+texture(TEXTURE,UV-shadow_offset).a;
 s+=texture(TEXTURE,UV+vec2(shadow_offset.x,-shadow_offset.y)).a+texture(TEXTURE,UV+vec2(-shadow_offset.x,shadow_offset.y)).a;
 s+=texture(TEXTURE,UV+vec2(shadow_offset.x,0)).a+texture(TEXTURE,UV-vec2(shadow_offset.x,0)).a;
 s+=texture(TEXTURE,UV+vec2(0,shadow_offset.y)).a+texture(TEXTURE,UV-vec2(0,shadow_offset.y)).a;
 s*=.125;
 vec3 source_rgb=s*shadow_color.rgb*shadow_color.a;
 float source_alpha=s*s*shadow_color.a;
 vec4 dst=texture(destination_texture,SCREEN_UV);
 COLOR=vec4(dst.rgb*(source_rgb+vec3(1.0-source_alpha)),dst.a);
}
