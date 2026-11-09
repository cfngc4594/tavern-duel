"""Package verified Windows build, checksums and report; no source/test inputs."""
import argparse,hashlib,json,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();out=a.output.resolve();package=out/'package'
report=json.loads((package/'verification.json').read_text(encoding='utf-8'))
assert not report['missing_assets'] and not report['different_assets'] and not report['forbidden_entries']
assert report['main_scene_exists'] and report['production_main_smoke_pass'] and report['compiled_scripts']>0 and not report['source_fallback']
expected={'TavernDuel.exe','TavernDuel.pck','README.txt','verification.json'}
# Godot can also produce an optional console wrapper, intentionally not shipped.
actual={x.name for x in package.iterdir()}
assert expected<=actual, 'Missing release files: '+str(expected-actual)
assert actual<=expected|{'TavernDuel.console.exe'}, 'Unexpected export files: '+str(actual-expected)
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()
for name in ['TavernDuel.exe','TavernDuel.pck']:assert (package/name).stat().st_size>100000
(package/'SHA256SUMS').write_text(''.join(digest(package/name)+'  '+name+'\n' for name in sorted(expected)),encoding='utf-8')
zip_path=out/'TavernDuel-Windows-x86_64.zip'
with zipfile.ZipFile(zip_path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name in sorted(expected|{'SHA256SUMS'}):z.write(package/name,'TavernDuel/'+name)
with zipfile.ZipFile(zip_path) as z:assert z.testzip() is None
(out/'SHA256SUMS').write_text(digest(zip_path)+'  '+zip_path.name+'\n',encoding='utf-8')
print(json.dumps({'zip':str(zip_path),'size':zip_path.stat().st_size,'sha256':digest(zip_path)}))
