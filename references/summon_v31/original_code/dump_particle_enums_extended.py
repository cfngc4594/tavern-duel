import dnfile,json,hashlib,struct
from pathlib import Path
p=Path('v31_work/source_code/managed/UnityEngine.ParticleSystemModule.dll');pe=dnfile.dnPE(str(p));enums={}
constants={x.Parent.row_index:x.Value.value for x in pe.net.mdtables.Constant if x.Parent.table.name=='Field'}
for ti,t in enumerate(pe.net.mdtables.TypeDef.rows,1):
 name=str(t.TypeName)
 if str(t.TypeNamespace)!='UnityEngine' or not name.startswith('ParticleSystem'):continue
 fields={}
 for f in t.FieldList:
  if f.row_index in constants:
   b=constants[f.row_index]
   fields[str(f.row.Name)]={'token':hex(0x04000000+f.row_index),'value':int.from_bytes(b,'little',signed=True)}
 if fields:enums[name]={'token':hex(0x02000000+ti),'fields':fields}
Path('v31_work/source_code/particle_enums_extended.json').write_text(json.dumps({'file':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'enums':enums},indent=2))
for n,v in enums.items():
 if any(x in n for x in ['Animation','MeshShape','StopBehavior','RenderSpace','Scaling']): print(n,{k:f['value'] for k,f in v['fields'].items()})
