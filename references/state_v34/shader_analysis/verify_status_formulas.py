"""Independent scalar equations against recovered source SM4 instructions.
This is arithmetic/binding/state QA, NOT a GPU, rasterizer, or client-pixel claim.
The public functions accept an already sampled texel so renderer QA can reuse them.
"""
from pathlib import Path
import json, sys, hashlib, math
import numpy as np
R=Path(__file__).parent
sys.path.insert(0,str(R.parents[2]/'v32_work/source_assets/shader_analysis'))
from remaining_formula_interpreter import run, sample, constants
SHADERS=('Custom_Card_UnlitTextureTint','Hero_Unlit_Transparent')

def lighting_scalar(sh_w, main_light):
    # Use the exact float32 constants encoded by the source instructions.
    return [min(1.0,max(0.0,1.05499995*abs(float(s))**0.416666657-0.0549999997))+float(l) for s,l in zip(sh_w,main_light)]

def source_vertex_color(shader, vertex_rgba, sh_w, main_light, blend, tint=(1,1,1,1)):
    lit=lighting_scalar(sh_w,main_light)+[1.0]
    if shader=='Custom_Card_UnlitTextureTint':
        return [(float(v)+(l-float(v))*float(blend))*float(c) for v,l,c in zip(vertex_rgba,lit,tint)]
    if shader=='Hero_Unlit_Transparent':
        return [float(v)*(1.0+(l-1.0)*float(blend)) for v,l in zip(vertex_rgba,lit)]
    raise ValueError(shader)

def source_fragment(texel_rgba, interpolated_rgba):
    return [float(t)*float(c) for t,c in zip(texel_rgba,interpolated_rgba)]

def source_output_merger(shader, source_rgba, dest_rgba, unorm=True):
    # The recovered shaders target normalized default/RTT buffers in existing evidence.
    # No quantization simulated; integer-bit precision belongs to separate GPU tests.
    s=[min(1,max(0,x)) if unorm else float(x) for x in source_rgba]
    d=list(dest_rgba)
    if shader=='Custom_Card_UnlitTextureTint':return s
    if shader=='Hero_Unlit_Transparent':return [x*s[3]+y*(1-s[3]) for x,y in zip(s,d)]
    raise ValueError(shader)

def main():
    rng=np.random.default_rng(340340); results=[]
    for shader in SHADERS:
        md=json.loads((R/shader/'metadata.json').read_text()); p=md['subshaders'][0]['m_Passes'][0]
        error=0.0; verr=0.0; uerr=0.0
        for i in range(4096):
            v=rng.uniform(-.3,1.7,4);tint=rng.uniform(-.2,1.5,4);uv=rng.uniform(-2,2,2);st=rng.uniform(-2,2,4)
            sh=rng.uniform(-3,3,3);light=rng.uniform(-.3,1.8,3);blend=float(rng.uniform(-.25,1.25))
            if i%16==0:sh[:]=0
            if i%16==1:blend=0
            if i%16==2:blend=1
            if i%16==3:v[3]=0
            if i%16==4:v[:]=1
            vals={'_Color':tint,'_MainTex_ST':st,'_GlobalMipBias':[0,0],'_LightingBlend':blend,'unity_SHAr':[0,0,0,sh[0]],'unity_SHAg':[0,0,0,sh[1]],'unity_SHAb':[0,0,0,sh[2]],'_MainLightColor':np.r_[light,1]}
            vin={'v0':np.r_[rng.uniform(-2,2,3),1],'v1':np.r_[uv,0,0],'v2':v}
            with np.errstate(divide='ignore',invalid='ignore'):
                av=run(R/shader/'blob1.asm.txt',{**constants(p,'progVertex',vals),**vin})
            actual=run(R/shader/'blob3.asm.txt',{**constants(p,'progFragment',vals),**{k.replace('o','v',1):x for k,x in av.items() if k.startswith('o')}})['o0']
            expected_v=source_vertex_color(shader,v,sh,light,blend,tint)
            expected_uv=[float(uv[j])*float(st[j])+float(st[j+2]) for j in range(2)]
            expected=source_fragment(sample(0,expected_uv),expected_v)
            error=max(error,float(np.max(np.abs(actual-expected))));verr=max(verr,float(np.max(np.abs(av['o2']-expected_v))));uerr=max(uerr,float(np.max(np.abs(av['o1'][:2]-expected_uv))))
            assert np.allclose(actual,expected,rtol=1e-11,atol=1e-12),(shader,i,actual,expected)
            assert np.allclose(av['o2'],expected_v,rtol=1e-11,atol=1e-12)
            assert np.allclose(av['o1'][:2],expected_uv,rtol=1e-11,atol=1e-12)
        state=p['m_State'];rt=state['rtBlend0'];b={k:v['val'] for k,v in rt.items()}
        target={'srcBlend':1,'destBlend':0,'srcBlendAlpha':1,'destBlendAlpha':0,'zWrite':1,'culling':0} if shader==SHADERS[0] else {'srcBlend':5,'destBlend':10,'srcBlendAlpha':5,'destBlendAlpha':10,'zWrite':0,'culling':2}
        for k,x in target.items():assert (b[k] if k in b else state[k]['val'])==x,(shader,k)
        assert state['zTest']['val']==4 and state['zClip']['val']==1 and b['colMask']==15
        # A direct separately evaluated source blend oracle catches alpha-squared errors.
        if shader==SHADERS[1]:
            assert np.allclose(source_output_merger(shader,[.8,.3,.1,.25],[.2,.4,.6,.8]),[.35,.375,.475,.6625])
        results.append({'shader':shader,'path_id':md['path_id'],'cases':4096,'max_vertex_error':verr,'max_uv_error':uerr,'max_fragment_error':error,'serialized_pass_state_verified':True,'passed':True,'source_sha256':{f:hashlib.sha256((R/shader/f).read_bytes()).hexdigest() for f in ['blob1.dxbc','blob3.dxbc']}})
    report={'build':'37.0.0.255130.254477','total_cases':sum(x['cases'] for x in results),'results':results,'scope':'Scalar high-level equations vs independent source SM4 instruction interpreter. Actual material binding names come from source parameter metadata. Includes zero/negative SH, blend0/1/outside range, negative/HDR colors and repeat UV/ST. Not a GPU, blend-quantization, rasterizer, sampled-texture, or client-pixel equivalence test.','runtime_global_boundary':'Exact live unity_SHAr.w, unity_SHAg.w, unity_SHAb.w, _MainLightColor.rgb, and _GlobalMipBias.x not recovered. Portable shaders expose them and retain existing scene compatibility defaults without claiming originals.','passed':True}
    (R/'formula_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':main()
