from pathlib import Path
import json,shutil,hashlib
R=Path(__file__).parent;P=R.parents[1]/'v34_work/TavernDuel';O=R/'drafts';O.mkdir(exist_ok=True)
base=(P/'shaders/native_combat_transparent_color.gdshader').read_text()
common=base[base.index('uniform sampler2D'):base.index('// FlashA original main pass:')]
common=common.replace('varying vec4 source_vertex_color;','uniform bool _SourceTargetUNorm=true;\nvarying vec4 source_vertex_color;')
# Retain the preexisting backend bridge rather than pretending it is original source shader logic.
header='shader_type spatial;\nrender_mode unshaded, depth_draw_always, cull_back, fog_disabled;\n'
code=header+common+'''// Source Custom/Card/UnlitDesat, -477307002458744689, DXBC blobs 1/3.
// Original spelling _Transistion is intentional. Source One/Zero RGBA, CullBack,
// ZWrite On, ZTest LEqual. MainLightColor.w participates in the vertex alpha.
uniform float _MainLightAlpha=1.0; // Compatibility default; original live value unknown.
uniform float _ValueRange=1.0;
uniform float _Transistion=0.0;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 source_vertex_color=mix(COLOR,vec4(source_sh_gamma(),1.0)+vec4(_MainLightColor,_MainLightAlpha),_LightingBlend);
}
void fragment() {
 vec4 t=texture(_MainTex,source_main_uv);
 float gray=0.300000012*_ValueRange*(t.r+t.g+t.b);
 vec4 result=mix(t,_Color*gray,_Transistion)*source_vertex_color;
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 // Keep opaque depth/sorting: no ALPHA write. Use separate alpha capture if needed.
}
'''
(O/'native_combat_death_unlit_desat.gdshader').write_text(code)
code=(P/'shaders/native_combat_diffuse_color.gdshader').read_text().replace('-5812771937585292081 Hero/Diffuse/DiffuseColor','4578800529589026196 Custom/Card/SelfIlluminDiffuse').replace('uniform float _LightingBlend = 0.0;','uniform float _Illum=1.0;').replace('source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;','source_main_uv=UV; // Source no-scale-offset texture: no ST arithmetic in blob3.').replace('vec4 result=vec4(t.rgb*light,t.a);','vec4 result=vec4(t.rgb*(light+vec3(_Illum)),t.a);')
(O/'native_combat_death_self_illumin_diffuse.gdshader').write_text(code)
code='shader_type spatial;\nrender_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;\n'+common+'''// Source Legacy Shaders/Particles/Alpha Blended Premultiply, blobs2/6.
// SOFTPARTICLES_OFF. Source ColorMask RGB: alpha target must remain untouched.
// Direct Godot blend cannot preserve destination alpha; CT + alpha-only capture
// below is required for exact source alpha transport. RGB blend is One/InvSrcAlpha.
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 source_vertex_color=COLOR;
}
void fragment() {
 vec4 result=texture(_MainTex,source_main_uv)*source_vertex_color*source_vertex_color.a;
 if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }
 ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));
 ALPHA=result.a;
}
'''
(O/'native_combat_death_legacy_premultiply.gdshader').write_text(code)
# Source alpha capture stores source framebuffer A in the R/G/B channels.
for suffix in ['death_unlit_desat','death_self_illumin_diffuse','death_legacy_premultiply']:
 base=(O/f'native_combat_{suffix}.gdshader').read_text();pos=base.index(' ALBEDO',base.index('void fragment()'));prefix=base[:pos]
 if suffix=='death_legacy_premultiply':
  # No source alpha update at all: with premul blend, zero RGB and zero A is identity.
  alpha=prefix+' ALBEDO=vec3(0.0);\n ALPHA=0.0;\n}\n'
 else:alpha=prefix+' ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));\n}\n'
 (O/f'native_combat_capture_alpha_{suffix}.gdshader').write_text(alpha)
 for kind,text in [('color',base),('alpha',alpha)]:
  text=text.replace('if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }','result=clamp(result,vec4(0.0),vec4(1.0));')
  (O/f'native_combat_capture_{kind}_unorm_{suffix}.gdshader').write_text(text)
 # Explicit transmission-only capture: maps D -> D*(1-Sa) for RGB-only premultiply.
 if suffix=='death_legacy_premultiply':
  trans=prefix+' ALBEDO=vec3(0.0);\n ALPHA=result.a;\n}\n'
  (O/f'native_combat_capture_transmission_{suffix}.gdshader').write_text(trans)
rows=[]
for folder,suffix in [('Custom_Card_UnlitDesat','death_unlit_desat'),('Custom_Card_SelfIlluminDiffuse','death_self_illumin_diffuse'),('Legacy Shaders_Particles_Alpha Blended Premultiply','death_legacy_premultiply'),('Hero_Particle_Particles_Transparent','transparent'),('Hero_Additive_Additive','additive'),('Hero_Unlit_Unlit_TransparentColor','transparent_color')]:
 md=json.load(open(R/folder/'metadata.json'));st=md['subshaders'][0]['m_Passes'][0]['m_State'];blend={k:int(v['val']) for k,v in st['rtBlend0'].items()}
 if suffix=='transparent':blend.update(srcBlend=5,destBlend=10,srcBlendAlpha=5,destBlendAlpha=10)
 rows.append({'suffix':suffix,'source_name':md['name'],'source_key':md['key'],'source_blend':blend,'source_blend_material_override':suffix=='transparent','source_cull':int(st['culling']['val']),'source_zwrite':int(st['zWrite']['val']),'source_ztest':int(st['zTest']['val']),'source_colmask':int(st['rtBlend0']['colMask']['val']),'source_light_mode':'UniversalForward' if suffix=='death_unlit_desat' else '', 'godot_shader':'res://shaders/native_combat_'+suffix+'.gdshader','new_shader':suffix.startswith('death_')})
(R/'shader_routes.json').write_text(json.dumps(rows,indent=2)+'\n')
binding=(P/'scripts/native_endgame_materials.gd').read_text().replace('res://references/endgame_v33/shader_routes.json','res://references/death_v35/shader_routes.json')
binding=binding.replace('if str(route.suffix)=="endgame_diffuse_transparent":','if str(route.suffix)=="death_self_illumin_diffuse":')
binding=binding.replace(' return mat\n',' if int(route.get("source_colmask",15))==14:mat.set_meta("source_alpha_write",false)\n return mat\n')
(O/'native_death_materials.gd').write_text(binding)
print('Wrote',len(list(O.iterdir())),'draft files and',len(rows),'source routes')
