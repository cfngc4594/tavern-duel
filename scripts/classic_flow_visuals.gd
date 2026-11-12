extends RefCounted
## Visual-only match-flow layer. No gameplay RNG, resource writes, or clock override.
## Geometry is measured against the source ledger; unobserved motion is labelled
## reconstruction rather than an original-client animation asset.
const BUTTON_CENTER = Vector2(1295,410)
const BUTTON_RECT = Rect2(1223,375,144,70)
const ROPE_LEFT = Vector2(332.5,420.8)
const ROPE_RIGHT = Vector2(1220.8,410.8)
const COIN_TOKEN_POS = Vector2(1120,456.7)
const COIN_CARD_POS = Vector2(1108,542)
const COIN_CARD_SCALE = 1.48
const COIN_PHASE_SECONDS = 0.6 + 1.51666668057442
const COIN_FLY_SECONDS = 1.0
const COIN_EFFECT_SECONDS = 4.90
var button_textures={"available":load("res://assets/original_flow_v20/end-turn-yellow.webp"),"complete":load("res://assets/original_flow_v20/end-turn-green.webp"),"enemy":load("res://assets/original_flow_v20/end-turn-gray.webp")}
var coin_texture = load("res://assets/original_flow_v20/coin_token.webp")
var game
var source_opening:Node
var source_coin:Node
var prepared_coin_assets:Dictionary={}
var source_birth_sent=false
var source_card_started=false
var coin_effects: Array = []
var button_previous = "disabled"
var button_current = "disabled"
var button_transition = 1.0
var button_hover = 0.0
var button_pressed = false
var button_press_depth = 0.0
var timeout_age = -1.0
var visual_time = 0.0
var last_turn_side = -1

func reset():
	_clear_source_opening()
	_clear_source_coin()
	coin_effects.clear();button_previous="disabled";button_current="disabled"
	button_transition=1;button_hover=0;button_pressed=false;button_press_depth=0
	timeout_age=-1;visual_time=0;last_turn_side=-1

func tick(dt: float):
	_tick_source_opening(dt)
	_tick_source_coin(dt)
	visual_time+=maxf(dt,0)
	for i in range(coin_effects.size()-1,-1,-1):
		coin_effects[i].age+=dt
		if coin_effects[i].age>COIN_EFFECT_SECONDS: coin_effects.remove_at(i)
	if timeout_age>=0:
		timeout_age+=dt
		if timeout_age>0.85: timeout_age=-1
	if game.flow.active():
		var side=0 if game.player_turn else 1
		if not is_instance_valid(game.native_rope_host) and last_turn_side>=0 and side!=last_turn_side and timeout_age<0 and is_instance_valid(game.flow.audio): game.flow.audio.button_flip()
		last_turn_side=side
	else: last_turn_side=-1
	var state=button_state()
	if state!=button_current:
		button_previous=button_current;button_current=state;button_transition=0
	button_transition=minf(1,button_transition+dt/0.30)
	var hot=state in ["available","complete"] and button_contains(game.pointer)
	button_hover=move_toward(button_hover,1.0 if hot else 0.0,dt*7)
	button_press_depth=move_toward(button_press_depth,1.0 if button_pressed and hot else 0.0,dt*14)
	if not hot or game.help_visible or game.settings_visible: button_pressed=false

func button_contains(point:Vector2)->bool:
	var context=game.get("source_projection")
	if context!=null and context.is_enabled():return game.source_phone_layout.contains("end_turn",point)
	return BUTTON_RECT.has_point(point)

func button_hit_rect() -> Rect2: return BUTTON_RECT

func has_available_actions() -> bool:
	if not game.flow.accepts_actions() or not game.player_turn or game.game_over or game.busy: return false
	if not game.power_used and game.mana>=2: return true
	for card in game.cards:
		if card.get("drawing",false) or card.get("returning",false): continue
		var d=game.definitions[card.key]
		if d.cost<=game.mana and (d.kind!="minion" or game.allies.size()<7): return true
	var targets: Array=[{"type":"hero","side":1,"pos":game.ENEMY_HERO}]
	for unit in game.enemies: targets.append({"type":"unit","unit":unit,"pos":unit.pos})
	for unit in game.allies:
		for target in targets:
			if game.legal_attack(unit,target): return true
	return false

