"""Read-only SM4/SM5 token decoder. Opcode/operand formats sourced from Microsoft's DirectX-Headers MIT-licensed header beside this file. Unknown formats are kept raw, not guessed."""
import re,struct,pathlib,json
ROOT=pathlib.Path(__file__).parent
header=(ROOT/'D3D12TokenizedProgramFormat.hpp').read_text()
def enum(name):
 txt=re.search(r'typedef enum '+name+r'\s*\{(.*?)\}',header,re.S)[1]
 txt=re.sub(r'//[^\n]*','',txt);d={};i=0
 for line in txt.split(','):
  line=line.strip()
  if not line:continue
  if '='in line:n,v=line.split('=',1);i=int(v.strip(),0)
  else:n=line
  d[i]=n.strip();i+=1
 return d
OPS={i:n.split('_OPCODE_')[-1].lower()for i,n in enum('D3D10_SB_OPCODE_TYPE').items()}
TYPES={0:'r',1:'v',2:'o',3:'x',6:'s',7:'t',8:'cb',9:'icb',10:'label',11:'primid',12:'depth',13:'null'}
def operand(a,p):
 start=p;t=a[p];p+=1;comp=t&3;mode=(t>>2)&3;typ=(t>>12)&255;ndim=(t>>20)&3;mod=0
 if t>>31:
  more=True
  while more:
   ext=a[p];p+=1;more=ext>>31
   if ext&63==1:mod=(ext>>6)&255
 suffix=''
 if comp==2:
  if mode==0:suffix=''.join('xyzw'[j]for j in range(4)if (t>>(4+j))&1)
  elif mode==1:suffix=''.join('xyzw'[(t>>(4+2*j))&3]for j in range(4))
  elif mode==2:suffix='xyzw'[(t>>4)&3]
  else:raise ValueError('bad component mode')
 indices=[]
 for j in range(ndim):
  rep=(t>>(22+3*j))&7;v=''
  if rep in (0,3):v=str(a[p]);p+=1
  elif rep in (1,4):v=str(a[p]|(a[p+1]<<32));p+=2
  elif rep!=2:raise ValueError('bad index representation')
  if rep in (2,3,4):r,p=operand(a,p);v+=(('+'if v else '')+r)
  indices.append(v)
 if typ in (4,5):
  n=4 if comp==2 else 1;vals=[]
  for j in range(n):
   if typ==4:v=struct.unpack('<f',struct.pack('<I',a[p]))[0];p+=1
   else:v=struct.unpack('<d',struct.pack('<II',a[p],a[p+1]))[0];p+=2
   vals.append(f'{v:.9g}')
  out='l('+','.join(vals)+')'
 else:
  out=TYPES.get(typ,'type'+str(typ))
  if indices:out+=indices[0]+''.join('['+x+']'for x in indices[1:])
  if suffix:out+='.'+suffix
 if mod==1:out='-'+out
 elif mod==2:out='abs('+out+')'
 elif mod==3:out='-abs('+out+')'
 elif mod:out=f'modifier{mod}('+out+')'
 return out,p

def sig(data):
 n,unk=struct.unpack_from('<II',data);out=[]
 for i in range(n):
  off,idx,sv,typ,reg,mask=struct.unpack_from('<6I',data,8+24*i);name=data[off:data.index(b'\0',off)].decode();m=''.join('xyzw'[j]for j in range(4)if(mask>>j)&1)
  out.append(f'{name}{idx}: register{reg}.{m} systemvalue={sv} componenttype={typ}')
 return out

def decode(b):
 n=struct.unpack_from('<I',b,28)[0];lines=[]
 for off in struct.unpack_from('<'+'I'*n,b,32):
  size=struct.unpack_from('<I',b,off+4)[0];data=b[off+8:off+8+size];kind=b[off:off+4]
  lines.append('// '+kind.decode())
  if kind in [b'ISGN',b'OSGN']:lines+=['// '+x for x in sig(data)]
  if kind not in [b'SHDR',b'SHEX']:continue
  a=struct.unpack('<'+'I'*(len(data)//4),data);lines.append(f'// shader kind={a[0]>>16}, model={(a[0]>>4)&15}.{a[0]&15}, length={a[1]}');i=2
  while i<len(a):
   t=a[i];op=t&2047;name=OPS.get(op,f'unknown_opcode_{op}');length=(t>>24)&127
   if name=='customdata':length=a[i+1]
   if not length:raise ValueError('zero length')
   args=[];p=i+1
   if t>>31:
    while True:
     ext=a[p];p+=1;args.append(f'opcode_extension(0x{ext:08x})')
     if not ext>>31:break
   if t&(1<<13):name+='_sat'
   try:
    if name.startswith('dcl_temps'):args.append(str(a[p]));p+=1
    elif name.startswith('dcl_global_flags'):args.append(hex((t>>11)&8191))
    elif name.startswith('dcl_resource'):
     x,p=operand(a,p);args.append(x);args.append(f'dimension={(t>>11)&31},returntype=0x{a[p]:x}');p+=1
    elif name.startswith('dcl_input')or name.startswith('dcl_output'):
     x,p=operand(a,p);args.append(x)
     while p<i+length:args.append(f'meta({a[p]})');p+=1
    elif name=='customdata':p=i+length;args.append('[raw]')
    else:
     while p<i+length:x,p=operand(a,p);args.append(x)
    if p!=i+length:raise ValueError(f'consumed {p-i} expected {length}')
    line=name+' '+', '.join(args)
   except Exception as ex:line=name+' RAW '+','.join(f'{x:08x}'for x in a[i+1:i+length])+' // '+repr(ex)
   lines.append(f'{i:04d}: '+line);i+=length
 return '\n'.join(lines)+'\n'
if __name__=='__main__':
 for p in ROOT.glob('*/*.dxbc'):
  try:p.with_suffix('.asm.txt').write_text(decode(p.read_bytes()))
  except Exception as ex:print(p,ex)
