"""Independent Mesa25.0.7 8.8-unorm sampler model, no renderer launch.
Engine-source-based compatibility diagnostic, not original D3D GPU equality.
"""
from pathlib import Path
import argparse,json
import numpy as np
from PIL import Image
from compare_gpu_pass_captures import FORMULAS,summary
from verify_highlight_formulas import SIGNS
F=np.float32

def mesa_target(x):
    # lp_build_clamped_float_to_unsigned_norm, float32->unorm8, mantissa23.
    v=F(F(np.clip(x,0,1))*F(255/256))
    v=F(v+F(32768.0))
    return (v.view(np.uint32)&255).astype(float)/255

def mesa_sample(image,uv):
    image=np.rint(np.asarray(image)*255).astype(np.int32)
    h,w=image.shape
    # lp_build_sample_image_linear: round-nearest coordinate*size*256, then-.5.
    pos=np.rint(F(F(uv)*F([w*256,h*256]))).astype(np.int32)-128
    ij=pos>>8;weight=pos&255
    def at(dx,dy):return image[np.clip(ij[...,1]+dy,0,h-1),np.clip(ij[...,0]+dx,0,w-1)]
    # lp_build_lerp_simple SSSE3/AVX2 pmulhrsw path rounds each dimension.
    def lerp(a,b,t):return a+((t*(b-a)+128)>>8)
    a=lerp(at(0,0),at(1,0),weight[...,0]);b=lerp(at(0,1),at(1,1),weight[...,0])
    out=lerp(a,b,weight[...,1])
    # lp_build_unsigned_norm_to_float multiplies by float32 reciprocal255.
    return F(F(out)*F(1/255))

def model_pass(kind,main,blend,shape,offset,uv_mode='divide',fma=False,sum_order='left'):
    h,w=shape;y,x=np.mgrid[:h,:w]
    if uv_mode=='divide':uv=F(np.stack(((x+.5)/w,(y+.5)/h),-1))
    else:uv=F(F(np.stack((x+.5,y+.5),-1))*F([1/w,1/h]))
    off=F(F([1/main.shape[1],1/main.shape[0]])*F(offset))
    coords=[F(uv+F(s)*off) for s in SIGNS]
    def sum4(t):
        balanced = sum_order=='balanced' or (sum_order=='mask_balanced' and kind.endswith('MaskBlend'))
        return F(F(t[0]+t[1])+F(t[2]+t[3])) if balanced else F(F(F(t[0]+t[1])+t[2])+t[3])
    t=[mesa_sample(main,c) for c in coords];sm=sum4(t)
    if kind.endswith('MultiSampleBlend'):out=np.maximum(F(sm*F(.25)),mesa_sample(blend,uv))
    elif kind.endswith('MaskBlend'):
        t=[mesa_sample(blend,c) for c in coords];sb=sum4(t);scaled=F(sb*F(.3))
        out=F(sm.astype(float)*float(F(.3))-scaled.astype(float)) if fma else F(F(sm*F(.3))-scaled)
    else:out=F(sm*F(.25))
    return mesa_target(out)

def run(folder):
    ims={f.stem[3:]:np.asarray(Image.open(f).convert('RGBA'))[:,:,0]/255 for f in folder.glob('*.png') if f.stem[3:] in {'dark','grey','blend1','light1','blend2','light2','blend3','blur','clip','silhouette'}}
    variants=[]
    for uv_mode in ['divide','multiply_reciprocal']:
      for fma in [False,True]:
       for sum_order in ['left','balanced','mask_balanced']:
        passes=[]
        for name,(kind,m,b,offset) in FORMULAS.items():
            expected=model_pass(kind,ims[m],ims[b] if b else None,ims[name].shape,offset,uv_mode,fma,sum_order)
            passes.append({'pass':name,**summary(expected,ims[name])})
        variants.append({'uv_mode':uv_mode,'mask_fma':fma,'sum_order':sum_order,'passes':passes,'all_exact':all(p['canonical_exact'] for p in passes),'all_within_one_byte':all(p['within_one_byte_diagnostic'] for p in passes)})
    return {'folder':str(folder),'backend_model':'Mesa25.0.7 llvmpipe 8.8 coordinates + rounded unorm8 lerp each axis + float32 shaders + Mesa target conversion','variants':variants,'interpretation':'Balanced sums model compiler reassociation as an inference tested against captures; generated shader IR was not captured. Backend-exact equality is distinct from original source-DXBC instruction/precision identity.','scope':'Source-based backend diagnostic for actual captured outputs, not proof of exact LLVM generated code or source Unity/D3D raster.'}

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('folder',type=Path);ap.add_argument('--out',type=Path,required=True);a=ap.parse_args();r=run(a.folder);a.out.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
