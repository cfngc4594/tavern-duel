extends RefCounted
## Presentation-only snapshots around the unchanged atomic historical rules.
## No target selection, damage, deaths, or rules RNG are executed by playback.
var game: Node
var capturing:=false
var playing:=false
var boards: Array=[]
var health: Array=[]
var steps: Array=[]
var current: Dictionary={}
var audio: Dictionary={}
var starts: Dictionary={}
var born: Array=[]
var pending_victory:=false
var index: int=-1
var hero_flashes: Array=[0.0,0.0]
var seen_born: Dictionary={}
func setup(owner_game: Node):game=owner_game
func begin():
 capturing=true;playing=true;steps.clear();current={};index=-1;born.clear();pending_victory=false;seen_born.clear();hero_flashes=[0.0,0.0]
 boards=[game.allies.duplicate(true),game.enemies.duplicate(true)];health=game.health.duplicate()
 starts={"floats":game.floats.size(),"particles":game.particles.size(),"death_ghosts":game.death_ghosts.size()}
func damage(target: Dictionary,amount: int):
 if not capturing:return
 if not current.is_empty():steps.append(current)
 current={"target":target.duplicate(true),"amount":amount,"boards":[],"health":[],"fx":{},"born":[],"logs":[]}
func settled():
 if not capturing or current.is_empty():return
 current.boards=[game.allies.duplicate(true),game.enemies.duplicate(true)];current.health=game.health.duplicate()
 current.born.append_array(born);born.clear()
 for name in starts:
  var values: Array=game.get(name)
  if not current.fx.has(name):current.fx[name]=[]
  current.fx[name].append_array(values.slice(int(starts[name])).duplicate(true))
  values.resize(int(starts[name]))
func record_born(id: int):
 if seen_born.has(id):return
 seen_born[id]=true;born.append(id)
func finish_capture():
 settled()
 if not current.is_empty():steps.append(current)
 current={};capturing=false
func show_step(which: int):
 if which<0 or which>=steps.size():return
 index=which
 var step: Dictionary=steps[which]
 var previous: Dictionary={}
 for board in boards:
  for unit in board:previous[unit.id]=unit
 var next_boards: Array=step.boards.duplicate(true)
 for board in next_boards:
  for i in range(board.size()):
   var unit: Dictionary=board[i]
   if previous.has(unit.id) and previous[unit.id].key==unit.key:
    var prior: Dictionary=previous[unit.id]
    for field in unit:
     if not str(field).begins_with("native_"):prior[field]=unit[field]
    board[i]=prior
 boards=next_boards;health=step.health.duplicate()
 if step.target.get("type","")=="hero":hero_flashes[int(step.target.side)]=1.0
 for log in step.logs:game._log(log.label,log.detail,log.color)
 for name in step.fx:game.get(name).append_array(step.fx[name].duplicate(true))
 if is_instance_valid(game.native_death):
  for event in step.get("death_voice_events",[]):game.native_death.present_voice(event)
 if is_instance_valid(game.native_damage):
  for item in step.get("dying_actors",[]):game.native_damage._retain_dead(item)
  for event in step.get("damage_splats",[]):game.native_damage.present(event)
 for id in step.born:
  for board in boards:
   for unit in board:
    if int(unit.id)==int(id):game.native_summon.begin(unit,{},"token")
func advance(delta: float):
 if not playing:return
 for i in range(2):hero_flashes[i]=maxf(0.0,float(hero_flashes[i])-delta*3.0)
 for board in boards:
  for unit in board:unit.flash=maxf(0.0,float(unit.flash)-delta*4.0)
func finish():
 playing=false;boards.clear();health.clear()
 if pending_victory:
  game._begin_endgame_presentation()
 pending_victory=false
func cancel():
 capturing=false;playing=false;boards.clear();health.clear();steps.clear();current={};born.clear();pending_victory=false
func get_audit() -> Dictionary:
 var entries: Array=[]
 for step in steps:
  entries.append({"target_type":step.target.get("type",""),"unit_id":step.target.get("unit",{}).get("id",-1),"side":step.target.get("side",-1),"amount":step.amount,"health":step.health.duplicate(),"unit_health":step.boards.map(func(b):return b.map(func(u):return {"id":u.id,"hp":u.hp}))})
 return {"playing":playing,"capturing":capturing,"visible_step":index,"steps":entries,"rules_resolutions":1 if not steps.is_empty() else 0}
