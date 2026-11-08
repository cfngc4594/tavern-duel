from pathlib import Path
import json,sys
R=Path(__file__).parent
MODE=sys.argv[1] if len(sys.argv)>1 else 'minion'
M=R.parents[2]/('v34_work/TavernDuel/assets/original_endgame_v33/manifest.json' if MODE=='hero' else 'v33_work/TavernDuel/assets/original_summon_v31/manifest.json')
m=json.loads(M.read_text());a=m['objects'];root=m['root_labels']['hero_actor' if MODE=='hero' else 'play_actor'];gt={o['refs'].get('.m_GameObject'):o for o in a.values() if o['type']=='Transform'}
def ancestry(go):
 out=[];seen=set()
 while go in a and go not in seen:
  seen.add(go);out.append(go)
  if go==root:return list(reversed(out))
  t=gt.get(go)
  if not t:return None
  go=a.get(t['refs'].get('.m_Father'),{}).get('refs',{}).get('.m_GameObject')
 return None
rows=[]
for key,o in a.items():
 if o['type']!='MeshRenderer':continue
 go=o['refs'].get('.m_GameObject');chain=ancestry(go)
 if not chain:continue
 components=[a.get(v,{}) for k,v in a[go]['refs'].items() if k.startswith('.m_Component')]
 mf=next((v for v in components if v.get('type')=='MeshFilter'),{});meshkey=mf.get('refs',{}).get('.m_Mesh');mesh=a.get(meshkey,{})
 nsub=len(mesh.get('data',{}).get('m_SubMeshes',[]));mats=[];inactive=[a[k]['name'] for k in chain if not a[k]['data']['m_IsActive']]
 for slot,mk in enumerate([o['refs'].get(f'.m_Materials[{i}]') for i in range(len(o['data'].get('m_Materials',[])))]):
  mat=a.get(mk,{});sk=mat.get('refs',{}).get('.m_Shader');shader=a.get(sk,{});sp=shader.get('data',{}).get('m_ParsedForm',{});subs=sp.get('m_SubShaders',[])
  # All relevant source shaders have one subshader; never search fallback shader chain.
  tags=dict(subs[0].get('m_Tags',{}).get('tags',[])) if subs else {}
  # Material overrides, if any, take precedence over shader tags.
  tags.update(dict(mat.get('data',{}).get('stringTagMap',[])))
  eligible=bool(tags.get('Highlight','')) and slot<nsub
  mats.append({'slot':slot,'material_key':mk,'material_name':mat.get('name'),'shader_key':sk,'shader_name':sp.get('m_Name'),'highlight_tag':tags.get('Highlight',''),'submesh_exists':slot<nsub,'eligible_if_visible':eligible})
 rows.append({'renderer_key':key,'gameobject_key':go,'path':'/'.join(a[k]['name'] for k in chain),'source_chain':[{'gameobject_key':k,'name':a[k]['name'],'transform_key':gt[k]['key'],'transform':gt[k]['data'],'gameobject_active':a[k]['data']['m_IsActive']} for k in chain],'source_enabled':bool(o['data']['m_Enabled']),'source_inactive_ancestors':inactive,'mesh_key':meshkey,'submesh_count':nsub,'materials':mats,'source_default_contributes':bool(o['data']['m_Enabled']) and not inactive and any(x['eligible_if_visible'] for x in mats),'runtime_boundary':'Runtime visibility, dynamically attached state meshes, and material substitutions must be re-evaluated; source prefab default is not live gameplay proof.'})
report={'source_manifest':str(M),'root_key':root,'source_filter':'Renderer enabled, active hierarchy, valid MeshFilter/sharedMesh, nonempty Material.GetTag(Highlight,false), submesh slot below min(mesh count, material count). Highlight plane is forcibly disabled during capture.','renderers':rows}
(R/(MODE+'_surface_eligibility.json')).write_text(json.dumps(report,indent=2)+'\n')
for r in rows:
 if any(x['eligible_if_visible'] for x in r['materials']):print(r['source_default_contributes'],r['path'],'inactive',r['source_inactive_ancestors'],[(m['slot'],m['shader_name']) for m in r['materials'] if m['eligible_if_visible']])
