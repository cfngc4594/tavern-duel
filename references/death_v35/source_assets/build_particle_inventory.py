import json,pathlib,hashlib
R=pathlib.Path(__file__).parent;m=json.load(open(R/'assets/manifest.json'));o=m['objects']
def go_for(r):return o.get(r['refs'].get('.m_GameObject'),{})
def transform_for(g):return next((o[k]for k in g.get('refs',{}).values()if o[k]['type']=='Transform'),None)
particles={};renderers={};transforms={};materials={};components={}
for k,r in o.items():
 typ=r['type'];d=r['data'];go=go_for(r)
 if typ=='Transform':transforms[k]=dict(game_object=r['refs'].get('.m_GameObject'),game_object_name=go.get('name'),original_local_position=d['m_LocalPosition'],original_local_rotation=d['m_LocalRotation'],original_local_scale=d['m_LocalScale'],parent_key=r['refs'].get('.m_Father'),children=[r['refs'].get('.m_Children['+str(i)+']')for i in range(len(d['m_Children']))])
 elif typ in ('ParticleSystemRenderer','MeshRenderer'):
  renderers[k]=dict(game_object=r['refs'].get('.m_GameObject'),game_object_name=go.get('name'),initial_enabled=d['m_Enabled'],material_keys=[r['refs'].get('.m_Materials['+str(i)+']')for i in range(len(d['m_Materials']))],mesh_keys={f:kk for f,kk in r['refs'].items()if o[kk]['type']=='Mesh'},source_fields=d)
 elif typ=='ParticleSystem':
  tf=transform_for(go)
  particles[k]=dict(game_object=r['refs'].get('.m_GameObject'),game_object_name=go.get('name'),game_object_initial_active=go.get('data',{}).get('m_IsActive'),transform_key=tf['key']if tf else None,duration=d['lengthInSec'],looping=d['looping'],playOnAwake=d.get('playOnAwake'),simulationSpeed=d.get('simulationSpeed'),serialized_moveWithTransform=d.get('moveWithTransform'),cullingMode=d.get('cullingMode'),autoRandomSeed=d.get('autoRandomSeed'),randomSeed=d.get('randomSeed'),enabled_modules={n:v for n,v in d.items()if isinstance(v,dict)and v.get('enabled')},all_source_fields=d,reference_keys=r['refs'])
 elif typ=='Material':materials[k]=dict(name=r['name'],shader_key=r['refs'].get('.m_Shader'),shader_name=o.get(r['refs'].get('.m_Shader'),{}).get('data',{}).get('m_ParsedForm',{}).get('m_Name'),properties=d['m_SavedProperties'],reference_keys=r['refs'])
 elif typ=='MonoBehaviour'and r['class_name'] not in ('PlayMakerFSM','SoundDef'):
  components[k]=dict(class_name=r['class_name'],game_object=r['refs'].get('.m_GameObject'),game_object_name=go.get('name'),data=d,reference_keys=r['refs'])
out=dict(build=m['build'],particles=particles,renderers=renderers,transforms=transforms,materials=materials,auxiliary_components=components,notes=['Raw ParticleSystem modules retained, including disabled modules. Enabled Collision/SubModule/ClampVelocity/RotationBySpeed/Force cannot be silently discarded.','The iTween target is the collision-plane Transform, not the particles root. Its original local position and quaternion define the plane. Native collision and sub-emission are a renderer compatibility boundary.','All record references resolve through exact original PPtrs. Names are diagnostic labels, never the reference authority.','PremiumMaterialSwitcher materials are serialized auxiliary dependencies; non-premium renderers use their own original material array.'])
(R/'particle_inventory.json').write_text(json.dumps(out,indent=2));(R/'material_bindings.json').write_text(json.dumps(materials,indent=2));print('PARTICLES',len(particles),'RENDERERS',len(renderers),'MATERIALS',len(materials))
