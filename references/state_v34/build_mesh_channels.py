from restore_status import *
m=json.load(open(OUT/'manifest.json'));result={}
for k,o in m['objects'].items():
 if o['type']!='Mesh':continue
 load(o['bundle']);obj=files[o['cab'].lower()].objects[int(o['path_id'])];d=tree(obj);channel=d['m_VertexData']['m_Channels'][3];present=channel['dimension']>0
 p=fetch_bundle(o['bundle']);result[k]={'name':o['name'],'bundle':o['bundle'],'bundle_path':str(p),'bundle_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'channel_index':3,'channel':channel,'vertex_count':d['m_VertexData']['m_VertexCount'],'color_present':present,'format':channel['format'],'normalization_divisor':255 if present and channel['format']==2 else 1}
savejson(SRC/'mesh_color_channels.json',{'source_build':m['build'],'schema':'meshes[source_key].channel is original Unity m_VertexData.m_Channels[3]; format2=UNorm8 normalized shader input.','mesh_count':len(result),'meshes':result});savejson(OUT/'data/mesh_color_channels.json',{'source_build':m['build'],'meshes':result});print('meshes',len(result))
