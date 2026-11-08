import pathlib,json,struct,lz4.block,hashlib
ROOT=pathlib.Path('/workspace/scratch/bb17e9e89c3a/v34_work/source_targeting/assets')
OUT=pathlib.Path(__file__).parent
manifest=json.load(open(ROOT/'data/highlight_resource_manifest.json'));manifest['objects'].update(json.load(open(ROOT/'data/highlight_builtin_resources.json'))['objects'])
res=[]
for key,obj in manifest['objects'].items():
 if obj['type']!='Shader':continue
 s=obj['data'];name=s['m_ParsedForm']['m_Name'];stem=name.replace('/','_');out=OUT/stem;out.mkdir(exist_ok=True)
 entries=[]
 for platform,offsets,csizes,dsizes in zip(s['platforms'],s['offsets'],s['compressedLengths'],s['decompressedLengths']):
  for seg,(offset,csize,dsize) in enumerate(zip(offsets,csizes,dsizes)):
   blob=lz4.block.decompress(bytes(s['compressedBlob'])[offset:offset+csize],uncompressed_size=dsize)
   (out/f'platform{platform}_segment{seg}.raw').write_bytes(blob)
   count=struct.unpack_from('<I',blob)[0]
   for i in range(count):
    pos,size,segment=struct.unpack_from('<III',blob,4+12*i)
    entry=blob[pos:pos+size]; idx=entry.find(b'DXBC');dxbc=None
    if idx>=0:
     length=struct.unpack_from('<I',entry,idx+24)[0];dxbc=entry[idx:idx+length];fname=f'blob{i}.dxbc';(out/fname).write_bytes(dxbc)
    entries.append({'blob_index':i,'offset':pos,'size':size,'segment':segment,'dxbc_offset':idx,'dxbc_size':len(dxbc)if dxbc else 0,'file':str((out/fname).relative_to(OUT))if dxbc else None})
 record={'key':key,'name':name,'source_bundle':obj['bundle'],'source_cab':obj['cab'],'path_id':obj['path_id'],'entries':entries,'subshaders':s['m_ParsedForm']['m_SubShaders']}
 (out/'metadata.json').write_text(json.dumps(record,indent=2))
 res.append({k:v for k,v in record.items()if k!='subshaders'})
(OUT/'highlight_shader_index.json').write_text(json.dumps(res,indent=2))
for x in res:
 print(x['name'],[(e['blob_index'],e['dxbc_size'])for e in x['entries']])
