import dnfile,json,struct
from pathlib import Path
p=dnfile.dnPE('v30_work/original_code/Assembly-CSharp.dll',clr_lazy_load=True)
cs={r.Parent.row_index:r for r in p.net.mdtables.Constant.rows if r.Parent.table.name=='Field'}
out={}
for t in p.net.mdtables.TypeDef.rows:
 name=str(t.TypeName)
 if name not in ['TagVisualActorCondition','TagVisualActorStateFunction','TagVisualActorFunction','GAME_TAG','GameTag','GameOption']:continue
 vals={}
 for f in t.FieldList:
  if f.row_index in cs:
   r=cs[f.row_index];b=r.Value.value
   if len(b)==4:vals[str(f.row.Name)]=struct.unpack('<i',b)[0]
 out[name]=vals
Path('v34_work/source_status/code/status_enum_constants.json').write_text(json.dumps(out,indent=2))
print(list(out))
