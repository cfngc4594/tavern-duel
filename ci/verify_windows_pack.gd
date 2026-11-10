extends SceneTree
# Invoke from prepare_windows_export.py's empty verification project, never source.
var packed_files:Array[String]=[]
func walk(path:String):
 for file in DirAccess.get_files_at(path):packed_files.append(path+"/"+file)
 for folder in DirAccess.get_directories_at(path):walk(path+"/"+folder)
func _initialize():
 var args=OS.get_cmdline_user_args()
 assert(args.size()==3,"Expected absolute PCK, manifest and report paths")
 # Enforce no local assets/scripts before mounting; source fallback is forbidden.
 assert(not DirAccess.dir_exists_absolute("res://assets"))
 assert(not FileAccess.file_exists("res://main.tscn"))
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
 assert(manifest is Dictionary and manifest.raw_assets.size()>0)
 assert(ProjectSettings.load_resource_pack(args[0],true),"PCK mount failed")
 var missing=[];var different=[]
 for rel in manifest.raw_assets:
  var path="res://"+rel
  if not FileAccess.file_exists(path):missing.append(rel)
  elif FileAccess.get_sha256(path)!=manifest.raw_assets[rel]:different.append(rel)
 walk("res://")
 var forbidden=[];var compiled=0
 for path in packed_files:
  var rel=path.trim_prefix("res://")
  if rel.ends_with(".gdc"):compiled+=1
  if rel.begins_with("tests/") or rel.begins_with("build/") or rel.begins_with("ci/") or rel.begins_with("addons/") or rel.begins_with("bench") or rel.begins_with("qa/") or rel.begins_with(".git/") or rel.ends_with(".gd") or rel.get_file().begins_with(".env") or rel.get_extension() in ["pem","key","keystore","jks"]:forbidden.append(rel)
 var main_exists=ResourceLoader.exists("res://main.tscn")
 var exported=JSON.parse_string(FileAccess.get_file_as_string("res://release-build.json"))
 assert(exported is Dictionary and exported.main_scene=="res://main.tscn" and exported.renderer=="forward_plus" and exported.mobile_renderer=="forward_plus" and exported.fallback_to_opengl3==false and manifest.renderer==exported.renderer and exported.debug==false)
 # The board experiment is benchmark-only until whole-scene tails are accepted.
 var bundle=exported.get("board_source_bundle")
 assert(bundle==null,"Normal production pack unexpectedly includes experimental board data")
 assert(not FileAccess.file_exists("res://original_board/generated/desktop_source.bin"),"Experimental board blob leaked into normal release")
 assert(not load("res://original_board/scripts/board_source_store.gd").enabled,"Unaccepted board candidate enabled in production")
 assert(exported.get("portrait_source_policy")==null,"Experimental portrait policy leaked into normal release metadata")
 assert(not FileAccess.file_exists("res://assets/portrait_source_policy.json"),"Experimental portrait policy leaked into normal release")
 assert(not load("res://scripts/portrait_source_images.gd").enabled,"Unaccepted portrait candidate enabled in production")
 var bundle_validation={"present":false,"candidate_default_enabled":false,"reason":"Experimental source bundle is benchmark-only"}
 var report={"source_commit":manifest.source_commit,"source_dirty":manifest.source_dirty,"export_settings":exported,"godot_version":Engine.get_version_info().string,"main_scene":manifest.main_scene,"renderer":manifest.renderer,"baseline_runtime_raw_count":manifest.baseline_runtime_raw_count,"expected_raw_count":manifest.expected_raw_count,"checked_raw_count":manifest.raw_assets.size(),"missing_assets":missing,"different_assets":different,"forbidden_entries":forbidden,"compiled_scripts":compiled,"main_scene_exists":main_exists,"packed_entries":packed_files.size(),"source_fallback":false,"board_source_bundle_validation":bundle_validation}
 var file=FileAccess.open(args[2],FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(report,"  "));file.close()
 var passed=missing.is_empty() and different.is_empty() and forbidden.is_empty() and compiled>0 and main_exists
 print("WINDOWS_PACK_VERIFY_", "PASS" if passed else "FAIL", " ",JSON.stringify(report))
 quit(0 if passed else 1)
