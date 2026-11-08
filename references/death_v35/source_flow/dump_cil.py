import dnfile,json,re,sys,hashlib,os
from pathlib import Path
from dncil.cil.body.reader import read_method_body_from_bytes
from dncil.clr.token import Token, StringToken
p=dnfile.dnPE(sys.argv[3] if len(sys.argv)>3 else 'v30_work/original_code/Assembly-CSharp.dll',clr_lazy_load=True)
out=Path('v35_work/source_death_flow')
types={};methods={};fields={}
for i,t in enumerate(p.net.mdtables.TypeDef.rows,1):
 n=f'{t.TypeNamespace}.{t.TypeName}'.strip('.')
 types[i]=n
 for m in t.MethodList:methods[m.row_index]=(n,m.row)
 for f in t.FieldList:fields[f.row_index]=(n,f.row)
def row_name(row):
 if hasattr(row,'TypeName'):return f'{row.TypeNamespace}.{row.TypeName}'.strip('.')
 if hasattr(row,'Name'):return str(row.Name)
 return str(row)
def resolve(tok):
 v=tok.value; tab=v>>24;idx=v&0xffffff
 try:
  if tab==0x70:return repr(p.net.user_strings.get(idx).value)
  if tab==0x06:return methods[idx][0]+'::'+str(methods[idx][1].Name)
  if tab==0x04:return fields[idx][0]+'::'+str(fields[idx][1].Name)
  if tab==0x02:return types[idx]
  t=p.net.mdtables.tables[tab];row=t.rows[idx-1]
  if tab==0x0a:
   cl=row.Class
   if cl.table.name=='TypeDef':n=types[cl.row_index]
   elif cl.table.name=='TypeRef':n=row_name(cl.row)
   else:n=row_name(cl.row)
   return n+'::'+str(row.Name)
  if tab==0x2b:return resolve(Token((row.Method.table.number<<24)|row.Method.row_index))+'<spec>'
  return row_name(row)
 except Exception as e:return str(tok)+':'+type(e).__name__
pattern=sys.argv[1] if len(sys.argv)>1 else r'^(Sound|SpellState|AnimationEventSfxPlayer|EntityDef|CardDef|SoundSpell|ActorAttackSpell)'
ms=[];ts=[]
for i,t in enumerate(p.net.mdtables.TypeDef.rows,1):
 n=types[i]
 if not re.search(pattern,n):continue
 ts.append({'type':n,'token':f'0x{0x02000000+i:08x}','fields':[{'name':str(f.row.Name),'token':f'0x{0x04000000+f.row_index:08x}','signature':f.row.Signature.value.hex()} for f in t.FieldList]})
 for m in t.MethodList:
  if os.getenv('METHOD_TOKENS') and f'0x{0x06000000+m.row_index:08x}' not in os.environ['METHOD_TOKENS'].lower().split(','):continue
  if os.getenv('METHOD_FILTER') and not re.search(os.environ['METHOD_FILTER'],str(m.row.Name)):continue
  r=m.row;item={'type':n,'method':str(r.Name),'token':f'0x{0x06000000+m.row_index:08x}','rva':hex(r.Rva),'signature':r.Signature.value.hex(),'parameters':[str(x.row.Name) for x in r.ParamList]}; ms.append(item)
  if not r.Rva:continue
  try:
   b=read_method_body_from_bytes(p.get_data(r.Rva));item['code_size']=b.code_size;item['instructions']=[]
   for ins in b.instructions:
    v=ins.operand
    item['instructions'].append({'offset':f'IL_{ins.offset-b.header_size:04x}','opcode':str(ins.opcode.name),'operand':resolve(v) if isinstance(v,Token) else ('['+', '.join(f'IL_{x-b.header_size:04x}' for x in v)+']') if ins.opcode.name=='switch' else f'IL_{v-b.header_size:04x}' if isinstance(v,int) and ('BranchTarget' in str(ins.opcode.operand_type) or ins.opcode.name.startswith(('br','beq','bne','blt','ble','bgt','bge','leave'))) else str(v) if v is not None else '', 'token':str(v) if isinstance(v,Token) else None})
  except Exception as e:item['error']=str(e)
name=sys.argv[2] if len(sys.argv)>2 else 'core'
(out/(name+'.cil.json')).write_text(json.dumps({'types':ts,'methods':ms},ensure_ascii=False,indent=2))
with (out/(name+'.cil.txt')).open('w') as fp:
 for t in ts:
  fp.write('\nTYPE '+t['type']+' '+t['token']+'\n')
  for f in t['fields']:fp.write('FIELD '+f['token']+' '+f['name']+' SIG '+f['signature']+'\n')
 for m in ms:
  fp.write('\n'+m['token']+' '+m['type']+'::'+m['method']+'('+','.join(m['parameters'])+') RVA '+m['rva']+' SIG '+m['signature']+'\n')
  for x in m.get('instructions',[]):fp.write(f"  {x['offset']} {x['opcode']:14s} {x['operand']} {x['token'] or ''}\n")
print(f'{name}: {len(ts)} types {len(ms)} methods')
