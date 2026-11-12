extends RefCounted
## Normal local match lifecycle. Original source presentation is isolated from the local match rules.
## Practice fixtures stay separate. Match RNG never shares the cosmetic RNG stream.
const Cards = preload("res://scripts/classic_flow_cards.gd")
const NORMAL_TURN_SECONDS = 75.0
const ROPE_SECONDS = 20.0
var game
var audio
var visuals
var burn_audio_started=false
var mode = "practice"
var phase = "playing"
var phase_time = 0.0
var first_side = 0
var seat_choice = -1
var seed_value = 0
var random = RandomNumberGenerator.new()
var opening_hand: Array = []
var rejected: Array = []
var selected: Array[int] = []
var deal_announced = 0
var replacement_history: Array = []
var temporary_mana = [0,0]
var clock_last_ms = 0
var timeout_pending = false
var timeout_side = -1
var rope_started = false
var active_turn = 0
var enemy_draws: Array = []
var burn_cards: Array = []
var source_draw_ticket:int=0
var last_full_hand_reminder_turn:int=0
var burn_generation:int=0
var first_hand_count = 0
var enemy_power_used = false
var test_clock_delta = -1.0

func reset():
	if game!=null and is_instance_valid(game.native_rope_host):game.native_rope_host.reset()
	burn_generation+=1
	if game!=null and "native_history_events" in game: game.native_history_events.reset()
	if visuals!=null: visuals.reset()
	if is_instance_valid(audio): audio.stop()
	burn_audio_started=false
	mode="practice";phase="playing";phase_time=0;opening_hand.clear();rejected.clear();selected.clear();replacement_history.clear()
	temporary_mana=[0,0];timeout_pending=false;timeout_side=-1;rope_started=false;active_turn=0
	enemy_draws.clear();burn_cards.clear();last_full_hand_reminder_turn=0;enemy_power_used=false;test_clock_delta=-1
	clock_last_ms=Time.get_ticks_msec()

func show_menu():
	if game!=null and "native_history_events" in game: game.native_history_events.reset()
	burn_generation+=1;last_full_hand_reminder_turn=0
	burn_cards.clear();enemy_draws.clear()
	mode="menu";phase="menu";phase_time=0;game.cards.clear();game.allies.clear();game.enemies.clear();game.enemy_hand.clear();game.recent_log.clear()
	game.mana=0;game.max_mana=0;game.enemy_mana=0;game.enemy_max_mana=0;game.banner_time=0

func shuffle_cards(pile: Array):
	for i in range(pile.size()-1,0,-1):
		var j=random.randi_range(0,i)
		var value=pile[i];pile[i]=pile[j];pile[j]=value

func begin_normal(chosen_seat: int = -1, chosen_seed: int = -1):
	if game!=null and "native_history_events" in game: game.native_history_events.reset()
	burn_generation+=1;last_full_hand_reminder_turn=0
	burn_cards.clear();enemy_draws.clear()
	mode="normal";phase="intro";phase_time=0;seat_choice=chosen_seat
	if chosen_seed<0: random.randomize();seed_value=random.seed
	else: random.seed=chosen_seed;seed_value=chosen_seed
	first_side=chosen_seat if chosen_seat in [0,1] else random.randi_range(0,1)
	game.definitions.merge(Cards.additional_definitions(),true)
	for key in game.definitions: game.definitions[key].card_id=key
	game._ensure_card_face_textures()
	game.cards.clear();game.allies.clear();game.enemies.clear();game.enemy_hand.clear()
	game.deck=Cards.mage_deck_recipe();game.enemy_deck=Cards.warlock_deck_recipe()
	shuffle_cards(game.deck);shuffle_cards(game.enemy_deck)
	game.mana=0;game.max_mana=0;game.enemy_mana=0;game.enemy_max_mana=0
	game.turn=0;game.side_turn=[0,0];game.player_turn=first_side==0;game.banner_time=0;game.tutorial_hint=false
	first_hand_count=3 if first_side==0 else 4
	for i in range(first_hand_count): opening_hand.append(game.deck.pop_front())
	for i in range(4 if first_side==0 else 3): game.enemy_hand.append(game.enemy_deck.pop_front())
	# AI mulligan follows the same exclusion rule, keeping inexpensive cards.
	var enemy_rejected: Array=[]
	for i in range(game.enemy_hand.size()):
		if game.definitions[game.enemy_hand[i]].cost>=4:
			enemy_rejected.append(game.enemy_hand[i]);game.enemy_hand[i]=game.enemy_deck.pop_front()
	game.enemy_deck.append_array(enemy_rejected);shuffle_cards(game.enemy_deck)
	game.recent_log.clear()
	game._event("match_opening")

