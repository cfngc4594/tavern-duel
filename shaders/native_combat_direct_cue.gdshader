shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform int cue_kind = 0;
uniform float cue_age = 0.0;
uniform float cue_fade = 1.0;
uniform vec4 _Color : source_color = vec4(0.58, 0.42, 0.27, 1.0);
uniform vec4 _Color2 : source_color = vec4(0.42, 0.36, 0.14, 0.24);
uniform vec4 _SecondColor : source_color = vec4(0.96, 0.94, 0.63, 0.5);
uniform float _Alpha = 0.6;
uniform float _Intensity = 1.25;

void fragment() {
	vec2 center = UV * 2.0 - 1.0;
	float radius = length(center);
	float alpha = 0.0;
	vec3 tint = vec3(1.0, 0.2, 0.025);
	if (cue_kind == 0) {
		float pulse = 0.88 + 0.12 * sin(cue_age * 19.0);
		float core = 1.0 - smoothstep(0.0, 0.35, radius);
		float halo = 1.0 - smoothstep(0.0, 0.9, radius);
		alpha = (core * 0.85 + halo * 0.35) * pulse * smoothstep(0.0, 0.1, cue_age);
		tint = mix(tint, vec3(1.0, 0.83, 0.4), core);
	} else if (cue_kind == 1) {
		float head = 1.0 - smoothstep(0.0, 0.65, length(vec2(center.x, (UV.y - 0.19) * 5.0)));
		float tail = 1.0 - smoothstep(0.04, 0.53 - UV.y * 0.37, abs(center.x));
		tail *= smoothstep(0.03, 0.22, UV.y) * (1.0 - smoothstep(0.22, 1.0, UV.y));
		alpha = head * 0.9 + tail * 0.6;
		tint = mix(tint, vec3(1.0, 0.9, 0.52), head);
	} else if (cue_kind == 2) {
		float spread = mix(0.1, 0.8, smoothstep(0.0, 0.49, cue_age));
		float ring = 1.0 - smoothstep(0.0, 0.2, abs(radius - spread));
		float flash = (1.0 - smoothstep(0.0, 0.7, radius)) * (1.0 - smoothstep(0.08, 0.3, cue_age));
		alpha = (ring * 0.6 + flash * 0.75) * (1.0 - smoothstep(0.15, 0.67, cue_age));
		tint = mix(tint, vec3(1.0, 0.84, 0.48), flash);
	} else {
		float disk = 1.0 - smoothstep(0.04, 0.33, radius);
		float glow = 1.0 - smoothstep(0.03, 0.85, radius);
		float rays = 1.0 - smoothstep(0.0, 0.18, min(abs(center.x), abs(center.y)));
		alpha = (disk * 0.65 + glow * (0.26 + 0.2 * rays)) * _Alpha * clamp(_Intensity, 0.0, 2.0);
		tint = mix(mix(_Color2.rgb, _Color.rgb, glow), _SecondColor.rgb, disk);
	}
	ALBEDO = tint;
	ALPHA = clamp(alpha * cue_fade, 0.0, 1.0);
}
