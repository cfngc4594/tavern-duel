import json,pathlib,sys,copy,struct
ROOT=pathlib.Path(__file__).parent
sys.path.insert(0,'v32_work/source_code')
import decode_combat_fsm as old
m=json.load(open('v34_work/source_status/assets/manifest.json')); objs=m['objects']
def read_actions(s):
 a=s['actionData']; ends=a['actionStartIndex'][1:]+[len(a['paramName'])];out=[]
 def read(j):
  t=a['paramDataType'][j];p=a['paramDataPos'][j]
  if t==12:
   n=a['arrayParamSizes'][p];j+=1;ar=[]
   for i in range(n):v,j=read(j);ar.append(v)
   return ar,j
  if t==40:
   n=a['customTypeSizes'][p];j+=1;v={'_serialized_type_name':a['customTypeNames'][p]}
   for i in range(n):name=a['paramName'][j];w,j=read(j);v[name]=w
   return v,j
  return old.param(a,j),j+1
 for i,n in enumerate(a['actionNames']):
  j=a['actionStartIndex'][i];d={}
  while j<ends[i]:name=a['paramName'][j];v,j=read(j);d[name]=v
  out.append(dict(index=i,class_name=n.split('.')[-1],enabled=bool(a['actionEnabled'][i]),params=d))
 return out
base_param=old.param
def status_param(a,i):
 t,p,z=a['paramDataType'][i],a['paramDataPos'][i],a['paramByteDataSize'][i]
 b=bytes(a['byteData'][p:p+z])
 if t==35 and z>=17:
  return {'value':dict(zip(('x','y','z','w'),struct.unpack('<ffff',b[:16]))),'useVariable':b[16],'name':b[17:].decode('utf-8')}
 if t in (15,16) and z>5:
  return {'value':struct.unpack('<f' if t==15 else '<i',b[:4])[0],'useVariable':b[4],'name':b[5:].decode('utf-8')}
 return base_param(a,i)
old.param=status_param
old.actions=read_actions
def val(x):return x.get('value',x) if isinstance(x,dict)else x
def walk(x,path=''):
 if isinstance(x,dict):
  if 'm_PathID'in x:yield path,x
  else:
   for k,v in x.items():yield from walk(v,path+'.'+k)
 elif isinstance(x,list):
  for i,v in enumerate(x):yield from walk(v,path+f'[{i}]')
def refmap(o):return {(int(p.get('m_FileID',0)),int(p['m_PathID'])):o['refs'].get(path) for path,p in walk(o['data'])}
def resolve(o,p):
 if not isinstance(p,dict)or not p.get('m_PathID'):return None
 if not p.get('m_FileID'):return o['cab'].lower()+':'+str(p['m_PathID'])
 return refmap(o).get((int(p['m_FileID']),int(p['m_PathID'])))
def norm(a,o):
 a=copy.deepcopy(a);params=a['params'];a['reference_keys']={p:resolve(o,v)for p,v in walk(params,'params')};a['target_object_key']=None
 for field in ('gameObject','m_GameObject','m_ParentObject','m_SpellObject','m_spellObject'):
  q=params.get(field)
  if isinstance(q,dict)and'ownerOption'in q:
   a['target_object_key']=resolve(o,o['data']['m_GameObject']) if q['ownerOption']==0 else resolve(o,val(q.get('gameObject')))
   if q['ownerOption']!=0 and q.get('gameObject',{}).get('useVariable'):a['target_variable']=q['gameObject'].get('name')
   break
 if a['class_name'] in ('PlayAnimation','AnimationPlaythroughAction','SetAnimationSpeed'):
  go=objs.get(a['target_object_key'],{});clips=[]
  for ck in go.get('refs',{}).values():
   c=objs.get(ck,{})
   if c.get('class_name')=='Animation':
    for k in c.get('refs',{}).values():
     clip=objs.get(k,{})
     if clip.get('class_name')=='AnimationClip'and clip.get('name')==val(params.get('animName',params.get('m_AnimName'))):clips.append(k)
  a['clip_key']=next(iter(dict.fromkeys(clips)),None)
 return a