func button_state() -> String:
	if game.flow.phase!="playing" or game.game_over: return "disabled"
	if not game.player_turn: return "enemy"
	if not game.flow.accepts_actions() or game.busy or not game.pending_battlecry.is_empty(): return "disabled"
	return "available" if has_available_actions() else "complete"

func button_sample() -> Dictionary:
	var switches_side=(button_previous=="enemy")!=(button_current=="enemy")
	var flip=absf(cos(button_transition*PI)) if switches_side and button_transition<1 else 1.0
	return {"state":button_current,"previous":button_previous,"hover":button_hover,"pressed":button_press_depth,"flip_scale":maxf(0.07,flip),"transition":button_transition,"switches_side":switches_side}

func press_button() -> bool:
	if button_state() not in ["available","complete"] or not button_contains(game.pointer): return false
	button_pressed=true
	return true

func release_button() -> bool:
	var commit=button_pressed and button_state() in ["available","complete"] and button_contains(game.pointer)
	button_pressed=false
	return commit

func rope_sample(seconds: float = -1.0) -> Dictionary:
	if seconds<0: seconds=game.turn_clock
	var elapsed=game.flow.ROPE_SECONDS-seconds
	var progress=clampf((elapsed-0.8)/(game.flow.ROPE_SECONDS-0.8),0,1)
	var entry=clampf(elapsed/0.8,0,1)
	var left=ROPE_LEFT;var right=ROPE_RIGHT
	var head=left.lerp(right,progress)
	return {"visible":game.flow.active() and seconds<=game.flow.ROPE_SECONDS,"progress":progress,"entry":entry,"left":left,"right":right,"head":head}

func timeout():
	timeout_age=0;button_pressed=false

