import dnfile,json,hashlib
from pathlib import Path
path=Path('v31_work/source_code/managed/UnityEngine.ParticleSystemModule.dll');p=dnfile.dnPE(str(path),clr_lazy_load=True)
wanted={};out={'assembly':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'types':{}}
for i,t in enumerate(p.net.mdtables.TypeDef.rows,1):
 name=str(t.TypeName)
 if name not in ('ParticleSystemSubEmitterType','ParticleSystemSubEmitterProperties','ParticleSystemCullingMode','ParticleSystemSimulationSpace','ParticleSystemCollisionType','ParticleSystemCollisionMode'):continue
 out['types'][name]={'token':hex(0x02000000+i),'values':{}}
 for f in t.FieldList:wanted[f.row_index]=(name,str(f.row.Name))
for c in p.net.mdtables.Constant.rows:
 if c.Parent.table.name=='Field' and c.Parent.row_index in wanted:
  name,field=wanted[c.Parent.row_index];out['types'][name]['values'][field]=int.from_bytes(c.Value.value,'little',signed=True)
Path('v35_work/source_death_flow/particle_enums.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
