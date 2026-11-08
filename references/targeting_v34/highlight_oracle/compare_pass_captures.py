"""Read 10 pass PNGs and audit numeric R8 outputs against source-DXBC-derived oracle.
Usage: python compare_pass_captures.py CAPTURE_DIRECTORY [--out OWN_OUTPUT.json]
Input names: dark grey blend1 light1 blend2 light2 blend3 blur clip silhouette .png.
Reads red bytes, no color management. Does not prove triangle raster source identity.
"""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
from PIL import Image
from verify_highlight_formulas import scalar_pass,sample_bilinear,quantize_r8,SIGNS
R=Path(__file__).parent
PASSES=[('blend1','HighlightMultiSampleBlend','dark','grey',-1.25),('blend2','HighlightMultiSampleBlend','blend1','light1',-1.25),('blend3','HighlightMultiSampleBlend','blend2','light2',-1.),('blur','HighlightMultiSample','blend3',None,-1.5),('silhouette','HighlightMaskBlend','blur','clip',-.800000011920929)]
ALL=['dark','grey','blend1','light1','blend2','light2','blend3','blur','clip','silhouette']
def godot_cpu_pass(kind,main,blend,shape,blur):
    # Independent compatibility precision model, NOT D3D hardware arithmetic.
    main=np.asarray(main,dtype=np.float32).astype(float)
    blend=np.asarray(blend,dtype=np.float32).astype(float) if blend is not None else None
    h,w=shape;y,x=np.mgrid[0:h,0:w]
    uv=np.stack(((x+.5)/w,(y+.5)/h),-1).astype(np.float32)
    off=np.array([blur/main.shape[1],blur/main.shape[0]],dtype=np.float32)
    coords=[(uv+s.astype(np.float32)*off).astype(np.float32).astype(float) for s in SIGNS]
    ts=[sample_bilinear(main,u) for u in coords];sm=((ts[0]+ts[1])+ts[2])+ts[3]
    if kind=='HighlightMultiSampleBlend':out=np.maximum(sm*.25,sample_bilinear(blend,uv.astype(float)))
    elif kind=='HighlightMaskBlend':
        bs=[sample_bilinear(blend,u) for u in coords];sb=((bs[0]+bs[1])+bs[2])+bs[3]
        out=.30000001192092896*(sm-sb)
    else:out=sm*.25
    return quantize_r8(out)

def compare(folder):
    images={};files={}
    for label in ALL:
        f=folder/(label+'.png')
        if not f.exists():f=folder/('%02d_'%(ALL.index(label)+1)+label+'.png')
        im=np.asarray(Image.open(f).convert('RGBA'))
        images[label]=im[:,:,0].astype(float)/255.;files[label]={'file':str(f),'shape':list(im.shape[:2]),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'nonzero_red_pixels':int(np.count_nonzero(im[:,:,0])),'edge_nonzero_red_pixels':int(np.count_nonzero(np.r_[im[0,:,0],im[-1,:,0],im[:,0,0],im[:,-1,0]]))}
    variants=[]
    for wrap in ['clamp','repeat']:
      for bits in [None,8]:
        rows=[]
        for label,kind,m,b,blur in PASSES:
            expected=scalar_pass(kind,images[m],images[b] if b else None,images[label].shape,blur,wrap,bits)
            diff=np.abs(np.rint(expected*255).astype(int)-np.rint(images[label]*255).astype(int))
            rows.append({'pass':label,'max_byte_error':int(diff.max()),'mean_byte_error':float(diff.mean()),'different_pixels':int(np.count_nonzero(diff)),'pixels_over_one_byte':int(np.count_nonzero(diff>1)),'canonical_exact':bool(not diff.any()),'within_one_byte':bool(np.all(diff<=1))})
        variants.append({'wrap':wrap,'sample_fraction_bits':bits,'passes':rows,'all_canonical_exact':all(x['canonical_exact'] for x in rows),'all_within_one_byte':all(x['within_one_byte'] for x in rows)})
    cpu_precision=[]
    for label,kind,m,b,blur in PASSES:
        expected=godot_cpu_pass(kind,images[m],images[b] if b else None,images[label].shape,blur)
        diff=np.abs(np.rint(expected*255).astype(int)-np.rint(images[label]*255).astype(int))
        cpu_precision.append({'pass':label,'max_byte_error':int(diff.max()),'different_pixels':int(np.count_nonzero(diff)),'canonical_exact':bool(not diff.any())})
    replacement=[]
    for label,level in [('dark',64),('grey',128),('light1',191),('light2',191),('clip',255)]:
        vals=np.unique(np.rint(images[label]*255).astype(int)).tolist();unexpected=[x for x in vals if x not in [0,level]];replacement.append({'pass':label,'unique_red_codes':vals,'canonical_foreground_code':level,'only_clear_and_expected':not unexpected})
    return {'input':str(folder),'files':files,'replacement_values':replacement,'variants':variants,'godot_cpu_precision':cpu_precision,'godot_cpu_precision_all_exact':all(x['canonical_exact'] for x in cpu_precision),'scope':'Observed scalar postprocess pass outputs compared against source-DXBC equations with independent canonical R8 sampler. Geometry masks supplied by implementation; triangle coverage, live visibility, original client capture and native Unity wrap defaults are not validated. One-byte diagnostic threshold is not a complete accumulated hardware error budget.'}
def main():
    ap=argparse.ArgumentParser();ap.add_argument('folder',type=Path);ap.add_argument('--out',type=Path);a=ap.parse_args();report=compare(a.folder);out=a.out or R/('capture_'+a.folder.name+'.json');out.write_text(json.dumps(report,indent=2)+'\n');print(out);print(json.dumps([{'wrap':v['wrap'],'sample_fraction_bits':v['sample_fraction_bits'],'all_canonical_exact':v['all_canonical_exact'],'all_within_one_byte':v['all_within_one_byte'],'passes':v['passes']} for v in report['variants']],indent=2))
if __name__=='__main__':main()