func _button_outline(scale: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var points=PackedVector2Array([Vector2(-56,-20),Vector2(-45,-25),Vector2(-18,-28),Vector2(18,-28),Vector2(45,-25),Vector2(56,-20),Vector2(56,20),Vector2(44,25),Vector2(17,28),Vector2(-17,28),Vector2(-45,24),Vector2(-56,19)])
	for i in range(points.size()): points[i]*=scale
	return points

func _poly_line(points: PackedVector2Array,color: Color,width: float):
	game.draw_target.draw_polyline(points+PackedVector2Array([points[0]]),color,width,true)

var last_own_button_face: String = "yellow"

func button_source_state() -> String:
	# Click gating is not ownership: a busy friendly turn must not flip to the enemy face.
	if not game.player_turn: return "gray"
	var state=button_state()
	if state=="available": last_own_button_face="yellow"
	elif state=="complete": last_own_button_face="green"
	return last_own_button_face

func draw_button():
	var context=game.get("source_projection")
	if context!=null and context.is_enabled():return # Original 3D hierarchy in the shared camera pass.
	game.draw_target.draw_set_transform(Vector2.ZERO)
	if not is_instance_valid(game.native_turn_ui):return
	var source_state=button_source_state()
	var texture=game.native_turn_ui.get_animated_button_texture(source_state)
	if texture!=null:game.draw_target.draw_texture_rect(texture,Rect2(BUTTON_CENTER-Vector2(83,52),Vector2(166,104)),false)
	# Text is now native font36 atlas geometry on original front/back label nodes.

func draw_rope():
	var s=rope_sample()
	if not s.visible: return
	game.draw_target.draw_set_transform(Vector2.ZERO)
	var deploy_left=s.right.lerp(s.left,s.entry)
	var head=s.head if s.entry>=1 else deploy_left
	var right: Vector2=s.right
	# Cable follows the board seam and terminates in the left socket of the
	# turn button. It no longer crosses the lower row or overlays the plate.
	var pts=PackedVector2Array()
	var length=maxf(0,right.x-head.x)
	for i in range(81):
		var t=i/80.0;var p=head.lerp(right,t)
		p.y+=sin(t*PI)*2.5+sin(s.entry*PI)*sin(t*PI)*13
		pts.append(p)
	var shadow=PackedVector2Array()
	for p in pts: shadow.append(p+Vector2(0,3.4))
	game.draw_target.draw_polyline(shadow,Color(0.19,0.10,0.035,0.38),18,true)
	game.draw_target.draw_polyline(pts,Color("67502e"),12,true)
	game.draw_target.draw_polyline(pts,Color("c0a06c"),8.5,true)
	var n=int(length/9)
	for i in range(n):
		var t=(i*9.0+4.5)/maxf(length,1);var p=head.lerp(right,t)
		p.y+=sin(t*PI)*2.5+sin(s.entry*PI)*sin(t*PI)*13
		game.draw_target.draw_line(p+Vector2(-4.4,3.6),p+Vector2(3.8,-3.6),Color("e0c18a"),3.25,true)
		game.draw_target.draw_line(p+Vector2(0.0,4.0),p+Vector2(5.5,-2.7),Color("81663b"),2.1,true)
	if s.entry<1:
		# Original cable arrives as a rolling coil from the right-hand socket.
		var radius=24.0*(1-s.entry)+11.0
		game.draw_target.draw_arc(head+Vector2(-radius,0),radius,-PI*0.2,PI*1.65,42,Color("705632"),10,true)
		game.draw_target.draw_arc(head+Vector2(-radius,0),radius,-PI*0.2,PI*1.65,42,Color("d2b681"),5,true)
		return
	game._glow(head,25,Color("ffe291"),0.76)
	game._glow(head,12,Color("fff0b4"),0.9)
	for i in range(13):
		var age=fposmod(visual_time*1.8+i*0.137,1.0)
		var p=head+Vector2(sin(i*4.7)*age*19,-age*28+age*age*12)
		game.draw_target.draw_line(p,p+Vector2(sin(i*2.3)*3,-2),Color(1,0.75+age*0.20,0.25,1-age),1.4,true)
	game.draw_target.draw_circle(head,3.8+sin(visual_time*31)*0.8,Color("ffe8a6"))
	game.draw_target.draw_circle(head,1.8,Color("fffce7"))

func opening_position(index: int) -> Vector2:
	if is_instance_valid(source_opening):return source_opening.opening_position(index)
	return Vector2.INF

func opening_card_contains(index:int,point:Vector2)->bool:
	return is_instance_valid(source_opening) and source_opening.card_contains(index,point)

func opening_confirm_contains(point:Vector2)->bool:
	return is_instance_valid(source_opening) and source_opening.confirm_contains(point)

func intro_duration()->float:
	return preload("res://scripts/native_opening_presentation.gd").intro_duration()

func deal_delay(index: int) -> float:
	return preload("res://scripts/native_opening_presentation.gd").deal_delay(index)

func deal_duration() -> float:
	return preload("res://scripts/native_opening_presentation.gd").deal_duration(game.flow.first_side)

func replace_duration()->float:
	# Local server resolves IDs synchronously. Source presentation waits .5 per
	# outgoing/incoming launch and 1+1.5 after the incoming loop; no rules change.
	return float(game.flow.selected.size())+2.5

func opening_audio(event:String):
	if is_instance_valid(source_opening):source_opening.play_audio(event)

func draw_opening():
	# Only the original source-camera hierarchy draws this phase. Screenshot
	# banners, text VS, drawn X, fake particles and screen Beziers were removed.
	pass

func _clear_source_opening():
	if is_instance_valid(source_opening):source_opening.dispose();source_opening.queue_free()
	source_opening=null

func _tick_source_opening(dt:float):
	if game.headless:return
	if not game.flow.phase in ["intro","deal","mulligan","replace","coin","gather"]:
		if is_instance_valid(source_opening):_clear_source_opening()
		return
	if not is_instance_valid(source_opening):
		source_opening=preload("res://scripts/native_opening_presentation.gd").new();game.add_child(source_opening);source_opening.setup(game)
	source_opening.advance(dt)

func _draw_spell_blueprint(pose: Dictionary,amount: float):
	# Use the actual spell-card silhouette and its existing ornamental surface,
	# rather than an unrelated rectangular UI wireframe.
	game.draw_target.draw_set_transform(pose.pos,pose.angle,Vector2.ONE*pose.scale)
	var path=PackedVector2Array([Vector2(-77,-111),Vector2(-67,-118),Vector2(66,-118),Vector2(77,-108),Vector2(77,102),Vector2(67,109),Vector2(-67,109),Vector2(-77,102)])
	game.draw_target.draw_colored_polygon(path,Color(0.02,0.26,0.72,amount*0.42))
	if game.card_face_textures.has("GAME_005"):
		game.draw_target.draw_texture_rect(game.card_face_textures["GAME_005"],Rect2(-82,-121,164,242),false,Color(0.12,0.48,1,amount*0.56))
	for i in range(7,0,-1): _poly_line(path,Color(0.16,0.52,1,amount*0.022),i*2.7)
	_poly_line(path,Color(0.60,0.91,1,amount*0.8),1.8)
	var parchment=PackedVector2Array([Vector2(-65,39),Vector2(-57,30),Vector2(-22,25),Vector2(22,25),Vector2(57,30),Vector2(66,39),Vector2(65,98),Vector2(-65,98)])
	_poly_line(parchment,Color(0.55,0.87,1,amount*0.65),1.4)
	var ribbon=PackedVector2Array([Vector2(-73,-3),Vector2(-57,-12),Vector2(-23,-15),Vector2(23,-15),Vector2(57,-12),Vector2(73,-3),Vector2(68,12),Vector2(31,6),Vector2(-31,6),Vector2(-68,12)])
	_poly_line(ribbon,Color(0.63,0.93,1,amount*0.72),1.4)
	game.draw_target.draw_texture_rect(game.classic_ui.mana_crystal,Rect2(-88,-128,27,36),false,Color(0.28,0.72,1,amount))
	game.draw_target.draw_set_transform(Vector2.ZERO)

func draw_coin_grant():
	# Native source-camera layer owns this sequence. No blueprint, sine particles,
	# token cosine spin or rectangle flash fallback is drawn here.
	pass

func play_coin(side: int,source: Vector2):
	var base=game.max_mana if side==0 else game.enemy_max_mana
	var available=game.mana if side==0 else game.enemy_mana
	var crystals=mini(10,maxi(base,available))
	var slot=clampi(available-1,0,9)
	var target=Vector2(1114+slot*25,831) if side==0 else Vector2(1018,54)
	coin_effects.append({"age":0.0,"side":side,"source":source,"target":target,"slot":slot,"base":base,"overflow":available>base})

func coin_play_sample(effect: Dictionary) -> Dictionary:
	var t: float=effect.age
	var dissolve=clampf(t/0.68,0,1)
	var travel=clampf((t-2.24)/0.72,0,1)
	var form=smoothstep(2.24,2.60,t)*(1-smoothstep(4.15,4.70,t))
	var target: Vector2=effect.target
	return {"pos":effect.source,"target":target,"dissolve":dissolve,"travel":travel,"formation":form,"alpha":clampf((COIN_EFFECT_SECONDS-t)/0.50,0,1),"flash":smoothstep(0.34,0.40,t)*(1-smoothstep(0.52,0.64,t)),"shatter":clampf((t-0.68)/0.26,0,1)}

func mana_crystal_sample(index: int) -> Dictionary:
	var p=Vector2(1114+index*25,831);var angle=0.0;var alpha=1.0
	for effect in coin_effects:
		if effect.side!=0 or effect.slot!=index or not effect.overflow or game.mana<=game.max_mana: continue
		var t: float=effect.age
		alpha=smoothstep(2.56,2.68,t)
		var settle=smoothstep(2.60,2.96,t)
		p+=Vector2(5*(1-settle),12*(1-settle));angle=-1.15*(1-settle)
	return {"pos":p,"angle":angle,"alpha":alpha}

func draw_coin_effects():
	for effect in coin_effects:
		var s=coin_play_sample(effect);var t: float=effect.age
		var pose={"key":"GAME_005","pos":effect.source,"scale":0.78,"angle":0.0,"front":true}
		if t<0.68:
			var flicker=1.0 if t<0.06 else 0.1 if t<0.18 else smoothstep(0.18,0.36,t)
			_draw_spell_blueprint(pose,flicker)
			game.draw_target.draw_set_transform(effect.source,0,Vector2.ONE*0.78)
			# Broken internal light traces precede the opaque, card-shaped flash.
			for i in range(15):
				var a=Vector2(sin(i*8.1)*70,-108+fmod(i*31,216));var b=a+Vector2(sin(i*3.7)*40,18+fmod(i*7,25))
				game.draw_target.draw_line(a,b,Color(0.83,0.97,1,flicker*0.8),1.4,true)
			game.draw_target.draw_rect(Rect2(-77,-115,154,230),Color(0.94,0.99,1,s.flash))
			game.draw_target.draw_set_transform(Vector2.ZERO)
			game._glow(effect.source,86,Color("c9edff"),s.flash*0.45)
		elif t<1.10:
			for i in range(64):
				var a=i*2.399;var q=effect.source+Vector2(sin(i*7.3)*62,cos(i*5.1)*89)+Vector2(cos(a),sin(a))*s.shatter*65
				var r=1.1+fmod(i,4)*0.7
				var tri=PackedVector2Array([q+Vector2(-r,r),q+Vector2(r*0.7,r*0.5),q+Vector2(0,-r*1.6)])
				game.draw_target.draw_colored_polygon(tri,Color(0.68,0.91,1,clampf(1-(t-0.68)/0.42,0,1)))
		if s.formation>0 and game.flow.temporary_mana[effect.side]>0:
			if effect.side==0:
				for i in range(effect.base):
					var gem=Vector2(1114+i*25,831)
					game._glow(gem,19,Color("87f2ff"),s.formation*0.70)
			game._glow(s.target,22,Color("bb70ff"),s.formation*(0.55+0.22*sin(t*11)))
			game._glow(s.target,11,Color("f1cdff"),s.formation*0.8)
			for i in range(12):
				var a=i*2.399+t*4;var q=s.target+Vector2(cos(a)*14,sin(a)*10)
				game.draw_target.draw_circle(q,1.0+fmod(i,2),Color(0.83,0.58,1,s.formation*0.6))
	game.draw_target.draw_set_transform(Vector2.ZERO)


func _clear_source_coin():
	if is_instance_valid(source_coin):source_coin.set_active(false);source_coin.queue_free()
	source_coin=null;source_birth_sent=false;source_card_started=false

func prepare_source_coin_assets():
	if prepared_coin_assets.is_empty():
		prepared_coin_assets=load("res://scripts/native_coin_player.gd").prepare_assets()

func _advance_source_coin_piece(delta:float):
	if delta<=0 or not is_instance_valid(source_coin):return
	source_coin.advance_source(delta,float(game.elapsed))
	source_coin.advance_card(delta)

func _tick_source_coin(delta:float):
	if game.headless:return
	var phase:String=game.flow.phase
	var t:float=game.flow.phase_time
	if not phase in ["deal","mulligan","replace","coin","gather"]:
		if is_instance_valid(source_coin):_clear_source_coin()
		return
	if not is_instance_valid(source_coin):
		if phase=="deal" and t+delta<0.37:return
		source_coin=load("res://scripts/native_coin_presentation.gd").new();game.add_child(source_coin);source_coin.setup(game,prepared_coin_assets)
		source_coin.player.audio_enabled=game.sound_enabled
		source_coin.begin_source_drop(game.flow.first_side==0)
		if phase=="deal":delta=maxf(0,t+delta-maxf(t,0.37))
	if phase=="coin":
		if game.flow.first_side==0:
			source_coin.player.finish_coin_object()
			source_coin.set_active(false)
			return
		var cursor=t
		var end=t+delta
		if not source_birth_sent and end>=0.5:
			_advance_source_coin_piece(maxf(0,0.5-cursor));cursor=maxf(cursor,0.5)
			source_coin.begin_source_birth(game.sound_enabled);source_birth_sent=true
		if not source_card_started and end>=0.6:
			_advance_source_coin_piece(maxf(0,0.6-cursor));cursor=maxf(cursor,0.6)
			source_coin.begin_source_card();source_card_started=true
		_advance_source_coin_piece(maxf(0,end-cursor))
	elif phase=="gather":
		_advance_source_coin_piece(delta)
		if game.flow.first_side==1:
			if not source_coin.gather_started:source_coin.begin_hand_transition(game._resting_hand_pose(game.flow.first_hand_count,game.flow.first_hand_count+1))
			source_coin.sample_hand_transition(t+delta)
	else:_advance_source_coin_piece(delta)
