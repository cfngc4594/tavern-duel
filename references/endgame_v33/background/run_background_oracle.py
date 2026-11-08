from pathlib import Path
import json,sys
sys.path.insert(0,str(Path(__file__).parent));from check_background_pngs import check
root=Path('v33_work/TavernDuel/qa/v33/background-mechanism');d=json.load(open(root/'result.json'));results=[]
for c in d['captures']:
 label=c['label'];r=root/label;ps=[];u=c['uniforms'];a=c['audit']['passes'];
 def add(name,kind,src=None,dst=None,**kw):
  q={'file':name+'.png','kind':kind,**kw}
  if src:q['source']=src+'.png'
  if dst:q['destination']=dst+'.png'
  ps.append(q)
 add('luminance','luminance','live_board')
 add('desaturate','desaturation','luminance','live_board',desaturation=a['desaturation_uniform'])
 add('vignette','vignette',None,'desaturate',amount=a['vignette_uniform'])
 for name,src in [('blur1','vignette'),('blur2','blur1'),('blur3_full','blur2')]if a['blend']>=1 else [('blur1','vignette'),('blur2','blur1'),('blur3_intermediate','blur2')]:
  add(name,'blur',src,offset=u[name]['values']['_BlurOffset'],brightness=u[name]['values']['_Brightness'])
 if a['blend']<1:add('blend','blend','blur3_intermediate','vignette',amount=a['blend'])
 meta={'mask':str(Path('../../../../assets/original_endgame_v33/background/vignette_mask.png')),'passes':ps};(r/'oracle-input.json').write_text(json.dumps(meta,indent=2));out=check(r,meta);(r/'independent-pixel-oracle.json').write_text(json.dumps(out,indent=2));results.append({'label':label,**out});print(label,out['passed_rgb'],[(x['kind'],x['max_error_rgba'])for x in out['results']])
(root/'all-independent-pixel-oracles.json').write_text(json.dumps(results,indent=2))
