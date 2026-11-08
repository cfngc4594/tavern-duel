import json,hashlib
from pathlib import Path
out=Path('v34_work/source_status')
paths=['v30_work/audio_code_evidence/final_core.cil.json','v30_work/audio_code_evidence/fsm_actor.cil.json','v30_work/audio_code_evidence/deeper.cil.json','v30_work/audio_code_evidence/playmaker_fsm_core.cil.json','v34_work/source_status/code/actor_visual_gates.cil.json','v34_work/source_status/code/tag_visual.cil.json','v34_work/source_status/code/legacy_state_components.cil.json','v32_work/source_code/damage_font_job_death_prepare.cil.json']
methods={}
for p in paths:
 for m in json.load(open(p))['methods']:
  key=(m['type'],m['token'])
  if key not in methods:methods[key]={'source_file':p,**m}
ids='060127ef 060127f0 06012838 0601283a 0601283b 0601283c 0601283d 0601283e 06012840 06012841 06012842 06012980 06012987 06012963 06012966 06012967 060148ff 06014935 06014936 06014937 0601493b 0601493c 06014988 06014989 0601498a 0601498b 06014a03 06014a07 06012cc5 06012d04 06012d05 06012d12 06012d14 06012d83 06012dc9 06012dfb 06012dfc 06012e28 06012e29 06012e76 06012e77 06012e79 06012eb2 06012f7b 06014bac 06014a8a 06014a8b 06014a92 06014a93'.split()
selected=[m for (_,t),m in methods.items() if t[2:] in ids or (m['type']=='HutongGames.PlayMaker.Fsm' and m['method'] in ('get_Active','Update','UpdateDelayedEvents','UpdateState'))]
(out/'code/hidden_actor_methods.json').write_text(json.dumps({'build':'37.0.0.255130.254477','methods':selected},ensure_ascii=False,indent=2))
assets=json.load(open(out/'assets/manifest.json')); obj=assets['objects']
bindings={}
for label,root in assets['root_labels'].items():
 comp=[obj[k] for k in obj[root]['refs'].values()]
 spell=next(c for c in comp if c['class_name']=='Spell'); fsm=next(c for c in comp if c['class_name']=='PlayMakerFSM')
 bindings[label]={'root_key':root,'root_active':obj[root]['data']['m_IsActive'],'spell_key':spell['key'],'fsm_key':fsm['key'],'fsm_enabled':fsm['data']['m_Enabled'],'fsm_game_object':fsm['refs']['.m_GameObject'],'object_container':spell['refs']['.m_ObjectContainer']}
legacy=[]
for k,v in obj.items():
 if v['class_name']=='SpellState':
  legacy.append({'component_key':k,'game_object_key':v['refs']['.m_GameObject'],'game_object_name':obj[v['refs']['.m_GameObject']]['name'],'data':v['data'],'refs':v['refs']})
(out/'code/hidden_actor_prefab_bindings.json').write_text(json.dumps({'bindings':bindings,'legacy_states':legacy},ensure_ascii=False,indent=2))
print('saved',len(selected),'methods',len(bindings),'prefab bindings')
