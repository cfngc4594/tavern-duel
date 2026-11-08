from restore_targeting import *
manifest_paths=[OUT/'manifest.json',OUT/'data/highlight_resource_manifest.json',OUT/'data/highlight_builtin_resources.json'];merged={}
for p in manifest_paths:merged.update(json.load(open(p))['objects'])
provenance=[]
for bundle in sorted({r['bundle']for r in merged.values()}):
 if bundle.startswith('/'):
  p=pathlib.Path(bundle);name=p.name;row=rows.get('Hearthstone_Data/'+name)or rows.get('Data/Win/'+name)
  if not row:
   choices=[r for k,r in rows.items()if k.endswith('/'+name)and 'Win' not in k and 'OSX' not in k]
   row=next((r for r in choices if r['content_key']==hashlib.md5(p.read_bytes()).hexdigest()),None)
 else:p=fetch_bundle(bundle);row=rows['Data/Win/'+bundle]
 b=p.read_bytes();assert row and hashlib.md5(b).hexdigest()==row['content_key'],(bundle,row)
 provenance.append({'bundle':bundle,'source_file':str(p),'official_install_path':row['filename'],'content_md5':row['content_key'],'actual_md5':hashlib.md5(b).hexdigest(),'sha256':hashlib.sha256(b).hexdigest(),'verified_exact_build_content':True})
savejson(OUT/'data/all_targeting_source_provenance.json',{'build':'37.0.0.255130.254477','objects':len(merged),'sources':provenance})
print('VERIFIED',len(provenance),len(merged))
