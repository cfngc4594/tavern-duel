import json,pathlib
S=pathlib.Path(__file__).parent;D=S/'assets/data';objs={}
for p in ['v33_work/TavernDuel/assets/original_summon_v31/manifest.json','v33_work/TavernDuel/assets/original_endgame_v33/manifest.json']:
 objs.update(json.load(open(p))['objects'])
def eligible(mat):
 key=mat.lower();r=objs.get(key,{})
 sk=r.get('refs',{}).get('.m_Shader');s=objs.get(sk,{});tags=[]
 for q in s.get('data',{}).get('m_ParsedForm',{}).get('m_SubShaders',[]):tags+=q.get('m_Tags',{}).get('tags',[])
 return {'material':key,'shader':sk,'tags':tags,'eligible':any(k=='Highlight'and v!=''for k,v in tags),'verified':bool(s)}
x=json.load(open('v33_work/TavernDuel/assets/native_cards/OriginalCards/card_assets.json'));profile=next(p for p in x['profiles']if p['name']=='minion_in_play');out={}
for r in profile['renderers']:
 k='cab-69c88b234dfa427e02d1fcee9337ae34:'+r['nodeId'];out[k]={'name':next(n['name']for n in profile['nodes']if n['id']==r['nodeId']),'mesh_key':r['meshKey'].lower(),'surfaces':[eligible(m)for m in r['materialKeys']]}
(D/'eligibility_surface_bindings.json').write_text(json.dumps({'minion':out},indent=2))
for k,r in out.items():print(r['name'],[(s['eligible'],s['verified'])for s in r['surfaces']])
