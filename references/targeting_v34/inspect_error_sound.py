from restore_targeting import *
g='7b1a22774f818544387c0f2ca4fea02c';n=guid_bundle[g]
paths=[BUNDLES/n,casc.DATA/n,V33/'bundles'/n,V33/'casc'/n,V33A/'bundles'/n,V33A/'casc'/n,V321/'bundles'/n,V321/'casc'/n,V32/'bundles'/n,V32/'casc'/n,PREVIOUS/'bundles'/n,PREVIOUS/'casc'/n,OLD/'bundles'/n,known/n]
assert any(p.exists() for p in paths),'No cached exact source bundle; stop without network.'
o=asset(g);d=tree(o);out=[]
for field,p in refs(d):
 target=resolve(o,p)
 if target:out.append({'field':field,'key':key(target),'identity':identity(target),'type':target.type.name,'class':cn(target),'data':tree(target) if target.type.name!='AudioClip' else target.read_typetree()})
savejson(OUT/'data/error_audio_binding.json',{'guid':g,'identity':identity(o),'class':cn(o),'type':o.type.name,'data':d,'direct_dependencies':out})
print(o.type.name,cn(o),d)
print([(x['field'],x['type'],x['class'],x['identity'])for x in out])
for x in out:
 if x['class']=='SoundDef': print(json.dumps(x,indent=2))
