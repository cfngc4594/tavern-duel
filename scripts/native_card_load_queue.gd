extends RefCounted
## Bounded initial allocation: one live card draw, then two clean completion checks.
var pending:Array=[]
var active=''
var clean_frames=0
var built:Array=[]
func enqueue(keys:Array):
 for key in keys:
  if key!=active and not pending.has(key):pending.append(key)
func reset():pending.clear();active='';clean_frames=0;built.clear()
func has_pending()->bool:return not active.is_empty() or not pending.is_empty()
func tick(ready:Callable,build:Callable)->bool:
 if not active.is_empty():
  clean_frames=clean_frames+1 if ready.call(active) else 0
  if clean_frames<2:return false
  active='';clean_frames=0
 if not pending.is_empty():
  active=pending.pop_front();built.append(active);build.call(active);return false
 return true
func get_audit():return {'active':active,'pending':pending.duplicate(),'clean_frames':clean_frames,'built':built.duplicate(),'max_concurrent_card_builds':1}
