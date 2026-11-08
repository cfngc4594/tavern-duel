extends SceneTree
class ClosedFlow extends RefCounted:
	func accepts_actions():return false
func _initialize():
	var h=load("res://scripts/native_history_events.gd").new()
	var a={"entity_id":"unit:1","key":"CS2_189","side":0,"kind":"minion","hp":1,"atk":1,"dead":false}
	var b={"entity_id":"unit:2","key":"CS2_189","side":1,"kind":"minion","hp":2,"atk":1,"dead":false}
	var id=h.begin_play(a,b);h.checkpoint(id,[a,b])
	assert(h.entries.is_empty())
	var hurt=b.duplicate(true);hurt.hp=1
	h.affected(hurt,id);h.affected(hurt,id);h.complete(id,[a,hurt]);h.complete(id,[a,hurt])
	assert(h.entries.size()==1 and h.entries[0].info_type==2)
	assert(h.entries[0].target.hp==2 and h.entries[0].target.after.hp==1)
	assert(h.entries[0].affected.is_empty())
	a.key="changed";assert(h.entries[0].key=="CS2_189")
	a.key="CS2_189"
	id=h.begin_attack(a,b);h.checkpoint(id,[a,b])
	var dead=a.duplicate(true);dead.hp=0;dead.dead=true
	h.affected(dead,id);h.complete(id,[b])
	assert(h.entries[0].info_type==3 and h.entries[0].source.died)
	assert(h.entries[0].key=="CS2_189" and h.entries[0].source.side==0)
	var old=id;h.reset();id=h.begin_play({"key":"CS2_056","side":1,"kind":"hero_power"})
	h.complete(old);assert(h.entries.is_empty());h.complete(id)
	assert(h.entries.size()==1 and h.entries[0].side==1 and h.entries[0].info_type==2)
	h.reset();id=h.begin_play(a);h.checkpoint(id,[a,b])
	var c=b.duplicate(true);c.entity_id="unit:3"
	h.complete(id,[a,hurt,c]);assert(h.entries[0].affected.size()==2)
	assert(h.entries[0].affected[0].entity_id!=h.entries[0].affected[1].entity_id)
	h.reset();id=h.begin_play({"key":"EX1_015","side":1,"kind":"minion"})
	h.drawn("SECRET_CARD",1,true);h.drawn("PUBLIC_CARD",0,false);h.complete(id)
	assert(h.entries[0].affected.size()==2 and h.entries[0].affected[0].key=="")
	assert(h.entries[0].affected[1].key=="PUBLIC_CARD")
	id=h.begin_play({"key":"TEST_WEAPON","side":0,"kind":"weapon"});h.complete(id)
	assert(h.entries[0].info_type==1)
	assert(h.begin_play({})==-1)
	var game=load("res://scripts/game.gd").new()
	game.flow=ClosedFlow.new();game.sound_enabled=false
	game.definitions={"CS2_189":{"kind":"minion"},"CS2_029":{"kind":"spell"}}
	game.health=[30,30];game.allies=[];game.enemies=[]
	assert(not game.play_card(0,Vector2.ZERO))
	game.busy=true;assert(not game.attack({},{}));game.busy=false
	assert(game.native_history_events.entries.is_empty())
	var target={"type":"hero","side":1}
	id=game._history_begin_play("CS2_029",0,target)
	game._damage(target,6);game._history_complete(id)
	assert(game.native_history_events.entries.size()==1)
	assert(game.native_history_events.entries[0].target.key=="HERO_07")
	assert(game.native_history_events.entries[0].target.damage_change==6)
	assert(game.native_history_events.entries[0].target.hp==30)
	assert(game.native_history_events.entries[0].target.after.hp==24)
	for side in range(2):
		for power in ["CS2_034","CS2_056"]:
			id=game._history_begin_play(power,side);game._history_complete(id)
			assert(game.native_history_events.entries[0].side==side)
			assert(game.native_history_events.entries[0].source.kind=="hero_power")
	game.native_history_events.reset()
	game._log("practice label","not a card",Color.WHITE)
	assert(game.native_history_events.entries.is_empty())
	game.free()
	print("NATIVE_HISTORY_EVENTS_PASS snapshots, targets, dedup, attacks, deaths, reset, powers, same-card entities")
	quit()
