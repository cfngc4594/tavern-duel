import json,pathlib,shutil,hashlib
S=pathlib.Path(__file__).parent;A=S/'assets';D=A/'data'
models={};bas=pathlib.Path('v33_work/TavernDuel/assets')
for kind,folder,k in [('minion','original_summon_v31','cab-69c88b234dfa427e02d1fcee9337ae34:-5639427765453469019'),('hero','original_endgame_v33','cab-69c88b234dfa427e02d1fcee9337ae34:8726536325208915598')]:
 m=json.load(open(bas/folder/'manifest.json'));objects=m['objects'];c=objects[k];plane=objects[c['refs']['.m_RenderPlane']];components=[objects[q]for q in plane['refs'].values()];mesh=next(objects[x['refs']['.m_Mesh']]for x in components if x['type']=='MeshFilter');tr=next(x for x in components if x['type']=='Transform');hr=next(x for x in components if x['class_name']=='HighlightRender')
 states=[]
 for i,x in enumerate(c['data']['m_HighlightStates']):
  mk=c['refs'].get('.m_HighlightStates[%s].m_Material'%i);states.append({'state':x['m_StateType'],'offset':x['m_Offset'],'material_key':mk,'material':objects.get(mk)})
 hierarchy=[];t=tr
 for i in range(8):
  hierarchy.append(t);parent=t['refs'].get('.m_Father')
  if not parent:break
  t=objects[parent]
 models[kind]={'source_manifest':str(bas/folder/'manifest.json'),'highlight_state':c,'plane':plane,'components':components,'mesh':mesh,'hierarchy_to_actor_root':hierarchy,'target_states':states,'static_silhouette':None,'render_queue':c['data']['m_RenderQueueOffset']+c['data']['m_RenderQueue'],'has_fsm_on_plane':any(x['class_name']=='PlayMakerFSM'for x in components)}
 for f in mesh['files'].values():
  src=bas/folder/f;dst=A/f;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
passes=[
 {'id':'dark','size_factor':0.3,'ortho':'base - 0.2 * renderSize','replacement_rgba':[.25,.25,.25,1]},
 {'id':'grey','size_factor':0.3,'ortho':'base - 0.25 * renderSize','replacement_rgba':[.5,.5,.5,1]},
 {'id':'blend1','size_factor':0.3,'equation':'max(avg4(dark.r),grey.r at center)','blur_offset':-1.25,'offset_texel_source':'dark'},
 {'id':'light1','size_factor':0.5,'ortho':'base - 0.01 * renderSize','replacement_rgba':[.75,.75,.75,1]},
 {'id':'blend2','size_factor':0.5,'equation':'max(avg4(blend1.r),light1.r at center)','blur_offset':-1.25,'offset_texel_source':'blend1'},
 {'id':'light2','size_factor':1,'ortho':'base + 0.05 * renderSize','replacement_rgba':[.75,.75,.75,1]},
 {'id':'blend3','size_factor':1,'equation':'max(avg4(blend2.r),light2.r at center)','blur_offset':-1,'offset_texel_source':'blend2'},
 {'id':'blur','size_factor':1,'equation':'avg4(blend3.r)','blur_offset':-1.5,'offset_texel_source':'blend3'},
 {'id':'clip','size_factor':0.92,'ortho':'base + 0.1 * clipSize','replacement_rgba':[1,1,1,1]},
 {'id':'silhouette','size_factor':1,'equation':'clamp(.3*(sum4(blur.r)-sum4(clip.r)),0,1)','blur_offset':-.8,'offset_texel_source':'blur'}]
