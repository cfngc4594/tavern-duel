import json,sys,zipfile
from pathlib import Path
apk=Path(sys.argv[1]);project=Path(sys.argv[2]);report=json.loads(Path(sys.argv[3]).read_text(encoding='utf-8'))
with zipfile.ZipFile(apk,'a',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 names=set(z.namelist())
 for rel in report['missing_assets']:
  p=project/rel;entry='assets/'+rel
  if entry in names:raise RuntimeError('Duplicate entry '+entry)
  z.write(p,entry);names.add(entry)
print('Added raw assets:',len(report['missing_assets']))
