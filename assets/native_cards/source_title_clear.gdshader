shader_type canvas_item;
render_mode unshaded, blend_disabled;
// UberText SetTargetClearColor: outline RGB with alpha=0, not transparent black.
void fragment(){COLOR=vec4(0.03921568766236305,0.0303975660353899,0.021530181169509888,0.0);}
