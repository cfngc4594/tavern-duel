"""Source-instruction oracle for the 3 highlight scalar passes and 5 replacements.
No original client/GPU execution. The CPU R8 resampler is a canonical reference,
not a claim that Unity native defaults, GPU raster or tolerance are all recovered.
"""
from pathlib import Path
import json,sys,hashlib
import numpy as np
R=Path(__file__).parent; S=R.parent
sys.path.insert(0,str(R.parents[2]/'v32_work/source_assets/shader_analysis'))
from remaining_formula_interpreter import run,constants,sample
NAMES=['Custom_Selection_HighlightMultiSample','Custom_Selection_HighlightMultiSampleBlend','Custom_Selection_HighlightMaskBlend']
SIGNS=np.array([[1,1],[-1,-1],[1,-1],[-1,1]],float)

def pixel_formula(kind,main_samples,blend_center=0.,blend_samples=(0,0,0,0)):
    # Four taps in the source instruction order, not center+4 taps.
    sm=((main_samples[0]+main_samples[1])+main_samples[2])+main_samples[3]
    if kind.endswith('HighlightMultiSample'):return sm*.25
    if kind.endswith('HighlightMultiSampleBlend'):return max(sm*.25,blend_center)
    if kind.endswith('HighlightMaskBlend'):
        sb=((blend_samples[0]+blend_samples[1])+blend_samples[2])+blend_samples[3]
        return max(0.,min(1.,sm*0.300000012-sb*0.300000012))
    raise ValueError(kind)

def quantize_r8(x):
    """Canonical D3D FLOAT->UNORM8 reference; actual D3D permits 0.6 integer ULP."""
    return np.floor(np.clip(np.nan_to_num(x,nan=0),0,1)*255.+.5)/255.

def sample_bilinear(image,uv,wrap='clamp',fraction_bits=None):
    """Sample scalar red. uv may be (...,2). No sRGB conversion. Texel centers +.5."""
    image=np.asarray(image,dtype=float);uv=np.asarray(uv,dtype=float);h,w=image.shape
    xy=uv*np.array([w,h])-.5;ij=np.floor(xy).astype(int);f=xy-ij
    if fraction_bits is not None:
        # Canonical nearest fixed-fraction coordinate model, hardware tolerance separate.
        n=2**fraction_bits;f=np.floor(f*n+.5)/n
    def at(dx,dy):
        x=ij[...,0]+dx;y=ij[...,1]+dy
        if wrap=='repeat':x%=w;y%=h
        elif wrap=='clamp':x=np.clip(x,0,w-1);y=np.clip(y,0,h-1)
        else:raise ValueError(wrap)
        return image[y,x]
    a=at(0,0)*(1-f[...,0])+at(1,0)*f[...,0]
    b=at(0,1)*(1-f[...,0])+at(1,1)*f[...,0]
    return a*(1-f[...,1])+b*f[...,1]

def scalar_pass(kind,main,blend=None,output_shape=None,blur=-1.25,wrap='clamp',fraction_bits=None,quantize=True):
    main=np.asarray(main,dtype=float);h,w=output_shape or main.shape;y,x=np.mgrid[0:h,0:w];uv=np.stack(((x+.5)/w,(y+.5)/h),axis=-1)
    offset=np.array([blur/main.shape[1],blur/main.shape[0]])
    taps=[sample_bilinear(main,uv+s*offset,wrap,fraction_bits) for s in SIGNS]
    sm=((taps[0]+taps[1])+taps[2])+taps[3]
    if kind.endswith('HighlightMultiSample'):out=sm*.25
    elif kind.endswith('HighlightMultiSampleBlend'):out=np.maximum(sm*.25,sample_bilinear(blend,uv,wrap,fraction_bits))
    elif kind.endswith('HighlightMaskBlend'):
        # IMPORTANT: same MAIN-normalized UV offsets even when blend has a different size.
        bt=[sample_bilinear(blend,uv+s*offset,wrap,fraction_bits) for s in SIGNS]
        sb=((bt[0]+bt[1])+bt[2])+bt[3];out=np.clip(sm*0.300000012-sb*0.300000012,0,1)
    else:raise ValueError(kind)
    return quantize_r8(out) if quantize else out

