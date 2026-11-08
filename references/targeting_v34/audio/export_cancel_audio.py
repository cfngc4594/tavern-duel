from pathlib import Path
import json,hashlib,io,wave
import UnityPy
from UnityPy.helpers.ResourceReader import get_resource_data
UnityPy.config.FALLBACK_UNITY_VERSION='6000.3.11f1'
R=Path(__file__).parent;old=Path('v30_work/audio_assets_evidence');R.joinpath('clips').mkdir(exist_ok=True);R.joinpath('original_fsb').mkdir(exist_ok=True)
clips={'cancel_attack':'066172a886131dc4b96649adffddf9cb','ui_no_can_do':'9c034c03dde8fd8458679423cb554253'}
cat=json.load(open(old/'base_assets_catalog.json'));gb={x['guid']:cat['m_bundleNames'][x['bundleId']]for x in cat['m_assets']};loc=json.load(open(old/'asset_catalog_locale_zhcn.json'));lg={x['baseGuid']:x['guid']for x in loc['m_assets']};gb.update({x['guid']:loc['m_bundleNames'][x['bundleId']]for x in loc['m_assets']});rows={x['filename']:x for x in json.load(open(old/'casc/install_rows.json'))}
envs={};prov=[];out={}
for name,g in clips.items():
 guid=lg.get(g,g);bn=gb[guid]
 if bn not in envs:
  p=old/'bundles'/bn;b=p.read_bytes();expected=rows['Data/Win/'+bn]['content_key'];assert hashlib.md5(b).hexdigest()==expected
  prov.append(dict(bundle=bn,path=str(p),source_content_md5=expected,actual_md5=hashlib.md5(b).hexdigest(),sha256=hashlib.sha256(b).hexdigest(),size=len(b),verified=True));envs[bn]=UnityPy.load(str(p))
 o=envs[bn].container[guid].deref();a=o.read();d=o.read_typetree();r=a.m_Resource;raw=bytes(a.m_AudioData)if a.m_AudioData else get_resource_data(r.m_Source,o.assets_file,r.m_Offset,r.m_Size)
 rp=R/'original_fsb'/(guid+'.fsb');rp.write_bytes(raw);samples=a.samples;assert len(samples)==1;fn,b=next(iter(samples.items()));fname='global_'+a.m_Name+'_'+guid[:8]+Path(fn).suffix;wp=R/'clips'/fname;wp.write_bytes(b)
 with wave.open(io.BytesIO(b))as w: info=dict(sample_rate=w.getframerate(),channels=w.getnchannels(),sample_width=w.getsampwidth(),sample_frames=w.getnframes(),duration_sec=w.getnframes()/w.getframerate())
 assert info['sample_rate']==d['m_Frequency'];assert info['channels']==d['m_Channels'];assert abs(info['duration_sec']-d['m_Length'])<.002
 out[name]=dict(name=name,base_guid=g,resolved_guid=guid,locale='zhCN'if guid!=g else'global',source=dict(bundle=bn,cab=o.assets_file.name,path_id=str(o.path_id),guid=guid),source_audio_clip=d,source_object_sha256=hashlib.sha256(o.get_raw_data()).hexdigest(),original_encoded_sha256=hashlib.sha256(raw).hexdigest(),original_encoded_bytes=len(raw),encoded_path=str(rp.relative_to(R)),export_sha256=hashlib.sha256(b).hexdigest(),export_bytes=len(b),source_path=str(wp.relative_to(R)),path='res://assets/original_targeting_audio_v34/clips/'+fname,processing='Full original Unity AudioClip FSB decoded with existing trusted UnityPy/fmod_toolkit. No trim, gain, pitch, resample or remix.',**info)
 print(name,info['duration_sec'],len(b),flush=True)
 (R/'clips_provenance.json').write_text(json.dumps(out,indent=2))
(R/'source_bundle_provenance.json').write_text(json.dumps(prov,indent=2));print('PASS',len(out),'clips',len(envs),'cached official bundle')
