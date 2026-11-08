"""Independent source-DXBC background image oracle. Uses actual predecessor PNGs,
not production shader evaluation; each pass is checked separately so quantization
is not conflated with a previous pass's error. Metadata supplied by GUI probe."""
from pathlib import Path
import json,sys,numpy as np
from PIL import Image

def read(p):
 a=np.asarray(Image.open(p).convert('RGBA'),dtype=np.float64)/255
 return a

def bilinear(a,w,h,dx=0,dy=0,repeat=False):
 # GPU normalized pixel-center convention, linear clamp/repeat.
 ih,iw=a.shape[:2];x=(np.arange(w)+.5)*iw/w-.5+dx*iw;y=(np.arange(h)+.5)*ih/h-.5+dy*ih
 x0=np.floor(x).astype(int);y0=np.floor(y).astype(int);fx=x-x0;fy=y-y0
 if repeat:x1=(x0+1)%iw;y1=(y0+1)%ih;x0%=iw;y0%=ih
 else:x1=np.clip(x0+1,0,iw-1);y1=np.clip(y0+1,0,ih-1);x0=np.clip(x0,0,iw-1);y0=np.clip(y0,0,ih-1)
 return (a[y0[:,None],x0[None,:]]*(1-fx)[None,:,None]+a[y0[:,None],x1[None,:]]*fx[None,:,None])*(1-fy)[:,None,None]+(a[y1[:,None],x0[None,:]]*(1-fx)[None,:,None]+a[y1[:,None],x1[None,:]]*fx[None,:,None])*fy[:,None,None]

def check(root,meta):
 rows=[]
 for p in meta['passes']:
  actual=read(root/p['file']);h,w=actual.shape[:2];kind=p['kind'];s=read(root/p['source'])if p.get('source')else None;d=read(root/p['destination'])if p.get('destination')else None
  if kind=='luminance':
   t=bilinear(s,w,h);expected=np.zeros_like(t);expected[:,:,0]=t[:,:,:3]@np.array([.212599993,.715200007,.0722000003])
  elif kind=='desaturation':
   t=bilinear(s,w,h);dst=bilinear(d,w,h);v=p['desaturation'];expected=dst.copy();expected[:,:,:3]=t[:,:,0,None]*(1-v)+dst[:,:,:3]*v
  elif kind=='vignette':
   mask=read(root/meta['mask']);m=bilinear(mask,w,h,repeat=True)[:,:,0,None];dst=bilinear(d,w,h);v=p['amount'];expected=dst.copy();expected[:,:,:3]*=m*v+1-v
  elif kind=='blur':
   ox=(p['offset']+.5)/s.shape[1];oy=(p['offset']+.5)/s.shape[0];expected=sum(bilinear(s,w,h,sx*ox,sy*oy)for sx,sy in [(1,1),(-1,-1),(1,-1),(-1,1)])*(p.get('brightness',1)*.25)
  elif kind=='blend':
   t=bilinear(s,w,h);dst=bilinear(d,w,h);v=p['amount'];expected=dst.copy();expected[:,:,:3]=t[:,:,:3]*v+dst[:,:,:3]*(1-v)
  else:raise ValueError(kind)
  diff=np.abs(actual-np.clip(expected,0,1));row={'kind':kind,'file':p['file'],'max_error_rgba':diff.reshape(-1,4).max(axis=0).tolist(),'mean_error_rgba':diff.reshape(-1,4).mean(axis=0).tolist(),'pixels':w*h,'rgb_within_3_lsb':bool((diff[:,:,:3]<=3/255+1e-9).all())};rows.append(row)
 return {'source':'independent compiled-DXBC equations, per-pass actual predecessor PNGs','results':rows,'passed_rgb':all(r['rgb_within_3_lsb']for r in rows)}
if __name__=='__main__':
 p=Path(sys.argv[1]);r=check(p.parent,json.loads(p.read_text()));(p.parent/'independent-pixel-oracle.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
