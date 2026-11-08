import hashlib,json,sys,zipfile
from pathlib import Path
apk=Path(sys.argv[1]);project=Path(sys.argv[2]);out=Path(sys.argv[3])
exts={'.png','.webp','.json','.bin','.sha256','.source_sha256','.value_sha256','.rgba8-mips','.dxt-mips','.wav','.ogg'}
with zipfile.ZipFile(apk) as z:
 names=set(z.namelist());missing=[];different=[];checked={};raw_png=0
 for p in (project/'assets').rglob('*'):
  if not p.is_file() or p.suffix not in exts:continue
  rel=p.relative_to(project).as_posix();entry='assets/'+rel
  if entry not in names:missing.append(rel);continue
  if hashlib.sha256(p.read_bytes()).digest()!=hashlib.sha256(z.read(entry)).digest():different.append(rel)
  checked[p.suffix]=checked.get(p.suffix,0)+1
  if p.suffix=='.png':raw_png+=1
 libs=sorted(n for n in names if n.startswith('lib/'))
 report={'apk':str(apk),'size_bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'zip_entries':len(names),'zip_crc_error':z.testzip(),'checked_assets_by_extension':checked,'raw_png_checked':raw_png,'missing_assets':missing,'different_assets':different,'native_libraries':libs,'script_source_entries':sum(n.endswith('.gd') for n in names),'compiled_script_entries':sum(n.endswith('.gdc') for n in names),'qa_entries':[n for n in names if '/qa_' in n or '/tests/' in n]}
 out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({k:v for k,v in report.items() if k not in {'missing_assets','different_assets','qa_entries'}},ensure_ascii=False))
 print('missing',len(missing),'different',len(different),'qa',len(report['qa_entries']))
 sys.exit(0 if not missing and not different and report['zip_crc_error'] is None else 1)
