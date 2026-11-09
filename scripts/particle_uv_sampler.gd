extends RefCounted
# Seek-local immutable UV corner tables. Unsupported tile grids use the original path.
# Recreated each seek so runtime module edits are reflected immediately.
const Curves=preload("res://scripts/native_summon_curves.gd")
const EPSILON=0.00000001
var uv_module:Dictionary
var tables:Array=[]
func setup(module:Dictionary)->bool:
	uv_module=module
	var cols:=1;var rows:=1
	if bool(module.get("enabled",false)) and int(module.get("mode",0))==0:
		cols=maxi(1,int(module.get("tilesX",1)));rows=maxi(1,int(module.get("tilesY",1)))
		if cols!=2 or rows!=2:return false
	for tile in cols*rows:
		var origin:=Vector2(tile%cols,int(tile/cols))/Vector2(cols,rows)
		for flip in 4:
			var corners:Array=[]
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				if flip&1:corner.x=1.0-corner.x
				if flip&2:corner.y=1.0-corner.y
				corners.append(origin+corner/Vector2(cols,rows))
			corners.make_read_only()
			tables.append(corners)
	tables.make_read_only()
	return true
func sample(p: Dictionary, age: float, speed: float) -> Array:

	var cols := 1; var rows := 1; var tile := 0
	if bool(uv_module.get("enabled", false)) and int(uv_module.get("mode", 0)) == 0:
		cols = maxi(1, int(uv_module.get("tilesX", 1))); rows = maxi(1, int(uv_module.get("tilesY", 1)))
		var normalized := age / float(p.life)
		var phase := normalized
		if int(uv_module.get("timeMode", 0)) == 1:
			var limits: Dictionary = uv_module.get("speedRange", {})
			phase = clampf((speed - float(limits.get("x", 0.0))) / maxf(EPSILON, float(limits.get("y", 1.0)) - float(limits.get("x", 0.0))), 0.0, 1.0)
		var frame_count := cols * rows if int(uv_module.get("animationType", 0)) == 0 else cols
		var frame := Curves.minmax(uv_module.get("frameOverTime", {}), phase, p.tile_mix) * float(uv_module.get("cycles", 1.0))
		if int(uv_module.get("timeMode", 0)) == 2: frame = age * float(uv_module.get("fps", 30.0)) / frame_count
		# Serialized UVModule values are normalized: the Unity inspector remaps
		# both curves by tilesX*tilesY (or tilesX for SingleRow).
		frame += Curves.minmax(uv_module.get("startFrame", {}), 0.0, p.tile_start_mix)
		tile = posmod(int(floor(frame * frame_count)), frame_count)
		if int(uv_module.get("animationType", 0)) == 1:
			var row := int(uv_module.get("rowIndex", 0))
			if int(uv_module.get("rowMode", 0)) == 1: row = mini(rows - 1, int(p.row_mix * rows))
			tile += clampi(row, 0, rows - 1) * cols
	var flip := (1 if float(p.flip_u)<float(uv_module.get("flipU",0.0)) else 0)+(2 if float(p.flip_v)<float(uv_module.get("flipV",0.0)) else 0)
	return tables[tile*4+flip]
