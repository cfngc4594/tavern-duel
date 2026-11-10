@tool
extends EditorPlugin
class RawRuntimeExport extends EditorExportPlugin:
 func _get_name():return "RawRuntimeAssets"
 func _export_begin(features:PackedStringArray,_debug:bool,_path:String,_flags:int):
  if not ("windows" in features or "android" in features):return
  var mobile_renderer=ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")
  var build_info={"main_scene":ProjectSettings.get_setting("application/run/main_scene"),"renderer":mobile_renderer if "android" in features else ProjectSettings.get_setting("rendering/renderer/rendering_method"),"mobile_renderer":mobile_renderer,"fallback_to_opengl3":ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3",true),"debug":_debug,"platform":"Android" if "android" in features else "Windows Desktop","privacy_test":"privacy_test" in features}
  if not "windows" in features:
   add_file("res://release-build.json",JSON.stringify(build_info).to_utf8_buffer(),false)
   return
  # The candidate remains off. Do not add its ~49.7 MB data to normal releases.
  # Benchmark exports contain both paths so comparisons use one identical PCK.
  build_info["board_source_bundle"]=null
  build_info["portrait_source_policy"]=null
  if "renderer_benchmark" in features:
   # Compile this export's generation, never a stale checked-in blob.
   var compiled=preload("res://original_board/scripts/board_source_compiler.gd").compile()
   if not compiled.get("ok",false):
    push_error("BOARD_SOURCE_COMPILE_FAILED "+str(compiled.get("error","unknown error")))
    return
   var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(compiled.bytes)
   build_info["board_source_bundle"]={"path":preload("res://original_board/scripts/board_source_store.gd").BUNDLE_PATH,"sha256":hash.finish().hex_encode(),"bytes":compiled.bytes.size(),"manifest":compiled.manifest}
   add_file(preload("res://original_board/scripts/board_source_store.gd").BUNDLE_PATH,compiled.bytes,false)
   print("BOARD_SOURCE_COMPILE_PASS ",JSON.stringify(compiled.manifest))
   # Tiny verified importer-policy metadata only. Raw source images are already
   # in the existing raw-assets scan; no second pixel/image bundle is added.
   var portraits=preload("res://scripts/portrait_source_images.gd")
   var policy=portraits.build_export_manifest(portraits.default_portrait_paths())
   if policy.get("entries",{}).is_empty():
    push_error("PORTRAIT_SOURCE_POLICY_FAILED No verified portrait entries")
    return
   var policy_bytes=JSON.stringify(policy).to_utf8_buffer()
   var policy_hash=HashingContext.new();policy_hash.start(HashingContext.HASH_SHA256);policy_hash.update(policy_bytes)
   build_info["portrait_source_policy"]={"path":portraits.MANIFEST_PATH,"bytes":policy_bytes.size(),"sha256":policy_hash.finish().hex_encode(),"entries":policy.entries.size()}
   add_file(portraits.MANIFEST_PATH,policy_bytes,false)
   print("PORTRAIT_SOURCE_POLICY_PASS ",JSON.stringify(build_info.portrait_source_policy))
  add_file("res://release-build.json",JSON.stringify(build_info).to_utf8_buffer(),false)
  for root in ["res://assets","res://original_board","res://source_rope","res://references","res://shaders"]:scan(root)
 func _export_file(path:String,_type:String,_features:PackedStringArray):
  # A source-tree stale blob may never replace the fresh export-time bundle.
  if path==preload("res://original_board/scripts/board_source_store.gd").BUNDLE_PATH:skip()
  if path==preload("res://scripts/portrait_source_images.gd").MANIFEST_PATH:skip()
 func scan(path:String):
  for file in DirAccess.get_files_at(path):
   if file.get_extension() in ["png","webp","json","bin","sha256","source_sha256","value_sha256","rgba8-mips","dxt-mips","wav","ogg","glsl"]:
    var full=path+"/"+file
    if full!=preload("res://original_board/scripts/board_source_store.gd").BUNDLE_PATH and full!=preload("res://scripts/portrait_source_images.gd").MANIFEST_PATH:add_file(full,FileAccess.get_file_as_bytes(full),false)
  for folder in DirAccess.get_directories_at(path):scan(path+"/"+folder)
var exporter=RawRuntimeExport.new()
func _enter_tree():add_export_plugin(exporter)
func _exit_tree():remove_export_plugin(exporter)
