from pathlib import Path
import json,re
R=Path(__file__).parent;O=R.parent/'TavernDuel/shaders'
base=(O/'native_combat_cutout.gdshader').read_text();common=base[base.index('uniform sampler2D'):base.index('uniform float _offsetU')]
rows=[]
def emit(suffix,folder,body,mode='mix',depth=False,cull=False):
 d=json.loads((R/folder/'metadata.json').read_text());p=d['subshaders'][0]['m_Passes'][0];state=p['m_State'];blend={k:int(v['val']) for k,v in state['rtBlend0'].items()}
 h=f'shader_type spatial;\nrender_mode unshaded, blend_{mode}, depth_draw_{"always" if depth else "never"}, cull_{"back" if cull else "disabled"}, fog_disabled;\n'
 code=h+'uniform bool _SourceTargetUNorm=true;\n'+'// Original '+d['name']+' '+d['key']+'. See v33 source DXBC and uniform register maps.\n'+common+body
 (O/f'native_combat_endgame_{suffix}.gdshader').write_text(code)
 rows.append({'suffix':'endgame_'+suffix,'source_name':d['name'],'source_key':d['key'],'source_blend':blend,'source_light_mode':'','source_cull':int(state['culling']['val']),'source_zwrite':int(state['zWrite']['val']),'godot_shader':f'res://shaders/native_combat_endgame_{suffix}.gdshader'})
def finish(mode='mix'):
 s='\n if (_SourceTargetUNorm) { result=clamp(result,vec4(0.0),vec4(1.0)); }\n'
 if mode=='add':s+=' ALBEDO=source_backend_inverse(clamp(result.rgb*result.a,vec3(0.0),vec3(1.0)));\n ALPHA=0.0;\n}'
 elif mode=='mul':s+=' ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));\n ALPHA=1.0;\n}'
 elif mode=='opaque':s+=' ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));\n}'
 else:s+=' ALBEDO=source_backend_inverse(clamp(result.rgb,vec3(0.0),vec3(1.0)));\n ALPHA=result.a;\n}'
 return s+'\n'
