import dnfile,json
from pathlib import Path
p=Path('v30_work/original_code/Assembly-CSharp.dll');pe=dnfile.dnPE(str(p),clr_lazy_load=True)
print('heap attrs',pe.net.user_strings.__dict__.keys(),flush=True)
for i,t in enumerate(pe.net.mdtables.TypeDef.rows,1):
 name=str(t.TypeNamespace)+'.'+str(t.TypeName)
 if any(x in name.lower()for x in ['shadertime','shaderglobal','globalshader','shaderutil']): print('candidate type',name,hex(0x02000000+i),flush=True)
print(pe.net.user_strings.__dict__.get('file_offset'),pe.net.user_strings.__dict__.get('rva'),flush=True)
