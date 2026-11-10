@tool
extends EditorPlugin
class RawRuntimeExport extends EditorExportPlugin:
 func _get_name():return "RawRuntimeAssets"
 func _export_begin(features:PackedStringArray,_debug:bool,_path:String,_flags:int):
  if not ("windows" in features or "android" in features):return
  var mobile_renderer=ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")
  var build_info={"main_scene":ProjectSettings.get_setting("application/run/main_scene"),"renderer":mobile_renderer if "android" in features else ProjectSettings.get_setting("rendering/renderer/rendering_method"),"mobile_renderer":mobile_renderer,"fallback_to_opengl3":ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3",true),"debug":_debug,"platform":"Android" if "android" in features else "Windows Desktop","privacy_test":"privacy_test" in features}
  add_file("res://release-build.json",JSON.stringify(build_info).to_utf8_buffer(),false)
  if not "windows" in features:return
  for root in ["res://assets","res://original_board","res://source_rope","res://references","res://shaders"]:scan(root)
 func scan(path:String):
  for file in DirAccess.get_files_at(path):
   if file.get_extension() in ["png","webp","json","bin","sha256","source_sha256","value_sha256","rgba8-mips","dxt-mips","wav","ogg","glsl"]:
    var full=path+"/"+file
    add_file(full,FileAccess.get_file_as_bytes(full),false)
  for folder in DirAccess.get_directories_at(path):scan(path+"/"+folder)
var exporter=RawRuntimeExport.new()
func _enter_tree():add_export_plugin(exporter)
func _exit_tree():remove_export_plugin(exporter)
