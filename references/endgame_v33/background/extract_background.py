import UnityPy,pathlib,json,struct,lz4.block,hashlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).parent));from disassemble_dxbc import decode
UnityPy.config.FALLBACK_UNITY_VERSION='6000.3.11f1'
p=pathlib.Path('v32_work/source_assets/global_settings/globalgamemanagers.assets'); e=UnityPy.load(str(p)); f=next(iter(e.assets)); out=pathlib.Path(__file__).parent/'background';out.mkdir(exist_ok=True)
for pid in [33,36,49,42,40]:
 o=f.objects[pid];s=o.read_typetree();name=s['m_ParsedForm']['m_Name'];d=out/name.replace('/','_');d.mkdir(exist_ok=True)
 (d/'parsed.json').write_text(json.dumps(s['m_ParsedForm'],indent=2));(d/'source.json').write_text(json.dumps({'file':str(p),'pid':pid,'sha256':hashlib.sha256(o.get_raw_data()).hexdigest()}))
 for platform,offsets,csizes,dsizes in zip(s['platforms'],s['offsets'],s['compressedLengths'],s['decompressedLengths']):
  for seg,(offset,csize,dsize) in enumerate(zip(offsets,csizes,dsizes)):
   blob=lz4.block.decompress(bytes(s['compressedBlob'])[offset:offset+csize],uncompressed_size=dsize);(d/f'platform{platform}_segment{seg}.raw').write_bytes(blob)
   for i in range(struct.unpack_from('<I',blob)[0]):
    pos,size,segment=struct.unpack_from('<III',blob,4+12*i);entry=blob[pos:pos+size];idx=entry.find(b'DXBC')
    if idx<0:continue
    length=struct.unpack_from('<I',entry,idx+24)[0];dxbc=entry[idx:idx+length];fp=d/f'blob{i}.dxbc';fp.write_bytes(dxbc);fp.with_suffix('.asm.txt').write_text(decode(dxbc))
 print(pid,name)
