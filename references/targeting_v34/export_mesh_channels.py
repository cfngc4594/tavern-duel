from restore_targeting import *
m=json.load(open(OUT/'manifest.json'));ch={}
for model in json.load(open(OUT/'data/eligibility_bindings.json'))['models'].values():m['objects'][model['mesh']['key']]=model['mesh']
hero=json.load(open('v33_work/TavernDuel/assets/original_endgame_v33/manifest.json'))['objects']
for r in json.load(open(OUT/'data/eligibility_surface_bindings.json'))['hero'].values():
 if r['mesh_key']in hero:m['objects'][r['mesh_key']]=hero[r['mesh_key']]
for k,r in m['objects'].items():
 if r['type']!='Mesh':continue
 load(r['bundle']);o=files[r['cab'].lower()].objects[int(r['path_id'])];d=tree(o); channels=d.get('m_VertexData',{}).get('m_Channels',[]); color=channels[3]if len(channels)>3 else None
 fmt=color.get('format')if color else None
 ch[k]={'name':r['name'],'source_object_sha256':r.get('source_object_sha256'),'m_VertexData.m_Channels':channels,'color_channel':color,'normalization_divisor':255 if fmt==2 else 127 if fmt==3 else 65535 if fmt==4 else 32767 if fmt==5 else 1,'normalization_source':'Unity VertexFormat enum. Float32=0 Float16=1 UNorm8=2 SNorm8=3 UNorm16=4 SNorm16=5. Integer formats6..11 are not normalized.'}
savejson(OUT/'data/mesh_color_channels.json',ch)