routes={}; labels={v:k for k,v in m['root_labels'].items()}
for k,o in objs.items():
 if o['class_name']!='PlayMakerFSM':continue
 f=o['data']['fsm'];g=resolve(o,o['data']['m_GameObject']);name=labels.get(g)
 if not name:continue
 states=old.decode_fsm(f)
 for s in states:s['actions']=[norm(a,o)for a in s['actions']]
 r=dict(root_key=g,prefab_root_key=g,fsm_component_key=k,stage='root',card_id=name,variables=f['variables'],globalTransitions=f['globalTransitions'],all_states=states,event_schedules={})
 routes[name+'/root']=r
 def schedule(event,seq):
  rows=[];cb=[]
  for at,sn in seq:
   s=next(s for s in states if s['name']==sn);aa=[a for a in s['actions'] if a['enabled']]
   rows.append(dict(at=at,state_name=sn,state_index=s['state_index'],actions=aa))
   for a in aa:
    if a['class_name']=='SpellFinishAction':cb.append(dict(at=at+val(a['params']['m_Delay']),event='OnSpellFinished',action_index=a['index'],state_name=sn,independent_of_fsm_transition=True))
  r['event_schedules'][event]=dict(state_enter_schedule=rows,callbacks=cb,nominal_duration=seq[-1][0],schedule_status='source-derived-complete-current-pool',zero_time_transitions_frame_quantized=True,clock='scaled game time')
 schedule('__start__',[(0,f['startState'])])
 if name=='frozen_minion':
  schedule('__start__',[(0,'Is Diamond?'),(0,'State 3')])
  schedule('Birth',[(0,'CheckIfMerc'),(0,'EnableIce')]);schedule('Death',[(0,'Death'),(3,'NoneState')]);schedule('None',[(0,'NoneState')]);r['branch_proof']='Current-pool normal non-signature/non-mercenary minions: PREMIUM tag12=0 and LETTUCE_MERCENARY tag1665=0. No Idle event or automatic transition is serialized; EnableIce is persistent.'
 elif name=='frozen_hero':
  schedule('Birth',[(0,'Scale Hero Frame?'),(0,'Regular Frame')]);schedule('Death',[(0,'Death'),(3,'NoneState')]);schedule('None',[(0,'NoneState')]);r['branch_proof']='Base HERO_07/HERO_08 frame tag selects Regular Frame; no hero taunt route is activated.'
 elif name=='sleep':
  schedule('Birth',[(0,'Birth State'),(0,'Idle')]);schedule('Idle',[(0,'Idle')]);schedule('Death',[(0,'Death State'),(1,'State 1'),(1,'None State')]);schedule('None',[(0,'None State')]);r['branch_proof']='Summoning sickness uses IsAsleep, not IsExhausted. Birth sets particle playbackSpeed=0.5, Idle persists, Death fades 1.0s then clears/stops.'
 elif name=='taunt':
  a=.6000000238418579;b=.4000000059604645
  schedule('Birth',[(0,'Starship Check'),(0,'Idle State'),(a,'State 6'),(a+b,'State 2'),(a+b+1,'State 3')]);schedule('Death',[(0,'Death'),(0,'State 4'),(1.2000000476837158,'State 5'),(1.2000000476837158,'NoneState')]);schedule('None',[(0,'NoneState')]);r['branch_proof']='Current-pool regular non-stealth non-starship minion: type8 route. Wait0.6→scale0.4→gleam1.0. State4 Wait1.2 explicitly transitions despite continuing highlight/animation actions.'

def strids(v):
 if isinstance(v,dict):return {k:str(x)if k in ('path_id','m_PathID')else strids(x)for k,x in v.items()}
 if isinstance(v,list):return [strids(x)for x in v]
 return v
out={'schema_version':1,'build':m['build'],'rules_build':5834,'scope':'Current-pool standard minion frozen, base hero frozen, summoning sickness, normal taunt. No deathrattle substitution.','routes':routes,'notes':['Original action index and enabled flags retained. Static schedules select only actual current pool branches.','No invented Idle event: frozen/taunt persist in their serialized final state until Death/None.','SpellFinishAction reports completion without waiting for particle visual tails.','Schedule fidelity does not prove renderer/shader/component implementation completeness.']}
(ROOT/'runtime_routes.json').write_text(json.dumps(strids(out),indent=2))
print('routes',list(routes))
