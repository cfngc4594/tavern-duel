extends RefCounted
## Limited 2014 (build 5834) Mage/Warlock rules. Rendering and input stay in game.gd.
## All methods are synchronous; presentation may wrap them in an animation callback.
var game
var corruption: Array = []
# Minimal weapon state for Acidic Swamp Ooze; these two decks contain no weapons.
var weapons: Array = [{}, {}]

func reset():
	corruption.clear()
	weapons = [{}, {}]

func needs_target(key: String) -> bool:
	return key in ["CS2_029", "CS2_024", "CS2_022", "CS2_057", "CS2_061", "CS2_063", "EX1_302", "EX1_308", "NEW1_003"]

func legal_target(key: String, t: Dictionary, side: int) -> bool:
	if not needs_target(key): return t.is_empty()
	if not game._valid_character(t): return false
	if t.type == "hero" and game.health[t.side] <= 0: return false
	if t.type == "unit" and t.unit.hp <= 0: return false
	if key in ["CS2_022", "CS2_057", "EX1_302"]: return t.type == "unit"
	if key == "CS2_063": return t.type == "unit" and t.unit.side != side
	if key == "NEW1_003":
		return t.type == "unit" and game.definitions[t.unit.key].get("race", "") == "DEMON"
	return true

func _board(side: int) -> Array:
	return game.allies if side == 0 else game.enemies

func _hero(side: int) -> Dictionary:
	return {"type":"hero", "side":side, "pos":game.PLAYER_HERO if side == 0 else game.ENEMY_HERO}

func _target(u: Dictionary) -> Dictionary:
	return {"type":"unit", "unit":u, "pos":u.pos}

func _characters(side: int) -> Array:
	var result: Array = []
	if game.health[side] > 0: result.append(_hero(side))
	for u in _board(side):
		if not u.dead and u.hp > 0: result.append(_target(u))
	return result

func _heal(side: int, amount: int):
	var healed: int = mini(amount, maxi(0, 30 - int(game.health[side])))
	game.health[side] += healed
	if healed > 0:
		game.floats.append({"p":_hero(side).pos, "text":"+" + str(healed), "life":2.2, "max":2.2, "color":Color("8eff87")})
	game._event("heal_" + str(side) + "_" + str(healed))

func _finish():
	game._clear_dead()
	game._check_victory()

func _destroy(u: Dictionary):
	u.hp = 0
	u.dead = true
	u.death_pending = true

func _discard(side: int):
	var hand: Array = game.cards if side == 0 else game.enemy_hand
	if hand.is_empty(): return
	var index: int = game.flow.random.randi_range(0, hand.size() - 1)
	var key: String = hand[index].key if side == 0 else hand[index]
	hand.remove_at(index)
	game._event("discard_" + key)
	game._log("弃牌", game.definitions[key].name, Color("a98acb"))

func freeze_target(t: Dictionary):
	if not game._valid_character(t): return
	var side: int = t.side if t.type == "hero" else t.unit.side
	var own_turn: bool = (game.player_turn and side == 0) or (not game.player_turn and side == 1)
	if t.type == "unit":
		if t.unit.hp <= 0: return
		if not t.unit.frozen:
			t.unit.thaw_turn = game.side_turn[side] + (0 if own_turn and t.unit.ready else 1)
		t.unit.frozen = true
		t.unit.ready = false
	else:
		if not game.hero_frozen[side]: game.hero_thaw_turn[side] = game.side_turn[side] + (0 if own_turn else 1)
		game.hero_frozen[side] = true
	game._event("freeze")

func _transform_sheep(u: Dictionary):
	# Keep identity, controller, board position and attack exhaustion. Remove enchantments.
	var id: int = u.id
	corruption = corruption.filter(func(mark): return mark.id != id)
	var old_ready: bool = u.ready
	var old_sickness: bool = u.summoning_sick
	var old_attacks: int = int(u.get("attacks_used", 0 if old_ready or u.frozen else 1))
	var replacement: Dictionary = game._new_unit("CS2_tk1", u.side, u.pos)
	replacement.id = id
	replacement.target = u.target
	replacement.attacks_used = old_attacks
	replacement.ready = not old_sickness and old_attacks == 0
	replacement.summoning_sick = old_sickness
	u.clear()
	u.merge(replacement, true)
	game._event("transform_sheep")

