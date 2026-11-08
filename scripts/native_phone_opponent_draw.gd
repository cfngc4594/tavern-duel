extends RefCounted
## Card.<DrawUnknownOpponentCard>d__514.MoveNext 0x06012f2d, default hidden path.
const Hand=preload("res://scripts/native_phone_hand.gd")
const Draw=preload("res://scripts/native_phone_draw.gd")
static func ease_in_out(t:float,power:int)->float:
 t=clampf(t,0,1)
 return pow(2*t,power)*.5 if t<.5 else 1-pow(2*(1-t),power)*.5
static func spline4(a:Vector3,b:Vector3,c:Vector3,d:Vector3,t:float)->Vector3:
 var points=[a+(a-b),a,b,c,d,d+(d-c)]
 var u=clampf(t,0,1)*3;var segment=mini(int(u),2);u-=segment
 var p0:Vector3=points[segment];var p1:Vector3=points[segment+1];var p2:Vector3=points[segment+2];var p3:Vector3=points[segment+3]
 return .5*(2*p1+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)
static func flight(start:Vector3,bone:Vector3,target:Dictionary,age:float,time_scale:float=1)->Dictionary:
 var t=age/maxf(time_scale,.00001)
 var change=clampf((t-.800000011920929)/.699999988079071,0,1)
 return {"position":spline4(start,start+Draw.ABOVE_DECK,bone,target.position,ease_in_out(t/1.75,4)),"rotation":Hand.lerp_source_angles(Vector3(275,90,0),target.rotation,ease_in_out(change,3)),"scale":(Vector3.ONE*.8799999952316284).lerp(target.scale,ease_in_out(change,5))}
