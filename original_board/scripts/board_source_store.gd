@tool
extends RefCounted
# Compatibility for existing local capture scripts that disable the retired
# bundle experiment. Reads below are always raw; this flag cannot enable it.
static var enabled:bool=false
## Phone source JSON and PNG data. Every read belongs to its caller.
## No desktop-only compiled bundle, global cache, or platform fallback.
func read_json(path:String):return raw_json(path)
func read_image(path:String)->Image:return raw_image(path)
static func raw_json(path:String)->Dictionary:
 if not FileAccess.file_exists(path):return {}
 var value=JSON.parse_string(FileAccess.get_file_as_string(path))
 return value if value is Dictionary else {}
static func raw_image(path:String)->Image:
 if not FileAccess.file_exists(path):return null
 var image=Image.new()
 if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
 return image
static func json_for(probe,path:String):
 if is_instance_valid(probe) and probe.has_method('read_source_json'):return probe.read_source_json(path)
 return raw_json(path)
static func image_for(probe,path:String)->Image:
 if is_instance_valid(probe) and probe.has_method('read_source_image'):return probe.read_source_image(path)
 return raw_image(path)
