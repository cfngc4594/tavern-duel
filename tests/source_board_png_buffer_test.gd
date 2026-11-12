extends SceneTree
const Materials=preload("res://original_board/scripts/board_materials.gd")
const Particles=preload("res://original_board/scripts/source_particles.gd")
func hash_bytes(bytes:PackedByteArray)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func _initialize():call_deferred("run")
func run():
 var paths:Array[String]=[]
 var directory=DirAccess.open("res://original_board/assets/textures")
 for file in directory.get_files():
  if file.ends_with(".png"):paths.append("res://original_board/assets/textures/"+file)
 var particle_data=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/assets/water_particles/source.json"))
 for row in particle_data.materials.values():
  if not paths.has(str(row.texture)):paths.append(str(row.texture))
 assert(paths.size()>0)
 var checked=0
 for path in paths:
  # Baseline is the previous file decoder on an actual original PNG, copied
  # byte-for-byte outside res:// so the test also works from an exported PCK.
  var temp="user://source-png-baseline.png"
  var file=FileAccess.open(temp,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(path));file.close()
  var before=Image.load_from_file(temp);assert(before!=null and not before.is_empty(),path)
  for decoded in [Materials._load_source_png(path),Particles._load_source_png(path)]:
   assert(decoded!=null and decoded.get_size()==before.get_size(),path)
   assert(decoded.get_format()==before.get_format() and decoded.has_mipmaps()==before.has_mipmaps(),path)
   assert(hash_bytes(decoded.get_data())==hash_bytes(before.get_data()),path)
  checked+=1
 assert(Materials._load_source_png("res://missing-original.png")==null)
 assert(Particles._load_source_png("res://missing-original.png")==null)
 DirAccess.remove_absolute("user://source-png-baseline.png")
 print("SOURCE_BOARD_PNG_BUFFER_PASS ",checked," original board/particle PNGs: identical dimensions/format/mips/pixel SHA256; missing paths fail closed")
 quit()
