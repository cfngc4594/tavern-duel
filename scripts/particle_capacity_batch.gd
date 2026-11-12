extends RefCounted
# The caller can reuse a cursor while existing birth and expiry times stay fixed.
# A rewind or an append outside the batch rebuilds the ordered endpoints.
static func count(context:Dictionary,particles:Array,at:float)->int:
	if not context.has("at") or at<float(context.at) or int(context.get("seen",-1))!=particles.size() or not is_same(context.get("source",[]),particles):
		var births:Array[float]=[];var ends:Array[float]=[]
		for p in particles:
			var birth:float=float(p.birth)
			var end:float=birth+minf(float(p.life),float(p.get("kill_age",INF)))
			# The literal old predicate describes half-open [birth,end).
			# Invalid/zero/negative intervals can never contribute; infinities
			# remain supported by the same comparisons, NaN intervals do not.
			if birth<end:births.append(birth);ends.append(end)
		births.sort();ends.sort()
		context.births=births;context.ends=ends;context.bi=0;context.ei=0;context.heap=[];context.living=0
	var births:Array=context.births;var ends:Array=context.ends;var heap:Array=context.heap
	var bi:int=context.bi;var ei:int=context.ei;var living:int=context.living
	while bi<births.size() and float(births[bi])<=at:living+=1;bi+=1
	while ei<ends.size() and float(ends[ei])<=at:living-=1;ei+=1
	while not heap.is_empty() and float(heap[0])<=at:
		_pop(heap);living-=1
	context.bi=bi;context.ei=ei;context.living=living
	return living
static func add_expiry(context:Dictionary,end:float)->void:
	var heap:Array=context.heap
	var index:int=heap.size();heap.append(end)
	while index>0:
		var parent:int=(index-1)/2
		if float(heap[parent])<=end:break
		heap[index]=heap[parent];index=parent
	heap[index]=end
static func _pop(heap:Array)->void:
	var tail:float=heap.pop_back()
	if heap.is_empty():return
	var index:int=0
	while index*2+1<heap.size():
		var child:int=index*2+1
		if child+1<heap.size() and float(heap[child+1])<float(heap[child]):child+=1
		if float(heap[child])>=tail:break
		heap[index]=heap[child];index=child
	heap[index]=tail
