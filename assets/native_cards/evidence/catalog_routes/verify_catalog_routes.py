import struct,json,pathlib,hashlib
p=pathlib.Path('/workspace/shared/native_shader_evidence');b=(p/'runtime_catalog_source.bin').read_bytes();off=29989308;n=struct.unpack_from('<I',b,off)[0];off+=4;names=[]
for _ in range(n):
 size=0;shift=0
 while True:
  a=b[off];off+=1;size|=(a&127)<<shift
  if a<128:break
  shift+=7
 names.append(b[off:off+size].decode());off+=size
assert off==len(b)
def target(i):
 bi=struct.unpack_from('<I',b,17384396+4*i)[0];return {'index':i,'guid':b[8+16*i:24+16*i].hex(),'bundle_index':bi,'bundle':names[bi]}
rows={}
for j in range(684519):
 h=struct.unpack_from('<Q',b,21775076+j*8)[0];rows[h]=(j,struct.unpack_from('<I',b,27251232+j*4)[0])
result={'catalog_sha256':hashlib.sha256(b).hexdigest(),'source_url':'https://us.cdn.blizzard.com/tpr/hs/data/c9/a7/c9a7cb0ba7d64199834c9450eb3d8955','routes':[]}
for guid in ['3b6d04aee23313140a4436f2db238cfd','583499402f221f24792040779fa00734']:
 idx=(b.find(bytes.fromhex(guid),8,17384392)-8)//16;base=target(idx);trace=[]
 for stage,v in [('quality',0x20000),('platform',0x40000),('locale',0x1000d),('region',0x80001)]:
  hit=rows.get((v<<32)|idx);trace.append({'stage':stage,'variant_id_hex':hex(v),'source_index':idx,'row':hit[0] if hit else None,'target':target(hit[1] if hit else idx)});idx=hit[1] if hit else idx
 result['routes'].append({'base':base,'trace':trace,'final':target(idx)})
(p/'verified_catalog_routes.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
