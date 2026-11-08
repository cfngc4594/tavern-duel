shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
// Build37 globalgamemanagers.assets Shader29 Hidden/TextOutline_Unlit.
// Damage UberText: zhCN9, RichText1, Outline1, RT0, HasBoldTextfalse.
// Source DXBC9tap equation independently rechecked in v32.1; no RTT or billboard.
// text_tint = source vertexColor * material _Color, both white for this prefab.
uniform sampler2D glyph_atlas : filter_linear, repeat_disable;
uniform vec2 atlas_texel;
uniform float outline_texels = 3.0;
uniform int text_mode=1; // 0 original normal alpha, 1 outline, 2 original eight-tap bold
uniform float bold_texels=1.25;
uniform vec4 text_tint : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.0,0.0,0.0,1.0);
float a(vec2 uv){return texture(glyph_atlas,uv).a;}
vec3 mask_backend_inverse(vec3 c) {
 vec3 target=pow((c+vec3(.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0); vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++){vec3 m=(lo+hi)*.5;vec3 y=m*(m*(m*.305306011+.682171111)+.012522878);vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);}
 return mix((lo+hi)*.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}
void fragment(){
 if(text_mode==0){
  ALBEDO=text_tint.rgb;
  ALPHA=a(UV)*text_tint.a;
 }else if(text_mode==2){
  vec2 b=atlas_texel*bold_texels;
  vec2 p=UV+b*0.600000024;vec2 n=UV-b*0.600000024;
  float sum=a(p)+a(n)+a(vec2(p.x,n.y))+a(vec2(n.x,p.y));
  sum+=a(UV+vec2(b.x,0.0))+a(UV-vec2(b.x,0.0));
  sum+=a(UV+vec2(0.0,b.y))+a(UV-vec2(0.0,b.y));
  ALBEDO=text_tint.rgb;
  ALPHA=sum*0.230000004*text_tint.a;
 }else{
 vec2 off=atlas_texel*outline_texels;
 vec2 p=UV+off*0.600000024;
 vec2 n=UV-off*0.600000024;
 float sum=a(p)+a(n)+a(vec2(p.x,n.y))+a(vec2(n.x,p.y));
 sum+=a(UV+vec2(0.0,off.y))+a(UV-vec2(0.0,off.y));
 sum+=a(UV+vec2(off.x,0.0))+a(UV-vec2(off.x,0.0));
 float center=a(UV);sum+=center;
 ALBEDO=center*(text_tint.rgb-outline_color.rgb)+outline_color.rgb;
 ALPHA=clamp(sum,0.0,1.0)*text_tint.a;
}
 // Verified Gamma backend correction; exactly once after source RGB equation.
 ALBEDO=mask_backend_inverse(clamp(ALBEDO,vec3(0.0),vec3(1.0)));
}
