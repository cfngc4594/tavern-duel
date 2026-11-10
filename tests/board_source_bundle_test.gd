extends SceneTree
const Compiler=preload('res://original_board/scripts/board_source_compiler.gd')
const Store=preload('res://original_board/scripts/board_source_store.gd')
const OUT='res://build/board_source/desktop_source.bin'
var checks=0
var failures=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func _initialize():call_deferred('run')
func run():
 check(not Store.enabled,'candidate defaults off')
 var compiled=Compiler.compile();check(compiled.ok,'compile current original sources')
 if not compiled.ok:quit(1);return
 check(Compiler.validate_sources(compiled.manifest),'full content hashes valid')
 var compiled_again=Compiler.compile()
 check(compiled.bytes==compiled_again.bytes,'deterministic compilation')
 compiled_again.clear()
 var validated=Store.validate_bytes(compiled.bytes)
 check(validated.ok and validated.manifest==compiled.manifest,'full bundle validation')
 check(compiled.manifest.json_entries>=97 and compiled.manifest.image_entries>=16,'startup dependency closure')
 var wrong=compiled.manifest.duplicate(true);wrong.dependencies[wrong.dependencies.keys()[0]]='0'.repeat(64)
 check(not Compiler.validate_sources(wrong),'content mismatch invalidates')
 wrong=compiled.manifest.duplicate(true);wrong.dependencies['res://missing-board-dependency.json']='0'.repeat(64)
 check(not Compiler.validate_sources(wrong),'missing dependency invalidates')
 # Same byte length cannot evade content-based SHA256 validation.
 var fixture='user://board-source-invalidation.json'
 var f=FileAccess.open(fixture,FileAccess.WRITE);f.store_string('{"value":1}');f.close()
 var fixture_manifest={'schema':1,'dependencies':{fixture:FileAccess.get_sha256(fixture)}}
 check(Compiler.validate_sources(fixture_manifest),'fixture valid')
 f=FileAccess.open(fixture,FileAccess.WRITE);f.store_string('{"value":2}');f.close()
 check(not Compiler.validate_sources(fixture_manifest),'same-length content change invalidates')
 DirAccess.remove_absolute(fixture)
 DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
 f=FileAccess.open(OUT,FileAccess.WRITE);f.store_buffer(compiled.bytes);f.close()
 Store.bundle_path=OUT;Store.enabled=true;Store.clear_cache()
 var store=Store.new();store.open_for_probe(true)
 var second=Store.new();second.open_for_probe(true)
 check(Store.get_audit().loads==1,'one retained bundle per generation')
 for path in compiled.manifest.dependencies:
  if not path.ends_with('.json'):continue
  var original=JSON.parse_string(FileAccess.get_file_as_string(path))
  var candidate=store.read_json(path)
  check(var_to_bytes(original)==var_to_bytes(candidate),'exact typed Variant '+path)
  candidate.clear()
  check(var_to_bytes(original)==var_to_bytes(second.read_json(path)),'caller mutation isolated '+path)
 for path in compiled.manifest.dependencies:
  if not path.ends_with('.png'):continue
  var original=Image.new();check(original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK,'reference PNG load')
  var candidate=store.read_image(path)
  check(candidate.get_size()==original.get_size() and candidate.get_format()==original.get_format() and candidate.has_mipmaps()==original.has_mipmaps() and candidate.get_data()==original.get_data(),'exact image '+path)
  candidate.fill(Color.MAGENTA)
  check(second.read_image(path).get_data()==original.get_data(),'image mutation isolated '+path)
 check(Store.get_audit().misses==0 and Store.get_audit().raw_json_reads==0 and Store.get_audit().raw_image_reads==0,'all source reads hit immutable bundle')
 var baseline_count=Store.get_audit().json_hits
 var phone=Store.new();phone.open_for_probe(false);phone.read_json('res://original_board/assets/phone/scene_phone.json')
 check(Store.get_audit().json_hits==baseline_count and Store.get_audit().raw_json_reads==1,'phone variant stays raw')
 var before=store.read_json('res://original_board/assets/scene.json')
 Store.clear_cache(false)
 second.open_for_probe(true)
 check(Store.get_audit().loads==2,'explicit invalidation reloads once')
 check(store.read_json('res://original_board/assets/scene.json')==before,'old snapshot survives invalidation')
 var envelope=bytes_to_var(compiled.bytes)
 envelope.schema=999
 check(not Store.validate_bytes(var_to_bytes(envelope)).ok,'wrong version rejected')
 envelope.schema=1;envelope.payload[envelope.payload.size()-1]^=1
 check(not Store.validate_bytes(var_to_bytes(envelope)).ok,'corrupt payload rejected')
 check(not Store.validate_bytes(PackedByteArray()).ok,'empty bundle rejected')
 var fresh_envelope=bytes_to_var(compiled.bytes)
 var malformed=bytes_to_var(fresh_envelope.payload)
 var first_image=malformed.images.values()[0]
 first_image.width+=1
 fresh_envelope.payload=var_to_bytes(malformed);fresh_envelope.sha256=Compiler.digest(fresh_envelope.payload)
 check(not Store.validate_bytes(var_to_bytes(fresh_envelope)).ok,'per-image dimensions mismatch rejected even with valid outer digest')
 first_image.width-=1;first_image.mipmaps=true
 fresh_envelope.payload=var_to_bytes(malformed);fresh_envelope.sha256=Compiler.digest(fresh_envelope.payload)
 check(not Store.validate_bytes(var_to_bytes(fresh_envelope)).ok,'unexpected mip layout rejected')
 malformed.clear();fresh_envelope.clear()
 Store.bundle_path='res://missing-board-bundle.bin';Store.clear_cache(false)
 var fallback=Store.new();fallback.open_for_probe(true)
 check(fallback.read_json('res://original_board/assets/scene.json')==before,'missing bundle preserves original source fallback')
 check(not Store.get_audit().error.is_empty(),'fallback exposed in audit')
 Store.bundle_path=OUT;Store.clear_cache();Store.enabled=false
 print('BOARD_SOURCE_BUNDLE_TEST_', 'PASS' if failures.is_empty() else 'FAIL',' checks=',checks,' json=',compiled.manifest.json_entries,' images=',compiled.manifest.image_entries,' image_bytes=',compiled.manifest.image_bytes,' bundle_bytes=',compiled.bytes.size())
 quit(0 if failures.is_empty() else 1)
