extends RefCounted
# Every job owns its kernel, arrays and shallow particle copies. Nested particle
# arrays are read-only here; only top-level saved numerical fields are changed.
var kernel: RefCounted
var particles: Array = []
var ages: Array[float] = []
var indices: Array[int] = []
var states: Array = []
func run() -> void:
	for index in range(particles.size()):
		states.append(kernel._particle_state(particles[index], ages[index]))
