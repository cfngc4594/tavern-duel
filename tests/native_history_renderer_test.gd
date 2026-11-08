extends SceneTree
# Actual production materials/resources and geometry are exercised headlessly.
# GPU shader compilation/raster coverage is still reserved for real AVD QA.
class Host extends Node:
 var definitions={"CS2_172":{"art":0}}
 var raw_portraits=[]
 var source_projection=true
 var source_visual_delta=1.0
 var native_history_events=preload("res://scripts/native_history_events.gd").new()
func _initialize():call_deferred("run")
func run():
 var host=Host.new();root.add_child(host)
 var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);host.raw_portraits=[ImageTexture.create_from_image(image)]
 var renderer=preload("res://scripts/native_history_renderer.gd").new();root.add_child(renderer);renderer.setup(host)
 assert(renderer.source.profiles.size()==3)
 assert(renderer.source.portraits.size()==35)
 for key in renderer.source.portraits:
  assert(renderer.source.portrait_pixels.has(key))
  assert(ResourceLoader.exists(renderer.BASE+renderer.source.portrait_pixels[key].file))
 for key in ["EX1_015","EX1_556","CS2_124"]:
  assert(renderer._portrait(key)!=null)
 assert(renderer._portrait_material_key("CS2_034")=="HERO_08bp")
 assert(renderer._portrait_material_key("CS2_056")=="HERO_07bp")
 # Preserve original CullBack through the reflected source-world root.
 # 37405 omitted this backend adaptation: only CullOff shadows were visible.
 for kind in renderer.source.profiles:
  for spec in renderer.source.profiles[kind].nodes:
   if not spec.has("mesh"):continue
   var raw=JSON.parse_string(FileAccess.get_file_as_string(renderer.BASE+renderer.source.meshes[spec.mesh]))
   var flipped=[]
   for surface in range(spec.materials.size()):
    if renderer.source.materials[spec.materials[surface]].shader_id in renderer.SOURCE_CULL_BACK:flipped.append(surface)
   var mesh=renderer._mesh(spec.mesh,flipped)
   for surface in range(raw.triangles.size()):
    var indices=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
    for triangle in range(raw.triangles[surface].size()):
     var original=raw.triangles[surface][triangle]
     assert(indices[triangle*3]==int(original[0]))
     assert(indices[triangle*3+1]==int(original[2 if surface in flipped else 1]))
     assert(indices[triangle*3+2]==int(original[1 if surface in flipped else 2]))
 var s=host.native_history_events.begin_play({"entity_id":1,"key":"CS2_172","side":0});host.native_history_events.complete(s)
 renderer.sync();assert(renderer.displayed.size()==1)
 var played=renderer.entries[s];assert(played.root.get_child(0).scale.is_equal_approx(Vector3.ONE*1.1));assert(played.size>0)
 print("PLAY_SIZE ",played.size," top=",renderer.top_position()," target=",played.target)
 s=host.native_history_events.begin_attack({"entity_id":1,"key":"CS2_172","side":0},{"entity_id":2,"key":"CS2_172","side":1});host.native_history_events.complete(s);renderer.sync()
 var attack=renderer.entries[s];assert(attack.half);assert(attack.size<played.size)
 print("ATTACK_SIZE ",attack.size," target=",attack.target)
 assert(renderer.displayed[0]==s)
 var full_count=0
 for i in range(24):
  s=host.native_history_events.begin_play({"entity_id":i+5,"key":"CS2_172","side":i%2});host.native_history_events.complete(s)
 renderer.sync();full_count=renderer.displayed.size();assert(full_count>0 and full_count<24)
 assert(full_count==6)
 assert(renderer.entries.size()==full_count)
 var last_z=INF
 for serial in renderer.displayed:
  var state=renderer.entries[serial];assert(state.target.z<last_z);last_z=state.target.z
 assert(is_equal_approx(renderer.source.portraits.CS2_172.full.floats._Scale,1.5399999618530273))
 assert(is_equal_approx(renderer.source.portraits.CS2_172.full.floats._OffsetX,-0.17000000178813934))
 assert(not FileAccess.get_file_as_string("res://shaders/native_history_portrait.gdshader").contains("mix(t,_Color*gray"))
 for i in range(24):
  s=host.native_history_events.begin_attack({"entity_id":i+50,"key":"CS2_172","side":i%2},{"entity_id":i+80,"key":"CS2_172","side":1-i%2});host.native_history_events.complete(s)
 renderer.sync();assert(renderer.displayed.size()==11)
 host.source_projection=null;renderer.sync();assert(not renderer.visible);assert(not renderer.entries.is_empty())
 host.native_history_events.reset();renderer.sync();assert(renderer.entries.is_empty());assert(renderer.last_serials.is_empty())
 host.source_projection=true;renderer.sync();assert(renderer.visible)
 s=host.native_history_events.begin_play({"entity_id":100,"key":"EX1_015","side":0});host.native_history_events.complete(s)
 renderer.sync();assert(renderer.displayed==[s]);assert(renderer.entries[s].event.key=="EX1_015")
 host.native_history_events.reset();renderer.sync();assert(renderer.entries.is_empty())
 assert(renderer.blockers.is_empty())
 var material_count=renderer.shared_material_cache.size()
 assert(material_count>0)
 for i in range(3):
  s=host.native_history_events.begin_play({"entity_id":200+i,"key":"CS2_172","side":0});host.native_history_events.complete(s);renderer.sync()
  await process_frame
  host.native_history_events.reset();renderer.sync();await process_frame
 assert(renderer.shared_material_cache.size()==material_count)
 renderer.queue_free()
 for i in range(3):await process_frame
 renderer=preload("res://scripts/native_history_renderer.gd").new();root.add_child(renderer);renderer.setup(host)
 s=host.native_history_events.begin_play({"entity_id":300,"key":"CS2_172","side":0});host.native_history_events.complete(s);renderer.sync()
 assert(renderer.shared_material_cache.size()==material_count)
 renderer.queue_free();host.queue_free()
 for i in range(3):await process_frame
 print("NATIVE_HISTORY_RENDERER_PASS: original three tile profiles, 35 original portrait textures, source CullBack winding adaptation, transforms, full/half sizes, source UV parameters, source height pruning (6 full / 11 half), latest-first placement, real immutable materials, reset/reenter/renderer teardown with bounded cache")
 quit()
