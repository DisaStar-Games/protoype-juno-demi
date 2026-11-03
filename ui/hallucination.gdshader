shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// The picture sways and ripples.
	vec2 wobble = vec2(sin(uv.y * 14.0 + t * 1.7), cos(uv.x * 11.0 + t * 1.3)) * 0.007 * intensity;
	vec3 col = texture(screen_tex, uv + wobble).rgb;

	// Sickly green tint.
	col = mix(col, col * vec3(0.7, 1.15, 0.8) + vec3(0.0, 0.03, 0.0), intensity * 0.7);

	// Dark edges that pulse.
	float edge = smoothstep(0.35, 0.95, length(uv - 0.5) * 1.4);
	col = mix(col, vec3(0.0, 0.08, 0.02), edge * intensity * (0.5 + 0.2 * sin(t * 2.0)));

	COLOR = vec4(col, 1.0);
}
