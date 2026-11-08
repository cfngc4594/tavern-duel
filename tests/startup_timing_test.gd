extends SceneTree
const Timing=preload("res://scripts/native_startup_timing.gd")
class FakeGame extends Node:
 var flow={"phase":"intro","phase_time":0.0}
 var native_initial_loading=true
 var help_visible=false
 var settings_visible=false
func _initialize():call_deferred("run")
func run():
 ProjectSettings.set_setting("diagnostics/startup_timing",false)
 var off=Timing.new();off.configure();off.begin("off");off.mark("off");off.once("off");off.end("off")
 assert(off.records.is_empty() and off.spans.is_empty() and off.observed.is_empty())
 var disabled_game=FakeGame.new();root.add_child(disabled_game)
 off.watch_game(disabled_game);off.arm_frame_window("disabled",disabled_game)
 assert(off.watched_tree==null and off.window_tree==null)
 assert(not RenderingServer.frame_pre_draw.is_connected(off._window_pre_draw))
 assert(not RenderingServer.frame_post_draw.is_connected(off._window_post_draw))
 disabled_game.queue_free()
 ProjectSettings.set_setting("diagnostics/startup_timing",true)
 var on=Timing.new();on.configure();on.begin("test_cpu","one");on.end("test_cpu","one");on.once("unique","one");on.once("unique","one")
 assert(on.records.size()==4 and on.spans.is_empty())
 assert(on.records[2].cpu_or_wall_ms>=0 and on.records[3].key=="one")
 var fake=FakeGame.new();root.add_child(fake);on.watch_game(fake)
 await process_frame
 fake.native_initial_loading=false;fake.flow.phase="mulligan"
 await process_frame
 await process_frame
 assert(on.watched_game==null and fake.flow.phase=="mulligan" and not fake.native_initial_loading)
 assert(on.observed.has("input_loading_gate_open_observed:"))
 await process_frame
 assert(on.window_label.is_empty())
 assert(not RenderingServer.frame_pre_draw.is_connected(on._window_pre_draw))
 assert(not RenderingServer.frame_post_draw.is_connected(on._window_post_draw))
 on.arm_frame_window("exit_cleanup",fake)
 assert(RenderingServer.frame_pre_draw.is_connected(on._window_pre_draw))
 # Invoke only diagnostic callbacks; this does not request rendering.
 for i in range(5):on._window_pre_draw();on._window_post_draw()
 assert(on.window_pre_count==2 and on.window_post_count==2)
 on.stop_watching()
 assert(on.window_tree==null and not RenderingServer.frame_post_draw.is_connected(on._window_post_draw))
 for row in on.records:
  if row.event=="frame_window_closed":assert(row.pre_samples<=2 and row.post_samples<=2)
 fake.queue_free();await process_frame
 var helper_source=FileAccess.get_file_as_string("res://scripts/native_startup_timing.gd")
 for forbidden in ["await ","force_draw(",".get_image(",".sync(","viewport_set_measure_render_time(","viewport_get_measured_render_time_gpu("]:
  assert(not helper_source.contains(forbidden))
 assert(load("res://scripts/game.gd")!=null)
 print("STARTUP_TIMING_TEST PASS disabled-no-records enabled-spans once game-parse")
 quit()
