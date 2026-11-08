import json,pathlib
S=pathlib.Path(__file__).parent;D=S/'assets/data';p=D/'eligibility_surface_bindings.json';out=json.load(open(p));hero=json.load(open(S/'highlight_oracle/hero_surface_eligibility.json'))
out['hero']={r['gameobject_key']:{'name':r['path'].split('/')[-1],'mesh_key':r['mesh_key'],'source_chain':r['source_chain'],'surfaces':[{'material':m['material_key'],'shader':m['shader_key'],'tags':[['Highlight',m['highlight_tag']]]if m['highlight_tag'] else [],'eligible':m['eligible_if_visible'],'verified':bool(m['shader_key'])}for m in r['materials']]}for r in hero['renderers']}
objs=json.load(open('v34_work/source_status/assets/manifest.json'))['objects'];out['attached']={}
for r in objs.values():
 if r['type']!='MeshRenderer':continue
 go=objs[r['refs']['.m_GameObject']];mf=next((objs[k]for k in go['refs'].values()if k in objs and objs[k]['type']=='MeshFilter'),None)
 if not mf:continue
 surfaces=[]
 for i in range(len(r['data']['m_Materials'])):
  key=r['refs'].get('.m_Materials[%s]'%i);mat=objs.get(key,{});sk=mat.get('refs',{}).get('.m_Shader');shader=objs.get(sk,{});tags=[]
  ss=shader.get('data',{}).get('m_ParsedForm',{}).get('m_SubShaders',[])
  if ss:tags=ss[0].get('m_Tags',{}).get('tags',[])
  surfaces.append({'material':key,'shader':sk,'tags':tags,'eligible':any(k=='Highlight'and v!=''for k,v in tags),'verified':bool(shader)})
 out['attached'][go['key']]={'name':go['name'],'mesh_key':mf['refs'].get('.m_Mesh'),'surfaces':surfaces}
p.write_text(json.dumps(out,indent=2))
print('hero/attached',len(out['hero']),len(out['attached']))
for k,r in out['attached'].items():
 if any(x['eligible']for x in r['surfaces']):print(k,r['name'])
