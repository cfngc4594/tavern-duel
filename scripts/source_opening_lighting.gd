extends RefCounted
## MulliganManager closures0x06005c7a/b: write _LightingBlend on each hero's
## portrait material AND frame material if non-null; then always call actor
## UpdateCustomFrameLightingBlend(value). No camera/world light intensity change.
## Intro0x06005cff invokes each closure(0) immediately alongside camera shake,
## then schedules iTween.ValueTo(from0,to1,delay2,time1,default easeOutExpo16).
## ApplyFloatTargets0x06000049 explicitly snaps onupdateparams to1 at completion.
const DELAY:float=2.0
const DURATION:float=1.0
static func blend(age_since_scheduled:float)->float:
	if age_since_scheduled<=DELAY:return 0.0
	if age_since_scheduled>=DELAY+DURATION:return 1.0
	return 1.0-pow(2.0,-10.0*(age_since_scheduled-DELAY)/DURATION)