emit('additive_power','Hero_Additive_AdditivePower','''uniform sampler2D _Diffuse : source_color, filter_linear, repeat_enable;
uniform vec4 _Diffuse_ST=vec4(1.0,1.0,0.0,0.0);
uniform float _Intensity=1.0;
uniform float _power=1.0;
uniform float _Strength=0.0;
void vertex() {
 source_main_uv=UV*_Diffuse_ST.xy+_Diffuse_ST.zw;
 source_vertex_color=2.0*vec4(mix(vec3(1.0),source_sh_gamma(),_LightingBlend)*_Color.rgb,_Color.a);
}
void fragment() {
 vec4 result=(texture(_Diffuse,source_main_uv)*(_Intensity*_power)-vec4(_Strength))*source_vertex_color;
'''+finish('add'),mode='premul_alpha')
emit('multiply_alpha_fade','Hero_Multiply_Multiply_AlphaFade','''void vertex() { source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw; }
void fragment() {
 vec4 result=vec4(1.0)+_Color.a*(texture(_MainTex,source_main_uv)-vec4(1.0));
'''+finish('mul'),mode='mul',cull=True)
emit('scrolling_manual','Hero_AddMultiply_AddMultiplyFXScrollingManual','''uniform sampler2D _FxTex : source_color, filter_linear, repeat_enable;
uniform float _Intensity=1.0;
uniform float _FxIntensity=1.0;
uniform float _ScrollX=0.0;
uniform float _ScrollY=0.0;
uniform float _ScaleX=1.0;
uniform float _ScaleY=1.0;
varying vec2 source_fx_uv;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 vec2 u=vec2(source_main_uv.x,1.0-source_main_uv.y)*vec2(_ScaleX,_ScaleY)+vec2(_ScrollX,_ScrollY);
 source_fx_uv=vec2(u.x,1.0-u.y);
 source_vertex_color=vec4(mix(vec3(1.0),source_sh_gamma()+_MainLightColor,_LightingBlend),1.0)*(2.0*COLOR*_Intensity*_FxIntensity);
}
void fragment() {
 vec4 t=texture(_MainTex,source_main_uv);
 vec4 result=texture(_FxTex,source_fx_uv)*vec4(t.rgb*_Color.rgb,t.a*(_Color.a-t.a))*source_vertex_color;
'''+finish(),mode='premul_alpha')
# DiffuseTransparent's original fragment multiplies RGB by t.a BEFORE SrcAlpha blending.
d=(O/'native_combat_diffuse_color.gdshader').read_text();d=d.replace('depth_draw_always','depth_draw_never').replace('vec4 result=vec4(t.rgb*light,t.a);','vec4 result=vec4(t.rgb*light*t.a,t.a);').replace('\n}', '\n}',1)
d=d.rsplit('\n}',1)[0]+'\n ALPHA=result.a;\n}\n';d=d.replace('Hero/Diffuse/DiffuseColor','Hero/Diffuse/Diffuse_Transparent').replace('-5812771937585292081','5202922422864527443')
(O/'native_combat_endgame_diffuse_transparent.gdshader').write_text(d)
p=json.load(open(R/'Hero_Diffuse_Diffuse_Transparent/metadata.json'));st=p['subshaders'][0]['m_Passes'][0]['m_State'];rows.append({'suffix':'endgame_diffuse_transparent','source_name':p['name'],'source_key':p['key'],'source_blend':{k:int(v['val']) for k,v in st['rtBlend0'].items()},'source_light_mode':'','source_cull':2,'source_zwrite':0,'godot_shader':'res://shaders/native_combat_endgame_diffuse_transparent.gdshader'})
# XPBar is retained as source coverage only: runtime has no server XP and does not instantiate it.
emit('xp_bar','Custom_FX_FX_XPBar','''uniform sampler2D _NoiseTex : source_color, filter_linear, repeat_enable;
uniform float _NoiseScale1=1.0;
uniform float _NoiseScale2=1.0;
uniform float _Uadd=0.0;
uniform float _Intensity=1.0;
uniform float _Percent=0.0;
uniform float _UnityTimeX=0.0;
varying vec2 source_secondary_uv;
varying vec2 source_noise1_uv;
varying vec2 source_noise2_uv;
void vertex() {
 source_main_uv=UV*_MainTex_ST.xy+_MainTex_ST.zw;
 source_secondary_uv=UV2*_MainTex_ST.xy+_MainTex_ST.zw;
 vec2 st_offset=vec2(_MainTex_ST.z,1.0-_MainTex_ST.y-_MainTex_ST.w);
 vec2 u=vec2(UV2.x,1.0-UV2.y);
 vec2 n1=vec2(u.x*_NoiseScale1-_UnityTimeX*1.70000005-_Uadd,u.y*0.100000001-_UnityTimeX*0.150000006)*_MainTex_ST.xy+st_offset;
 vec2 n2=vec2(u.x*_NoiseScale2-_UnityTimeX*3.5-_Uadd,u.y*0.300000012-_UnityTimeX*0.449999988)*_MainTex_ST.xy+st_offset;
 source_noise1_uv=vec2(n1.x,1.0-n1.y);source_noise2_uv=vec2(n2.x,1.0-n2.y);
}
void fragment() {
 vec2 u=vec2(clamp(source_secondary_uv.x+0.5-_Percent,0.100000001,0.899999976),1.0-((1.0-source_secondary_uv.y)*0.0399999991-_UnityTimeX*0.400000006));
 vec4 ramp=texture(_MainTex,u);vec4 a=texture(_NoiseTex,source_noise1_uv);vec4 b=texture(_NoiseTex,source_noise2_uv);
 vec4 result=clamp((a+b*(b-a))*_Intensity*ramp.a+texture(_MainTex,source_main_uv),vec4(0.0),vec4(1.0));
'''+finish('opaque'),depth=True,cull=True)
# Self-Illumin: sampled RGB * (diffuse lighting + ambient/unlit mix), output alpha 1.
d=(O/'native_combat_diffuse_color.gdshader').read_text().replace('vec4 result=vec4(t.rgb*light,t.a);','vec4 result=vec4(t.rgb*(light+mix(vec3(1.0),source_sh_gamma(),_LightingBlend)),1.0);').replace('Hero/Diffuse/DiffuseColor','Hero/Self-Illumin_Diffuse').replace('-5812771937585292081','-9022200813960445910')
(O/'native_combat_endgame_self_illumin.gdshader').write_text(d)
p=json.load(open(R/'Hero_Self-Illumin_Diffuse/metadata.json'));st=p['subshaders'][0]['m_Passes'][0]['m_State'];rows.append({'suffix':'endgame_self_illumin','source_name':p['name'],'source_key':p['key'],'source_blend':{k:int(v['val']) for k,v in st['rtBlend0'].items()},'source_light_mode':'','source_cull':int(st['culling']['val']),'source_zwrite':int(st['zWrite']['val']),'godot_shader':'res://shaders/native_combat_endgame_self_illumin.gdshader'})
for row in rows:
 suffix=row['suffix'];base=(O/f'native_combat_{suffix}.gdshader').read_text();pair=(row['source_blend']['srcBlendAlpha'],row['source_blend']['destBlendAlpha']);prefix=base[:base.index(' ALBEDO',base.index('void fragment()'))]
 if pair==(5,10):alpha=' ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));\n ALPHA=result.a;'
 elif pair==(5,1):alpha=' ALBEDO=source_backend_inverse(vec3(clamp(result.a*result.a,0.0,1.0)));\n ALPHA=0.0;'
 elif pair==(1,10):alpha=' ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));\n ALPHA=result.a;'
 elif pair==(2,0):alpha=' ALBEDO=vec3(0.0);\n ALPHA=1.0-result.a;';prefix=prefix.replace('blend_mul','blend_mix')
 elif pair==(1,0):alpha=' ALBEDO=source_backend_inverse(vec3(clamp(result.a,0.0,1.0)));'
 else:raise ValueError(pair)
 alpha_code='// Source framebuffer alpha captured into RGB.\n'+prefix+alpha+'\n}\n'
 (O/f'native_combat_capture_alpha_{suffix}.gdshader').write_text(alpha_code)
 for kind,code in [('color',base),('alpha',alpha_code)]:
  pos=code.index(' ALBEDO',code.index('void fragment()'));code=code[:pos]+' result=clamp(result,vec4(0.0),vec4(1.0));\n'+code[pos:]
  (O/f'native_combat_capture_{kind}_unorm_{suffix}.gdshader').write_text(code)
(R/'routes.json').write_text(json.dumps(rows,indent=2));print(len(rows),'routes')
