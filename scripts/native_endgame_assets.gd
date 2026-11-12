extends "res://scripts/native_combat_assets.gd"
## The end-game bundle has its own material identities and vertex-input metadata.
## All unchanged source shaders keep the already verified combat translation.
var endgame_materials
var endgame_textures=preload("res://scripts/native_endgame_textures.gd").new()
func setup(card_renderer: Node=null,source_base: String="res://assets/original_endgame_v33/") -> void:
 super.setup(card_renderer,source_base)
 # UberText assigns both renderer.sortingOrder and a relative material queue.
 # Recover the domain from every source text, including inactive account UI.
 for record in objects.values():
  if record.get("class_name","")=="UberText":
   var order: int=int(record.data.get("m_RenderQueue",0))
   var queue: int=clampi(3000+order,1,5000)
   if not source_sorting_orders.has(order):source_sorting_orders.append(order)
   if not source_render_queues.has(queue):source_render_queues.append(queue)
 source_sorting_orders.sort();source_render_queues.sort()
 if FileAccess.file_exists(source_base+"data/mesh_color_channels.json"):
  var metadata=JSON.parse_string(FileAccess.get_file_as_string(source_base+"data/mesh_color_channels.json"))
  mesh_color_channels.merge(metadata.get("meshes",metadata),true)
 if ResourceLoader.exists("res://scripts/native_endgame_materials.gd"):
  endgame_materials=load("res://scripts/native_endgame_materials.gd").new()
func load_texture(key: String) -> Texture2D:
 if texture_cache.has(key):return texture_cache[key]
 var original: Texture2D=endgame_textures.load_source_texture(key,self)
 if original!=null:
  texture_cache[key]=original;return original
 return super.load_texture(key)

func material(key: String,texture_override: Texture2D=null) -> Material:
 var translated: Material
 if endgame_materials!=null:translated=endgame_materials.build(key,self,texture_override)
 if translated==null:translated=super.material(key,texture_override)
 if texture_override!=null:endgame_textures.bind_source_sampler(translated,"_MainTex",texture_override,self)
 return translated

func bind_hero_portrait(materials: Array,texture: Texture2D) -> int:
 var count:=0
 for material in materials:
  var material_key: String=material.get_meta("source_key","")
  var record: Dictionary=objects.get(material_key,{})
  if not str(record.get("name","")).contains("portrait"):continue
  material.set_shader_parameter("_MainTex",texture)
  endgame_textures.bind_source_sampler(material,"_MainTex",texture,self)
  count+=1
 return count
