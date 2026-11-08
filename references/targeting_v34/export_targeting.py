from restore_targeting import *
sys.path.insert(0,str(V32.parent/'source_code'));from decode_combat_fsm import decode_fsm
labels_to_guids=dict(zip(sys.argv[1::2],sys.argv[2::2]));previous={}
if (OUT/'manifest.json').exists():
 previous=json.load(open(OUT/'manifest.json'))
roots=previous.get('root_prefabs',{});labels=previous.get('root_labels',{})
labels_to_guids={**{label:next(g for g,k in roots.items()if k==key_)for label,key_ in labels.items()},**labels_to_guids}
for label,g in labels_to_guids.items():
 o=asset(g);export(o);roots[g]=key(o);labels[label]=key(o)
 print('ROOT',label,key(o),'records',len(records),'missing',len(missing),'errors',len(errors),flush=True)
write_manifest(roots);m=json.load(open(OUT/'manifest.json'));m['root_labels']=labels;m['scope']='Same-build targeting source assets; no production implementation implied.';savejson(OUT/'manifest.json',m)
fsms=[]
for k,r in records.items():
 if 'fsm'not in r['data']:continue
 f=r['data']['fsm'];fsms.append({'key':k,'game_object':r['refs'].get('.m_GameObject'),'start_state':f['startState'],'states':decode_fsm(f),'variables':f['variables'],'globalTransitions':f['globalTransitions']})
savejson(OUT/'data/targeting_fsm_decoded.json',fsms)
provenance=[]
for n in sorted({r['bundle']for r in records.values()}):
 p=fetch_bundle(n);b=p.read_bytes();row=rows['Data/Win/'+n];ck=row['content_key'];assert hashlib.md5(b).hexdigest()==ck
 pp=next((p for p in [casc.DATA/(n+'.provenance.json'),V321/'casc'/(n+'.provenance.json'),V32/'casc'/(n+'.provenance.json'),PREVIOUS/'casc'/(n+'.provenance.json'),OLD/'casc'/(n+'.provenance.json')]if p.exists()),None)
 provenance.append({'bundle':n,'source_path':str(p),'build':'37.0.0.255130.254477','bytes':len(b),'official_install_path':row['filename'],'official_install_md5':ck,'actual_md5':hashlib.md5(b).hexdigest(),'sha256':hashlib.sha256(b).hexdigest(),'verified_exact_build_content':True,'download_provenance':json.load(open(pp))if pp else None})
savejson(OUT/'data/source_bundle_provenance.json',provenance)
print('DONE',dict(collections.Counter(r['type']for r in records.values())),len(missing),len(errors),flush=True)
