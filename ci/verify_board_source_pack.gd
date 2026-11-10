extends SceneTree
## Verify an actual exported blob from an empty fixture, not source fallback.
func _initialize():
 var args=OS.get_cmdline_user_args()
 assert(args.size()==2,"Expected absolute PCK and output report paths")
 assert(not FileAccess.file_exists("res://main.tscn"),"Use an empty verification fixture")
 assert(ProjectSettings.load_resource_pack(args[0],true),"PCK mount failed")
 var info=JSON.parse_string(FileAccess.get_file_as_string("res://release-build.json"))
 var entry=info.get("board_source_bundle",{})
 assert(entry.has("path") and entry.has("bytes") and entry.has("sha256"),"Bundle metadata absent")
 var blob=FileAccess.get_file_as_bytes(entry.path)
 assert(blob.size()==int(entry.bytes) and FileAccess.get_sha256(entry.path)==entry.sha256,"Bundle does not match this export")
 var store=load("res://original_board/scripts/board_source_store.gd")
 var validation=store.validate_bytes(blob)
 assert(validation.get("ok",false),"Invalid exported bundle: "+str(validation.get("error")))
 assert(JSON.parse_string(JSON.stringify(validation.manifest))==entry.manifest,"Export manifest mismatch after JSON numeric normalization")
 assert(store.get_audit().loads==0,"Packaging validation populated gameplay cache")
 var report={"passed":true,"source_fallback":false,"bundle_bytes":blob.size(),"bundle_sha256":entry.sha256,"manifest":validation.manifest,"default_enabled":store.enabled,"privacy_test":info.privacy_test}
 var file=FileAccess.open(args[1],FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(report,"  "));file.close()
 print("BOARD_SOURCE_PACK_VERIFY_PASS ",JSON.stringify(report))
 quit()
