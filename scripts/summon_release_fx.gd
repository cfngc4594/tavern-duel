extends Node2D
## Visual reconstruction from the preserved 2013 30 fps reference, not original assets.
## Absolute-age sampling avoids frame-rate-dependent emission and gameplay RNG changes.
var game: Node
const CYAN = Color(0.10,0.52,1.0)
const WHITE = Color(0.72,0.96,1.0)

func setup(owner_game: Node):
	game = owner_game
	var additive = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

static func noise(n: float) -> float:
	return fposmod(sin(n*127.1+311.7)*43758.5453123,1.0)

static func phase_values(age: float) -> Dictionary:
	return {"release_flash":exp(-pow((age-0.065)/0.026,2.0))*smoothstep(0.0,0.025,age),"surface":smoothstep(0.06,0.28,age)*(1.0-smoothstep(1.00,1.045,age)),
		"shell":smoothstep(0.99,1.025,age)*(1.0-smoothstep(1.14,1.36,age)),
		"oval":smoothstep(1.16,1.29,age)*(1.0-smoothstep(1.56,1.83,age)),
		"contact":smoothstep(1.38,1.50,age)*(1.0-smoothstep(1.55,1.84,age))}

static func surface_particles(age: float) -> Array:
	var values=phase_values(age)
	var result=[]
	if values.surface<=0.0:return result
	# Short lived irregular chips sparkle across the face and its narrow perimeter.
	# Most remain on the card; a small minority drift just beyond its left/right lip.
	for i in range(76):
		var cycle=0.19+noise(i+70.0)*0.28
		var clock=age-0.055-noise(i+19.0)*0.18
		if clock<0.0:continue
		var generation=floor(clock/cycle)
		var t=fposmod(clock,cycle)/cycle
		var seed=float(i)+generation*91.7
		var x=lerpf(-73.0,73.0,noise(seed+9.0))
		var y=lerpf(-106.0,105.0,noise(seed+22.0))
		if i%4==0:x=(-1.0 if i%8==0 else 1.0)*(74.0+t*8.0);y=lerpf(-102.0,104.0,noise(seed+47.0))
		var a=sin(PI*t)*values.surface*(1.0-0.68*smoothstep(0.30,0.65,age))*(0.30+noise(seed+4.0)*0.70)
		result.append({"p":Vector2(x,y-t*(3.0+noise(seed+55.0)*8.0)),"size":Vector2(0.8+noise(seed+1.0)*2.2,1.1+noise(seed+2.0)*3.2),"angle":noise(seed+3.0)*TAU+t*1.1,"alpha":a,"white":i%3==0})
	return result

static func landing_particles(age: float) -> Array:
	var result=[]
	var clock=age-1.40
	if clock<0.0:return result
	# The source is a tight rim-breakup, not long radial fireworks or brown dust.
	for i in range(35):
		var delay=noise(i+100.0)*0.075
		var life=0.19+noise(i+101.0)*0.20
		var t=clock-delay
		if t<0 or t>life:continue
		var a=TAU*noise(i+103.0)
		var origin=Vector2(cos(a)*48.0,sin(a)*61.0)
		var velocity=Vector2(cos(a)*(18.0+noise(i+104.0)*50.0),-45.0-noise(i+105.0)*68.0+sin(a)*25.0)
		result.append({"p":origin+velocity*t+Vector2(0,90*t*t),"size":Vector2(1.7+noise(i+106.0)*2.8,2.0+noise(i+107.0)*5.5),"angle":a+t*4.0,"alpha":pow(1.0-t/life,0.65),"white":i%5!=0,"warm":i%5==0})
	return result

func _process(_dt):queue_redraw()

func _draw():
	if not is_instance_valid(game):return
	if game.help_visible or game.settings_visible:return
	for c in game.staged_cards:
		if not c.has("release_started"):continue
		var age=maxf(0.0,game.elapsed-float(c.release_started))
		var values=phase_values(age)
		if values.values().all(func(v):return float(v)<=0.00001):continue
		var pose=game.selected_card_face_pose(c)
		draw_set_transform(pose.pos+game.shake_offset,pose.angle,pose.scale)
		if values.release_flash>0.005:
			draw_colored_polygon(game._card_surface_outline(),Color(0.23,0.54,0.72,values.release_flash*0.50))
		if values.surface>0:
			_draw_surface(c,age,values.surface)
		if values.shell>0:
			_draw_shell(c,values.shell)
		# The raised oval has its own light ribbon; the discarded card shell does not
		# keep a second shadow or become a permanent readiness indicator.
		var u=game.unit_by_id(int(c.get("release_unit",-1)))
		if u.is_empty():continue
		draw_set_transform(u.pos+Vector2(0,-float(u.get("lift",0.0)))+game.shake_offset,float(u.rotation),Vector2.ONE*float(u.scale)*0.9)
		if values.oval>0:_draw_oval(age,values.oval,values.contact)
		for p in landing_particles(age):_chip(p,Color(1.0,0.91,0.58) if p.warm else (WHITE if p.white else CYAN))
	draw_set_transform(Vector2.ZERO)

