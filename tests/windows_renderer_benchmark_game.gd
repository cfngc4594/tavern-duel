extends "res://scripts/game.gd"
## Benchmark-only clock adapter. Production game source is not copied or rewritten.
func _process(_dt):
	super._process(1.0 / 60.0)
