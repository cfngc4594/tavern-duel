extends RefCounted
# Every job owns its kernel and arrays. The caller supplies copies or gives a
# job exclusive use of each particle until join. Nested arrays are read-only.
var kernel: RefCounted
var particles: Array = []
var ages: Array[float] = []
var indices: Array[int] = []
var states: Array = []
func run() -> void:
	for index in range(particles.size()):
		states.append(kernel._particle_state(particles[index], ages[index]))
