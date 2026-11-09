extends SceneTree
## Manual CPU microbenchmark, not a CI performance threshold or an FPS claim.
## Run: godot --headless --path . --script tests/mana_layout_cpu_benchmark.gd
const Layout=preload("res://scripts/source_phone_board_layout.gd")
const SAMPLES=240
const BATCH=10
func _initialize():call_deferred("run")
func run():
 var options={"aspect":16.0/9.0,"permanent_mana_count":4,"temporary_mana_count":1,"mana_tray_position":Vector3(1.2,3.4,5.6)}
 for i in 20:
  assert(Layout.recovered_items(0,0,options).friendly_mana==Layout.recovered_mana_items(options).friendly_mana)
 var samples={"full_layout":[],"mana_only":[]}
 for sample in SAMPLES:
  var results={}
  # Reverse A/B order on successive samples to reduce first/second bias.
  var order=["full_layout","mana_only"] if sample%2==0 else ["mana_only","full_layout"]
  for label in order:
   var result:Dictionary={}
   var started=Time.get_ticks_usec()
   for i in BATCH:
    result=Layout.recovered_items(0,0,options).friendly_mana if label=="full_layout" else Layout.recovered_mana_items(options).friendly_mana
   samples[label].append(float(Time.get_ticks_usec()-started)/BATCH)
   results[label]=result
  assert(results.full_layout==results.mana_only,"Mana layout output changed")
 print("MANA_LAYOUT_EQUIVALENCE_PASS samples=",SAMPLES," alternating_order=true")
 for label in samples:
  var values:Array=samples[label];values.sort();var total=0.0
  for value in values:total+=value
  print("MANA_LAYOUT_CPU ",label," mean_us=",total/SAMPLES," p50_us=",values[SAMPLES/2]," p95_us=",values[int(SAMPLES*.95)])
 print("SCOPE: one layout helper call only; excludes controller, renderer, particles, GPU, and total frame time")
 quit()
