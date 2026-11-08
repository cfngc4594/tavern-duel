shader_type canvas_item;
render_mode unshaded, blend_mix;
// Exact selected rich-text outline SAMPLE ALGEBRA, not a complete Label renderer port.
// Source: original Metal shader -439991501706543190; see outline_metal_excerpt.txt.
// Executed on Godot alpha glyph atlas (NOT original Unity atlas). Godot glyph quad padding
// differs/unverified; source sample algebra does not establish pixel parity.
uniform vec4 source_main_st = vec4(1.0,1.0,0.0,0.0);
uniform float outline_texels = 3.0;
uniform vec4 text_tint : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float source_mip_bias = 0.0;
varying vec4 raw_vertex_color;
void vertex() { raw_vertex_color = COLOR; }
vec2 atlas(vec2 uv) { return uv*source_main_st.xy+source_main_st.zw; }
void fragment() {
    vec2 outline_uv=TEXTURE_PIXEL_SIZE*outline_texels;
    vec2 p=UV+outline_uv*0.600000024;
    vec2 n=UV-outline_uv*0.600000024;
    float sum=texture(TEXTURE,atlas(p),source_mip_bias).a+texture(TEXTURE,atlas(n),source_mip_bias).a;
    sum+=texture(TEXTURE,atlas(vec2(p.x,n.y)),source_mip_bias).a+texture(TEXTURE,atlas(vec2(n.x,p.y)),source_mip_bias).a;
    sum+=texture(TEXTURE,atlas(UV+vec2(0.0,outline_uv.y)),source_mip_bias).a;
    sum+=texture(TEXTURE,atlas(UV-vec2(0.0,outline_uv.y)),source_mip_bias).a;
    sum+=texture(TEXTURE,atlas(UV+vec2(outline_uv.x,0.0)),source_mip_bias).a;
    // Original has asymmetric ST ordering: final -X subtraction is AFTER atlas ST.
    sum+=texture(TEXTURE,atlas(UV)-vec2(outline_uv.x,0.0),source_mip_bias).a;
    float center=texture(TEXTURE,atlas(UV),source_mip_bias).a;sum+=center;
    vec4 t=raw_vertex_color*text_tint;
    float source_alpha=clamp(sum,0.0,1.0)*t.a;
    COLOR=vec4(source_alpha);
}