def main():
    rng=np.random.default_rng(341234);results=[]
    for name in NAMES:
        md=json.loads((S/name/'metadata.json').read_text());p=md['subshaders'][0]['m_Passes'][0];maxerr=0;uv_err=0
        for i in range(2048):
            uv=rng.uniform(-.2,1.2,2);texel=rng.uniform(.0005,.1,2);offset=rng.uniform(-3,3,2)
            vals={'_MainTex_TexelSize':[*texel,1/texel[0],1/texel[1]],'_BlurOffsets':[*offset,0,0],'_GlobalMipBias':[0,0]}
            v=run(S/name/'blob1.asm.txt',{**constants(p,'progVertex',vals),'v0':np.array([.2,.3,.4,1]),'v1':np.r_[uv,0,0]})
            coords=uv+SIGNS*texel*offset
            for j,co in enumerate(coords):uv_err=max(uv_err,float(np.max(abs(v[f'o{j+2}'][:2]-co))))
            actual=run(S/name/'blob3.asm.txt',{**constants(p,'progFragment',vals),**{k.replace('o','v',1):x for k,x in v.items() if k.startswith('o')}})['o0']
            expected=pixel_formula(name,[sample(0,u)[0] for u in coords],sample(1,uv)[0],[sample(1,u)[0] for u in coords])
            maxerr=max(maxerr,float(np.max(abs(actual-expected))));assert np.allclose(actual,expected,atol=1e-12,rtol=1e-11)
        st=p['m_State'];assert [st[k]['val'] for k in ['zTest','zWrite','culling','zClip']]==[8,0,0,1];assert [st['rtBlend0'][k]['val'] for k in ['srcBlend','destBlend','srcBlendAlpha','destBlendAlpha','colMask']]==[1,0,1,0,15]
        results.append({'shader':name,'cases':2048,'max_shader_error':maxerr,'max_uv_error':uv_err,'state_verified':True,'passed':True})
    replacement={}
    for color,v in [('White',1),('LightGrey',.75),('Grey',.5),('DarkGrey',.25),('BlackOverlay',0)]:
        name='Custom_Unlit_Color_'+color;d=json.loads((S/name/'metadata.json').read_text());p=d['subshaders'][0]['m_Passes'][0];out=run(S/name/'blob3.asm.txt',{})['o0'];assert np.array_equal(out,[v,v,v,1]);st=p['m_State'];assert [st[k]['val'] for k in ['zTest','zWrite','culling','zClip']]==[8,0,0,1]
        replacement[color]={'source_rgba':list(out),'canonical_r8_code':int(round(float(quantize_r8(v))*255)),'state':'One/Zero RGBA, Always depth test, no depth write, no culling, ZClip on'}
    # Cross-check the vectorized image oracle against DXBC, including differing image sizes.
    image_cases=0;image_err=0
    for wrap in ['clamp','repeat']:
      for bits in [None,8]:
       for name in NAMES:
        p=json.loads((S/name/'metadata.json').read_text())['subshaders'][0]['m_Passes'][0]
        a=rng.integers(0,256,(9,13))/255.;b=rng.integers(0,256,(7,11))/255.;shape=(10,15);blur=-.800000011920929
        out=scalar_pass(name,a,b,shape,blur,wrap,bits);h,w=shape
        def sampler(slot,uv):return np.full(4,sample_bilinear(a if slot==0 else b,uv[:2],wrap,bits))
        vals={'_GlobalMipBias':[0,0]};c=constants(p,'progFragment',vals)
        for y in range(h):
         for x in range(w):
          uv=np.array([(x+.5)/w,(y+.5)/h]);coords=uv+SIGNS*[blur/a.shape[1],blur/a.shape[0]];regs={**c,'v1':np.r_[uv,0,0],**{f'v{j+2}':np.r_[p,0,0] for j,p in enumerate(coords)}}
          actual=float(quantize_r8(run(S/name/'blob3.asm.txt',regs,sampler=sampler)['o0'][0]));e=abs(actual-out[y,x]);image_err=max(image_err,e);image_cases+=1;assert e<1e-12
    report={'build':'37.0.0.255130.254477','shader_formula_cases':sum(x['cases'] for x in results),'results':results,'replacement_outputs':replacement,'image_oracle_instruction_cases':image_cases,'max_image_oracle_error':image_err,'passed':True,'scope':'Scalar source instructions and canonical R8 image pass functions; no GPU, triangle coverage, MSAA, client pixels or native default wrap verified. Both clamp/repeat and ideal/fixed8 bilinear options tested.','r8_quantization':'floor(clamp(x,0,1)*255+0.5)/255 at EACH pass target. D3D FLOAT->UNORM allows 0.6 integer ULP; canonical values are reference, not source GPU bit identity.','quantization_source':'https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm#FLOATtoUNORM','native_wrap_boundary':'HighlightRender and RenderTextureTracker set no wrap mode. Native Unity defaults have not been recovered. Compare both oracle modes; if borders stay black the output can be mode-independent.'}
    (R/'formula_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
