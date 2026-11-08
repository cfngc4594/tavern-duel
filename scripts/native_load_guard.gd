extends RefCounted
## A stalled graphics cache is a visible failure, never silent infinite loading.
const STALL_MS=120000
const TOTAL_MS=600000
var started_ms=-1
var progress_ms=-1
var progress_key=''
var error=''
func reset():
 started_ms=-1;progress_ms=-1;progress_key='';error=''
func check(now:int,key:String,invalid:String='')->String:
 if not error.is_empty():return error
 if started_ms<0:started_ms=now;progress_ms=now;progress_key=key
 if not invalid.is_empty():error=invalid;return error
 if key!=progress_key:progress_key=key;progress_ms=now
 if now-started_ms>=TOTAL_MS:error='加载超过十分钟，请关闭后重新打开。'
 elif now-progress_ms>=STALL_MS:error='卡面或棋盘连续两分钟未完成加载，请关闭后重新打开。'
 return error