func resolve_spell(key: String, t: Dictionary, side: int) -> bool:
	if needs_target(key) and not legal_target(key, t, side): return false
	if key=="CS2_027" and _board(side).size()>=7: return false
	match key:
		"CS2_029": game._damage(t, 6)
		"CS2_024":
			game._damage(t, 3)
			freeze_target(t)
		"CS2_022": _transform_sheep(t.unit)
		"CS2_023": game._draw_cards(2, side)
		"CS2_025", "CS2_032":
			var amount: int = 1 if key == "CS2_025" else 4
			for u in _board(1-side).duplicate():
				if not u.dead: game._damage(_target(u), amount)
		"CS2_026":
			for u in _board(1-side): freeze_target(_target(u))
		"CS2_027":
			for i in range(2):
				if _board(side).size() >= 7: break
				var p := Vector2(800, game.FRIEND_Y if side == 0 else game.ENEMY_Y)
				_board(side).append(game._new_unit("CS2_mirror", side, p))
			game._event("mirror_image")
		"EX1_277":
			for i in range(3):
				if game.health[1-side] <= 0: break
				var targets: Array = _characters(1-side)
				if targets.is_empty(): break
				var chosen: Dictionary = targets[game.flow.random.randi_range(0, targets.size()-1)]
				game._damage(chosen, 1)
				game._event("arcane_missile_" + str(i+1))
				game._clear_dead()
		"CS2_057": game._damage(t, 4)
		"CS2_061":
			game._damage(t, 2)
			_heal(side, 2)
		"CS2_062":
			# Damage the entire snapshot before resolving any deaths or victory.
			var targets: Array = _characters(0) + _characters(1)
			for target in targets: game._damage(target, 3)
		"CS2_063":
			corruption.append({"id":t.unit.id, "caster":side, "due":game.side_turn[side]+1})
			t.unit.corrupted = true
			game._event("corruption_attached")
		"EX1_302":
			game._damage(t, 1)
			if t.unit.hp <= 0: game._draw_cards(1, side)
		"EX1_308":
			game._damage(t, 4)
			_discard(side)
		"NEW1_003":
			_destroy(t.unit)
			_heal(side, 5)
		"GAME_005": game.flow.coin(side, _hero(side).pos)
		_: return false
	_finish()
	return true

func battlecry(u: Dictionary, target: Dictionary) -> bool:
	match u.key:
		"CS2_064":
			var targets: Array = _characters(0) + _characters(1)
			for t in targets:
				if t.type == "unit" and t.unit.id == u.id: continue
				game._damage(t, 1)
		"EX1_301":
			# Destroy an empty crystal first: cap current mana only if it exceeds the new maximum.
			if u.side == 0:
				game.max_mana = maxi(0, game.max_mana - 1)
				game.mana = mini(game.mana, game.max_mana)
			else:
				game.enemy_max_mana = maxi(0, game.enemy_max_mana - 1)
				game.enemy_mana = mini(game.enemy_mana, game.enemy_max_mana)
			game._event("destroy_mana_crystal")
		"EX1_066":
			weapons[1-u.side] = {}
			game._event("destroy_enemy_weapon")
		_: return false
	_finish()
	return true

func begin_turn(side: int):
	var due: Array = []
	var future: Array = []
	for mark in corruption:
		if mark.caster == side and game.side_turn[side] >= mark.due: due.append(mark)
		else: future.append(mark)
	corruption = future
	for mark in due:
		var u: Dictionary = game.unit_by_id(mark.id)
		if not u.is_empty() and not u.dead:
			_destroy(u)
			game._event("corruption_destroy")
	_finish()

func resolve_combat(u: Dictionary, t: Dictionary):
	# Snapshot damage and water-elemental properties before applying simultaneous combat.
	var damage: int = u.atk
	var retaliate: int = t.unit.atk if t.type == "unit" else 0
	var attacker_freezes: bool = u.key == "CS2_033"
	var defender_freezes: bool = t.type == "unit" and t.unit.key == "CS2_033"
	game._damage(t, damage)
	if retaliate > 0: game._damage(_target(u), retaliate)
	if attacker_freezes and damage > 0: freeze_target(t)
	if defender_freezes and retaliate > 0: freeze_target(_target(u))

func use_power(side: int) -> bool:
	# Caller owns legality, the 2-mana payment and once-per-turn latch.
	# CardDefs says draw + 2 damage; no claim of general trigger-engine completeness.
	game._draw_cards(1, side)
	game._damage(_hero(side), 2)
	game._event("life_tap")
	_finish()
	return true

func ai_target(key: String, side: int) -> Dictionary:
	if not needs_target(key): return {}
	var enemy: int = 1-side
	var candidates: Array = _characters(enemy)
	# Prefer minion targets for removal; aim direct damage at lethal hero first.
	if key in ["CS2_029", "CS2_024", "EX1_308", "CS2_061"]:
		var amount: int = {"CS2_029":6, "CS2_024":3, "EX1_308":4, "CS2_061":2}[key]
		if game.health[enemy] <= amount: return _hero(enemy)
	for t in candidates:
		if t.type == "unit" and legal_target(key, t, side):
			if key == "EX1_302" and t.unit.hp > 1: continue
			return t
	if key == "NEW1_003" and game.health[side] <= 25:
		for u in _board(side):
			var t: Dictionary = _target(u)
			if legal_target(key, t, side): return t
	for t in candidates:
		if legal_target(key, t, side): return t
	return {}
