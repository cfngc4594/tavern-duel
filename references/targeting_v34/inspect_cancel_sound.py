from restore_targeting import *
g='9cde7207a78024e46aa5a0a657807845';o=asset(g);d=tree(o)
out=[]
for field,p in refs(d):
 target=resolve(o,p)
 if target:out.append({'field':field,'key':key(target),'identity':identity(target),'type':target.type.name,'class':cn(target),'data':tree(target) if target.type.name!='AudioClip' else target.read_typetree()})
savejson(OUT/'data/cancel_audio_binding.json',{'guid':g,'identity':identity(o),'class':cn(o),'type':o.type.name,'data':d,'direct_dependencies':out})
print(o.type.name,cn(o),d)
print([(x['field'],x['type'],x['class'],x['identity'])for x in out])
