extends SceneTree
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const CameraPolicy=preload("res://scripts/source_board_camera_policy.gd")
func _initialize():call_deferred("run")
func run():
 for aspect in [1.5,16.0/9.0,2.04,2.4]:
  for permanent in [0,1,4,10,12]:
   for temporary in [0,1,3]:
    for tray in [{},{"mana_tray_hidden":true},{"mana_tray_position":Vector3(1.2,3.4,5.6)}]:
     var options={"aspect":aspect,"permanent_mana_count":permanent,"temporary_mana_count":temporary};options.merge(tray)
     var full=Layout.recovered_items(3,7,options);var mana=Layout.recovered_mana_items(options)
     assert(mana.size()==2 and mana.friendly_mana==full.friendly_mana and mana.opposing_mana==full.opposing_mana)
 assert(Layout.recovered_mana_items().friendly_mana==Layout.recovered_items(0,0).friendly_mana)
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://original_board/references/minimum_scene_config.json"))
 var vp=SubViewport.new();vp.size=Vector2i(2400,1080);root.add_child(vp)
 var cr=Node3D.new();vp.add_child(cr);var camera=Camera3D.new();cr.add_child(camera)
 var canvas=Vector2(2000,900);var offset=Vector2(200,0)
 CameraPolicy.apply(camera,cr,canvas)
 var recovered=Layout.recovered_items(3,7,{"aspect":canvas.x/canvas.y,"permanent_mana_count":4,"temporary_mana_count":2,"end_turn_enabled":true})
 var real_snapshot=Layout.build(recovered,camera,Vector2(vp.size),canvas,offset)
 assert(real_snapshot.ready)
 assert(real_snapshot.items.friendly_play.slots.size()==3)
 assert(real_snapshot.items.opposing_play.slots.size()==7)
 var zone=recovered.friendly_play.source_row
 var slots=Layout.normal_slots(zone,3)
 var gap_slots=Layout.normal_slots(zone,3,2)
 var gap_width=float(zone.collider_bounds.size[0])/7.0*(1.0+float(zone.spacing.phone_width_modifiers[4]))
 assert(is_equal_approx(gap_slots[1].x-gap_slots[0].x,2.0*gap_width))
 var zero_gap=Layout.normal_slots(zone,3,0)
 assert(is_equal_approx(zero_gap[1].x-zero_gap[0].x,float(zone.collider_bounds.size[0])/7.0*1.25))
 assert(slots[1].is_equal_approx(Layout.vector(zone.collider_bounds.center)))
 assert(is_equal_approx(slots[2].x-slots[1].x,float(zone.collider_bounds.size[0])/7.0*1.25))
 assert(Layout.contains(real_snapshot,"friendly_play",real_snapshot.items.friendly_play.center))
 assert(real_snapshot.items.friendly_play.actors.size()==3)
 assert(is_equal_approx(real_snapshot.items.friendly_play.actors[0].source_scale.x,1.058))
 assert(is_equal_approx(real_snapshot.items.end_turn.source_scale.x,0.923))
 assert(real_snapshot.items.friendly_mana.crystals.size()==6)
 assert(real_snapshot.items.friendly_mana.tray_endpoints.hidden.is_equal_approx(Vector3(1.100000024,5.870626926,-4.740528107)))
 assert(real_snapshot.items.friendly_mana.crystals[0].list_index==3)
 assert(real_snapshot.items.friendly_mana.crystals[4].list_index==0)
 assert(is_equal_approx(real_snapshot.items.friendly_mana.crystals[1].source_world_position.z-real_snapshot.items.friendly_mana.crystals[0].source_world_position.z,0.33000001311302185))
 assert(not Layout.contains(real_snapshot,"friendly_mana",real_snapshot.items.friendly_mana.center))
 var unsupported=Layout.build(Layout.recovered_items(3,7,{"custom_hero_frame":true}),camera,Vector2(vp.size),canvas,offset)
 assert(not unsupported.ready)
 assert(real_snapshot.items.friendly_hero.visual_polygon.size()>=4)
 assert(real_snapshot.items.friendly_play.actors[0].visual_polygon.size()>=4)
 for aspect in [1.5,16.0/9.0,2.04,21.0/9.0]:
  var size=Vector2(900.0*aspect,900.0);vp.size=Vector2i(size);CameraPolicy.apply(camera,cr,size)
  for count in range(1,8):
   var options={"aspect":aspect,"permanent_mana_count":10,"temporary_mana_count":2}
   var snap=Layout.build(Layout.recovered_items(count,count,options),camera,Vector2(vp.size),size,(size-Vector2(1600,900))*0.5)
   assert(snap.ready and snap.items.friendly_play.actors.size()==count)
   assert(snap.items.friendly_mana.crystals.size()==10)
   assert(not Layout.contains(snap,"end_turn",snap.items.end_turn.center))
 vp.size=Vector2i(2400,1080);CameraPolicy.apply(camera,cr,canvas)
 var empty=Layout.build({},camera,Vector2(vp.size),canvas,offset)
 assert(not empty.ready and empty.blockers.size()==Layout.REQUIRED.size())
 # Synthetic contract geometry tests only, not claimed original anchor data.
 var rows={};var c=Vector3(-7.72,0,-4.45)
 for key in Layout.REQUIRED:
  rows[key]={"verified":true,"source":"synthetic-test-only","center_world":c,"hit_polygon_world":[c+Vector3(-1,0,-1),c+Vector3(1,0,-1),c+Vector3(1,0,1),c+Vector3(-1,0,1)]}
 var snapshot=Layout.build(rows,camera,Vector2(vp.size),canvas,offset)
 assert(snapshot.ready)
 assert(Layout.contains(snapshot,"friendly_hero",snapshot.items.friendly_hero.center))
 assert(not Layout.contains(snapshot,"friendly_hero",snapshot.items.friendly_hero.center+Vector2(900,900)))
 rows.friendly_hero.blockers=["Custom-frame offset unresolved"]
 var blocked=Layout.build(rows,camera,Vector2(vp.size),canvas,offset)
 assert(not blocked.ready and not Layout.contains(blocked,"friendly_hero",snapshot.items.friendly_hero.center))
 camera.set_meta("native_phone_registered",false)
 assert(not Layout.build(rows,camera,Vector2(vp.size),canvas,offset).ready)
 vp.queue_free();print("SOURCE_PHONE_BOARD_LAYOUT_PASS: real source poses/colliders/visual bounds; counts1..7, aspects1.5/16:9/2.04/21:9, mana ordering/cap, endturn state, unsupported variants fail closed");quit()
