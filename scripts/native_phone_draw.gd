extends RefCounted
## Card.DrawFriendlyCardWithTiming default classic (no alternate draw-spell tag).
## Real Unity world endpoints required; this helper never guesses screen positions.
const Hand=preload("res://scripts/native_phone_hand.gd")
const ABOVE_DECK=Vector3(-0.30000001192092896,3.5999999046325684,0)
static func ease33(t:float)->float:
 # Decompiled iTween.easeInSineOutExpo compares value to START/2, not 0.5.
 # MoveTo path invokes (start=0,end=1,value), so every positive t uses OutExpo.
 if t<=0:return 0.0
 return 1.0 if t>=1 else 1.0-pow(2.0,-10.0*t)
static func ease15(t:float)->float:
 return 0.0 if t<=0 else pow(2.0,10.0*(minf(t,1.0)-1.0))
static func spline3(a:Vector3,b:Vector3,c:Vector3,t:float)->Vector3:
 var u=clampf(t,0,1)*2.0
 var p0:Vector3;var p1:Vector3;var p2:Vector3;var p3:Vector3
 if u<1:p0=a+(a-b);p1=a;p2=b;p3=c
 else:u-=1;p0=a;p1=b;p2=c;p3=c+(c-b)
 return .5*(2*p1+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)
static func flight(start:Vector3,finish:Vector3,finish_scale:Vector3,age:float,time_scale:float=1.0)->Dictionary:
 var t=age/maxf(time_scale,.00001)
 return {"position":spline3(start,start+ABOVE_DECK,finish,ease33(t/1.5)),"rotation":Hand.lerp_source_angles(Vector3(270,270,0),Vector3(0,0,357),Hand.source_ease(clampf((t-.15000000596046448)/1.350000023841858,0,1))),"scale":(Vector3.ONE*.8799999952316284).lerp(finish_scale,Hand.source_ease(clampf((t-.15000000596046448)/.75,0,1)))}
static var endpoints:Dictionary={}
static func thickness(count:int)->String:
 if count<=1:return "1"
 if count/26.0>.75:return "Full"
 if count/26.0>.5:return "75"
 if count/26.0>.25:return "50"
 return "25"
static func time_scale(tracker:int,fast_option:bool=false)->float:
 if fast_option or tracker>6:return .5559999942779541
 if tracker<3:return 1.0
 return 1.0-.11100000143051147*(tracker+1-3)
static func layout_count(cards:Array)->int:
 var count=0
 for card in cards:
  if not card.get("drawing",false) or card.get("source_draw_phase","")=="seat":count+=1
 return count
static func advance(game,dt:float):
 if endpoints.is_empty():endpoints=JSON.parse_string(FileAccess.get_file_as_string("res://assets/native_cards/phone_deck_runtime.json")).rows
 var next_dt=dt
 var flight_active=false
 for card in game.cards:
  if card.get("source_draw_phase","")=="flight":flight_active=true
 for i in game.cards.size():
  var card:Dictionary=game.cards[i]
  if not card.get("drawing",false):continue
  if not card.has("source_draw_deck_count"):
   card.source_phone_hidden=true;continue # No source deck event metadata, never infer.
  var phase=str(card.get("source_draw_phase","queued"))
  var step=dt
  if phase=="queued":
   card.source_phone_hidden=true
   if flight_active or preload("res://scripts/native_hand_burn_timeline.gd").blocks_draw(game,0,int(card.get("source_draw_ticket",-1))):continue
   if not card.get("announced",true):
    card.announced=true;game.play_sound("draw");game._event("draw_depart")
   step=next_dt
   phase="flight";card.source_draw_phase=phase;card.source_draw_age=0.0;flight_active=true
   card.source_draw_start=Hand.vector(endpoints["Zone_Friendly_Deck:m_Tickness"+thickness(int(card.source_draw_deck_count))+"TopOfDeck"].phone_world_position)
   card.source_draw_time_scale=time_scale(int(card.get("source_draw_tracker",0)),bool(card.get("source_fast_draw",false)))
  if phase=="flight":
   card.source_phone_hidden=false;card.source_draw_age+=step
   var finish=endpoints.FriendlyDrawCard
   var pose=flight(card.source_draw_start,Hand.vector(finish.phone_world_position),Hand.vector(finish.phone_local.scale),card.source_draw_age,card.source_draw_time_scale)
   game._publish_source_hand_pose(card,pose)
   if card.source_draw_age<1.5*card.source_draw_time_scale:continue
   next_dt=maxf(0.0,card.source_draw_age-1.5*card.source_draw_time_scale)
   card.source_draw_seat_step=next_dt
   card.source_draw_phase="seat";card.source_draw_seat_age=0.0;flight_active=false
   var count=layout_count(game.cards)
   var target=game.native_phone_hand.source_pose(i,count)
   card.source_phone_transition={"generation":game.native_phone_hand.generation,"count":count,"age":0.0,"from":pose.duplicate(true),"pose":pose.duplicate(true),"target":target,"duration":0.5,"other_duration":0.5,"ease_type":15}
  elif phase=="seat":
   card.source_draw_seat_age+=dt
   if card.source_draw_seat_age>=.30000001192092896:
    card.drawing=false;game._event("draw_seated")
