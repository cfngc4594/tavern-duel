from restore_targeting import *
wanted={'Custom/Unlit/Color/Grey','Custom/Unlit/Color/White','Custom/Unlit/Color/BlackOverlay'}
pths=[V32/'casc/resources.assets',V32/'global_settings/globalgamemanagers.assets',V32.parent/'source_code/camera_source/sharedassets0.assets']
matches=[]
for p in pths:
 e=UnityPy.load(str(p))
 for f in e.assets:files[f.name.lower()]=f;bundle_file[f.name.lower()]=str(p)
 for o in e.objects:
  if o.type.name!='Shader':continue
  d=tree(o);n=d.get('m_ParsedForm',{}).get('m_Name',d.get('m_Name'))
  if n in wanted:
   export(o);matches.append({'name':n,'key':key(o),'source_file':str(p),'file_sha256':hashlib.sha256(p.read_bytes()).hexdigest()});print('FOUND',matches[-1],flush=True)
savejson(OUT/'data/highlight_builtin_resources.json',{'objects':records,'matches':matches,'unmatched_shader_names':sorted(wanted-{x['name']for x in matches}),'errors':errors,'missing':missing})
