from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image
from fontTools.ttLib import TTFont
from scipy.ndimage import map_coordinates
p=Path('/workspace/shared/unity_text_roles_results');output={'roles':[]}
for role in ['body','glei_digits','belwe_digits']:
 r=p/role;j=json.load(open(r/'glyphs.json'));gs={g['character']:g for g in j['glyphs']};a=np.array(Image.open(r/'atlas_rgba.png')); f=TTFont(r/'font.ttf');u=f['head'].unitsPerEm;hh=f['hhea'];size=j['requestSize'];line=(hh.ascent-hh.descent+hh.lineGap)/u*size*.1;asc=hh.ascent/u*size*.1
 report={'role':role,'sha_match':hashlib.sha256((r/'font.ttf').read_bytes()).hexdigest()==j['fontSha256'],'glyph_count':len(gs),'atlas_size':[a.shape[1],a.shape[0]],'hhea':{'units':u,'asc':hh.ascent,'desc':hh.descent,'gap':hh.lineGap},'line_height_char1':line,'ascent_char1':asc,'glyph_issues':[],'whitespace':[],'bounds_issues':[],'bounds_max_error':0,'screenshots':[]}
 for g in gs.values():
  if g.get('isWhitespace'):report['whitespace'].append({'char':g['character'],'available':g['available'],'advance':g['advance']});continue
  uv=np.array([[g[k]['x'],g[k]['y']] for k in ['uvBottomLeft','uvBottomRight','uvTopLeft','uvTopRight']]);x0,y0=uv.min(axis=0);x1,y1=uv.max(axis=0);b=[round(x0*a.shape[1]),round((1-y1)*a.shape[0]),round(x1*a.shape[1]),round((1-y0)*a.shape[0])];nz=np.count_nonzero(a[b[1]:b[3],b[0]:b[2],3]);rot=g['uvBottomLeft']['x']==g['uvBottomRight']['x']; dims=(b[2]-b[0],b[3]-b[1]);expected=(g['glyphHeight'],g['glyphWidth']) if rot else (g['glyphWidth'],g['glyphHeight'])
  if not g['available'] or not nz or dims!=expected:report['glyph_issues'].append(g['character'])
 for t in j['texts']:
  lines=t['text'].split('\n');width=max(sum(gs[c]['advance'] for c in ln) for ln in lines)*.1;H=line*(1+(len(lines)-1)*t['lineSpacing']);e=t['rendererLocalBounds']['m_Extent'];err=max(abs(width-e['x']*2),abs(H-e['y']*2));report['bounds_max_error']=max(err,report['bounds_max_error'])
  if err>1e-4:report['bounds_issues'].append({'id':t['id'],'error':err,'expected':[width,H],'actual':[e['x']*2,e['y']*2]})
  if not t.get('screenshot'):continue
  target=np.array(Image.open(r/t['screenshot']))[:,:,3]/255.;ih,iw=target.shape;y,x=np.indices(target.shape);scale=ih/(2*t['cameraOrthographicSize']);wx=(x+.5-iw/2)/scale+t['cameraPosition']['x'];wy=(ih/2-y-.5)/scale+t['cameraPosition']['y'];out=np.zeros_like(wx);atlas=a[:,:,3]/255.
  for li,ln in enumerate(lines):
   pen=-sum(gs[c]['advance'] for c in ln)*.05;by=-asc+H/2-li*line*t['lineSpacing']
   for c in ln:
    g=gs[c]
    if not g['glyphWidth'] or not g['glyphHeight']:pen+=g['advance']*.1;continue
    xx=(wx-pen-g['minX']*.1)/(g['glyphWidth']*.1);yy=(wy-by-g['minY']*.1)/(g['glyphHeight']*.1);mask=(xx>=0)&(xx<=1)&(yy>=0)&(yy<=1);bl=np.array(list(g['uvBottomLeft'].values()));br=np.array(list(g['uvBottomRight'].values()));tl=np.array(list(g['uvTopLeft'].values()));uv=bl[:,None]+(br-bl)[:,None]*xx[mask]+(tl-bl)[:,None]*yy[mask];al=map_coordinates(atlas,[(1-uv[1])*a.shape[0]-.5,uv[0]*a.shape[1]-.5],order=1,mode='nearest');out[mask]=al**2+out[mask]*(1-al);pen+=g['advance']*.1
  moment=lambda z:[float((z*x).sum()/z.sum()),float((z*y).sum()/z.sum())]
  report['screenshots'].append({'id':t['id'],'mse':float(np.mean((out-target)**2)),'mae':float(np.abs(out-target).mean()),'max_error':float(np.abs(out-target).max()),'actual_moment':moment(target),'predicted_moment':moment(out),'baseline_first_char1':-asc+H/2,'per_line_step_char1':line*t['lineSpacing']})
 print(json.dumps(report,ensure_ascii=False),flush=True);output['roles'].append(report)
(p/'independent-qa/validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2))
