extends "res://scripts/game.gd"
## Benchmark-only clock adapter. Production game source is not copied or rewritten.
var last_process_usec:=0
func _process(_dt):
	var start:=Time.get_ticks_usec()
	super._process(1.0 / 60.0)
	last_process_usec=Time.get_ticks_usec()-start
