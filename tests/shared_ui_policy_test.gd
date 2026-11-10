extends SceneTree
const Policy=preload("res://scripts/source_board_camera_policy.gd")
class Host extends Node:
 enum Interaction {IDLE,PLACEMENT_PREVIEW}
 var presentation_size=Vector2(1600,900)
 var presentation_offset=Vector2.ZERO
 var board_render_target_size=Vector2i(1600,900)
 var flow={"temporary_mana":[0,0]}
 var max_mana=4
 var player_turn=true
 var interaction_state=Interaction.IDLE
 var preview_index=0
 var pending_battlecry={}
 var allies=[]
 var enemies=[]
func _initialize():call_deferred("run")
func run():
 assert(not Policy.qa_phone_platform)
 assert(Policy.source_ui_requested())
 assert(not Policy.source_ui_enabled()) # Readiness remains mandatory.
 var host=Host.new();root.add_child(host)
 var controller=preload("res://scripts/source_phone_layout_controller.gd").new();host.add_child(controller)
 controller.setup(host)
 assert(controller.enabled and controller.context!=null)
 assert(Policy.source_ui_enabled())
 assert(controller.contains("friendly_hero",controller.snapshot.items.friendly_hero.center))
 var mobile=OS.has_feature("android") or OS.has_feature("ios")
 assert(Policy.phone_platform_requested()==mobile) # Never impersonate touch hardware.
 ProjectSettings.set_setting("native_ui/shared_source_ui",false)
 controller.refresh();assert(controller.enabled==mobile)
 ProjectSettings.set_setting("native_ui/shared_source_ui",true)
 controller.refresh();assert(controller.enabled)
 ProjectSettings.set_setting("native_mobile/source_consumers_verified",false)
 controller.refresh();assert(not controller.enabled and controller.context==null)
 assert(not Policy.source_ui_enabled())
 ProjectSettings.set_setting("native_mobile/source_consumers_verified",true)
 controller.refresh();assert(controller.enabled and controller.context!=null)
 assert(FileAccess.get_file_as_string("res://scripts/game.gd").contains('if OS.has_feature("android") or OS.has_feature("ios"): return'))
 print("SHARED_UI_POLICY_PASS production default, explicit compatibility opt-out, atomic readiness, and unchanged real platform identity")
 host.queue_free();await process_frame;quit()