func _draw_surface(c: Dictionary,age: float,strength: float):
	# Broad low-energy bloom plus irregular filaments; never a uniformly white slab.
	var paths=game.held_card_rim_paths(true)
	for path in paths:
		for width in [20.0,13.0,8.0]:draw_polyline(path,Color(CYAN,0.016*strength),width,true)
		for i in range(path.size()-1):
			var a=strength*(0.10+0.16*pow(0.5+0.5*sin(age*21.0+i*2.53),3.0))
			draw_line(path[i],path[i+1],Color(WHITE,a),2.5,true)
	# Portrait rim carries the same cold light, leaving the dark art readable.
	var portrait=[]
	for i in range(55):
		var a=TAU*i/54.0
		portrait.append(Vector2(cos(a)*53.0,sin(a)*67.0-45.0))
	draw_polyline(PackedVector2Array(portrait),Color(CYAN,0.29*strength),3.4,true)
	for p in surface_particles(age):_chip(p,WHITE if p.white else CYAN)

func _draw_shell(c: Dictionary,strength: float):
	# Filled card envelope with a portrait-sized hole, rather than a transparent
	# card-art crossfade over the newly revealed oval.
	var outer=game._card_surface_outline()
	var center=Vector2(2,-48)
	var inner=PackedVector2Array()
	for p in outer:
		var d=p-center
		var k=1.0/sqrt(pow(d.x/53.0,2)+pow(d.y/70.0,2))
		inner.append(center+d*k)
	for i in range(outer.size()):
		var j=(i+1)%outer.size()
		for tri in [PackedVector2Array([outer[i],outer[j],inner[j]]),PackedVector2Array([outer[i],inner[j],inner[i]])]:
			if absf((tri[1]-tri[0]).cross(tri[2]-tri[0]))>0.01:
				var colors=PackedColorArray()
				for point in tri:
					var near_edge=point.distance_to(center)>80.0
					colors.append(Color(0.20,0.62,1.0,(0.105 if near_edge else 0.025)*strength))
				draw_polygon(tri,colors)
	for path in game.held_card_rim_paths(true):
		for width in [22.0,14.0,8.0]:draw_polyline(path,Color(CYAN,0.04*strength),width,true)
		var rim_colors=PackedColorArray()
		for point in path:
			var a=0.60+0.35*sin(point.y*0.22+point.x*0.16+game.elapsed*14.0)
			rim_colors.append(Color(WHITE,(0.45+0.40*a)*strength))
		draw_polyline_colors(path,rim_colors,3.5,true)

func _draw_oval(age: float,strength: float,contact: float):
	var path=PackedVector2Array()
	var colors=PackedColorArray()
	for i in range(73):
		var a=TAU*i/72.0
		var ripple=sin(a*13.0-age*31.0)*1.4+sin(a*23.0+age*47.0)*0.8
		path.append(Vector2(cos(a)*(47.0+ripple),sin(a)*(61.0+ripple)))
		var pulse=0.43+0.57*pow(0.5+0.5*sin(a*7.0+age*27.0),2.0)
		var lower=0.70+0.45*smoothstep(-0.7,0.6,sin(a))
		colors.append(Color(CYAN.lerp(WHITE,pulse*0.18),strength*pulse*lower))
	for width in [18.0,12.0]:draw_polyline(path,Color(CYAN,0.055*strength),width,true)
	draw_polyline_colors(path,colors,9.0+contact*2.0,true)
	# Uneven white/warm lobes cluster above and along the sides during contact.
	if contact>0:
		for i in range(19):
			var a=lerpf(-PI*1.07,0.12,noise(i+330.0))
			var r=5.0+noise(i+331.0)*7.0
			var p=Vector2(cos(a)*52.0,sin(a)*70.0-3.0)
			var pulse=0.5+0.5*sin(age*37.0+i*5.3)
			for layer in range(3,0,-1):
				draw_circle(p,r*layer*0.60,Color(0.95,0.91,0.69,contact*(0.15+0.12*pulse)/layer))
	for i in range(38):
		var a=TAU*noise(i+208.0)+age*(0.16 if i%2==0 else -0.12)
		var p={"p":Vector2(cos(a)*(46.0+sin(age*35+i)*3.0),sin(a)*(60.0+sin(age*31+i)*3.0)),"size":Vector2(1.4+noise(i+209.0)*2.0,2.0+noise(i+210.0)*3.4),"angle":a+age*0.8,"alpha":strength*(0.35+0.65*pow(0.5+0.5*sin(age*40+i*2.9),3.0))}
		_chip(p,WHITE if i%7==0 else CYAN)

func _chip(p: Dictionary,color: Color):
	var s: Vector2=p.size
	var pos: Vector2=p.p
	var angle: float=p.angle
	var points=PackedVector2Array()
	for q in [Vector2(-s.x,-s.y*0.28),Vector2(s.x*0.45,-s.y),Vector2(s.x,s.y*0.25),Vector2(-s.x*0.65,s.y)]:points.append(pos+q.rotated(angle))
	draw_colored_polygon(points,Color(color,float(p.alpha)))
	# A restrained halo around the larger luminous chips, no opaque round confetti.
	if maxf(s.x,s.y)>2.6:draw_circle(pos,maxf(s.x,s.y)*1.5,Color(CYAN,float(p.alpha)*0.045))
