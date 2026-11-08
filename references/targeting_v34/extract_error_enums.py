import dnfile,json,pathlib,struct
p=dnfile.dnPE('v30_work/original_code/Assembly-CSharp.dll',clr_lazy_load=True);wanted={};types={}
for i,t in enumerate(p.net.mdtables.TypeDef.rows,1):
 name=str(t.TypeName)
 if i not in (0x0c17,0x28c5):continue # exact call-signature TypeDef rows only
 name=f'{t.TypeNamespace}.{name}'.strip('.')+'@'+hex(0x02000000+i)
 types[name]={'type_token':hex(0x02000000+i),'fields':{}}
 for f in t.FieldList:wanted[f.row_index]=(name,str(f.row.Name))
for c in p.net.mdtables.Constant.rows:
 if c.Parent.table.name!='Field' or c.Parent.row_index not in wanted:continue
 name,field=wanted[c.Parent.row_index];types[name]['fields'][field]=int.from_bytes(c.Value.value,'little',signed=True)
pathlib.Path('v34_work/source_targeting/error_enum_constants.json').write_text(json.dumps(types,indent=2));print([(k,len(v['fields']))for k,v in types.items()])
