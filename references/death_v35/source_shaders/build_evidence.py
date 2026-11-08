from pathlib import Path
import json,hashlib,struct
R=Path(__file__).parent;A=R.parent/'source_death_assets/assets'
m=json.load(open(A/'manifest.json'));prov=json.load(open(A/'data/source_bundle_provenance.json'));rows=json.load(open(R/'shader_routes.json'));records=[]
for row in rows:
 o=m['objects'][row['source_key']];d=o['data'];folder=R/row['source_name'].replace('/','_');nameindex={}
 st=d['m_ParsedForm']['m_SubShaders'][0]['m_Passes'][0]
 for stage in ['progVertex','progFragment']:
  variants=[]
  for sub in st[stage]['m_PlayerSubPrograms']:
   for q in sub:variants.append({**q,'keywords':[d['m_ParsedForm']['m_KeywordNames'][j] for j in q['m_KeywordIndices']]})
  nameindex[stage]={'variants':variants,'common_parameters':st[stage]['m_CommonParameters']}
 materials=[]
 for key,mat in m['objects'].items():
  if mat['type']=='Material' and mat['refs'].get('.m_Shader')==row['source_key']:
   textures=[]
   for tkey in mat['refs'].values():
    tx=m['objects'].get(tkey,{})
    if tx.get('type')=='Texture2D':
     td=tx['data'];textures.append({'key':tkey,'name':tx['name'],'mip_count':td['m_MipCount'],'color_space':td['m_ColorSpace'],'settings':td['m_TextureSettings'],'size':[td['m_Width'],td['m_Height']],'export':tx.get('file')})
   materials.append({'key':key,'name':mat['name'],'saved_properties':mat['data']['m_SavedProperties'],'textures':textures})
 raw=next(folder.glob('*.raw')).read_bytes();entries=[]
 for i in range(struct.unpack_from('<I',raw)[0]):
  pos,size,segment=struct.unpack_from('<III',raw,4+12*i);part=raw[pos:pos+size]
  (folder/f'entry{i}.bin').write_bytes(part)
  entries.append({'blob_index':i,'file':f'entry{i}.bin','sha256':hashlib.sha256(part).hexdigest(),'bytes':size})
 record={'route':row,'shader_properties':d['m_ParsedForm']['m_PropInfo'],'name_indices':st['m_NameIndices'],'programs':nameindex,'source_entries':entries,'materials':materials,'bundle_provenance':next(x for x in prov if x['bundle']==o['bundle'])}
 records.append(record)
(R/'shader_evidence.json').write_text(json.dumps({'build':'37.0.0.255130.254477','records':records},indent=2)+'\n')
print('Evidence for',len(records),'source shaders and',sum(len(x['materials']) for x in records),'non-Gold materials.')
