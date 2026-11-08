from restore_death import *
sys.path.insert(0,str(V32.parent/'source_code'));from decode_combat_fsm import decode_fsm
roots={};labels={}
for label,g in [('minion_death','0d12844e0f5834ae084290dc98ded3af'),('minion_death_splat','abea9449432314da1a71c67f549c71b0')]:
 o=asset(g);export(o);roots[g]=key(o);labels[label]=key(o)
 print('ROOT',label,key(o),'records',len(records),'missing',len(missing),'errors',len(errors),flush=True)
actor=asset('23b7de16184fa8042bf6b734e7ca4d60')
for c in tree(actor)['m_Component']:
 o=resolve(actor,c['component'])
 if o.type.name=='Animation':
  for p in tree(o)['m_Animations']:
   clip=resolve(o,p)
   if tree(clip)['m_Name']=='AllyInPlay_Death':export(clip);labels['actor_death_clip']=key(clip)
# Current-pool CardDef references: preserve exact character death sounds and dynamic portrait textures.
carddefs=json.load(open(OLD/'carddefs.json'));card_rows={}
for cid,oldrow in carddefs.items():
 go=asset(oldrow['guid']);cd=next(resolve(go,q['component'])for q in tree(go)['m_Component']if cn(resolve(go,q['component']))=='CardDef');d=tree(cd)
 cr={'card_id':cid,'carddef':identity(cd),'carddef_object_sha256':hashlib.sha256(cd.get_raw_data()).hexdigest(),'custom_death':d['m_CustomDeathSpellPath'],'golden_custom_death':d['m_GoldenCustomDeathSpellPath'],'death_effect':d['m_DeathEffectDef'],'portrait':d['m_PortraitTexturePath'],'normal_actor':d.get('m_InPlayActorPath',d.get('m_ActorPath'))}
 cr['voice_roots']=[]
 for i,path in enumerate(d['m_DeathEffectDef']['m_SoundSpellPaths']):
  g=path.rsplit(':',1)[-1];ob=asset(g);export(ob);roots[g]=key(ob);labels['death_voice_'+cid+'_'+str(i)]=key(ob);cr['voice_roots'].append(key(ob))
 if cr['voice_roots']:
  g=d['m_PortraitTexturePath'].rsplit(':',1)[-1];ob=asset(g);export(ob);cr['portrait_texture_key']=key(ob)
 card_rows[cid]=cr
savejson(SRC/'card_pool_bindings.json',{'build':'37.0.0.255130.254477','rules_build':5834,'cards':card_rows,'notes':['13 minion entities in the current30-card pool include Sheep and Mirror Image. The other17 are spells or Coin.','Character DeathEffectDef sound paths do not replace shared body type5. All30 normal custom_death and DeathEffectDef visual paths are empty.']})
write_manifest(roots);m=json.load(open(OUT/'manifest.json'));m['root_labels']=labels;m['scope']='Same-build ordinary Card_Play_Ally death roots and direct object closure; no production implementation implied.';savejson(OUT/'manifest.json',m)
fsms=[]
for k,r in records.items():
 if 'fsm' not in r['data']:continue
 f=r['data']['fsm'];fsms.append({'key':k,'game_object':r['refs'].get('.m_GameObject'),'start_state':f['startState'],'states':decode_fsm(f),'variables':f['variables'],'globalTransitions':f['globalTransitions']})
savejson(OUT/'data/death_fsm_decoded.json',fsms)
provenance=[]
for n in sorted({r['bundle']for r in records.values()}):
 p=fetch_bundle(n);b=p.read_bytes();row=rows['Data/Win/'+n];ck=row['content_key'];assert hashlib.md5(b).hexdigest()==ck
 pp=next((q for q in [SRC/'casc'/(n+'.provenance.json'),SRC.parent.parent/'v34_work/source_status/casc'/(n+'.provenance.json'),SRC.parent.parent/'v34_work/source_targeting/casc'/(n+'.provenance.json'),V321/'casc'/(n+'.provenance.json'),V32/'casc'/(n+'.provenance.json'),PREVIOUS/'casc'/(n+'.provenance.json'),OLD/'casc'/(n+'.provenance.json')]if q.exists()),None)
 provenance.append({'bundle':n,'source_path':str(p),'build':'37.0.0.255130.254477','bytes':len(b),'official_install_path':row['filename'],'official_install_md5':ck,'actual_md5':hashlib.md5(b).hexdigest(),'sha256':hashlib.sha256(b).hexdigest(),'verified_exact_build_content':True,'download_provenance':json.load(open(pp))if pp else None})
savejson(OUT/'data/source_bundle_provenance.json',provenance)
print('DONE',dict(collections.Counter(r['type']for r in records.values())),len(missing),len(errors),flush=True)
