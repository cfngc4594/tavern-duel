from pathlib import Path
exec(Path('v30_work/audio_code_evidence/dump_cil.py').read_text().split('pattern=sys.argv')[0])
rows=[]; consts={}
for c in p.net.mdtables.Constant.rows:
 if c.Parent.table.name=='Field':
  val=c.Value.value
  consts[c.Parent.row_index]=int.from_bytes(val,'little',signed=True) if len(val) in [1,2,4,8] else val.hex()
for i,t in enumerate(p.net.mdtables.TypeDef.rows,1):
 parent=t.Extends;ext=row_name(parent.row) if parent and parent.row else ''
 if any(s in ext for s in ['CardSound','Conditional','Voice','Speech']) or any(str(m.row.Name)=='DetermineBestAudioSource' for m in t.MethodList):
  rows.append({'type':types[i],'base':ext,'methods':[{'name':str(m.row.Name),'token':f'0x{0x06000000+m.row_index:08x}'} for m in t.MethodList],'fields':[str(f.row.Name) for f in t.FieldList]})
 if any(s in types[i].lower() for s in ['game_tag','gametag','gameoption','limitmax','spellstate']):
  fs={str(f.row.Name):consts.get(f.row_index) for f in t.FieldList if f.row_index in consts}
  if fs:rows.append({'enum':types[i],'fields':fs})
(out/'metadata_closure.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))
