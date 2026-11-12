extends SceneTree

const Background := preload("res://scripts/native_endgame_background.gd")
const ARM_SETTING := "render_quality/android_fx_benchmark_arm"
const LITE_SETTING := "render_quality/terminal_background_lite"

class BoardScene extends Node3D:
	var camera: Camera3D

class Host extends Node:
	var headless := false
	var spatial_scene: BoardScene
	var world_canvas: Node2D
	var presentation_size := Vector2(2000, 900)
	var presentation_offset := Vector2(200, 0)
	var board_render_target_size := Vector2i(2000, 900)

func _initialize():
	call_deferred("run")

func run():
	var host := Host.new()
	root.add_child(host)
	host.world_canvas = Node2D.new()
	host.add_child(host.world_canvas)
	host.world_canvas.position = host.presentation_offset
	var viewport := SubViewport.new()
	viewport.size = host.board_render_target_size
	host.add_child(viewport)
	host.spatial_scene = BoardScene.new()
	viewport.add_child(host.spatial_scene)
	host.spatial_scene.camera = Camera3D.new()
	host.spatial_scene.add_child(host.spatial_scene.camera)
	host.spatial_scene.camera.current = true
	var effect := Background.new()
	host.add_child(effect)
	effect.setup(host)

	ProjectSettings.set_setting(LITE_SETTING, true)
	for arm in ["reference", "spell"]:
		ProjectSettings.set_setting(ARM_SETTING, arm)
		assert(not effect._use_lite_backdrop())
	ProjectSettings.set_setting(ARM_SETTING, "reference")
	assert(effect.begin() != null)
	assert(effect.get_audit().backdrop_viewports == 9)
	assert(effect.get_audit().live_result_viewports == 2)
	var original_board := effect.board_view
	var original_overlay := effect.overlay

	ProjectSettings.set_setting(LITE_SETTING, false)
	for arm in ["candidate", "endgame", "candidate_hero_lite"]:
		ProjectSettings.set_setting(ARM_SETTING, arm)
		assert(effect._use_lite_backdrop())
	assert(effect.begin() != null)
	assert(original_board.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	assert(not original_overlay.visible)
	var audit := effect.get_audit()
	assert(audit.backdrop_mode == "single_pass" and audit.backdrop_viewports == 0)
	assert(audit.live_result_viewports == 2 and audit.blockers.is_empty())
	assert(effect.layer.layer == 1 and effect.layer.get_child(0) is BackBufferCopy)
	assert(effect.layer.get_child(1) == effect.overlay)
	assert(effect.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(effect.overlay.material.get_shader_parameter("_HasResult"))
	assert(effect.overlay.material.get_shader_parameter("_VignetteMask") is Texture2D)
	effect.advance(0.25)
	assert(is_equal_approx(effect.overlay.material.get_shader_parameter("_BackdropAmount"), effect.amount))
	assert(effect.amount > 0.0 and effect.amount < 1.0)
	host.presentation_size = Vector2(1600, 900)
	host.board_render_target_size = Vector2i(1600, 900)
	effect.refresh_layout()
	assert(effect.result_view.size == host.board_render_target_size)
	assert(effect.overlay.size == host.presentation_size)
	assert(effect.get_audit().backdrop_viewports == 0)
	effect.release()
	assert(not effect.overlay.material.get_shader_parameter("_HasResult"))
	effect.advance(0.5)
	assert(effect.phase == "idle" and effect.layer == null)
	assert(effect.get_audit().live_result_viewports == 0)

	ProjectSettings.set_setting(ARM_SETTING, "")
	assert(not effect._use_lite_backdrop())
	ProjectSettings.set_setting(LITE_SETTING, true)
	assert(effect._use_lite_backdrop())
	host.queue_free()
	await process_frame
	print("TERMINAL_BACKGROUND_LITE_PASS reference=9 candidate=0 backdrop viewports, retained result layering, resize, fade and disposal")
	quit()
