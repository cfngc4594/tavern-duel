from pathlib import Path
import sys,json,numpy as np
R=Path(__file__).parent
sys.path.insert(0,str(R.parents[1]/'v32_work/source_assets/shader_analysis'))
from remaining_formula_interpreter import run,sample,constants,gamma
rng=np.random.default_rng(33032);res=[]
for name in ['Hero_Additive_AdditivePower','Hero_Multiply_Multiply_AlphaFade','Hero_AddMultiply_AddMultiplyFXScrollingManual','Custom_FX_FX_XPBar']:
 p=json.load(open(R/name/'metadata.json'))['subshaders'][0]['m_Passes'][0];err=0
 for i in range(1024):
  C=rng.uniform(0,1.4,4);col=rng.uniform(0,1.3,4);uv=rng.uniform(-.4,1.4,2);uv2=rng.uniform(-.4,1.4,2);st=rng.uniform(-.4,1.4,4);sh=rng.uniform(.01,1.5,3);light=rng.random(3);blend=rng.random();I,power,strength,fxi=rng.uniform(.01,2,4);sx,sy=rng.uniform(-1,1,2);scx,scy=rng.uniform(.1,2,2);time=rng.random();n1,n2=rng.uniform(.1,3,2);uadd=rng.random();pct=rng.random()
  vals={'_Color':col,'_MainTex_ST':st,'_Diffuse_ST':st,'_GlobalMipBias':[0,0],'_LightingBlend':blend,'unity_SHAr':[0,0,0,sh[0]],'unity_SHAg':[0,0,0,sh[1]],'unity_SHAb':[0,0,0,sh[2]],'_MainLightColor':np.r_[light,1],'_Intensity':I,'_power':power,'_Strength':strength,'_ScrollX':sx,'_ScrollY':sy,'_ScaleX':scx,'_ScaleY':scy,'_FxIntensity':fxi,'_Time':[time,time*20,time*40,time*60],'_NoiseScale1':n1,'_NoiseScale2':n2,'_Uadd':uadd,'_Percent':pct}
  vin={'v0':np.r_[rng.random(3),1],'v1':np.r_[uv,0,0],'v2':np.r_[uv2,0,0] if name.endswith('XPBar') else C}
  av=run(R/name/'blob1.asm.txt',{**constants(p,'progVertex',vals),**vin});actual=run(R/name/'blob3.asm.txt',{**constants(p,'progFragment',vals),**{k.replace('o','v'):v for k,v in av.items()if k.startswith('o')}})['o0'];u=uv*st[:2]+st[2:];t=sample(0,u)
  if name.endswith('AdditivePower'):expected=(t*I*power-strength)*2*np.r_[(1+(gamma(sh)-1)*blend)*col[:3],col[3]]
  elif name.endswith('AlphaFade'):expected=1+col[3]*(t-1)
  elif name.endswith('ScrollingManual'):expected=sample(1,u*[scx,scy]+[sx,sy])*np.r_[t[:3]*col[:3],t[3]*(col[3]-t[3])]*2*C*I*fxi*np.r_[1+(gamma(sh)+light-1)*blend,1]
  else:
   q=uv2*st[:2]+st[2:];a=sample(1,(uv2*[n1,.100000001]-time*np.array([1.70000005,.150000006])-[uadd,0])*st[:2]+st[2:]);b=sample(1,(uv2*[n2,.300000012]-time*np.array([3.5,.449999988])-[uadd,0])*st[:2]+st[2:]);ramp=sample(0,[np.clip(q[0]+.5-pct,.100000001,.899999976),q[1]*.0399999991-time*.400000006]);expected=np.clip((a+b*(b-a))*I*ramp[3]+t,0,1)
  err=max(err,float(np.max(abs(actual-expected))));assert np.allclose(actual,expected,atol=1e-12,rtol=1e-10),(name,i,actual,expected)
 res.append({'shader':name,'cases':1024,'max_error':err,'passed':True})
for name in ['Hero_Diffuse_Diffuse_Transparent','Hero_Self-Illumin_Diffuse']:
 err=0
 for i in range(1024):
  uv=rng.random(2);P=rng.uniform(-1,1,3);normal=rng.uniform(-1,1,3);normal/=np.linalg.norm(normal);sh=rng.uniform(.01,1,3);direction=rng.uniform(-1,1,3);main=rng.random(3);factor=rng.random();count=i%9;col=rng.uniform(.1,1.3,4);blend=rng.random();regs={'v1':np.r_[uv,0,0],'v2':np.r_[P,0],'v3':np.r_[normal,0],'cb0[4]':np.zeros(4),'cb0[5]':np.r_[direction,0],'cb0[6]':np.r_[main,1],'cb0[10]':np.r_[count,0,0,0],'cb2[11]':np.array([0,count,factor,0]),'cb2[12]':np.array([0,1,2,3]),'cb2[13]':np.array([4,5,6,7]),'cb2[27]':np.r_[0,0,0,sh[0]],'cb2[28]':np.r_[0,0,0,sh[1]],'cb2[29]':np.r_[0,0,0,sh[2]],'cb3[1]':col,'cb3[2]':np.r_[blend,0,0,0]}
  light=gamma(sh)+main*factor*np.clip(np.dot(normal,direction),0,1)
  for j in range(count):
   pos=np.r_[rng.uniform(2,4,3),1];clr=rng.random(4);att=rng.random(4);spot=rng.uniform(-1,1,4);regs[f'cb1[{j}]']=pos;regs[f'cb1[{256+j}]']=clr;regs[f'cb1[{512+j}]']=att;regs[f'cb1[{768+j}]']=spot
   delta=pos[:3]-P*pos[3];d2=max(np.dot(delta,delta),.0000610351562);d=delta/np.sqrt(d2);atten=1/(1+25*d2*att[0]);s=np.clip(np.dot(spot[:3],d)*att[2]+att[3],0,1);light+=clr[:3]*atten*s*s*np.clip(np.dot(normal,d),0,1)
  t=sample(0,uv)*col
  expected=np.r_[t[:3]*light*t[3],t[3]] if name.endswith('Transparent') else np.r_[t[:3]*(light+1+(gamma(sh)-1)*blend),1]
  actual=run(R/name/'blob15.asm.txt',regs)['o0'];err=max(err,float(np.max(abs(actual-expected))));assert np.allclose(actual,expected,atol=1e-12,rtol=1e-10),(name,i,actual,expected)
 res.append({'shader':name,'cases':1024,'max_error':err,'passed':True,'additional_lights':'0..8'})
report={'total_cases':sum(x['cases']for x in res),'results':res,'scope':'Independent source DXBC instruction interpreter vs high-level formulas only, not GPU/client-pixel equivalence. XP shader is not instantiated without server rewards.'}
(R/'formula_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
