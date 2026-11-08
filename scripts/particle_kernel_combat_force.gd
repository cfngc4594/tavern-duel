extends "res://scripts/particle_kernel_combat.gd"
# Pure numerical specialization; all integration remains inherited.
var _force_randomized: bool = false
var _force_world: bool = false
var _force_modes := PackedInt32Array()
var _force_low := PackedFloat64Array()
var _force_high := PackedFloat64Array()
var _force_context_active: bool = false
var _force_seed_x: int = 0
var _force_seed_y: int = 0
var _force_seed_z: int = 0
var _force_inverse := Basis.IDENTITY
var _force_gravity := Vector3.ZERO
var _force_has_gravity: bool = false


func prepare() -> void:
	super.prepare()
	_prepare_force_parameters()

func _particle_state(p: Dictionary, age: float) -> Dictionary:
	var previous: bool = _force_context_active
	_prime_force_context(p)
	var state: Dictionary = super._particle_state(p, age)
	_force_context_active = previous
	return state

func _acceleration(p: Dictionary, normalized: float, step_index: int = 0) -> Vector3:
	if _force_context_active: return _prepared_acceleration(step_index)
	return super._acceleration(p, normalized, step_index)

# Main-thread setup; raw remains read-only until all worker tasks have joined.
func _prepare_force_parameters() -> void:
	_force_context_active = false
	var force: Dictionary = raw.get("ForceModule", {})
	_force_randomized = bool(force.get("enabled", false)) and bool(force.get("randomizePerFrame", false))
	_force_world = bool(force.get("inWorldSpace", false))
	_force_modes.clear(); _force_low.clear(); _force_high.clear()
	if not _force_randomized: return
	for axis in ["x", "y", "z"]:
		var curve: Dictionary = force.get(axis, {})
		var mode: int = int(curve.get("minMaxState", 0))
		if mode not in [0, 3]: _force_randomized = false; return
		var high: float = Curves.number(curve.get("scalar", 0.0))
		var low: float = Curves.number(curve.get("minScalar", high)) if mode == 3 else high
		if not is_finite(low) or not is_finite(high): _force_randomized = false; return
		_force_modes.append(mode)
		_force_high.append(high)
		_force_low.append(low)

# Only mode 0/3 force/gravity is admitted by the owning base solver's gate.
func _prime_force_context(p: Dictionary) -> void:
	_force_context_active = _force_randomized
	if not _force_context_active: return
	var mix: Vector3 = p.force_mix
	_force_seed_x = int(mix.x * 2147483647.0) + 15485863
	_force_seed_y = int(mix.y * 2147483647.0) + 2 * 15485863
	_force_seed_z = int(mix.z * 2147483647.0) + 3 * 15485863
	var gravity_curve: Dictionary = raw.get("InitialModule", {}).get("gravityModifier", {})
	if int(gravity_curve.get("minMaxState", 0)) not in [0, 3]: _force_context_active = false; return
	var gravity: float = Curves.minmax(gravity_curve, 0.0, p.gravity_mix)
	if not is_finite(gravity): _force_context_active = false; return
	_force_has_gravity = absf(gravity) > EPSILON
	if (_force_world or _force_has_gravity) and (not is_finite(p.motion_basis.determinant()) or p.motion_basis.determinant() == 0.0): _force_context_active = false; return
	_force_inverse = p.motion_basis.inverse() if _force_world or _force_has_gravity else Basis.IDENTITY
	if _force_has_gravity: _force_gravity = _force_inverse * (compatibility_basis * source_gravity * gravity)

func _force_step_mix_prepared(step_index: int) -> Vector3:
	var term: int = maxi(0, step_index) * 104729
	var x: int = (_force_seed_x + term) & 0x7fffffff
	x = ((x ^ (x >> 16)) * 1103515245 + 12345) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1103515245 + 12345) & 0x7fffffff
	var y: int = (_force_seed_y + term) & 0x7fffffff
	y = ((y ^ (y >> 16)) * 1103515245 + 12345) & 0x7fffffff
	y = ((y ^ (y >> 13)) * 1103515245 + 12345) & 0x7fffffff
	var z: int = (_force_seed_z + term) & 0x7fffffff
	z = ((z ^ (z >> 16)) * 1103515245 + 12345) & 0x7fffffff
	z = ((z ^ (z >> 13)) * 1103515245 + 12345) & 0x7fffffff
	return Vector3(float(x) / 2147483648.0, float(y) / 2147483648.0, float(z) / 2147483648.0)

func _prepared_acceleration(step_index: int) -> Vector3:
	var mix: Vector3 = _force_step_mix_prepared(step_index)
	var result := Vector3(_force_high[0] if _force_modes[0] == 0 else lerpf(_force_low[0], _force_high[0], mix.x), _force_high[1] if _force_modes[1] == 0 else lerpf(_force_low[1], _force_high[1], mix.y), _force_high[2] if _force_modes[2] == 0 else lerpf(_force_low[2], _force_high[2], mix.z))
	if _force_world: result = _force_inverse * (compatibility_basis * result)
	if _force_has_gravity: result += _force_gravity
	return result
