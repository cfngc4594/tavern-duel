from restore_status import *
e=load('essential_base_global-prefab-0.unity3d');found=[]
for o in e.objects:
 if o.type.name!='MonoScript':continue
 d=o.read_typetree()
 if 'TagVisual' in d.get('m_ClassName',''):print('SCRIPT',key(o),d,flush=True);found.append(o.path_id)
for o in e.objects:
 if o.type.name!='MonoBehaviour':continue
 d=o.read_typetree()
 if d.get('m_Script',{}).get('m_FileID')==0 and d.get('m_Script',{}).get('m_PathID')in found:
  savejson(SRC/'tag_visual_config.json',{'key':key(o),'class_name':cn(o),'data':d});print('FOUND',key(o),list(d),flush=True)
