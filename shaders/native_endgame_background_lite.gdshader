shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D _ScreenBoard : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D _VignetteMask : filter_linear, repeat_disable;
uniform sampler2D _ResultColor : filter_linear, repeat_disable;
uniform sampler2D _ResultTransmission : filter_linear, repeat_disable;
uniform float _BackdropAmount = 0.0;
uniform float _BackdropSaturation = 1.0;
uniform float _BackdropVignette = 1.0;
uniform bool _HasResult = false;

void fragment() {
	vec3 board = texture(_ScreenBoard, SCREEN_UV).rgb;
	if (_BackdropAmount > 0.0) {
		// Approximate the original three blur passes in one screen-space draw.
		vec2 radius = SCREEN_PIXEL_SIZE * (0.004 / max(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y));
		vec3 soft = board * 0.4;
		soft += texture(_ScreenBoard, SCREEN_UV + radius).rgb * 0.15;
		soft += texture(_ScreenBoard, SCREEN_UV - radius).rgb * 0.15;
		soft += texture(_ScreenBoard, SCREEN_UV + radius * vec2(1.0, -1.0)).rgb * 0.15;
		soft += texture(_ScreenBoard, SCREEN_UV + radius * vec2(-1.0, 1.0)).rgb * 0.15;
		board = mix(board, soft, _BackdropAmount);
		float luminance = dot(board, vec3(0.2126, 0.7152, 0.0722));
		board = mix(vec3(luminance), board, _BackdropSaturation);
		board *= mix(texture(_VignetteMask, UV).r, 1.0, _BackdropVignette);
	}
	if (_HasResult) {
		board = texture(_ResultColor, UV).rgb + texture(_ResultTransmission, UV).rgb * board;
	}
	COLOR = vec4(board, 1.0);
}
