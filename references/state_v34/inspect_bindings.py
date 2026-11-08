from restore_status import *
result={}
for label,g in [('hero_table','c7908ae61ab34412aa7f5a9bf3c89cf2'),('corruption_enchant',dict(zip(json.load(open(OLD/'cards_map.json'))['map']['keys'],json.load(open(OLD/'cards_map.json'))['map']['values']))['CS2_063e'].rsplit(':',1)[1])]:
 o=asset(g);d=tree(o);cs=[]
 for v in d.get('m_Component',[]):
  c=resolve(o,v['component']);cs.append({'key':key(c),'class_name':cn(c),'data':tree(c)})
 result[label]={'guid':g,'key':key(o),'root':d,'components':cs}
 print(label,g,flush=True)
 for c in cs:
  for field,v in c['data'].items():
   if field=='m_Table':
    for a in v:
     if a['m_Type'] in [8,14,52]:print(a,flush=True)
   elif isinstance(v,str)and ('Spell' in v or 'FX' in v or 'Effect'in field):print(field,v,flush=True)
   elif isinstance(v,dict) and any(t in field for t in ['EffectDef']): print(field,v,flush=True)
savejson(SRC/'binding_roots.json',result)
