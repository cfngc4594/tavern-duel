extends RefCounted
## Card.MillCardWithTiming (0x06012f45) and recovered HandFull Birth FSM.
## Separate source draw slots on each side; no rule/deck/hand mutation.
const FLIGHT=1.5
const HIDE_ACTOR=0.15000000596046448
const ASH_WAIT=3.4100000858306885
const LIFE=FLIGHT+HIDE_ACTOR+ASH_WAIT
static func blocks_draw(game,side:int,ticket:int)->bool:
 var flow=game.get("flow")
 if flow==null:return false
 var burns=flow.get("burn_cards")
 if burns==null:return false
 for burn in burns:
  if int(burn.side)!=side or int(burn.deck_count)<0:continue
  if str(burn.phase) in ["queued","flight"] and (ticket<0 or int(burn.ticket)<ticket):return true
 return false
static func prior_draw(game,side:int,ticket:int)->bool:
 if side==0:
  for card in game.cards:
   if not card.get("drawing",false) or card.get("source_draw_phase","")=="seat":continue
   if not card.has("source_draw_deck_count"):continue
   if int(card.get("source_draw_ticket",-1))<ticket:return true
 else:
  var hand=game._source_opposing_hand()
  if is_instance_valid(hand):
   for card in hand.draw_queue:
    if int(card.get("ticket",-1))<ticket:return true
 return false
static func advance(game,dt:float):
 var busy=[false,false]
 for burn in game.flow.burn_cards:
  if str(burn.phase)=="flight":busy[int(burn.side)]=true
 for burn in game.flow.burn_cards.duplicate():
  var side:int=burn.side
  if str(burn.phase)=="queued":
   if int(burn.deck_count)<0:
    burn.phase="blocked";burn.blocker="No source deck event; generated-card overflow route is not inferred"
   elif busy[side] or prior_draw(game,side,int(burn.ticket)):continue
   else:
    burn.phase="flight";busy[side]=true
    # One GameState field, not one gate per hero. active_turn is the local
    # presentation equivalent of source TURN (increments on every side turn).
    var turn:int=game.flow.active_turn
    var full:bool=game.cards.size()>=10 if side==0 else game.enemy_hand.size()>=10
    burn.remind_full_hand=false
    if full and turn!=game.flow.last_full_hand_reminder_turn:
     game.flow.last_full_hand_reminder_turn=turn;burn.remind_full_hand=true
  burn.age+=maxf(0.0,dt)
  if str(burn.phase)=="flight" and float(burn.age)>=FLIGHT:
   burn.phase="burning";busy[side]=false
  if float(burn.age)>=LIFE:game.flow.burn_cards.erase(burn)
