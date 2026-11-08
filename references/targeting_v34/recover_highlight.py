from restore_targeting import *
# Exact names are literal ShaderUtils.FindShader values in HighlightRender::.ctor.
wanted={'Custom/Selection/HighlightMultiSample','Custom/Selection/HighlightMultiSampleBlend','Custom/Selection/HighlightMaskBlend','Custom/UnlitColor','Custom/Unlit/Color/Grey','Custom/Unlit/Color/LightGrey','Custom/Unlit/Color/DarkGrey','Custom/Unlit/Color/BlackOverlay','Custom/Unlit/Color/White','Custom/Selection/Highlight'}
roots={};matches=[]
for n in ['essential_base_global-material-0.unity3d','essential_base_global-shader-0.unity3d','essential_base_global-prefab-0.unity3d','essential_base_global_shared-shader-0.unity3d']:
 if 'Data/Win/'+n not in rows:continue
 e=load(n)
 for o in e.objects:
  if o.type.name!='Shader':continue
  d=tree(o);name=d.get('m_ParsedForm',{}).get('m_Name')
  if name in wanted: export(o);roots[name]=key(o);print('FOUND',name,key(o),flush=True)
# Full original material closure for targetability states26 and27; exact serialized bindings.
e=load('essential_base_global-material-0.unity3d')
for pid in [-6183552841940532935,3080504552357699045]:
 for f in e.assets:
  if pid in f.objects:export(f.objects[pid])
savejson(OUT/'data/highlight_resource_manifest.json',{'build':'37.0.0.255130.254477','roots':roots,'objects':records,'unresolved':missing,'export_errors':errors,'unmatched_shader_names':sorted(wanted-set(roots))})
print('DONE',len(records),'missing',missing,'errors',errors,'unmatched',wanted-set(roots),flush=True)
