shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.75;

float grain(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 scene = texture(screen_texture, uv).rgb;
	float corners = smoothstep(0.30, 0.78, length((uv - 0.5) * vec2(1.0, 0.78)));
	vec2 pixel = floor(FRAGCOORD.xy / 2.0);
	float paper = (grain(pixel) - 0.5) * 0.026;
	scene = scene * (1.0 - corners * 0.52 * strength);
	scene += paper * strength;
	COLOR = vec4(scene, 1.0);
}
