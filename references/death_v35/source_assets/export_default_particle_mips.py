from pathlib import Path
import sys,json,hashlib
sys.path.insert(0,str(Path(__file__).parent));import restore_death as r
D=Path(__file__).parent/'sampler_audit';D.mkdir(exist_ok=True)
e=r.load('essential_base_global-prefab-0.unity3d');o=r.files['cab-69c88b234dfa427e02d1fcee9337ae34'].objects[5681093337556782924];t=o.read()
print(t.m_TextureFormat,t.m_MipCount,t.m_Width,t.m_Height)
print([x for x in dir(t) if any(y in x.lower() for y in ['image','texture','data'])])
from PIL import Image
bundle=r.fetch_bundle('essential_base_global-prefab-0.unity3d');official=r.rows['Data/Win/essential_base_global-prefab-0.unity3d']['content_key'];assert hashlib.md5(bundle.read_bytes()).hexdigest()==official
raw=t.get_image_data();assert len(raw)==21844 and t.m_TextureFormat==4 and t.m_MipCount==7
out=r.OUT/'mips';out.mkdir(exist_ok=True)
parts=[];levels=[];off=0
for level in range(7):
 w=max(1,64>>level);h=max(1,64>>level);length=w*h*4
 chunk=raw[off:off+length];assert len(chunk)==length
 im=Image.frombytes('RGBA',(w,h),chunk).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
 data=im.tobytes();parts.append(data)
 levels.append({'level':level,'width':w,'height':h,'byte_offset':off,'bytes':length,'source_chunk_sha256':hashlib.sha256(chunk).hexdigest(),'oriented_rgba_sha256':hashlib.sha256(data).hexdigest()})
 if level==0:
  existing=Image.open(r.OUT/'textures'/'Default-Particle__5681093337556782924.png').convert('RGBA')
  assert existing.size==im.size and existing.tobytes()==data,'base differs from already audited export'
 off+=length
assert off==len(raw)
f=out/'Default-Particle__5681093337556782924.rgba8-mips';f.write_bytes(b''.join(parts))
report={'source_build':'37.0.0.255130.254477','texture_key':'cab-69c88b234dfa427e02d1fcee9337ae34:5681093337556782924','texture_name':'Default-Particle','source_bundle':'essential_base_global-prefab-0.unity3d','official_bundle_md5':official,'format':'RGBA32 original -> Godot FORMAT_RGBA8, each original mip vertically flipped once to match audited PNG','mip_count':7,'mips_stripped':t.m_MipsStripped,'width':64,'height':64,'output_path':str(f.relative_to(r.OUT)),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'base_level_matches_prior_png':True,'levels':levels}
(D/'default_particle_mips.json').write_text(json.dumps(report,indent=2));(out/'Default-Particle__5681093337556782924.provenance.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

m=json.load(open(r.OUT/"manifest.json"));m["objects"][report["texture_key"]]["files"]["rgba8_mips"]=report["output_path"];m["objects"][report["texture_key"]]["original_mips"]=report;(r.OUT/"manifest.json").write_text(json.dumps(m,indent=2));
