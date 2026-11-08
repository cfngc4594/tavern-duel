import dnfile,json
from pathlib import Path
out={}
for name,types in [('Assembly-CSharp.dll',['SoundCategory','Option']),('Blizzard.T5.iTween.dll',['EaseType'])]:
 p=dnfile.dnPE('v30_work/original_code/'+name,clr_lazy_load=True)
 const={c.Parent.row_index:int.from_bytes(c.Value.value,'little',signed=True) for c in p.net.mdtables.Constant.rows if c.Parent.table.name=='Field' and len(c.Value.value) in [1,2,4,8]}
 for i,t in enumerate(p.net.mdtables.TypeDef.rows,1):
  if str(t.TypeName) in types:
   fs={str(f.row.Name):const[f.row_index] for f in t.FieldList if f.row_index in const}
   if str(t.TypeName)=='Option':fs={k:v for k,v in fs.items() if 'VOLUME' in k or 'SOUND' in k or v in [3,8,9,10,11]}
   out[name+'::'+str(t.TypeNamespace)+'.'+str(t.TypeName)]={'type_token':hex(0x02000000+i),'fields':fs}
Path('v30_work/audio_code_evidence/audio_constants.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
