from pathlib import Path
import json,hashlib,struct
from PIL import Image
import texture2ddecoder as dec
R=Path(__file__).parents[1];S=R/'source_endgame_assets/assets';O=R/'TavernDuel/assets/original_endgame_v33';out=O/'mips';out.mkdir(exist_ok=True)
manifest=json.load(open(S/'manifest.json'));specs=json.load(open(S/'data/original_texture_payloads.json'));rows={}
def flip_block(b,kind,h):
 color=bytearray(b[-8:]);color[4:4+h]=color[4:4+h][::-1]
 if kind==10:return bytes(color)
 a=bytearray(b[:8]);bits=int.from_bytes(a[2:8],'little');r=[(bits>>(12*j))&4095 for j in range(4)];r[:h]=r[:h][::-1];a[2:8]=sum(v<<(12*j)for j,v in enumerate(r)).to_bytes(6,'little')
 return bytes(a+color)
for key,spec in specs.items():
 if spec.get('mip_count',0)<=1:continue
 fmt=spec['format'];assert fmt in (10,12)
 raw=(S/spec['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==spec['sha256'];offset=0;chunks=[];levels=[]
 for level in range(spec['mip_count']):
  w=max(1,spec['width']>>level);h=max(1,spec['height']>>level);bx=(w+3)//4;by=(h+3)//4;bs=8 if fmt==10 else 16;length=bx*by*bs;b=raw[offset:offset+length];assert len(b)==length
  rows_flipped=[]
  for y in range(by-1,-1,-1):
   for x in range(bx):rows_flipped.append(flip_block(b[(y*bx+x)*bs:(y*bx+x+1)*bs],fmt,min(h,4)))
  flipped=b''.join(rows_flipped)
  decode=dec.decode_bc1 if fmt==10 else dec.decode_bc3
  original=Image.frombytes('RGBA',(w,h),decode(b,w,h),'raw','BGRA')
  expected=original.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
  actual=Image.frombytes('RGBA',(w,h),decode(flipped,w,h),'raw','BGRA')
  assert actual.tobytes()==expected.tobytes(),(spec['name'],level,'block flip mismatch')
  if level==0:
   prior=Image.open(S/manifest['objects'][key]['files']['png']).convert('RGBA');assert prior.tobytes()==actual.tobytes(),(spec['name'],'not prior PNG')
  levels.append({'level':level,'width':w,'height':h,'bytes':length,'source_sha256':hashlib.sha256(b).hexdigest(),'oriented_sha256':hashlib.sha256(flipped).hexdigest(),'exact_decoded_vertical_flip':True})
  chunks.append(flipped);offset+=length
 assert offset==len(raw),(spec['name'],offset,len(raw))
 path=Path('mips')/(spec['name']+'__'+key.split(':')[-1]+'.dxt-mips');data=b''.join(chunks);(O/path).write_bytes(data)
 rows[key]={'name':spec['name'],'file':str(path),'width':spec['width'],'height':spec['height'],'mip_count':spec['mip_count'],'format':fmt,'source_sha256':spec['sha256'],'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'top_matches_png':True,'levels':levels,'bridge':'Lossless BC1/BC3 block row/index reordering for vertical UV convention. Original endpoint/color/alpha indices and every source mip preserved; no mip regeneration/recompression.'}
(O/'data/original_oriented_mips.json').write_text(json.dumps(rows,indent=2));(R/'texture_analysis/original_oriented_mips.json').write_text(json.dumps(rows,indent=2));print(len(rows),'textures',sum(len(s['levels'])for s in rows.values()),'mip levels verified')
