from pathlib import Path
from urllib.request import Request,urlopen
import hashlib,json,struct,zlib,datetime
R=Path(__file__).parent;BASE='https://us.cdn.blizzard.com/tpr/hs';BUILD='37.0.0.255130.254477'
def must(ok,msg):
 if not ok:raise ValueError(msg)
def blte(b,ek,ck,size):
 must(b[:4]==b'BLTE','magic');hs=int.from_bytes(b[4:8],'big');must(hs==0 or 12<=hs<=len(b),'header bounds');must(hashlib.md5(b[:hs] if hs else b).hexdigest()==ek,'encoding hash')
 chunks=[];off=hs;modes=[]
 if hs:
  n=int.from_bytes(b[9:12],'big');must(b[8]==15 and hs==12+24*n,'table')
  for i in range(n):
   enc,dec,h=struct.unpack_from('>II16s',b,12+24*i);c=b[off:off+enc];off+=enc;must(len(c)==enc and hashlib.md5(c).digest()==h,'chunk hash');chunks.append((c,dec))
  must(off==len(b),'trailing bytes')
 else:chunks=[(b[8:],size)]
 out=[]
 for c,dec in chunks:
  must(0<dec<=size,'decoded chunk bound');mode=c[:1];must(mode in (b'N',b'Z'),'unsupported or encrypted mode')
  if mode==b'N':raw=c[1:]
  else:
   z=zlib.decompressobj();raw=z.decompress(c[1:],dec+1);must(z.eof and not z.unused_data and not z.unconsumed_tail,'zlib end/bounds')
  must(len(raw)==dec,'decoded chunk size');out.append(raw);modes.append(mode.decode())
 raw=b''.join(out);must(len(raw)==size and hashlib.md5(raw).hexdigest()==ck,'content size/hash');return raw,sorted(set(modes))
def get_manifest(name,ek,ck,enc,size):
 p=R/f'{name}.bin';u=f'{BASE}/data/{ek[:2]}/{ek[2:4]}/{ek}'
 if p.exists():
  b=p.read_bytes();must(len(b)==size and hashlib.md5(b).hexdigest()==ck,'existing source changed');return b
 with urlopen(Request(u,headers={'User-Agent':'SelectedOfficialAssetInspector/1.0','Accept-Encoding':'identity'}),timeout=60) as res:
  must(res.status==200 and res.geturl()==u,'HTTP status/destination');wire=res.read(enc+1);must(len(wire)==enc,'wire size')
 raw,modes=blte(wire,ek,ck,size);p.write_bytes(raw)
 prov={'url':u,'encoding_key':ek,'content_key':ck,'encoded_bytes':enc,'decoded_bytes':size,'sha256':hashlib.sha256(raw).hexdigest(),'modes':modes,'verified_content_encoding_and_chunk_md5':True,'build':BUILD,'checked_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()};(R/f'{name}.provenance.json').write_text(json.dumps(prov,indent=2)+'\n');print(name,'verified',flush=True);return raw
install=get_manifest('install','9672ba24e5115eceba9afa8b0e1af6b5','c1734f5819fa5fa25ff2a2195c818b0b',3692602,4174116)
encoding=get_manifest('encoding','c4e07adea53689c6ea209ff868cb9d71','07583f35a65941ab99e4efe53c15c35a',2964247,2964085)
b=install;must(b[:2]==b'IN','install');v,hs,tc,n=struct.unpack_from('>BBHI',b,2);must((v,hs)==(1,16),'install schema');p=10;tags=[]
def string(b,p):
 end=b.index(0,p);return b[p:end].decode(),end+1
for i in range(tc):
 name,p=string(b,p);kind=int.from_bytes(b[p:p+2],'big');p+=2;mask=b[p:p+(n+7)//8];p+=(n+7)//8;tags.append((name,mask))
wanted={'Data/Win/initial_base_global-8411aad9-texture-3.unity3d':None};rows=[]
for i in range(n):
 name,p=string(b,p);key=b[p:p+hs].hex();p+=hs;size=int.from_bytes(b[p:p+4],'big');p+=4
 if name in wanted:
  t=[name for name,mask in tags if mask[i//8]&(1<<(7-i%8))];must(all(x in t for x in ['Windows','enUS','Production']),'platform/locale/stage');rows.append({'filename':name,'content_key':key,'decoded_bytes':size,'install_entry_index':i,'tags':t})
must(p==len(b) and len(rows)==len(wanted),'install exact matches');b=encoding;must(b[:3]==b'EN\1','encoding');cs,es,cps,eps,cn,en,unk,spec=struct.unpack_from('>BBHHIIBI',b,3);must(cs==es==16,'key sizes');p=22+spec;index=[(b[p+i*32:p+i*32+16],b[p+i*32+16:p+i*32+32]) for i in range(cn)];start=p+cn*32
for row in rows:
 key=bytes.fromhex(row['content_key']);pi=max(i for i,(first,h) in enumerate(index) if first<=key);page=b[start+pi*cps*1024:start+(pi+1)*cps*1024];must(hashlib.md5(page).digest()==index[pi][1],'page hash');p=0
 while p+38<=len(page):
  count=page[p]
  if count==0:break
  size=int.from_bytes(page[p+1:p+6],'big');ck=page[p+6:p+22];p+=22;must(p+count*16<=len(page),'page record bound');eks=[page[p+j*16:p+(j+1)*16].hex() for j in range(count)];p+=count*16
  if ck==key:
   must(size==row['decoded_bytes'],'encoding size differs');row.update(encoding_keys=eks,encoding_page=pi,encoding_page_md5_verified=True);break
 must('encoding_keys' in row,'encoding entry absent')
 for ek in row['encoding_keys']:row.setdefault('official_loose_urls',[]).append(f'{BASE}/data/{ek[:2]}/{ek[2:4]}/{ek}')
report={'build':BUILD,'build_config_key':'adaa96c427202039f22cc717564bdc97','cdn_config_key':'ff9025d0103bd77a12912ccb15b40178','rows':rows,'network_scope':'Only immutable previously successful install/encoding objects; no archive index requested.'};(R/'coin_bundle_inventory.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)

