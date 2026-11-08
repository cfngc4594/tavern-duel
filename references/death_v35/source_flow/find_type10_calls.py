from pathlib import Path
exec(Path('v35_work/source_death_flow/dump_cil.py').read_text().split('pattern=sys.argv')[0])
import bisect
raw=Path('v30_work/original_code/Assembly-CSharp.dll').read_bytes(); byoff=sorted((p.get_offset_from_rva(m.Rva),i) for i,(n,m) in methods.items() if m.Rva); offsets=[x[0] for x in byoff]; candidates=set();at=0
while True:
 at=raw.find(b'\x1f\x0a',at)
 if at<0: break
 ix=bisect.bisect_right(offsets,at)-1
 if ix>=0: candidates.add(byoff[ix][1])
 at+=2
res=[]
for i in sorted(candidates):
 n,m=methods[i]
 try:b=read_method_body_from_bytes(p.get_data(m.Rva))
 except Exception:continue
 hit=False
 for j,x in enumerate(b.instructions):
  if x.opcode.name!='ldc.i4.s' or x.operand!=10:continue
  ctx=b.instructions[max(j-3,0):j+9]
  if any(isinstance(y.operand,Token) and ('Spell' in resolve(y.operand) or 'Splat' in resolve(y.operand)) for y in ctx):hit=True
 if not hit:continue
 item={'type':n,'method':str(m.Name),'token':f'0x{0x06000000+i:08x}','instructions':[]}
 for ins in b.instructions:
  v=ins.operand
  item['instructions'].append({'offset':f'IL_{ins.offset-b.header_size:04x}','opcode':str(ins.opcode.name),'operand':resolve(v) if isinstance(v,Token) else str(v) if v is not None else '', 'token':str(v) if isinstance(v,Token) else None})
 res.append(item); print(item['token'],n+'::'+str(m.Name))
(out/'type10_spell_call_sites.json').write_text(json.dumps(res,indent=2))
