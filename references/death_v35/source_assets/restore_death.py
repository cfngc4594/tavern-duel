import pathlib,json,sys,re,struct,zlib,hashlib,urllib.request,urllib.error,functools,lz4.block,collections,math
import UnityPy
from UnityPy.helpers.MeshHelper import MeshHandler
UnityPy.config.FALLBACK_UNITY_VERSION='6000.3.11f1'
SRC=pathlib.Path(__file__).parent
OLD=pathlib.Path('/workspace/scratch/bb17e9e89c3a/v30_work/audio_assets_evidence')
OUT=SRC/'assets'
PREVIOUS=pathlib.Path('/workspace/scratch/bb17e9e89c3a/v31_work/source_assets')
V32=pathlib.Path('/workspace/scratch/bb17e9e89c3a/v32_work/source_assets')
V321=pathlib.Path('/workspace/scratch/bb17e9e89c3a/v32_1_work/source_damage_assets')
BUNDLES=SRC/'bundles';BUNDLES.mkdir(exist_ok=True)
for n in ['textures','meshes','animations','shaders','data','fonts']: (OUT/n).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(OLD));import casc_audio_fetch as casc
casc.ROOT=SRC;casc.DATA=SRC/'casc';casc.DATA.mkdir(exist_ok=True)
# The fixed official build's verified CASC tables are read locally, not regenerated.
for n in ['archive_entries.json']:
 p=casc.DATA/n
 if not p.exists():p.symlink_to(OLD/'casc'/n)
rows={x['filename']:x for x in json.load(open(OLD/'casc/install_rows.json'))};enc=json.load(open(OLD/'casc/encoding_rows.json'))
rows['Data/Win/unity default resources']=rows['Hearthstone_Data/Resources/unity default resources']
dep=json.load(open(OLD/'bundle_deps.json'));ns=dep['allBundleNames'];deps=dict(zip(ns,dep['bundles']))
cat=json.load(open(OLD/'base_assets_catalog.json'));guid_bundle={x['guid']:cat['m_bundleNames'][x['bundleId']]for x in cat['m_assets']}
locale_cat=json.load(open(OLD/'asset_catalog_locale_zhcn.json'));guid_bundle.update({x['guid']:locale_cat['m_bundleNames'][x['bundleId']]for x in locale_cat['m_assets']})
cabmap={}
for n in ['cab_bundle_map.json','shared_cab_bundle_map.json']:
 cabmap.update(json.load(open(OLD/n)))
cabmap.update(json.load(open(PREVIOUS/'cab_bundle_map.json')))
cabmap.update(json.load(open(V32/'cab_bundle_map.json')))
cabmap.update(json.load(open(V321/'cab_bundle_map.json')))
for prev in ['v34_work/source_status','v34_work/source_targeting']:
 cabmap.update(json.load(open(SRC.parent.parent/prev/'cab_bundle_map.json')))
if (SRC/'cab_bundle_map.json').exists():cabmap.update(json.load(open(SRC/'cab_bundle_map.json')))

def cabfrom(b):
 assert b[:8]==b'UnityFS\0';ver=int.from_bytes(b[8:12],'big');p=12;p=b.index(0,p)+1;p=b.index(0,p)+1
 size,cs,ds,flags=struct.unpack('>QIII',b[p:p+20]);p+=20
 if ver>=7:p=(p+15)//16*16
 assert not flags&128
 inf=b[p:p+cs]
 if flags&63 in [2,3]:inf=lz4.block.decompress(inf,uncompressed_size=ds)
 elif flags&63:raise ValueError(flags)
 return re.findall(rb'CAB-[a-f0-9]{32}',inf)[0].decode().lower()
for p in (OLD/'bundle_cab_prefixes').glob('*.prefix'):
 try:
  b=p.read_bytes();hs=int.from_bytes(b[4:8],'big');cabmap[cabfrom(b[hs+1:])]=p.name.removesuffix('.prefix')
 except Exception:pass
for p in (OLD/'bundles').glob('*.unity3d'):
 try:cabmap[cabfrom(p.read_bytes()[:65536])]=p.name
 except Exception:pass
known=OLD/'library_source/Yeti-CS2_182-original-containers/Yeti-CS2_182-assets/original_containers'
for p in known.glob('*.unity3d'):
 try:cabmap[cabfrom(p.read_bytes()[:65536])]=p.name
 except Exception:pass
