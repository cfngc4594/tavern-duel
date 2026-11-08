extends RefCounted
# Direct TurnStartIndicator/iTween source equations. Screen projection is deliberately outside this class.
var elapsed: float = 0.0
var running: bool = false
var serial: int = 0
var fade_start_alpha:float=0.0
const DISPLAY_DURATION = 1.5
const DESIRED_DELAY = 1.0 # Getter only; Show itself does not apply this delay.
static func expo_out(t:float) -> float:
 if t>=1.0:return 1.0 # iTween Apply*Targets snaps exact target on completion.
 return 1.0-pow(2.0,-10.0*maxf(0.0,t))
static func sample(t:float) -> Dictionary:
 t=maxf(0.0,t)
 var s=9.800000190734863
 var a=1.0
 var phase="hold"
 if t<.25:
  s=lerpf(1.0,10.0,expo_out(t/.25));a=t/.25;phase="enter"
 elif t<.4000000059604645:
  s=lerpf(10.0,9.800000190734863,expo_out((t-.25)/.15000000596046448));phase="punch"
 elif t>=DISPLAY_DURATION:
  s=lerpf(9.800000190734863,.009999999776482582,expo_out((t-DISPLAY_DURATION)/.25))
  a=clampf(1.0-(t-DISPLAY_DURATION)/.25,0.0,1.0);phase="exit" if t<1.75 else "inactive"
 return {"elapsed":t,"visible":t<1.75,"phase":phase,"alpha":a,"scale":s,"position_delta":Vector3.ONE*.019999999552965164*expo_out(minf(t/DISPLAY_DURATION,1.0))}
func start():
 fade_start_alpha=float(get_audit().alpha)
 serial+=1;elapsed=0.0;running=true
func advance(dt:float) -> Dictionary:
 if running:
  elapsed+=maxf(0.0,dt)
  if elapsed>=1.75:running=false
 return get_audit()
func cancel():running=false;elapsed=1.75
func get_audit() -> Dictionary:
 var result=sample(elapsed)
 if elapsed<.25:result.alpha=lerpf(fade_start_alpha,1.0,elapsed/.25)
 result.fade_start_alpha=fade_start_alpha
 result.visible=result.visible and running;result.serial=serial;result.running=running;result.desired_delay_getter=DESIRED_DELAY
 return result
