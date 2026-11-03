shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// 0..1: horizontal tearing and colour split.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
// rgb = colour washed over the screen, a = how much.
uniform vec4 flash : source_color = vec4(0.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 24.0);
	float rnd = fract(sin(band * 12.9898 + floor(TIME * 20.0) * 78.233) * 43758.5453);
	float tear = (rnd - 0.5) * 0.09 * glitch * step(0.55, rnd);
	float split = 0.014 * glitch;

	vec3 col;
	col.r = texture(screen_tex, uv + vec2(tear + split, 0.0)).r;
	col.g = texture(screen_tex, uv + vec2(tear, 0.0)).g;
	col.b = texture(screen_tex, uv + vec2(tear - split, 0.0)).b;

	// Wash of colour, strongest at the edges.
	float edge = 0.6 + 0.4 * smoothstep(0.2, 0.9, length(uv - 0.5) * 1.4);
	col = mix(col, flash.rgb, flash.a * edge);
	COLOR = vec4(col, 1.0);
}
