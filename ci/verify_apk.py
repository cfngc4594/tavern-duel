import hashlib,json,os,sys,zipfile
from pathlib import Path
from renderer_policy import validate_packed_renderer
apk=Path(sys.argv[1]);project=Path(sys.argv[2]);out=Path(sys.argv[3])
exts={'.png','.webp','.json','.bin','.sha256','.source_sha256','.value_sha256','.rgba8-mips','.dxt-mips','.wav','.ogg'}
with zipfile.ZipFile(apk) as z:
 names=set(z.namelist());missing=[];different=[];checked={};raw_png=0
 # Verify actual compiled project values, not only source text or an export label.
 renderer_error=None;renderer_settings={}
 try:renderer_settings=validate_packed_renderer(z.read('assets/project.binary'))
 except (KeyError,ValueError) as error:renderer_error=str(error)
 export_settings={}
 try:
  export_settings=json.loads(z.read('assets/release-build.json'))
  expected_privacy=os.environ.get('PRIVACY_TEST','0')=='1'
  if export_settings.get('renderer')!='forward_plus' or export_settings.get('mobile_renderer')!='forward_plus' or export_settings.get('fallback_to_opengl3') is not False or export_settings.get('privacy_test') is not expected_privacy:
   raise ValueError('Export metadata does not match requested renderer/privacy policy')
 except (KeyError,ValueError) as error:renderer_error=str(error)
 # Runtime raw-file loaders also live below original_board and source_rope.
 # Imported Godot textures/audio do not replace files read with FileAccess.
 runtime_roots=('assets','original_board','source_rope')
 for p in (p for root in runtime_roots for p in (project/root).rglob('*')):
  if not p.is_file() or p.suffix not in exts:continue
  rel=p.relative_to(project).as_posix();entry='assets/'+rel
  if entry not in names:missing.append(rel);continue
  if hashlib.sha256(p.read_bytes()).digest()!=hashlib.sha256(z.read(entry)).digest():different.append(rel)
  checked[p.suffix]=checked.get(p.suffix,0)+1
  if p.suffix=='.png':raw_png+=1
 libs=sorted(n for n in names if n.startswith('lib/'))
 report={'export_settings':export_settings,'renderer_settings':renderer_settings,'renderer_error':renderer_error,'base_renderer_uses_pinned_engine_default':'rendering/renderer/rendering_method' not in renderer_settings,'runtime_gpu_verified':False,'apk':str(apk),'size_bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'zip_entries':len(names),'zip_crc_error':z.testzip(),'checked_assets_by_extension':checked,'raw_png_checked':raw_png,'missing_assets':missing,'different_assets':different,'native_libraries':libs,'script_source_entries':sum(n.endswith('.gd') for n in names),'compiled_script_entries':sum(n.endswith('.gdc') for n in names),'qa_entries':[n for n in names if '/qa_' in n or '/tests/' in n]}
 out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({k:v for k,v in report.items() if k not in {'missing_assets','different_assets','qa_entries'}},ensure_ascii=False))
 print('missing',len(missing),'different',len(different),'qa',len(report['qa_entries']))
 sys.exit(0 if not missing and not different and report['zip_crc_error'] is None and renderer_error is None else 1)
