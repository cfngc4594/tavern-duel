shader_type canvas_item;
render_mode blend_premul_alpha;
// All ordinary game draw commands retain their old SrcAlpha/OneMinusSrcAlpha
// result by premultiplying once. The spatial RT is already accumulated RGB;
// its draw command uses alpha=2 as an explicit vertex-stage marker, stripped
// before texturing. This keeps exact existing command order and no extra copy.
varying float source_is_accumulated;
void vertex() {
 source_is_accumulated=COLOR.a>1.5?1.0:0.0;
 if(source_is_accumulated>0.5) COLOR.a=1.0;
}
void fragment() {
 if(source_is_accumulated<0.5) COLOR.rgb*=COLOR.a;
}
