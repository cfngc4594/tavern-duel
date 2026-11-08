"""Independent original SM4 instruction oracle vs high-level recovered equations.
This is CPU arithmetic/binding QA, never a client-pixel, rasterizer or GPU claim.
"""
from pathlib import Path
import sys,json,hashlib,numpy as np
R=Path(__file__).parent
sys.path.insert(0,str(R.parents[1]/'v32_work/source_assets/shader_analysis'))
from remaining_formula_interpreter import run,sample,constants,gamma

def unlit_desat(texel,vertex_rgba,tint,value_range,transition,sh_w,main_light,lighting_blend):
    t=np.array(texel);c=np.array(vertex_rgba)
    lighting=np.r_[gamma(np.array(sh_w)),1]+np.array(main_light)
    v=c+(lighting-c)*lighting_blend
    g=.300000012*value_range*sum(t[:3])
    return (t+(np.array(tint)*g-t)*transition)*v

def self_illumin_diffuse(texel,tint,illum,sh_w,normal,position,main_position,main_color,main_factor,additional):
    n=np.array(normal);n=n/np.linalg.norm(n)
    light=gamma(np.array(sh_w))+np.array(main_color)*main_factor*np.clip(np.dot(n,main_position),0,1)
    for p,c,a,sd in additional:
        delta=np.array(p[:3])-np.array(position)*p[3];d2=max(np.dot(delta,delta),.0000610351562);direction=delta/np.sqrt(d2)
        spot=np.clip(np.dot(sd[:3],direction)*a[2]+a[3],0,1)
        light+=np.array(c[:3])/(1+25*d2*a[0])*spot*spot*np.clip(np.dot(n,direction),0,1)
    t=np.array(texel)*np.array(tint)
    return np.r_[t[:3]*(light+illum),t[3]]

def premultiply(texel,vertex_rgba,soft_fade=1):
    c=np.array(vertex_rgba);c[3]*=soft_fade
    return np.array(texel)*c*c[3]

def output_merger(source,dest,blend='opaque',unorm=True):
    s=np.array(source);d=np.array(dest)
    if unorm:s=np.clip(s,0,1)
    if blend=='opaque':out=s
    elif blend=='alpha':out=s*s[3]+d*(1-s[3])
    elif blend=='additive':out=s*s[3]+d
    elif blend=='legacy_rgb_only':out=np.r_[s[:3]+d[:3]*(1-s[3]),d[3]]
    else:raise ValueError(blend)
    return np.clip(out,0,1) if unorm else out

