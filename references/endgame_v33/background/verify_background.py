from pathlib import Path
import sys,json,numpy as np
R=Path(__file__).parent;sys.path.insert(0,str(R.parents[1]/'v32_work/source_assets/shader_analysis'))
from remaining_formula_interpreter import run,sample
rng=np.random.default_rng(330333);out=[]
for name,blob in [('Blur',2),('Desaturation',3),('Desaturation',5),('Vignetting',3),('Blend',3),('BlendToColor',3)]:
 err=0
 for i in range(1024):
  u=rng.random(2);amount=rng.random();brightness=rng.uniform(.1,2);off=rng.random()*2;px=1/rng.uniform(32,2048,2);d=rng.random(4);col=rng.random(4)
  regs={'v1':np.r_[u,0,0],'cb0[4]':np.zeros(4),'cb0[130]':np.r_[amount,0,0,0],'cb0[131]':np.r_[off,brightness,0,0]}
  if name=='Blur':
   o=px*(off+.5);coords=[u+o,u-o,u+o*[1,-1],u+o*[-1,1]]
   regs.update({f'v{j+2}':np.r_[q,0,0]for j,q in enumerate(coords)});exp=sum(sample(0,q)for q in coords)*brightness*.25
  elif name=='Desaturation':
   exp=np.array([np.dot(sample(0,u)[:3],[.212599993,.715200007,.0722000003]),0,0,0])if blob==3 else np.r_[np.repeat(sample(0,u)[0],3),amount]
  elif name=='Vignetting':exp=np.r_[np.repeat(sample(0,u)[0],3),1]*amount
  elif name=='Blend':exp=np.r_[sample(0,u)[:3],amount]
  else:regs['cb0[130]']=col;regs['cb0[131]']=np.r_[amount,0,0,0];exp=np.r_[col[:3],amount]
  act=run(R/'background'/('Custom_FullScreen_'+name)/f'blob{blob}.asm.txt',regs)['o0'];err=max(err,float(max(abs(act-exp))));assert np.allclose(act,exp,atol=1e-12,rtol=1e-10),(name,act,exp)
 out.append({'shader':name,'blob':blob,'cases':1024,'max_error':err})
report={'total_cases':6144,'results':out,'scope':'Compiled fragment equations independently interpreted; vertex four-diagonal offset traced from original VS. Source framebuffer blending preserved explicitly in adapters. Not client screenshot equivalence.'}
(R/'background_formula_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