cabmap['unity default resources']='unity default resources'
files={};bundle_file={};envs={};object_guid={};missing=[];errors=[];records={}
def fetch_bundle(n):
 for p in [BUNDLES/n,casc.DATA/n,SRC.parent.parent/'v34_work/source_status/bundles'/n,SRC.parent.parent/'v34_work/source_status/casc'/n,SRC.parent.parent/'v34_work/source_targeting/bundles'/n,SRC.parent.parent/'v34_work/source_targeting/casc'/n,V321/'bundles'/n,V321/'casc'/n,V32/'bundles'/n,V32/'casc'/n,PREVIOUS/'bundles'/n,PREVIOUS/'casc'/n,OLD/'bundles'/n,known/n]:
  if p.exists():return p
 r=rows['Data/Win/'+n];ek=enc[r['content_key']]['encoding_keys'][0]
 print('FETCH',n,r['size'],flush=True)
 d=casc.fetch(n,ek,r['content_key']);p=BUNDLES/n;p.write_bytes(d);return p

def load(n):
 if n in envs:return envs[n]
 e=UnityPy.load(str(fetch_bundle(n)));envs[n]=e
 for f in e.assets:files[f.name.lower()]=f;bundle_file[f.name.lower()]=n;cabmap[f.name.lower()]=n
 for g,p in e.container.items():
  try:o=p.deref();object_guid[key(o)]=g
  except Exception:pass
 return e

def key(o):return o.assets_file.name.lower()+':'+str(o.path_id)
def resolve(o,p):
 if not isinstance(p,dict)or not p.get('m_PathID'):return None
 f=o.assets_file;cab=f.name.lower()
 if p.get('m_FileID',0):
  cab=f.externals[p['m_FileID']-1].path.rsplit('/',1)[-1].lower()
  if cab not in files:
   if cab not in cabmap and (SRC/'cab_bundle_map.json').exists():cabmap.update(json.load(open(SRC/'cab_bundle_map.json')))
   if cab in cabmap:load(cabmap[cab])
   else:
    missing.append({'source':key(o),'cab':cab,'reference':p,'from_bundle':bundle_file[f.name.lower()]});return None
  f=files[cab]
 r=f.objects.get(p['m_PathID'])
 if r is None:missing.append({'source':key(o),'cab':cab,'reference':p,'reason':'path id absent'})
 return r

def refs(d,path=''):
 if isinstance(d,dict):
  if 'm_PathID'in d and 'm_FileID'in d:
   if d['m_PathID']:yield path,d
  else:
   for k,v in d.items():yield from refs(v,path+'.'+k)
 elif isinstance(d,(list,tuple)):
  for i,v in enumerate(d):yield from refs(v,path+f'[{i}]')

trees={}
def tree(o):
 k=key(o)
 if k not in trees:trees[k]=o.read_typetree()
 return trees[k]
def cn(o):
 if o.type.name!='MonoBehaviour':return o.type.name
 s=resolve(o,tree(o).get('m_Script'))
 return tree(s).get('m_ClassName','MonoBehaviour')if s else 'MonoBehaviour'
def identity(o):return {'bundle':bundle_file[o.assets_file.name.lower()],'cab':o.assets_file.name,'path_id':str(o.path_id),'guid':object_guid.get(key(o))}
def safe(x):return re.sub(r'[^A-Za-z0-9_.-]+','_',x)[:90]
def jsondefault(x):
 if isinstance(x,(bytes,bytearray)):return {'raw_bytes_hex':x.hex()}
 if hasattr(x,'tolist'):return x.tolist()
 return str(x)
def finite(d):
 if isinstance(d,float)and not math.isfinite(d):return 'Infinity' if d>0 else '-Infinity' if d<0 else 'NaN'
 if isinstance(d,dict):return {k:finite(v)for k,v in d.items()}
 if isinstance(d,(list,tuple)):return [finite(v)for v in d]
 return d
def savejson(p,d):
 t=p.with_suffix(p.suffix+'.tmp');t.write_text(json.dumps(finite(d),ensure_ascii=False,indent=2,default=jsondefault,allow_nan=False));t.replace(p)
