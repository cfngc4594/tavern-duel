extends SceneTree
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const Policy=preload("res://scripts/source_board_camera_policy.gd")
func _initialize():call_deferred("run")
func run():
 var renderer=load("res://scripts/native_card_renderer.gd").new();root.add_child(renderer)
 # Existing shader/glyph API only, no costly card/viewports initialization.
 renderer.number_bundle=renderer._load_glyph_bundle("res://assets/unity_number_sample/")
 var mana=load("res://scripts/native_phone_mana_renderer.gd").new();root.add_child(mana);mana.setup(renderer)
 print("MANA_SETUP ",mana.get_audit());assert(mana.geometry_ready)
 var vp=SubViewport.new();vp.size=Vector2i(1600,900);root.add_child(vp);var cr=Node3D.new();vp.add_child(cr);var cam=Camera3D.new();cr.add_child(cam);Policy.apply(cam,cr,Vector2(1600,900))
 var snapshot=Layout.build(Layout.recovered_items(0,0,{"permanent_mana_count":2,"temporary_mana_count":1}),cam,Vector2(vp.size),Vector2(1600,900),Vector2.ZERO)
 var values={"available":2,"permanent":2,"friendly_counter":"2/2","opposing_counter":"4/4","crystal_samples":[{"state":"used"},{"state":"ready"},{"state":"ready"}]}
 mana.sync(snapshot,values);print("MANA_SYNC ",mana.get_audit());assert(mana.rendering_ready)
 assert(mana.pieces.crystal_0.root.transform.is_equal_approx(snapshot.items.friendly_mana.crystals[0].source_pose))
 assert(mana.pieces.crystal_0.mesh.get_surface_override_material(0).get_shader_parameter("fade_rgb").is_equal_approx(Vector3.ONE*0.4627451002597809))
 assert(mana.text_nodes.size()==4)
 values.crystal_samples[0]={"clip":"ManaGemUsed","time":0.1};mana.sync(snapshot,values)
 assert(not mana.rendering_ready and not mana.visible)
 mana.queue_free();renderer.queue_free();vp.queue_free();await process_frame
 print("PHONE_MANA_RENDERER_PASS source meshes/materials/temporary override/glyphs/source poses/settled state curves; unregistered explicit live samples fail closed");quit()
