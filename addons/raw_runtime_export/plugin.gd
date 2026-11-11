@tool
extends EditorPlugin
class RawRuntimeExport extends EditorExportPlugin:
 func _get_name():return "RawRuntimeAssets"
 func _export_begin(features:PackedStringArray,_debug:bool,_path:String,_flags:int):
  if not "android" in features:return
  var mobile_renderer=ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")
  var build_info={"main_scene":ProjectSettings.get_setting("application/run/main_scene"),"renderer":mobile_renderer,"mobile_renderer":mobile_renderer,"fallback_to_opengl3":ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3",true),"debug":_debug,"platform":"Android","privacy_test":"privacy_test" in features}
  add_file("res://release-build.json",JSON.stringify(build_info).to_utf8_buffer(),false)
 func _export_file(path:String,_type:String,_features:PackedStringArray):
  # Historical desktop experiment outputs are never Android runtime inputs.
  if path=="res://original_board/generated/desktop_source.bin":skip()
  if path=="res://assets/portrait_source_policy.json":skip()
var exporter=RawRuntimeExport.new()
func _enter_tree():add_export_plugin(exporter)
func _exit_tree():remove_export_plugin(exporter)
