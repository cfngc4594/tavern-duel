extends RefCounted
## Source-derived HistoryManager/TileEntry event adapter. No presentation/log parsing.
## entries is newest-first, completed only. Inflight actions have stable serials.
## Source: CreatePlayedTile 0x060058fc, CreateAttackTile 0x060058fe,
## NotifyEntityAffected 0x0600590b, MarkCurrentHistoryEntryAsCompleted 0x06005901.
var entries: Array = []
var _pending: Dictionary = {}
var _order: Array = []
var _serial: int = 0
var generation: int = 0

func reset():
	entries.clear();_pending.clear();_order.clear();generation+=1
	# Never recycle IDs: late animation callbacks cannot complete a new match's action.

func begin_play(source: Dictionary, target: Dictionary = {}) -> int:
	return _begin(source,target,"played",1 if source.get("kind","")=="weapon" else 2)

func begin_attack(source: Dictionary, target: Dictionary) -> int:
	return _begin(source,target,"attack",3)

func _begin(source: Dictionary, target: Dictionary, kind: String, info_type: int) -> int:
	if source.get("key","")=="":return -1
	_serial+=1
	var snapshot=source.duplicate(true)
	if not snapshot.has("entity_id"):snapshot.entity_id="action:"+str(_serial)
	_pending[_serial]={"serial":_serial,"key":str(snapshot.key),"side":int(snapshot.get("side",0)),"kind":kind,"info_type":info_type,"source":snapshot,"target":target.duplicate(true),"affected":[],"complete":false,"baseline":{}}
	_order.append(_serial)
	return _serial

func current_serial() -> int:
	return int(_order.back()) if not _order.is_empty() else -1

func checkpoint(serial: int, snapshots: Array):
	if not _pending.has(serial):return
	for snapshot in snapshots:
		if snapshot.has("entity_id"):_pending[serial].baseline[str(snapshot.entity_id)]=snapshot.duplicate(true)

func affected(snapshot: Dictionary, serial: int = -1):
	if serial<0:serial=current_serial()
	if not _pending.has(serial) or snapshot.is_empty():return
	var entry: Dictionary=_pending[serial]
	var identity=str(snapshot.get("entity_id",""))
	if identity=="":return
	# Original NotifyEntityAffected deduplicates source, target, then affected records.
	for role in ["source","target"]:
		if str(entry[role].get("entity_id",""))==identity:
			entry[role].after=snapshot.duplicate(true)
			entry[role].died=bool(snapshot.get("dead",false))
			entry[role].damage_change=int(entry[role].get("hp",0))-int(snapshot.get("hp",0))
			return
	for item in entry.affected:
		if str(item.entity_id)==identity:
			item.after=snapshot.duplicate(true);item.died=bool(snapshot.get("dead",false));item.damage_change=int(item.get("hp",0))-int(snapshot.get("hp",0));return
	var before: Dictionary=entry.baseline.get(identity,snapshot).duplicate(true)
	before.after=snapshot.duplicate(true);before.died=bool(snapshot.get("dead",false))
	before.damage_change=int(before.get("hp",0))-int(snapshot.get("hp",0))
	entry.affected.append(before)

func complete(serial: int = -1, snapshots: Array = []):
	if serial<0:serial=current_serial()
	if not _pending.has(serial):return
	var entry: Dictionary=_pending[serial]
	var seen: Dictionary={}
	for snapshot in snapshots:
		var identity=str(snapshot.get("entity_id",""))
		if identity=="":continue
		seen[identity]=true
		if not entry.baseline.has(identity) or _changed(entry.baseline[identity],snapshot):affected(snapshot,serial)
	for identity in entry.baseline:
		if seen.has(identity) or snapshots.is_empty():continue
		var removed: Dictionary=entry.baseline[identity].duplicate(true)
		for role in ["source","target"]:
			if str(entry[role].get("entity_id",""))==str(identity) and entry[role].has("after"):removed=entry[role].after.duplicate(true)
		for item in entry.affected:
			if str(item.entity_id)==str(identity) and item.has("after"):removed=item.after.duplicate(true)
		removed.dead=true;removed.removed=true
		affected(removed,serial)
	entry.erase("baseline");entry.complete=true
	_pending.erase(serial);_order.erase(serial)
	entries.push_front(entry)
	# Completion order may differ for nested actions; source queue order is authoritative.
	entries.sort_custom(func(a,b):return int(a.serial)>int(b.serial))

func _changed(before: Dictionary, after: Dictionary) -> bool:
	for field in ["key","side","hp","max_hp","atk","armor","dead","frozen","shield"]:
		if before.get(field)!=after.get(field):return true
	return false

func drawn(key: String, side: int, hidden: bool = false, burned: bool = false):
	var serial=current_serial()
	if serial<0:return
	var entity_id="draw:"+str(serial)+":"+str(_pending[serial].affected.size())
	affected({"entity_id":entity_id,"key":"" if hidden else key,"side":side,"kind":"card","hidden":hidden,"drawn":true,"is_burned_card":burned},serial)
