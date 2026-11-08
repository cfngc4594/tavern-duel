extends RefCounted
## Exact RGBA8 acceleration. Image bytes and legacy feather arithmetic are retained.
static var plans:Dictionary={}
static var roundtrip_checked:bool=false
static var roundtrip_ok:bool=false

static func legacy(cell:Image)->void:
	for y in range(cell.get_height()):
		for x in range(cell.get_width()):
			var uv = (Vector2(x, y) / Vector2(cell.get_size()) - Vector2(0.5, 0.5)) * 2.0
			var col = cell.get_pixel(x, y)
			col.a *= clampf((1.0 - uv.length()) * 100.0, 0.0, 1.0)
			cell.set_pixel(x, y, col)

static func _roundtrip_is_exact()->bool:
	if roundtrip_checked:return roundtrip_ok
	roundtrip_checked=true
	var bytes:=PackedByteArray();bytes.resize(256*4)
	for i in range(256):
		bytes[i*4]=i;bytes[i*4+1]=255-i;bytes[i*4+2]=(i*73)%256;bytes[i*4+3]=i
	var probe:=Image.create_from_data(256,1,false,Image.FORMAT_RGBA8,bytes)
	for x in range(256):
		var color:Color=probe.get_pixel(x,0);color.a*=1.0;probe.set_pixel(x,0,color)
	roundtrip_ok=probe.get_data()==bytes
	return roundtrip_ok

static func _plan(width:int,height:int)->Dictionary:
	var key:=Vector2i(width,height)
	if plans.has(key):return plans[key]
	if plans.size()>=16:return {}
	var outside:=PackedInt32Array();var feather:=PackedInt32Array()
	for y in range(height):
		for x in range(width):
			var uv = (Vector2(x, y) / Vector2(width,height) - Vector2(0.5, 0.5)) * 2.0
			var factor:float=clampf((1.0 - uv.length()) * 100.0, 0.0, 1.0)
			if factor==0.0:outside.append((y*width+x)*4+3)
			elif factor!=1.0:feather.append(y*width+x)
	var result:Dictionary={"outside":outside,"feather":feather}
	result.make_read_only();plans[key]=result
	return result

static func apply(cell:Image)->void:
	var width:int=cell.get_width();var height:int=cell.get_height()
	if cell.get_format()!=Image.FORMAT_RGBA8 or cell.has_mipmaps() or width<=0 or height<=0 or width*height>1048576 or not _roundtrip_is_exact():
		legacy(cell);return
	var plan:Dictionary=_plan(width,height)
	if plan.is_empty():legacy(cell);return
	var bytes:PackedByteArray=cell.get_data()
	if bytes.size()!=width*height*4:legacy(cell);return
	for alpha_index in plan.outside:bytes[alpha_index]=0
	cell.set_data(width,height,false,Image.FORMAT_RGBA8,bytes)
	for index in plan.feather:
		var x:int=index%width
		var y:int=index/width
		var uv = (Vector2(x, y) / Vector2(cell.get_size()) - Vector2(0.5, 0.5)) * 2.0
		var col = cell.get_pixel(x, y)
		col.a *= clampf((1.0 - uv.length()) * 100.0, 0.0, 1.0)
		cell.set_pixel(x, y, col)