SKIP_REFS={'.m_Script','.m_AudioClip','.m_audioClip','.m_Resource','.m_Category','.m_RandomClips','.m_ObjectHideFlags'}
ALLOWED={'GameObject','Transform','RectTransform','MonoBehaviour','MeshFilter','MeshRenderer','SkinnedMeshRenderer','ParticleSystemRenderer','ParticleSystem','Animation','AnimationClip','Material','Mesh','Texture2D','Shader','Animator','Avatar','AnimatorController','MonoScript','AudioSource','TrailRenderer','LineRenderer','Light','BoxCollider','SphereCollider','MeshCollider','AudioClip','PhysicMaterial','Font','TextMesh'}
def export(o):
 k=key(o)
 if k in records:return
 d=tree(o);name=d.get('m_Name','');typ=o.type.name;cl=cn(o)
 rec={'key':k,**identity(o),'source_object_sha256':hashlib.sha256(o.get_raw_data()).hexdigest(),'source_object_bytes':len(o.get_raw_data()),'type':typ,'class_name':cl,'name':name,'data':d,'refs':{},'files':{}}
 records[k]=rec
 if typ in ['Texture2D','Mesh','AnimationClip','Shader','Font']:
  stem=safe(name or typ)+'__'+str(o.path_id)
  try:
   v=o.read()
   if typ=='Font':
    raw=d.get('m_FontData',[])
    raw=bytes(raw) if isinstance(raw,list) else raw
    if raw:
     p=OUT/'fonts'/(stem+'.ttf');p.write_bytes(raw);rec['files']['font']=str(p.relative_to(OUT));rec['font_file_sha256']=hashlib.sha256(raw).hexdigest()
    rec['data']={x:y for x,y in d.items()if x!='m_FontData'}
   elif typ=='Texture2D':
    if d.get('m_Width',0)==0 and d.get('m_Height',0)==0 and d.get('m_CompleteImageSize',0)==0 and not d.get('m_StreamData',{}).get('size',0):
     rec['runtime_texture_placeholder']=True
     rec['export_note']='Original serialized zero-size dynamic font atlas has no image payload. Runtime engine rasterizes glyphs from the original Font.m_FontData.'
    else:
     p=OUT/'textures'/(stem+'.png');v.image.save(p);rec['files']['png']=str(p.relative_to(OUT))
    rec['data']={x:y for x,y in d.items()if x not in ['image data','m_ImageData']}
   elif typ=='Mesh':
    h=MeshHandler(v);h.process();m={'coordinate_space':'original Unity local, unchanged','name':name,'vertices':h.m_Vertices,'uv0':h.m_UV0,'uv1':h.m_UV1,'normals':h.m_Normals,'colors':h.m_Colors,'triangles':list(h.get_triangles())}
    p=OUT/'meshes'/(stem+'.mesh.json');savejson(p,m);rec['files']['mesh']=str(p.relative_to(OUT))
    p=OUT/'meshes'/(stem+'.obj');p.write_text(v.export());rec['files']['obj']=str(p.relative_to(OUT))
    rec['data']={x:y for x,y in d.items()if x not in ['m_VertexData','m_IndexBuffer','m_CompressedMesh']}
   elif typ=='AnimationClip':
    p=OUT/'animations'/(stem+'.json');savejson(p,d);rec['files']['animation']=str(p.relative_to(OUT))
   elif typ=='Shader':
    p=OUT/'shaders'/(stem+'.json');savejson(p,d);rec['files']['shader_data']=str(p.relative_to(OUT))
    try:
     p=OUT/'shaders'/(stem+'.shader.txt');p.write_text(v.export());rec['files']['shader_text']=str(p.relative_to(OUT))
    except Exception as ex:rec['shader_export_warning']=repr(ex)
  except Exception as ex:errors.append({'key':k,'type':typ,'error':repr(ex)});rec['export_error']=repr(ex)
 # No unrelated audio, CardDef, material arrays of global config, or script ancestry.
 if typ=='MonoBehaviour' and any(x in cl for x in ['SoundDef','SoundConfig']):return
 for field,p in refs(d):
  if any(field==s or field.startswith(s+'[')for s in SKIP_REFS):continue
  target=resolve(o,p)
  if target:
   rec['refs'][field]=key(target)
   if target.type.name in ALLOWED:export(target)

def asset(g):
 e=load(guid_bundle[g]);return e.container[g].deref()
def write_manifest(roots):
 savejson(OUT/'manifest.json',{'root_labels':{'hand_out_medium':roots.get('7106ac4b00cca44a6a998fd151491481'),'play_in_medium':roots.get('b66403dbb17e349b7a74ccac69286f92'),'hand_actor':roots.get('d00eb0f79080e0749993fe4619e9143d'),'play_actor':roots.get('23b7de16184fa8042bf6b734e7ca4d60')},'name_index':dict((n,[k for k,r in records.items()if r['name']==n])for n in set(r['name']for r in records.values())if n),'build':'37.0.0.255130.254477','schema_version':1,'root_prefabs':roots,'objects':records,'unresolved':missing,'export_errors':errors,'notes':['Object path IDs serialized as strings to preserve 64-bit identity.','Mesh JSON preserves original Unity coordinates. OBJ exporter reflects X and reverses winding; prefer mesh JSON.','Texture PNG is UnityPy decoded original bitmap, no repainting. Shader compiled code is not directly executable Godot code.']})
 current=json.load(open(SRC/'cab_bundle_map.json')) if (SRC/'cab_bundle_map.json').exists() else {}
 current.update(cabmap);savejson(SRC/'cab_bundle_map.json',current)
 savejson(SRC/'restore_status.json',{'object_counts':dict(collections.Counter(r['type']for r in records.values())),'unresolved':missing,'export_errors':errors})

