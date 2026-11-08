import pathlib,json,hashlib,UnityPy
p=pathlib.Path('/workspace/shared/native_shader_evidence');scope={};exec((p/'locate_coin_bundle.py').read_text().split('install=get_manifest')[0],{'__file__':str(p/'locate_coin_bundle.py')},scope)
b=(p/'coin_bundle.blte').read_bytes()
# execute helper definitions together so shared globals are available
ns={'__file__':str(p/'locate_coin_bundle.py')};exec((p/'locate_coin_bundle.py').read_text().split('install=get_manifest')[0],ns)
raw,modes=ns['blte'](b,'4978c68d869336c4e3697998fdbd0bc1','1319d915957505c955dadd6a30ec687b',7009659)
f=p/'initial_base_global-8411aad9-texture-3.unity3d';f.write_bytes(raw)
UnityPy.config.FALLBACK_UNITY_VERSION='6000.3.11f1';e=UnityPy.load(str(f));found=[]
for k,o in e.container.items():
 if '583499402f221f24792040779fa00734' in k:
  d=o.read();out=p/'atlas_spell_neutral.png';d.image.save(out);r={'guid':'583499402f221f24792040779fa00734','container_key':k,'path_id':str(o.path_id),'name':d.m_Name,'png':out.name,'png_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'bundle_sha256':hashlib.sha256(raw).hexdigest(),'bundle_md5':hashlib.md5(raw).hexdigest(),'url':'https://us.cdn.blizzard.com/tpr/hs/data/49/78/4978c68d869336c4e3697998fdbd0bc1','verified_blte_header_chunk_and_decoded_md5':True};found.append(r)
assert len(found)==1; (p/'coin_texture_provenance.json').write_text(json.dumps(found[0],indent=2));print(found)
