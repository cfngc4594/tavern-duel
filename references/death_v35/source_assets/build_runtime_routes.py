import json,pathlib,sys,copy,struct
ROOT=pathlib.Path(__file__).parent
sys.path.insert(0,'v32_work/source_code')
import decode_combat_fsm as old
m=json.load(open(ROOT/'assets/manifest.json'));objs=m['objects']
old.TABLES[33]='fsmObjectParams'
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
def patched_param(a,i):
 t,p,z=a['paramDataType'][i],a['paramDataPos'][i],a['paramByteDataSize'][i];b=bytes(a['byteData'][p:p+z])
 if t==35 and z>=17:return {'value':dict(zip(('x','y','z','w'),struct.unpack('<ffff',b[:16]))),'useVariable':b[16],'name':b[17:].decode('utf-8')}
 if t in (15,16) and z>5:return {'value':struct.unpack('<f'if t==15 else'<i',b[:4])[0],'useVariable':b[4],'name':b[5:].decode('utf-8')}
 return base_param(a,i)
old.param=patched_param;old.actions=read_actions
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
 if not isinstance(p,dict)or not int(p.get('m_PathID',0)):return None
 if not p.get('m_FileID'):return o['cab'].lower()+':'+str(p['m_PathID'])
 return refmap(o).get((int(p['m_FileID']),int(p['m_PathID'])))
def norm(a,o):
 a=copy.deepcopy(a);params=a['params'];a['reference_keys']={p:resolve(o,v)for p,v in walk(params,'params')};a['target_object_key']=None
 for field in ('gameObject','m_GameObject','m_ParentObject','m_SpellObject','m_spellObject'):
  q=params.get(field)
  if isinstance(q,dict)and'ownerOption'in q:
   a['target_object_key']=resolve(o,o['data']['m_GameObject'])if q['ownerOption']==0 else resolve(o,val(q.get('gameObject')))
   if q['ownerOption']!=0 and q.get('gameObject',{}).get('useVariable'):a['target_variable']=q['gameObject'].get('name')
   break
 if a['class_name']=='AnimationPlaythroughAction'and val(params.get('m_AnimName'))=='AllyInPlay_Death':a['clip_key']=m['root_labels']['actor_death_clip']
 return a
routes={};labels={v:k for k,v in m['root_labels'].items()};unknown=[]
for k,o in objs.items():
 if o['class_name']!='PlayMakerFSM':continue
 f=o['data']['fsm'];g=resolve(o,o['data']['m_GameObject']);name=labels[g];states=old.decode_fsm(f)
 for s in states:s['actions']=[norm(a,o)for a in s['actions']]
 r=dict(root_key=g,prefab_root_key=g,fsm_component_key=k,stage='root',card_id=name,variables=f['variables'],globalTransitions=f['globalTransitions'],all_states=states,event_schedules={})
 routes[name+'/root']=r
 def schedule(event,seq):
  r['event_schedules'][event]=dict(state_enter_schedule=[dict(at=t,state_name=sn,state_index=next(s['state_index']for s in states if s['name']==sn),actions=[a for a in next(s['actions']for s in states if s['name']==sn)if a['enabled']])for t,sn in seq],nominal_duration=seq[-1][0],schedule_status='source-derived-complete-current-pool',zero_time_transitions_frame_quantized=True,clock='scaled game time')
 schedule('__start__',[(0,f['startState'])])
 if name=='minion_death':
  schedule('Birth',[(0,'Birth State'),(0,'Birth Animate'),(.5,'Birth SubState'),(3.5,'disable shadows'),(3.5,'None State')]);schedule('None',[(0,'None State')]);r['branch_proof']='Original normal type5. ShakePosition blocks0.5s; AnimationPlaythroughAction and AudioPlaythroughAction immediately finish. SubState Wait3s; None releases Actor. Full CIL proof v32_work/source_code/death_release_timing.json and v35 source_death_flow.'
 elif name=='minion_death_splat':
  schedule('Idle',[(0,'Idle State')]);r['branch_proof']='Separate type10 death-splat indicator. Its use is a Card caller decision, not implied by ordinary death Birth; do not auto-enable with the body.'
def strids(v):
 if isinstance(v,dict):return {k:str(x)if k in ('path_id','m_PathID')else strids(x)for k,x in v.items()}
 if isinstance(v,list):return [strids(x)for x in v]
 return v
def chk(x,p=''):
 if isinstance(x,dict):
  if 'serialized_type'in x or 'unresolved_type'in x:unknown.append({'path':p,'value':x})
  for k,v in x.items():chk(v,p+'.'+k)
 elif isinstance(x,list):
  for i,v in enumerate(x):chk(v,p+f'[{i}]')
chk(routes)
out=dict(schema_version=1,build=m['build'],rules_build=5834,scope='Ordinary non-premium minion body death and independent DeathSplat indicator.',routes=routes,notes=['All object references encoded as strings for64-bit integrity.','type33 FsmTexture decoded from source fsmObjectParams; dynamic PortraitTexture is not original placeholder.','Death starts only at graveyard presentation, not simply when HP becomes0.','Source movement, visibility, audio and particle dependencies retained; portable renderer parity not implied.'])
(ROOT/'runtime_routes.json').write_text(json.dumps(strids(out),indent=2));(ROOT/'assets/data/death_fsm_decoded.json').write_text(json.dumps(strids(list(routes.values())),indent=2));(ROOT/'action_decode_validation.json').write_text(json.dumps(dict(unresolved=unknown,pass_no_unresolved=not unknown),indent=2));print('PASS',list(routes),'unknown',len(unknown))
