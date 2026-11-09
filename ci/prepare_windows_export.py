"""Prepare an isolated production-only Windows export. Does not edit the checkout."""
import argparse, hashlib, json, shutil, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument("source",type=Path);p.add_argument("output",type=Path)
a=p.parse_args();source=a.source.resolve();out=a.output.resolve()
if out.exists():raise SystemExit("Output must be new, refusing to replace: "+str(out))
if source == out or source in out.parents and 'build' not in out.relative_to(source).parts:
    raise SystemExit("Use a new build directory or a separate destination")
stage=out/'project';stage.mkdir(parents=True)
roots={'assets','original_board','source_rope','scripts','shaders'}
exts={'.png','.webp','.json','.bin','.sha256','.source_sha256','.value_sha256','.rgba8-mips','.dxt-mips','.wav','.ogg'}
files={'main.tscn','project.godot','default_bus_layout.tres'}
tracked=subprocess.check_output(['git','-C',str(source),'ls-files','-z']).decode().split('\0')
for rel in tracked:
    if not rel:continue
    path=Path(rel)
    if path.parts[0] not in roots and rel not in files and not (path.parts[0]=='references' and path.suffix in exts):continue
    if path.name.startswith('.env') or path.suffix in {'.jks','.keystore','.pem','.key'}:
        raise SystemExit('Forbidden private file: '+rel)
    target=stage/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/path,target)
project=stage/'project.godot';text=project.read_text(encoding='utf-8')
assert 'run/main_scene="res://main.tscn"' in text
assert 'renderer/rendering_method="gl_compatibility"' in text
assert '[editor_plugins]' not in text, 'Review existing editor plugins before export'
project.write_text(text+'\n[editor_plugins]\nenabled=PackedStringArray("res://addons/raw_runtime_export/plugin.cfg")\n',encoding='utf-8')
shutil.copytree(source/'addons/raw_runtime_export',stage/'addons/raw_runtime_export')
shutil.copyfile(source/'ci/windows_export_presets.cfg',stage/'export_presets.cfg')
exts={'.png','.webp','.json','.bin','.sha256','.source_sha256','.value_sha256','.rgba8-mips','.dxt-mips','.wav','.ogg'}
entries={}
for root in ('assets','original_board','source_rope','references'):
    for path in sorted((stage/root).rglob('*')):
        if path.is_file() and path.suffix in exts:entries[path.relative_to(stage).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
assert entries, 'No runtime assets'
sha=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
dirty=bool(subprocess.check_output(['git','-C',str(source),'status','--porcelain'],text=True).strip())
manifest={'source_commit':sha,'source_dirty':dirty,'godot_version':'4.7.1.stable','main_scene':'res://main.tscn','renderer':'gl_compatibility','baseline_runtime_raw_count':sum(not key.startswith('references/') for key in entries),'expected_raw_count':len(entries),'raw_assets':entries}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(out/'verify-empty').mkdir();(out/'verify-empty/project.godot').write_text('config_version=5\n',encoding='utf-8')
(out/'package').mkdir();shutil.copyfile(source/'ci/WINDOWS-README.txt',out/'package/README.txt')
print(json.dumps({'staging':str(stage),'raw_count':len(entries),'source_commit':sha}))