def main():
 rng=np.random.default_rng(35035);results=[]
 names=['Custom_Card_UnlitDesat','Hero_Particle_Particles_Transparent','Hero_Additive_Additive','Hero_Unlit_Unlit_TransparentColor']
 for name in names:
  md=json.load(open(R/name/'metadata.json'));p=md['subshaders'][0]['m_Passes'][0];err=0;uv_err=0
  for i in range(4096):
   c=rng.uniform(-.2,1.5,4);tint=rng.uniform(-.2,1.5,4);uv=rng.uniform(-3,3,2);st=rng.uniform(-2,2,4);sh=rng.uniform(-3,3,3);light=rng.uniform(-.3,1.8,4);blend=rng.uniform(-.25,1.25);vr=rng.uniform(0,5);transition=rng.uniform(-.25,1.25);intensity=rng.uniform(0,2);alpha=rng.uniform(0,2)
   if i%16==0:sh[:]=0
   if i%16==1:blend=0
   if i%16==2:blend=1
   if i%16==3:transition=0
   if i%16==4:transition=1
   particle_tint=rng.uniform(-.3,1.7,4)
   values={'_Color':tint,'_TintColor':particle_tint,'_MainTex_ST':st,'_GlobalMipBias':[0,0],'_LightingBlend':blend,'unity_SHAr':[0,0,0,sh[0]],'unity_SHAg':[0,0,0,sh[1]],'unity_SHAb':[0,0,0,sh[2]],'_MainLightColor':light,'_ValueRange':vr,'_Transistion':transition,'_Intensity':intensity,'_Alpha':alpha}
   with np.errstate(divide='ignore',invalid='ignore'):
    av=run(R/name/'blob1.asm.txt',{**constants(p,'progVertex',values),'v0':rng.random(4),'v1':np.r_[uv,0,0],'v2':c})
   actual=run(R/name/'blob3.asm.txt',{**constants(p,'progFragment',values),**{k.replace('o','v',1):v for k,v in av.items() if k.startswith('o')}})['o0']
   u=uv*st[:2]+st[2:];t=sample(0,u)
   if name=='Custom_Card_UnlitDesat':expected=unlit_desat(t,c,tint,vr,transition,sh,light,blend)
   elif name=='Hero_Particle_Particles_Transparent':expected=t*2*c*particle_tint*np.r_[1+(gamma(sh)-1)*blend,1]*[intensity,intensity,intensity,alpha]
   elif name=='Hero_Additive_Additive':expected=t*2*c*particle_tint*np.r_[1+(gamma(sh)+light[:3]-1)*blend,1]
   else:expected=t*c*tint*np.r_[1+(gamma(sh)+light[:3]-1)*blend,1]
   err=max(err,float(np.max(abs(actual-expected))));uv_err=max(uv_err,float(np.max(abs(av['o1'][:2]-u))));assert np.allclose(actual,expected,atol=1e-12,rtol=1e-11),(name,i,actual,expected)
  results.append({'shader':name,'cases':4096,'max_fragment_error':err,'max_uv_error':uv_err,'programs':['blob1','blob3'],'passed':True})
 name='Custom_Card_SelfIlluminDiffuse';err=0
 for i in range(4096):
  uv=rng.uniform(-2,2,2);position=rng.uniform(-2,2,3);normal=rng.uniform(-1,1,3);sh=rng.uniform(-2,2,3);mainpos=rng.uniform(-1,1,3);main=rng.uniform(0,2,3);factor=rng.random();count=i%9;tint=rng.uniform(-.2,1.5,4);illum=rng.uniform(0,2)
  regs={'v1':np.r_[uv,0,0],'v2':np.r_[position,0],'v3':np.r_[normal,0],'cb0[4]':np.zeros(4),'cb0[5]':np.r_[mainpos,0],'cb0[6]':np.r_[main,1],'cb0[10]':np.r_[count,0,0,0],'cb2[11]':np.array([0,count,factor,0]),'cb2[12]':np.array([0,1,2,3]),'cb2[13]':np.array([4,5,6,7]),'cb2[27]':np.r_[0,0,0,sh[0]],'cb2[28]':np.r_[0,0,0,sh[1]],'cb2[29]':np.r_[0,0,0,sh[2]],'cb3[0]':np.r_[illum,0,0,0],'cb3[1]':tint};additional=[]
  for j in range(count):
   pos=np.r_[rng.uniform(-3,3,3),float(j%2)];clr=rng.random(4);att=rng.uniform(.01,1,4);spot=rng.uniform(-1,1,4);additional.append((pos,clr,att,spot))
   for off,value in [(0,pos),(256,clr),(512,att),(768,spot)]:regs[f'cb1[{off+j}]']=value
  actual=run(R/name/'blob15.asm.txt',regs)['o0'];expected=self_illumin_diffuse(sample(0,uv),tint,illum,sh,normal,position,mainpos,main,factor,additional)
  err=max(err,float(np.max(abs(actual-expected))));assert np.allclose(actual,expected,atol=1e-12,rtol=1e-11),(name,i,actual,expected)
 results.append({'shader':name,'cases':4096,'max_fragment_error':err,'programs':['blob15'],'variant':'_ADDITIONAL_LIGHTS (unshadowed), 0..8 lights','passed':True})
 name='Legacy Shaders_Particles_Alpha Blended Premultiply';err=0
 for i in range(4096):
  uv=rng.uniform(-2,2,2);c=rng.uniform(-.2,1.4,4);actual=run(R/name/'blob6.asm.txt',{'v1':c,'v2':np.r_[uv,0,0]})['o0'];expected=premultiply(sample(0,uv),c)
  err=max(err,float(np.max(abs(actual-expected))));assert np.allclose(actual,expected,atol=1e-12,rtol=1e-11)
 results.append({'shader':name,'cases':4096,'max_fragment_error':err,'programs':['blob6'],'variant':'SOFTPARTICLES_OFF','passed':True})
 for row in results:
  row['source_sha256']={p:hashlib.sha256((R/row['shader']/(p+'.dxbc')).read_bytes()).hexdigest() for p in row['programs']}
 # Independent state assertions, including serialized material-driven blend factors.
 expected_states={names[0]:(1,0,1,2,15),names[1]:(5,10,0,0,15),names[2]:(5,1,0,0,15),names[3]:(5,10,0,2,15),'Custom_Card_SelfIlluminDiffuse':(1,0,1,2,15),name:(1,10,0,0,14)}
 for n,(sb,db,z,c,mask) in expected_states.items():
  st=json.load(open(R/n/'metadata.json'))['subshaders'][0]['m_Passes'][0]['m_State'];b=st['rtBlend0']
  for k,x in [('srcBlend',sb),('destBlend',db),('srcBlendAlpha',sb),('destBlendAlpha',db),('colMask',mask)]:
   assert (b[k]['val']==x or (n==names[1] and b[k]['name'].startswith('_'))),(n,k)
  assert st['zWrite']['val']==z and st['culling']['val']==c and st['zTest']['val']==4
 assert np.allclose(output_merger([.8,.3,.1,.25],[.2,.4,.6,.8],'alpha'),[.35,.375,.475,.6625])
 assert np.allclose(output_merger([.2,.1,.05,.25],[.2,.4,.6,.8],'legacy_rgb_only'),[.35,.4,.5,.8])
 report={'build':'37.0.0.255130.254477','total_cases':sum(x['cases'] for x in results),'results':results,'pass_state_assertions':6,'passed':True,'scope':'High-level scalar equations vs independently decoded source DXBC interpreter with analytic texture samples. Does not validate actual rasterization, GPU, texture filtering/mips, original live globals, shadow variants, soft-particle scene-depth binding, original-client pixels, or 8-bit quantization.'}
 (R/'formula_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