func toggle_mulligan(index: int):
	if phase!="mulligan" or index<0 or index>=opening_hand.size(): return
	if selected.has(index): selected.erase(index)
	else: selected.append(index)
	visuals.opening_audio("reject" if selected.has(index) else "keep");game._event("mulligan_toggle")

func confirm_mulligan():
	if phase!="mulligan": return
	selected.sort();rejected.clear();replacement_history.clear()
	# Remove all selected physical cards before drawing replacements; only then
	# return rejected cards to the deck. The other copy of an ID can still be drawn.
	for index in selected:
		rejected.append(opening_hand[index])
		var replacement=game.deck.pop_front()
		replacement_history.append({"index":index,"old":opening_hand[index],"new":replacement})
		opening_hand[index]=replacement
	game.deck.append_array(rejected);shuffle_cards(game.deck)
	phase="replace";phase_time=0;game._event("mulligan_confirm")

func finish_opening():
	if phase=="playing": return
	for key in opening_hand: game._add_card(key,false)
	if first_side==1: game._add_card("GAME_005",false)
	else: game.enemy_hand.append("GAME_005")
	# Carry the gather endpoint into the resting hand; do not recreate cards offscreen.
	for i in range(game.cards.size()):
		var pose=game._resting_hand_pose(i,game.cards.size())
		game.cards[i].pos=pose.pos;game.cards[i].scale=pose.scale;game.cards[i].angle=pose.angle
	phase="playing";phase_time=0;game._event("opening_complete")
	game._begin_normal_turn(first_side)

func begin_turn():
	if is_instance_valid(audio): audio.stop_rope()
	burn_audio_started=false
	timeout_pending=false;timeout_side=-1;rope_started=false;active_turn+=1
	game.turn_clock=NORMAL_TURN_SECONDS;clock_last_ms=Time.get_ticks_msec()
	if not game.player_turn: enemy_power_used=false

func active() -> bool:
	return phase=="playing" and not game.game_over

func accepts_actions() -> bool:
	return active() and not timeout_pending

func tick(dt: float):
	if visuals!=null: visuals.tick(dt)
	phase_time+=dt
	preload("res://scripts/native_hand_burn_timeline.gd").advance(game,dt)
	for list in [enemy_draws]:
		for i in range(list.size()-1,-1,-1):
			list[i].age+=dt
			if list[i].age>list[i].duration: list.remove_at(i)
	if phase=="intro" and phase_time>=visuals.intro_duration():
		phase="deal";phase_time=0;deal_announced=0
	elif phase=="deal":
		var shown=0
		for index in range(first_hand_count):
			if phase_time>=visuals.deal_delay(index): shown+=1
		if shown>deal_announced: game._event("opening_deal");deal_announced=shown
		if phase_time>=visuals.deal_duration(): phase="mulligan";phase_time=0;game._event("mulligan_begin")
	elif phase=="replace" and phase_time>=visuals.replace_duration():
		phase="coin";phase_time=0;game._event("opening_coin")
	elif phase=="coin" and phase_time>=(visuals.COIN_PHASE_SECONDS if first_side==1 else 0.35):
		phase="gather";phase_time=0
	elif phase=="gather" and phase_time>=visuals.COIN_FLY_SECONDS: finish_opening()

func tick_clock(visual_delta:float=-1.0):
	var now=Time.get_ticks_msec()
	var wall_delta=maxf(0,float(now-clock_last_ms)/1000.0)
	clock_last_ms=now
	if test_clock_delta>=0: wall_delta=test_clock_delta
	var source_rope=game.native_rope_host
	if not active():
		if is_instance_valid(source_rope):source_rope.tick(maxf(visual_delta,0) if visual_delta>=0 else wall_delta,wall_delta,false,game.turn_clock)
		return
	game.turn_clock=maxf(0,game.turn_clock-wall_delta)
	if is_instance_valid(source_rope):source_rope.tick(maxf(visual_delta,0) if visual_delta>=0 else wall_delta,wall_delta,true,game.turn_clock)
	if game.turn_clock<=ROPE_SECONDS and not rope_started:
		rope_started=true;game._event("rope_start")
		if not is_instance_valid(source_rope) and is_instance_valid(audio): audio.rope_start()
	if rope_started and game.turn_clock<=ROPE_SECONDS-0.8 and not burn_audio_started:
		burn_audio_started=true
		if not is_instance_valid(source_rope) and is_instance_valid(audio): audio.rope_burn()
	if game.turn_clock<=0:
		if not timeout_pending:
			timeout_pending=true;timeout_side=0 if game.player_turn else 1
			if visuals!=null: visuals.timeout()
			if not is_instance_valid(source_rope) and is_instance_valid(audio): audio.rope_timeout()
			game.cancel_interaction();game.mouse_down=false;game.pressed_card=-1
			game._event("turn_timeout");game.show_toast("时间到 · 当前动作结算后结束回合")
		# Committed damage/summons finish atomically. Uncommitted previews are
		# canceled above. Never kill a live tween and silently lose its effect.
		if not game.busy:
			if game.player_turn: game.end_turn(true)
			else: game._begin_player_turn()

