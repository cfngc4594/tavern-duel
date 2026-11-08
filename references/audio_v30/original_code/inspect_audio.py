import dnfile, json, re, sys
from pathlib import Path
p=dnfile.dnPE('v30_work/original_code/Assembly-CSharp.dll')
out=Path('v30_work/audio_code_evidence')
rows=[]
for ti,t in enumerate(p.net.mdtables.TypeDef.rows,1):
 name=f'{t.TypeNamespace}.{t.TypeName}'.strip('.')
 if re.search('sound|audio|speech|spell|actor|animationevent',name,re.I):
  methods=[{'token':f'0x{0x06000000+m.row_index:08x}','name':str(m.row.Name),'rva':m.row.Rva} for m in t.MethodList]
  fields=[{'token':f'0x{0x04000000+f.row_index:08x}','name':str(f.row.Name)} for f in t.FieldList]
  rows.append({'type':name,'token':f'0x{0x02000000+ti:08x}','methods':methods,'fields':fields})
(out/'audio_types.json').write_text(json.dumps(rows,indent=2))
for r in rows:
 if re.search('^(Sound|Audio|Speech|Spell|Actor|Animation)',r['type']):
  print(r['type'],r['token']);print('  '+', '.join(m['name'] for m in r['methods']))
