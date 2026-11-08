from restore_death import *
result={};evidence_bundles=set()
for label,g in [('actor','23b7de16184fa8042bf6b734e7ca4d60'),('spell_table','81be4c58f5a9d454e815f1b0703d8179')]:
 go=asset(g);evidence_bundles.add(identity(go)['bundle']);found=[]
 for p in tree(go)['m_Component']:
  c=resolve(go,p['component']);d=tree(c);cl=cn(c)
  if cl=='Actor':found.append(dict(key=key(c),class_name=cl,source_object_sha256=hashlib.sha256(c.get_raw_data()).hexdigest(),spell_table_path=d['m_spellTablePrefab']))
  if 'm_Table'in d:found.append(dict(key=key(c),class_name=cl,source_object_sha256=hashlib.sha256(c.get_raw_data()).hexdigest(),selected_entries=[x for x in d['m_Table']if x['m_Type']in(5,10)]))
 result[label]=dict(guid=g,key=key(go),source=identity(go),components=found)
cp=json.load(open(SRC/'card_pool_bindings.json'))
for c in cp['cards'].values():c.pop('normal_actor',None);evidence_bundles.add(c['carddef']['bundle'])
cp['notes']=['13 minion entities in this30-card pool include11 collectibles, Sheep and Mirror Image; the other17 entities are spells or Coin.','All30 normal custom-death paths and DeathEffectDef visual paths are empty.','Character death audio is selected separately from the common type5 body effect. Five character files resolve through the zhCN locale catalog; eight remain global effects/vocalizations. No unsupported claim that all13 are spoken Chinese.']
savejson(SRC/'card_pool_bindings.json',cp);savejson(SRC/'actor_spell_bindings.json',result)
prov=[]
for n in sorted(evidence_bundles):
 p=fetch_bundle(n);b=p.read_bytes();expected=rows['Data/Win/'+n]['content_key'];assert hashlib.md5(b).hexdigest()==expected
 prov.append(dict(bundle=n,source_path=str(p),official_install_md5=expected,actual_md5=hashlib.md5(b).hexdigest(),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),verified_exact_build_content=True,build='37.0.0.255130.254477'))
savejson(SRC/'binding_source_provenance.json',prov);print('PASS',len(cp['cards']),'carddefs',len(evidence_bundles),'evidence bundles')
