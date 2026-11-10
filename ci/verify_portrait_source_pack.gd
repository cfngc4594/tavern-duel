extends SceneTree
## Mounted exported PCK only, not a source-tree fallback.
func _initialize():
 var args=OS.get_cmdline_user_args()
 assert(args.size()==2,"Expected PCK and report paths")
 assert(not FileAccess.file_exists("res://main.tscn"),"Use an empty fixture")
 assert(ProjectSettings.load_resource_pack(args[0],true),"PCK mount failed")
 var info=JSON.parse_string(FileAccess.get_file_as_string("res://release-build.json"))
 var entry=info.get("portrait_source_policy",{})
 assert(entry.has("path") and entry.has("sha256") and entry.has("bytes"),"Missing export policy metadata")
 var bytes=FileAccess.get_file_as_bytes(entry.path)
 assert(bytes.size()==int(entry.bytes) and FileAccess.get_sha256(entry.path)==entry.sha256,"Policy not from this export")
 var policy=JSON.parse_string(bytes.get_string_from_utf8())
 var source=load("res://scripts/portrait_source_images.gd")
 assert(not source.enabled,"Candidate unexpectedly enabled by default")
 assert(policy is Dictionary and source.set_verified_manifest(policy),"Invalid policy")
 assert(policy.entries.size()==int(entry.entries) and entry.entries>0,"Missing approved entries")
 var image_bytes=0
 for path in policy.entries:
  # Exercise exported semantics explicitly. This verifier itself uses an editor
  # executable, but packed games intentionally do not depend on .import files.
  var image=source._read_entry(path,policy.entries[path],false)
  assert(image!=null,"Packed source/image bytes fail verified policy: "+path)
  var texture=ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
  assert(texture!=null,"Missing packed imported baseline: "+path)
  var reference=texture.get_image()
  assert(reference.get_size()==image.get_size() and reference.get_format()==image.get_format() and reference.has_mipmaps()==image.has_mipmaps() and reference.get_data()==image.get_data(),"Packed imported pixels differ: "+path)
  image_bytes+=image.get_data_size()
 var report={"passed":true,"source_fallback":false,"default_enabled":source.enabled,"policy":entry,"decoded_image_bytes":image_bytes,"all_imported_pixels_exact":true}
 var file=FileAccess.open(args[1],FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(report,"  "));file.close()
 print("PORTRAIT_SOURCE_PACK_VERIFY_PASS ",JSON.stringify(report));quit()
