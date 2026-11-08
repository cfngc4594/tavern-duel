extends RefCounted
# Snapshot once per base-solver seek; no resampling or color-space conversion.
const GradientSampler = preload("res://scripts/particle_gradient_sampler.gd")
var mode: int = 0
var low: Color = Color.WHITE
var high: Color = Color.WHITE
var low_gradient: RefCounted
var high_gradient: RefCounted
func setup(data: Dictionary, curves) -> void:
	mode = int(data.get("minMaxState", 0))
	if mode in [0, 2]: high = curves.color(data.get("maxColor", {}))
	if mode == 2: low = curves.color(data.get("minColor", {}))
	if mode in [1, 3, 4]:
		high_gradient = GradientSampler.new(); high_gradient.setup(data.get("maxGradient", {}), curves)
	if mode == 3:
		low_gradient = GradientSampler.new(); low_gradient.setup(data.get("minGradient", {}), curves)
func sample(time: float, mix_value: float) -> Color:
	match mode:
		0: return high
		1: return high_gradient.sample(time)
		2: return low.lerp(high, mix_value)
		3: return low_gradient.sample(time).lerp(high_gradient.sample(time), mix_value)
		4: return high_gradient.sample(mix_value)
	return Color.WHITE
