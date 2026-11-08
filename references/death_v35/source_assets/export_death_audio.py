from restore_death import *
from UnityPy.helpers.ResourceReader import get_resource_data
import io,wave
R=SRC/'audio';(R/'clips').mkdir(parents=True,exist_ok=True);(R/'original_fsb').mkdir(exist_ok=True)
m=json.load(open(OUT/'manifest.json'));lg={x['baseGuid']:x['guid']for x in locale_cat['m_assets']};requests={};bindings={}
for k,r in m['objects'].items():
 if r['class_name']!='SoundDef':continue
 d=r['data'];paths=([d['m_AudioClip']]if d['m_AudioClip']else[])+[q['m_Clip']for q in d['m_RandomClips']]
 bindings[k]=dict(sound_def_key=k,game_object=r['cab'].lower()+':'+str(d['m_GameObject']['m_PathID']),configuration=d,clip_base_guids=[x.rsplit(':',1)[-1]for x in paths])
 for path in paths:requests[path.rsplit(':',1)[-1]]=path
out={};prov={}
for g,path in requests.items():
 guid=lg.get(g,g);ob=asset(guid);a=ob.read();d=tree(ob);res=a.m_Resource
 raw=bytes(a.m_AudioData)if a.m_AudioData else get_resource_data(res.m_Source,ob.assets_file,res.m_Offset,res.m_Size)
 rp=R/'original_fsb'/(guid+'.fsb');rp.write_bytes(raw);samples=a.samples;assert len(samples)==1
 fn,b=next(iter(samples.items()));fname=('zhCN_'if guid!=g else'global_')+a.m_Name+'_'+guid[:8]+pathlib.Path(fn).suffix;wp=R/'clips'/fname;wp.write_bytes(b)
 with wave.open(io.BytesIO(b))as w:info=dict(sample_rate=w.getframerate(),channels=w.getnchannels(),sample_width=w.getsampwidth(),sample_frames=w.getnframes(),duration_sec=w.getnframes()/w.getframerate())
 assert info['sample_rate']==d['m_Frequency']and info['channels']==d['m_Channels']and abs(info['duration_sec']-d['m_Length'])<.002
 out[g]=dict(requested_path=path,base_guid=g,resolved_guid=guid,locale='zhCN'if guid!=g else'global',source=identity(ob),source_audio_clip=d,source_object_sha256=hashlib.sha256(ob.get_raw_data()).hexdigest(),original_encoded_sha256=hashlib.sha256(raw).hexdigest(),original_encoded_bytes=len(raw),encoded_path=str(rp.relative_to(R)),export_sha256=hashlib.sha256(b).hexdigest(),export_bytes=len(b),source_path=str(wp.relative_to(R)),existing_production_path='res://assets/original_audio_v30/clips/'+fname,processing='Full original FSB decoded by already-verified UnityPy/fmod_toolkit; no trim, gain, pitch, resample or remix.',**info)
 bn=identity(ob)['bundle'];p=fetch_bundle(bn);bb=p.read_bytes();md5=hashlib.md5(bb).hexdigest();assert md5==rows['Data/Win/'+bn]['content_key'];prov[bn]=dict(bundle=bn,path=str(p),md5=md5,sha256=hashlib.sha256(bb).hexdigest(),bytes=len(bb),verified_exact_build_content=True)
 print(path,info['duration_sec'],flush=True)
 savejson(R/'clips_provenance.json',out)
savejson(R/'sound_bindings.json',bindings);savejson(R/'source_bundle_provenance.json',list(prov.values()));print('PASS',len(out),'clips',len(prov),'bundles')
