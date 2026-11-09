@tool
extends EditorPlugin
class RawRuntimeExport extends EditorExportPlugin:
 func _get_name():return "RawRuntimeWindows"
 func _export_begin(features:PackedStringArray,_debug:bool,_path:String,_flags:int):
  if not "windows" in features:return
  var build_info={"main_scene":ProjectSettings.get_setting("application/run/main_scene"),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"debug":_debug,"platform":"Windows Desktop"}
  add_file("res://release-build.json",JSON.stringify(build_info).to_utf8_buffer(),false)
  for root in ["res://assets","res://original_board","res://source_rope","res://references"]:scan(root)
 func scan(path:String):
  for file in DirAccess.get_files_at(path):
   if file.get_extension() in ["png","webp","json","bin","sha256","source_sha256","value_sha256","rgba8-mips","dxt-mips","wav","ogg"]:
    var full=path+"/"+file
    add_file(full,FileAccess.get_file_as_bytes(full),false)
  for folder in DirAccess.get_directories_at(path):scan(path+"/"+folder)
var exporter=RawRuntimeExport.new()
func _enter_tree():add_export_plugin(exporter)
func _exit_tree():remove_export_plugin(exporter)
