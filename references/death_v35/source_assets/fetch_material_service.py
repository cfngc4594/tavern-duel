from restore_death import *
D=SRC/'managed';D.mkdir(exist_ok=True)
for platform,source in [('mac','Hearthstone.app/Contents/Resources/Data/Managed/Blizzard.T5.MaterialService.dll'),('win','Hearthstone_Data/Managed/Blizzard.T5.MaterialService.dll')]:
 row=rows[source];ek=enc[row['content_key']]['encoding_keys'][0];name='Blizzard.T5.MaterialService.'+platform+'.dll';d=casc.fetch(name,ek,row['content_key']);p=D/name;p.write_bytes(d)
 assert hashlib.md5(d).hexdigest()==row['content_key'];savejson(p.with_suffix('.dll.provenance.json'),dict(build='37.0.0.255130.254477',source_install_row=row,sha256=hashlib.sha256(d).hexdigest(),md5=hashlib.md5(d).hexdigest(),bytes=len(d),download_provenance=json.load(open(casc.DATA/(name+'.provenance.json')))));print(p,len(d),flush=True)