b={'build':'37.0.0.255130.254477','scope':'Ordinary played minion and hero current target eligibility','state_logic':{'token':'0x06012dd4','valid_not_hovered':26,'valid_hovered':27,'invalid':'return false, UpdateActorState continues to ordinary non-hand hover state2 or idle1; no orange eligibility','same_for_friendly_enemy_hero_minion':True,'validity_source':'selected SubOption.IsValidTarget(entityID), not color/side heuristic','exit_targeting':'Return to normal DoOptionHighlight response mode, restoring ready6/hover7 or idle1 as appropriate'},'state_apply':{'setup':'HighlightState.Setup: one Random.value seed per component, currentState1, renderer disabled','change':'copy bound state material properties, set preserved _Seed, RenderSilouette, apply bound offset. No PlayMakerFSM on current hero/minion plane, so enable renderer immediately.','hide':'state0,1 disables renderer immediately; state29 also hides without FSM','state26_material':'cab-3563ba8b89db13ca6eb196aa111591f1:-6183552841940532935','state27_material':'cab-3563ba8b89db13ca6eb196aa111591f1:3080504552357699045'},'models':models,'silhouette_pipeline':{'source':'HighlightRender.CreateSilhouetteTexture 0x0601527A; SetupRenderObjects0x0601527D; SetProjectionMatrix0x06015278; BlendBlit0x06015277','geometry_filter':'enabled MeshRenderer with MeshFilter/sharedMesh and nonempty Material.GetTag("Highlight",false). For each submesh min(mesh.subMeshCount,sharedMaterials.count). Hide highlight plane itself during render.','root_setup':'save actor world rotation+localScale, set root world scale1 and identity world rotation, then restore after rendering','resolution':'derive HighlightRender plane renderer world bounds: X=size.x, H=max(size.z,size.y); larger dimension256, other=int(256*smaller/larger); baseOrtho=H*0.5','view':'inverse(TRS(plane.position + renderOverrideOffset, plane.rotation * Euler(90,180,0), (1,1,-1)))','projection':'Ortho(-ortho,ortho,-ortho,ortho,1-renderScale,1+renderScale); renderScale=highlight plane world scale.x','format_enum':16,'rt_filter_mode':1,'format_note':'RenderTextureFormat.R8; source new output via RenderTextureTracker. All pass outputs scalar red replicated RGBA.','passes':passes,'four_sample_uvs':'uv + texelSize * blurOffset * [(1,1),(-1,-1),(1,-1),(-1,1)]','material_override':'final scalar silhouette texture replaces highlight material _MainTex; _FlareTex remains original','source_shaders':'highlight_resource_manifest.json + highlight_builtin_resources.json; decoded DXBC directories Custom_Selection_* and Custom_Unlit_Color_*','compatibility_limits':['Render projection, render target format, sampling, actor transform snapshot and replacement-material culling must be recreated; copying the source material onto arbitrary oval is not exact.','Legacy static snapshots of actor can only be reused if contributing renderer visibility/geometry matches; source recreates on VisibilityStatesChanged or force.','Do not mark eligible pixels as verified before renderer/RT adapter is exercised.']}}
(D/'eligibility_bindings.json').write_text(json.dumps(b,indent=2))
# Current card pool exact localized metadata. Kept distinct from 5834 rules.
pool=json.load(open(bas/'data/dual_deck_cards_5834.json'));rows={r['m_noteMiniGuid']:r for r in json.load(open('v30_work/audio_assets_evidence/CARD.dbf.json'))['Records']};out=[]
for id in sorted(set(pool['cards'])|{'HERO_01','HERO_08','HERO_07','CS2_034','CS2_056'}):
 r=rows.get(id);v=r.get('m_targetArrowText')if r else None
 out.append({'card_id':id,'dbf_id':r['m_ID']if r else None,'target_arrow_text':v,'zhCN':v['m_locValues'][12]if v else None,'enUS':v['m_locValues'][0]if v else None})
(D/'target_arrow_card_text.json').write_text(json.dumps({'build':b['build'],'source':'v30_work/audio_assets_evidence/CARD.dbf.json; official dbf.unity3d verified in existing source provenance','cil':'CardTextBuilder.GetTargetingArrowText0x06011E0F obtains CARD.m_targetArrowText, localizes, TextUtils.TransformCardText. Empty hides indicator.','cards':out},ensure_ascii=False,indent=2))
print('eligibility and text',[(r['card_id'],r['zhCN'])for r in out if r['zhCN']])
