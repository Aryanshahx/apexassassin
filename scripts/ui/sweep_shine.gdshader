shader_type canvas_item;
render_mode unshaded;

// Works with the splash's alpha-only lettering mask and with the button's
// rectangular ColorRect. The source art and button input remain untouched.
uniform vec4 shine_color : source_color = vec4(1.0, 0.95, 0.75, 0.65);
uniform float rate = 0.60;
uniform float width = 0.12;
uniform bool rounded_button = false;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float position = fract(TIME * rate) * 1.55 - 0.28;
	float diagonal = UV.x + (1.0 - UV.y) * 0.16;
	float band = 1.0 - smoothstep(0.0, width, abs(diagonal - position));
	float edge = 1.0;
	if (rounded_button) {
		// Rounded ends keep the sweep inside the existing rounded button.
		vec2 q = abs(UV - vec2(0.5));
		float corner = length(max(vec2(q.x * 3.5 - 1.55, q.y - 0.34), vec2(0.0)));
		edge = 1.0 - smoothstep(0.11, 0.16, corner);
	}
	COLOR = vec4(shine_color.rgb, source.a * shine_color.a * band * edge);
}
