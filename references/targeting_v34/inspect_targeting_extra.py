from pathlib import Path
exec(Path('v34_work/source_targeting/dump_cil.py').read_text().split('pattern=sys.argv')[0].replace("sys.argv[3] if len(sys.argv)>3 else 'v30_work/original_code/Assembly-CSharp.dll'", "'v30_work/original_code/Assembly-CSharp.dll'"))
cs=[]
for c in p.net.mdtables.Constant.rows:
 if c.Parent.table.name!='Field':continue
 n,f=fields.get(c.Parent.row_index,('',None))
 if n not in ['TargetReticleManager','TARGET_ARROW_TYPE','TARGET_RETICLE_TYPE']:continue
 import struct
 raw=c.Value.value
 v=struct.unpack('<f',raw)[0]if c.Type==12 else int.from_bytes(raw,'little',signed=True)
 cs.append({'type':n,'name':str(f.Name),'value':v,'raw':raw.hex()})
(out/'constants.json').write_text(json.dumps(cs,indent=2))
