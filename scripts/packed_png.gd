extends RefCounted
## Raw PNG bytes are intentionally included in the Android sparse PCK.
## FileAccess reads either packed or loose bytes; never require an OS filesystem path.
static func load_png(path:String)->Image:
 var image=Image.new()
 var bytes=FileAccess.get_file_as_bytes(path)
 if bytes.is_empty() or image.load_png_from_buffer(bytes)!=OK:return null
 return image
