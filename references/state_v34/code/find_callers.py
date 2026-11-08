from pathlib import Path
exec(Path('v34_work/source_status/code/dump_cil.py').read_text().split('pattern=sys.argv')[0].replace("sys.argv[3] if len(sys.argv)>3 else 'v30_work/original_code/Assembly-CSharp.dll'", "'v30_work/original_code/Assembly-CSharp.dll'"))
import bisect,struct
wanted={int(s,16) for s in sys.argv[1:]}
raw=Path('v30_work/original_code/Assembly-CSharp.dll').read_bytes()
byoff=sorted((p.get_offset_from_rva(m.Rva),i) for i,(n,m) in methods.items() if m.Rva)
offsets=[x[0] for x in byoff];candidates=set()
for tok in wanted:
 needle=struct.pack('<I',tok);at=0
 while True:
  at=raw.find(needle,at)
  if at<0:break
  ix=bisect.bisect_right(offsets,at)-1
  if ix>=0:candidates.add(byoff[ix][1])
  at+=1
res=[]
for i in sorted(candidates):
 n,m=methods[i]
 try:b=read_method_body_from_bytes(p.get_data(m.Rva))
 except Exception:continue
 hits=[ins for ins in b.instructions if isinstance(ins.operand,Token) and ins.operand.value in wanted]
 if not hits:continue
 item={'type':n,'method':str(m.Name),'token':f'0x{0x06000000+i:08x}','rva':hex(m.Rva),'instructions':[]}
 for ins in b.instructions:
  v=ins.operand
  op=resolve(v) if isinstance(v,Token) else ('['+', '.join(f'IL_{x-b.header_size:04x}' for x in v)+']') if ins.opcode.name=='switch' else f'IL_{v-b.header_size:04x}' if isinstance(v,int) and ins.opcode.name.startswith(('br','beq','bne','blt','ble','bgt','bge','leave')) else str(v) if v is not None else ''
  item['instructions'].append({'offset':f'IL_{ins.offset-b.header_size:04x}','opcode':str(ins.opcode.name),'operand':op,'token':str(v) if isinstance(v,Token) else None})
 res.append(item)
 for hit in hits:print(item['token'],n+'::'+str(m.Name),f'IL_{hit.offset-b.header_size:04x}',resolve(hit.operand))
name='callers_'+'_'.join(s.removeprefix('0x') for s in sys.argv[1:])
(out/(name+'.json')).write_text(json.dumps(res,indent=2))