func coin(side: int, source: Vector2 = Vector2(800,500)):
	if side==0:
		var gained=mini(1,10-game.mana);game.mana+=gained;temporary_mana[0]+=gained
	else:
		var gained=mini(1,10-game.enemy_mana);game.enemy_mana+=gained;temporary_mana[1]+=gained
	if not is_instance_valid(game.native_combat) or not game.native_combat.supports_spell("GAME_005"):visuals.play_coin(side,source)
	game.play_sound("mana_refresh");game._event("coin_play")

func next_draw_ticket()->int:
	source_draw_ticket+=1
	return source_draw_ticket

func _queue_burn(key:String,side:int,deck_count:int,ticket:int):
	if ticket<0:ticket=next_draw_ticket()
	burn_cards.append({"key":key,"side":side,"deck_count":deck_count,"ticket":ticket,"age":0.0,"phase":"queued","duration":preload("res://scripts/native_hand_burn_timeline.gd").LIFE})

func opponent_draw(key: String, burned: bool, deck_count:int=-1, ticket:int=-1):
	if burned:
		_queue_burn(key,1,deck_count,ticket);game._event("enemy_burn")
	else:
		enemy_draws.append({"age":0.0,"duration":0.7})
		if game.get("source_projection")==null:game.play_sound("draw")
		game._event("enemy_draw")

func player_burn(key: String, deck_count:int=-1, ticket:int=-1):
	_queue_burn(key,0,deck_count,ticket);game._event("player_burn")

func opening_position(index: int) -> Vector2:
	return visuals.opening_position(index)

func pointer_press() -> bool:
	if phase=="menu":
		for i in range(3):
			if Rect2(491+i*210,415,198,48).has_point(game.pointer): seat_choice=i-1;game.play_sound("click")
		if Rect2(570,500,460,70).has_point(game.pointer): game.start_match("normal",seat_choice);game.play_sound("click")
		elif Rect2(570,602,460,58).has_point(game.pointer): game.start_match("practice");game.play_sound("click")
		return true
	if phase=="mulligan":
		for i in range(first_hand_count):
			if visuals.opening_card_contains(i,game.pointer): toggle_mulligan(i);return true
		if visuals.opening_confirm_contains(game.pointer): confirm_mulligan()
		return true
	return phase!="playing"

func draw_ui():
	if phase=="playing":
		if not game.game_over and not game.help_visible and not game.settings_visible: _draw_transient_cards();visuals.draw_coin_effects()
		return
	game.draw_target.draw_set_transform(Vector2.ZERO)
	if phase=="menu": game.draw_target.draw_rect(Rect2(0,0,1600,900),Color(0.025,0.02,0.015,0.70))
	if phase=="menu":
		game._panel(Rect2(380,215,840,518),Color("30251b"),game.GOLD,24,3)
		game._text("酒馆对决",Vector2(800,305),54,game.CREAM,true)
		game._text("2014 经典规则 · 法师对术士",Vector2(800,350),21,game.GOLD,true)
		var labels=["随机先后手","我方先手","我方后手"]
		for i in range(3):
			game._button(Rect2(491+i*210,415,198,48),labels[i])
			if seat_choice==i-1: game.draw_target.draw_rect(Rect2(495+i*210,419,190,40),Color("83d8f3"),false,3)
		game._button(Rect2(570,500,460,70),"开始完整经典对局")
		game._button(Rect2(570,602,460,58),"进入4费练习场")
		game._text("法师17种 / 术士15种 · 每副30张 · 本地单机",Vector2(800,700),16,game.GOLD,true)
		return
	visuals.draw_opening()

func _draw_transient_cards():
	if game.get("source_projection")!=null:return # Source phone draw owns actual Card_Hidden; legacy burn overlay is not an original effect.
	for item in enemy_draws:
		var p=Vector2(1360,285).lerp(Vector2(800,20),clampf(item.age/0.65,0,1))
		game.draw_target.draw_set_transform(p,0.2*(1-item.age/0.7),Vector2.ONE*0.57);game._card_back(Rect2(-78,-116,156,232))
	# Full-hand burn is exclusively the recovered source actor/FSM.
	game.draw_target.draw_set_transform(Vector2.ZERO)

func draw_rope():
	if is_instance_valid(game.native_rope_host) and game.native_rope_host.enabled():return
	visuals.draw_rope()
