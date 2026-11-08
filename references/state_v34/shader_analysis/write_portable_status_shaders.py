from pathlib import Path
R=Path(__file__).parent
project=R.parents[1]/'TavernDuel'
base=(project/'shaders/native_combat_transparent_color.gdshader').read_text()
common=base[:base.index('// FlashA original main pass:')]
common=common.replace('// Mesh UV and ST are already Y-conjugated by native_combat_assets.gd.','// Mesh UV and ST must already be Y-conjugated by the existing native asset adapter.\n// Original texture state: trilinear, repeat U/V/W, mip bias -0.5, one mip only.\n// Use bilinear without generated mip levels. _GlobalMipBias has no effect at one level.')
common=common.replace('uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);','uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);\nuniform float _GlobalMipBias = 0.0;')
card=common.replace('unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled','unshaded, depth_draw_opaque, cull_disabled, fog_disabled')
card+='''// Custom/Card/UnlitTextureTint, path ID -34040995226017085.
// Source: One Zero RGBA, ZTest LEqual, ZWrite On, Cull Off, no alpha clip.
// Godot opaque spatial output cannot separately write source alpha without changing
// pipeline class. Direct board RGB is preserved; source RT alpha needs a capture pass.
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec4 lighting=vec4(source_sh_gamma()+_MainLightColor,1.0);
 source_vertex_color=mix(COLOR,lighting,_LightingBlend)*_Color;
}
void fragment() {
 vec4 result=texture(_MainTex,source_main_uv,_GlobalMipBias)*source_vertex_color;
 // Output-merger UNorm conversion is separate from the recovered shader arithmetic.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 // Do not write ALPHA: source opaque rendering must keep opaque sorting/depth.
}
'''
hero=common.replace('uniform vec4 _Color = vec4(1.0);\n','')
hero+='''// Hero/Unlit_Transparent, path ID -1939901832466623549.
// Source: SrcAlpha OneMinusSrcAlpha in BOTH RGB and alpha; ZTest LEqual,
// ZWrite Off, Cull Back. Godot blend_mix destination-alpha differs from source
// Aout=As*As+Ad*(1-As); transparent RT alpha equivalence requires dual RT.
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec4 lighting=vec4(mix(vec3(1.0),source_sh_gamma()+_MainLightColor,_LightingBlend),1.0);
 source_vertex_color=COLOR*lighting;
}
void fragment() {
 vec4 result=texture(_MainTex,source_main_uv,_GlobalMipBias)*source_vertex_color;
 // Output-merger UNorm conversion is separate from the recovered shader arithmetic.
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
'''
for name,text in [('native_status_card_unlit_tint.gdshader',card),('native_status_hero_unlit_transparent.gdshader',hero)]:
 (R/name).write_text(text);print(R/name)
